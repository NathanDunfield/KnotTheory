(* ::Package:: *)

(************************************************************************)
(* This file was generated automatically by the Mathematica front end.  *)
(* It contains Initialization cells from a Notebook file, which         *)
(* typically will have the same name as this file except ending in      *)
(* ".nb" instead of ".m".                                               *)
(*                                                                      *)
(* This file is intended to be loaded into the Mathematica kernel using *)
(* the package loading commands Get or Needs.  Doing so is equivalent   *)
(* to using the Evaluate Initialization Cells menu command in the front *)
(* end.                                                                 *)
(*                                                                      *)
(* DO NOT EDIT THIS FILE.  This entire file is regenerated              *)
(* automatically each time the parent Notebook file is saved in the     *)
(* Mathematica front end.  Any changes you make to this file will be    *)
(* overwritten.                                                         *)
(************************************************************************)



(* ::Input::Initialization:: *)
BeginPackage["KnotTheory`UniversalKh`",{"KnotTheory`","QuantumGroups`Utilities`MatrixWrapper`"}];


(* ::Input::Initialization:: *)
UniversalKh::about="Universal Khovanov homology over Q[t] is calculated using Jeremy Green's JavaKh program, interpreted by a wrapper written by Dror Bar-Natan, and decomposed into direct summands using a program of Scott Morrison and Alexander Shumakovitch.";


(* ::Input::Initialization:: *)
UniversalKh::usage="UniversalKh[K] computes the universal Khovanov homology over Q. (Probably broken for links, at present.) See also KhC and KhE for more about the output.";


(* ::Input::Initialization:: *)
sInvariant::usage="sInvariant[K] computes the s-invariant of a knot K, using the UniversalKh program. (Probably broken for links, at present.)";


(* ::Input::Initialization:: *)
KhReduced::usage="KhReduced[K][q,t] gives the reduced Khovanov homology of the knot K, using the UniversalKh program.";


(* ::Input::Initialization:: *)
KhE::usage="KhE denotes a free generator in Khovanov homology, corresponding to an exceptional pair. See ?UniversalKh for more information."
KhC::usage="KhC denotes a torsion generator in Khovanov homology, with the differential in KhC[n] being the n-th power of the punctured torus. Thus KhC[1] corresponds to a knight's move pair. See ?UniversalKh for more information."


(* ::Input::Initialization:: *)
Begin["`Private`"]


(* ::Input::Initialization:: *)
q=Global`q;t=Global`t;
(* NMD: Additional globals for readable debugging output*)
M=Global`M;h=Global`h;
T=Global`T;H=Global`H;
Arc=Global`Arc;
Curtain=Global`Curtain;


(* ::Input::Initialization:: *)
KhN[pd_PD,options___] := KhN[pd,options]=Module[
{n,pd1,  f, cl, out,kh,saveContext,saveContextPath,JavaKhDirectory,jarDirectory,classDirectory,classpath,new=True,javaoptions, ans},

javaoptions=(JavaOptions/.{options}/.Options[Kh]);

n=Max @@ (Max @@@ pd);
pd1 = pd /. {
X[n, i_, 1, j_] :> X[n, i, n+1, j],
X[i_, 1, j_, n] :> X[i, n+1, j, n],
X[1, j_, n, i_] :> X[n+1, j, n, i],
X[j_, n, i_, 1] :> X[j, n, i, n+1]
};

(* Print["pd1->",pd1]; *)

new=True; (* This is just an option for Scott, to allow comparing against Jeremy's program before butchering it. *)
If[new,
JavaKhDirectory=ToFileName[KnotTheoryDirectory[],"JavaKh-v2"];
classpath=KnotTheory`FastKh`JavaKhv2ClassPath[];,
JavaKhDirectory=ToFileName[KnotTheoryDirectory[],"JavaKh-v1"];
classpath=KnotTheory`FastKh`JavaKhv1ClassPath[];,
];

SetDirectory[JavaKhDirectory];
f=OpenWrite["pd",PageWidth->Infinity];
WriteString[f,ToString[pd1]];
Close[f];

cl=StringJoin["!java -classpath \"",classpath,"\" ",javaoptions," org.katlas.JavaKh.JavaKh -U -Q < pd 2> JavaKh.log"];
f=OpenRead[cl];
out=Read[f,Expression];
Close[f];

If[out==EndOfFile,Print["Something went wrong running JavaKh; nothing was returned. The command line was: "];Print[cl];Print["There may have been an error log produced by Java: "];
FilePrint["JavaKh.log"];Return[$Failed]];

ResetDirectory[];

out=StringReplace[out,{"q"->"#1","t"->"#2"}];
(* ToExpression is dangerous! We have to fiddle with the $Context here. *)
saveContext=$Context;
saveContextPath=$ContextPath;
$Context="KnotTheory`UniversalKh`Private`";
$ContextPath={"KnotTheory`UniversalKh`Private`"};
kh=ToExpression[out<>"&"][q,t];
$Context=saveContext;
$ContextPath=saveContextPath;
(* Print["kh->",kh]; *)
minr=Exponent[kh, t, Min];
maxr=Exponent[kh, t, Max];
obs = Expand[kh /. h -> 0 /. M[_, n_, ___]  :> Plus @@ Array[Arc, n]];
obs = obs /. (q^j_.)*Arc[i_] :> Arc[j, i] /. Arc[i_] :> Arc[0, i];
mos= Expand[
h*kh /. {M[0,_]-> 0, M[_, 0] -> 0, h-> H}
/. M[m_, n_, cs___] :> Plus @@ Flatten[MapIndexed[
(#1*Curtain@@Reverse[#2])&,
Partition[{cs}, n],
{2}
]]
];
mos = mos /. (q^j_.)*Curtain[k_, l_] :> Curtain[j, k, l] /. Curtain[k_, l_] :> Curtain[0, k, l];
mos = mos /. (H^g_.)*Curtain[j_, k_, l_] :> H^(g-1)Curtain[j, k, j+2(g-1), l];
ans = Komplex @@ Table[{r, Coefficient[obs, t, r],  Coefficient[mos, t, r]}, {r, minr, maxr}];
(* Print["gradings list->", GradingsList[ans]]; *)
(* Print["all matrices->", AllMatrices[ans]]; *)
ans
]


(* ::Input::Initialization:: *)
RemoveUnnecessaryZeros[A_SparseArray] := SparseArray[A, A["Dimensions"], 0]


(* ::Input::Initialization:: *)
ElementaryMatrix[m_,n_,i_,j_]/;1<=i<=m\[And]1<=j<=n:= SparseArray[{{i,j}->1},{m,n},0]


(* ::Input::Initialization:: *)
ReplaceAllInEntries[s_SparseArray,rule_]:=With[
{elem=ReplaceAll[s["NonzeroValues"],rule],
def=Replace[s["Background"],rule]},
SparseArray[Automatic,s["Dimensions"],def,{1,{s["RowPointers"],s["ColumnIndices"]},elem}]
]


(* ::Input::Initialization:: *)
GradingsList[k:Komplex[{n_,_,_},___]]:={n,Cases[{#},Arc[m_,_]:>m,2]&/@(List@@k)[[All,2]]}


(* ::Input::Initialization:: *)
AllMatrices[k:Komplex[{n_,_,_},___]]:={n,
Module[{gradings=GradingsList[k][[2]],dimensions,matrix, matrices},
dimensions=Length/@gradings;
Table[
matrix=SparseArray[{}, {dimensions[[i+1]],dimensions[[i]]}, 0];
If[!SparseArrayQ[matrix], matrix,
matrix =matrix+(k[[i,3]]/.(Curtain[q1_,m1_,q2_,m2_]:>ElementaryMatrix[dimensions[[i+1]],dimensions[[i]],Position[gradings[[i+1]],q2][[1,1]]+m2-1,Position[gradings[[i]],q1][[1,1]]+m1-1]));
matrix = RemoveUnnecessaryZeros[matrix];
matrix =  ReplaceAllInEntries[matrix, H->T]]
,{i,1,Length[k]-1}]
]
}


(* ::Input::Initialization:: *)
ZeroVector[n_]:=Table[0,{n}]


(* ::Input::Initialization:: *)
Matrix/:\[Alpha]_ Matrix[j_,k_,data_]/;(NumberQ[\[Alpha]/.T->3.14159`]):=Matrix[j,k,\[Alpha] data]


(* ::Input::Initialization:: *)
FirstRow[Matrix[r_,c_,data_]]:=Matrix[1,c,{First[data]}]
FirstRow[Matrix[0,c_,_]]:=Matrix[0,c]
FirstColumn[Matrix[r_,c_,data_]]:=Matrix[r,1,{First[#]}&/@data]
FirstColumn[Matrix[r_,0,_]]:=Matrix[r,0]
RestColumns[Matrix[r_,c_,data_]]:=Matrix[r,c-1,Rest/@data]
RestColumns[Matrix[r_,0|1,_]]:=Matrix[r,0]
RestRows[Matrix[r_,c_,data_]]:=Matrix[r-1,c,Rest[data]]
RestRows[Matrix[0|1,c_,_]]:=Matrix[0,c]


(* ::Input::Initialization:: *)
RotateRows[Matrix[r_,c_,data_]]:=Matrix[r,c,RotateLeft[data]]
RotateColumns[Matrix[r_,c_,data_]]:=Matrix[r,c,RotateLeft/@data]


(* ::Input::Initialization:: *)
RotateRows[Matrix[r_,c_,data_],n_]:=Matrix[r,c,RotateLeft[data,n]]
RotateColumns[Matrix[r_,c_,data_],n_]:=Matrix[r,c,RotateLeft[#,n]&/@data]


(* ::Input::Initialization:: *)
DegenerateSparse[A_SparseArray] := False;
DegenerateSparse[{}] = True;
DegenerateSparse[{{}}]= True;

SparseZeroQ[{}] = True;
SparseZeroQ[{{}}] = True;
SparseZeroQ[A_SparseArray] := Module[{entries},
entries = Union[Map[#[[2]]&, ArrayRules[A]]];
entries == {0}
]

InitialSubmatrix[A_SparseArray, a_, b_] := Module[
{keep},
keep[rule_Rule] := Module[{i, j}, {i, j} = rule[[1]]; ((i <= a)&& (j <= b)) || (i == j == _)];
SparseArray[Select[ArrayRules[A], keep], {a, b}]
]

FirstColumn[A_SparseArray] := InitialSubmatrix[A, A["Dimensions"][[1]], 1]
FirstRow[A_SparseArray] := InitialSubmatrix[A, 1, A["Dimensions"][[2]]]

TerminalSubmatrix[A_SparseArray, a_, b_] := Module[{rule, rules, newrules, i, j, r, m, n},
rules = ArrayRules[A];
newrules = {};
Do[
rule = rules[[r]];
{i, j} = rule[[1]];
If[(a <= i)&& (b <= j), AppendTo[newrules, {i - a +1, j - b + 1} -> rule[[2]]];
If [SameQ[{i, j}, {_, _}], AppendTo[newrules, rule]];
(a <= i)&& (b <= j),{i - a +1, j - b + 1} -> rule[[2]]], 
  {r, Length[rules]}
];
{m, n} = A["Dimensions"];
SparseArray[newrules, {m  - a + 1, n - b + 1}]
]

RestColumns[A_SparseArray] := TerminalSubmatrix[A, 1, 2];RestRows[A_SparseArray] := TerminalSubmatrix[A, 2, 1];
RestRows[{{}}] := {};

RotateSparse[A_SparseArray, a_, b_] := Module[{m, n, i, j,rule, newrules, rules},
{m, n} = A["Dimensions"];
rules = ArrayRules[A];
newrules = {};
Do[
rule = rules[[r]];
{i, j} = rule[[1]];
If [SameQ[{i, j}, {_, _}],
AppendTo[newrules, rule],
AppendTo[newrules, {Mod[i + a, m, 1], Mod[j + b, n, 1]} -> rule[[2]]]
],
{r, Length[rules]}];
SparseArray[newrules, {m, n}]
]


(* ::Input::Initialization:: *)
MinTExpWithPosition[A_SparseArray] := Module[{nonzero},
nonzero = Select[ArrayRules[A], !SameQ[#[[2]], 0]&];
LexicographicSort[Map[{Exponent[#[[2]], T], #[[1]]}&, nonzero]][[1]]
]


(* ::Input::Initialization:: *)
UniversalKhTimingData={};


(* ::Input::Initialization:: *)
twist[\[Alpha]_,k_,\[Lambda]_,\[Mu]_,\[Nu]_]:=Module[{ans},
If[DegenerateSparse[\[Nu]],
SparseArray[{}, {0, 0}],
\[Nu]-(1/\[Alpha])T^(-k)\[Mu] . \[Lambda]]
]


(* ::Input::Initialization:: *)
UniversalKh[K:((Knot|Link|TorusKnot)[_Integer,__]),options___]:=UniversalKh[K,options]=Module[{khn,result,components,factor},
CreditMessage[UniversalKh::about];
If[Length[Skeleton[K]]>1,
Print["Warning: UniversalKh is currently *broken* for links. It may be a simple matter of dividing the coefficient of KhE by (q+q^{-1}), but we haven't identified the bug."];
];
khn=KhN[PD[K],options];
result=AbsoluteTiming[DecomposeComplex[GradingsList[khn],AllMatrices[khn]]];
AppendTo[UniversalKhTimingData,{K,result[[1]]/.Second->1}];
result[[2]]
]
UniversalKh[d_PD,options___]:=With[{khn=KhN[d,options]},
DecomposeComplex[GradingsList[khn],AllMatrices[khn]]
]


(* ::Input::Initialization:: *)
DecomposeComplex[{g0_,gradings0_},{g0_,matrices0_List}]:=Module[{g=g0,gradings=gradings0,matrices=matrices0,result=0,matrix,objects,exponents,i,j,k,\[Alpha],\[Lambda],\[Mu],\[Nu]},
(* Print["Starting decomp"];*)
While[Length[matrices]>0,objects=gradings[[1]];matrix=matrices[[1]];
(* Print["matrix->", matrix]; *)
While[!SparseZeroQ[matrix],
{k, {i, j}}= MinTExpWithPosition[matrix];
If[k==0,
Print["Found an isomorphism I wasn't expecting!"];
Print["Result so far: ",result];
Print["Remaining objects at this height: ",objects];
Print["Remaining matrices at this height: ",matrix];
Print["Other gradings: ",gradings];
Print["Other matrices: ",matrices];
Return[$Failed]];
objects=RotateLeft[objects,j-1];
gradings[[2]]=RotateLeft[gradings[[2]],i-1];
matrix=RotateSparse[matrix,-(i - 1), -(j- 1)];

If[Length[matrices]>1,matrices[[2]]=RotateSparse[matrices[[2]],0, -(i-1)]];
\[Alpha]=matrix[[1,1]]/T^k;
\[Lambda]=RestColumns[FirstRow[matrix]];
\[Mu]=RestRows[FirstColumn[matrix]];
\[Nu]=RestRows[RestColumns[matrix]];
matrix=twist[\[Alpha],k,\[Lambda],\[Mu],\[Nu]];
If[Length[matrices]>1,matrices[[2]]=RestColumns[matrices[[2]]]];
result+=t^(g+1) q^(2 k+objects[[1]]) KhC[k];
objects=Rest[objects];
gradings[[2]]=Rest[gradings[[2]]];];
If[!SparseZeroQ[matrix],
Print["I was expecting the matrix to be zero now."];
Print["Result so far: ",result];
Print["Remaining objects at this height: ",objects];
Print["Remaining matrices at this height: ",matrix];
Print["Other gradings: ",gradings];
Print["Other matrices: ",matrices];
Return[$Failed]];
result+=KhE Plus@@(t^g q^#1&)/@objects;
matrices=Rest[matrices];
gradings=Rest[gradings];
g++;];
result+=KhE Plus@@(t^g q^#1&)/@gradings[[1]];result]


(* ::Input::Initialization:: *)
sInvariant[K_]:=With[{ukh=UniversalKh[K]},
If[Length[Position[ukh,KhE]]==1,
Replace[ukh/.{_KhC:>0,KhE->1},{q^s_.:>s,1->0}],
ukh/.{_KhC:>0,KhE->1}
]
]


(* ::Input::Initialization:: *)
\[Alpha]0rules={KhE->q+q^-1,KhC[1]->t^-1 q^-3+ q^1,KhC[n_]/;n>=2:>(q+q^-1)(t^-1 q^(-2n)+1)};


(* ::Input::Initialization:: *)
reducedRules={KhE->q^-1,KhC[n_]:>t^-1 q^(-2n-1)+q^-1};


(* ::Input::Initialization:: *)
KhReduced[K_]:=Function[{q,t},Evaluate[Expand[UniversalKh[K]/.reducedRules]]]


(* ::Input::Initialization:: *)
End[]


(* ::Input::Initialization:: *)
EndPackage[]
