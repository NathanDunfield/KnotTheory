(* ::Package:: *)

BeginPackage["KnotTheory`"]

$RecursionLimit = 65536;

Kh::usage = "Kh[L][q, t] returns the Poincare polynomial of the
Khovanov Homology of a knot/link L (over a field of characteristic 0)
in terms of the variables q and t. Kh[L, Program -> prog] uses the
program prog to perform the computation. The currently available
programs are \"FastKh\", written in Mathematica by Dror Bar-Natan in
the winter of 2005, \"JavaKh-v1\", written in java (java 1.5
required!) by Jeremy Green in the summer of 2005 and \"JavaKh-v2\" (default), an update of \"JavaKh-v1\" (now requiring java 1.6) written by Scott Morrison in 2008.
(\"JavaKh\" is also available, currently an alias for \"JavaKh-v2\".)
The java programs are several thousand times faster than the Mathematica program, though java
may not be available on some systems. \"JavaKh2\" also takes the option
\"Modulus -> p\" which changes the characteristic of the ground field
to p. If p==0 JavaKh works over the rational numbers; if p==Null JavaKh
works over Z (see ?ZMod for the output format)."

JavaOptions::usage = "JavaOptions is an option to Kh. Kh[L, Program ->
\"JavaKh2\", JavaOptions -> jopts] calls java with options jopts. Thus
for example, JavaOptions -> \"-Xmx256m\" sets the maximum java heap
size to 256MB - useful for large computations."

ZMod::usage = "ZMod[m] denotes the cyclic group Z/mZ. Thus if m=0 it is the
infinite cyclic group Z and if m>0 it is the finite cyclic group with m
elements. ZMod[m1, m2, ...] denotes the direct sum of ZMod[m1],
ZMod[m2], ... .";

ExpansionOrder; Program;

TabularKh::usage = "TabularKh[polynomial, {diagonals}] generates an html table displaying the coefficients
of the polynomial, with diagonals highlighted. The tables appearing in the Knot Atlas are generated using
TabularKh[Kh[K][q,t], KnotSignature[K]+{1,-1}]";

(* Here we expose just a few of the names in the context KnotTheory`FastKh`Tangles`.
   You can thus use AppendTo[$ContextPath, "KnotTheory`FastKh`Tangles`"], and gain access to these symbols,
   without importing all the local variables from the implementations below. *)

BeginPackage["KnotTheory`FastKh`Tangles`"]

bdot; Morphisms; Objects; Smoothing; MM; e; Q; KhComplex; HC; Kom; DeLoop; Contract;

EndPackage[]

Begin["`FastKh`"]

bdot[_]^_ ^=0; tdot[_]^_ ^=0;

EquivalenceClasses[l_List] := Module[{pos}, Fold[
      (
          pos = First /@ Position[#1, #2];
          Append[Delete[#1, List /@ pos], Union@@(#1[[pos]])]
          )&,
      l, Union @@ l
]];

DotRule[top_, bot_] := DotRule[top, bot] = Module[{z}, Flatten[Cases[
  DeleteCases[
    EquivalenceClasses[Join[
      Cases[{top}, P[i_,j_][m_] :> {z@i,z@j,tdot@m}, Infinity],
      Cases[{bot}, P[i_,j_][m_] :> {z@i,z@j,bdot@m}, Infinity]
    ]],
    _z, {2}
  ],
  l_List :> ((# -> First[l])& /@ l)
]]];

HCLaw[
        Cobordism[top1_Smoothing,bot1_Smoothing],
        Cobordism[top2_Smoothing,bot2_Smoothing]
        ] /; MemberQ[{top1, bot1, top2, bot2}, Q, Infinity] := MapAt[
      (Q^Exponent[Times@@bot1, Q]*Q^Exponent[Times@@bot2, Q])&,
      MapAt[
        (Q^Exponent[Times@@top1, Q]*Q^Exponent[Times@@top2, Q])&,
        HCLaw[Cobordism[top1, bot1] /. Q->1, 
          Cobordism[top2, bot2] /. Q->1],
        {1,1,1}
        ],
      {1,2,1}
      ];

(*
  Note: Gluing d disks along z zippers, the result has b boundaries and
  genus g with 2g=2+z-d-b.
*)
HCLaw[
  Cobordism[top1_Smoothing, bot1_Smoothing],
  Cobordism[top2_Smoothing, bot2_Smoothing]
] /; FreeQ[{top1, bot1, top2, bot2}, Q] := HCLaw[
  Cobordism[top1, bot1], Cobordism[top2, bot2]
] = Module[
  {dr, top, bot, dots, handles=1, h, g2, decors, law, to, cob},
  dr = DotRule[top1 top2, bot1 bot2];
  top = Smoothing[
    First@top1*First@top2 //. P[i_, j_][m_] P[j_, k_][n_] :> (
      P[i, k][Min[m, n]]
    ) /. {
      P[i_, j_][m_]^2 :> (handles /= (tdot[m] /. dr /. bdot -> h); Loop[m]),
      P[i_, i_][m_] :> (handles /= (tdot[m] /. dr /. bdot -> h); Loop[m])
    }
  ];
  bot=Smoothing[
    First@bot1*First@bot2 //. P[i_, j_][m_] P[j_, k_][n_] :> (
      handles *= (bdot[m] /. dr /. bdot -> h);
      P[i, k][Min[m, n]]
    ) /. {
      P[i_, j_][m_]^2 :> (handles *= (bdot[m] /. dr /. bdot -> h); Loop[m]),
      P[i_, i_][m_] :> Loop[m]
    }
  ];
  dots = Union[
    Last /@ DotRule[top, bot],
    Cases[{top}, Loop[m_] :> tdot[m], Infinity],
    Cases[{bot}, Loop[m_] :> bdot[m], Infinity]
  ];
  handles *= Times @@ (Union[Last /@ dr] /. bdot -> h)^2;
  handles /= Times @@ (
    Join[
      Union[Last /@ DotRule[top1, bot1]],
      Union[Last /@ DotRule[top2, bot2]],
      Union[Last /@ DotRule[top, bot]]
    ] /. dr /. bdot -> h
  );
  decors = Expand[(handles /. h[m_]^g2_ :> (2bdot[m])^(g2/2)) *
    Times @@ MapThread[
      If[#1===#2, 1, #1+#2]&,
      {dots, dots /. dr}
    ]
  ];
  law = Union[
    Last /@ DotRule[top1, bot1], Last /@ DotRule[top2, bot2]
  ];
  law = DeleteCases[
    Thread[to[law, law /. dr]],
    to[m_, m_]
  ] /. to -> Rule;
  {Cobordism[top, bot, decors], law}
];

HC[0, _] = HC[_, 0] = 0;
HC[Smoothing[s1_], Smoothing[s2_]]:= Smoothing[
  s1 s2 //. P[i_, j_][m_] P[j_, k_][n_]:> P[i, k][Min[m, n]]
    /. {P[i_, j_][m_]^2 :> Loop[m], P[i_, i_][m_] :> Loop[m]}
];

HC[n1_.*e[t1__]*s1_Smoothing, n2_.*e[t2__]*s2_Smoothing] :=
    n1 n2 e[t1,t2]HC[s1, s2];

HC[
      Cobordism[top1_Smoothing,bot1_Smoothing, ds1_],
      Cobordism[top2_Smoothing,bot2_Smoothing, ds2_]
      ] := Module[
      {cob, law},
      {cob,law} = HCLaw[
          Cobordism[top1, bot1], Cobordism[top2, bot2]
          ];
      cob = MapAt[Expand[(ds1 ds2 /. law)*#]&, cob, 3];
      cob
      ];

HC[a_Plus, b_] := HC[#, b]& /@ a;
HC[a_, b_Plus] := HC[a, #]& /@ b;

HC[Morphism[top_, bot_, a_+b_], s_] := Plus[
      HC[Morphism[top, bot, a],s],
      HC[Morphism[top, bot, b],s]
      ];
HC[Morphism[top_, bot_, MM[e[i___],e[j___], mat_]], e[k___] * s_Smoothing] :=
    Module[
      {cob, law},
      {cob, law} = HCLaw[
          Cobordism[Coefficient[top, e[i]], Coefficient[bot, e[j]]],
          Cobordism[s,s]
          ];
      MM[e[i,k], e[j,k], Expand[Last[cob]*(mat /. law)]]
      ];

HC[s_, Morphism[top_, bot_, a_Plus]] := HC[s, Morphism[top, bot, #]]& /@ a

HC[e[k___] * s_Smoothing, Morphism[top_, bot_, MM[e[i___],e[j___], mat_]]] :=
    Module[
      {cob, law},
      {cob, law} = HCLaw[
          Cobordism[s,s],
          Cobordism[Coefficient[top, e[i]], Coefficient[bot, e[j]]]
          ];
      MM[e[k,i], e[k,j], Expand[Last[cob]*(mat /. law)]]
      ];

HC[
      Kom[f1_, obs1_, mos1_],
      Kom[f2_, obs2_, mos2_]
      ] := Module[
      {l1, l2, k, j1, j2, obs, morph, mos, rule},
      l1=Length[obs1]-1; l2=Length[obs2]-1;
      obs=Objects @@ Table[
            Plus @@ Table[
                j2=k-j1;
                HC[obs1[[1+j1]], obs2[[1+j2]]] /. 
                  e[t__] :> e[t, j1],
                {j1,Max[0,k-l2],Min[l1, k]}
                ],
            {k,0,l1+l2}
            ];
      mos = Morphisms @@ Table[
            Plus @@ Table[
                j2=k-j1;
                Plus[
                  If[1+j1 > l1 || mos1[[1+j1]] === 0 || obs2[[1+j2]]===0,
                    0, 
                    HC[
                        Morphism[obs1[[1+j1]], obs1[[2+j1]], mos1[[1+j1]]],
                       obs2[[1+j2]]
                        ] /. 
                      MM[e[t1__], e[t2__], mm_] :> 
                        MM[e[t1, j1], e[t2, j1+1], mm]
                    ],
                  If[1+j2 > l2 || obs1[[1+j1]] === 0 || mos2[[1+j2]] === 0,
                   0, 
                    HC[
                        obs1[[1+j1]],
                        Morphism[obs2[[1+j2]], obs2[[2+j2]], mos2[[1+j2]]]
                       ] /. 
                      MM[e[t1__], e[t2__], mm_] :> 
                        MM[e[t1, j1], e[t2, j1], Expand[(-1)^j1*mm]]
                    ]
                  ],
                {j1,Max[0,k-l2],Min[l1, k]}
                ],
            {k, 0, l1+l2-1}
            ];
      ReTag[Kom[f1+f2, obs, mos]]
      ];

ReTag[kom_Kom] := Module[
    {f, obs, mos, l},
    {f, obs, mos} = List @@ kom;
    l=Length[obs]-1;
    Do[
      rule = Union[Cases[{obs[[1+k]]}, _e, Infinity]];
      rule = Thread[Rule[rule, e /@ Range[Length[rule]]]];
      obs[[1+k]] = obs[[1+k]] /. rule;
      If[k<l,
        mos[[1+k]] = 
          mos[[1+k]] /. 
            MM[e1_, e2_, mm_] :> MM[e1 /. rule, e2, mm]
        ];
      If[k>0,
        mos[[k]] = 
          mos[[k]] /. MM[e1_, e2_, mm_] :> MM[e1, e2 /. rule, mm]
        ],
      {k, 0, l}
      ];
    Kom[f, obs, mos]
    ]

(*
  Note: Gluing d disks along z zippers, the result has b boundaries and
  genus g with 2g=2+z-d-b.
*)
VCLaw[
  Cobordism[top_Smoothing,mid_Smoothing],
  Cobordism[mid_Smoothing,bot_Smoothing]
] := VCLaw[Cobordism[top, mid], Cobordism[mid, bot]] = Module[
  {decors, law1, law2, dots, dots1, dots2, dr1, dr2, dr, to, h, g2},
  {law1, law2} = {{}, {}};
  decors = Times @@ Cases[
    {mid},
    Loop[m_] :> (
      AppendTo[law1, bdot[m] -> mdot[m]];
      AppendTo[law2, tdot[m] -> mdot[m]];
      mdot[m]
    ),
    Infinity
  ];
  dots = Union[Last /@ DotRule[top, bot]];
  dots1 = Union[Last /@ (dr1 = DotRule[top, mid] /. bdot -> mdot)];
  dots2 = Union[Last /@ (dr2 = DotRule[mid, bot] /. tdot -> mdot)];
  dr = Flatten[Cases[
    EquivalenceClasses[Join[List @@@ dr1, List @@@ dr2]],
    l_List :> ((# -> First[l])& /@ Rest[l])
  ]];
  decors *= Times @@ (Union[Last /@ dr] /. bdot -> h)^2;
  decors *= Times @@ (
    Cases[mid, P[__][m_] :> mdot[m], Infinity] /. dr /. bdot -> h
  );
  decors /= Times @@ (Join[dots1, dots2, dots] /. dr /. bdot -> h);
  decors = decors /. h[m_]^g2_ :> (2bdot[m])^(g2/2);
  decors *= Expand[Times @@ MapThread[
    If[#1===#2, 1, #1+#2]&,
    {dots, dots /. dr}
  ]];
  law1 = Join[law1,
    DeleteCases[
        Thread[to[dots1, dots1 /. dr]] /. mdot -> bdot,
        to[m_, m_]
      ] /. to -> Rule
    ];
  law2 = Join[law2,
    DeleteCases[
        Thread[to[dots2, dots2 /. dr]],
        to[m_, m_]
      ] /. to -> Rule
    ];
  {law1, law2, decors}
];

VC[a_, b_, c__] := VC[a, VC[b,c]];
VC[
      Cobordism[top_Smoothing,mid_Smoothing, ds1_],
      Cobordism[mid_Smoothing,bot_Smoothing, ds2_]
      ] := Module[
      {law1, law2, decor, cob},
      {law1, law2, decor} = VCLaw[Cobordism[top, mid], Cobordism[mid, bot]];
      cob = Cobordism[top, bot,
          Expand[decor*(ds1 /. law1)*(ds2 /. law2)] /. (_mdot)^2 -> 
                1 /. (_mdot -> 0)
          ];
      cob
      ];

DeLoop[kom_Kom] := Module[
      {f, obs, mos, l, dot},
      {f, obs, mos} = List @@ kom;
      l=Length[obs]-1;
      Do[
        obs[[1+k]] = 
          obs[[1+k]] //.e[i___]Smoothing[Loop[j_]*rest_.] :> (
                If[k>0, 
                  mos[[k]] = 
                    mos[[k]] /. MM[e[l___], e[i], mat_] :> Plus[
                          MM[e[l], e[i,-1],
                            Expand[dot[j]*mat] /. bdot[j]dot[j] -> 1 /. 
                              dot[j] -> 0
                            ],
                          MM[e[l], e[i,1],
                            mat /. bdot[j] -> 0
                            ]
                          ]];
                If[k<l, 
                  mos[[1+k]] = 
                    mos[[1+k]] /. 
                      MM[e[i], e[l___], mat_] :> Plus[
                          MM[e[i,-1], e[l],
                            mat /. tdot[j] -> 0
                            ],
                          MM[e[i,1], e[l],
                            Expand[dot[j]*mat] /. tdot[j]dot[j] -> 1 /. 
                              dot[j] -> 0
                            ]
                          ]];
                e[i,-1]Smoothing[rest/Q] + e[i,1]Smoothing[rest*Q]
                ),
        {k, 0, l}
        ];
      ReTag[Kom[f, obs, mos] /. MM[_, _, {{0}}] -> 0]
      ];

Contract[kom_Kom] := Module[
      {
        f, obs, mos, l, k, e2s0, e2s1, s2b, b, e2b0, e2b1, killed0, killed1, 
        done, mok
        },
      {f, obs, mos} = List @@ kom;
      l=Length[obs]-1;
      Do[
        e2s0 = 
          Cases[{obs[[1+k]]}, i_e*s_Smoothing :> (i -> s), Infinity];
        e2s1 = 
          Cases[{obs[[1+k+1]]}, i_e*s_Smoothing :> (i -> s), Infinity];
        s2b = 
          Union[Union[Last /@ e2s0, Last /@ e2s1] /. 
              P[j__][m_] :> P[j]];
        s2b = Thread[Rule[s2b, b /@ Range[Length[s2b]]]];
        e2b0 = e2s0 /. P[j__][m_] :> P[j] /. s2b;
        e2b1 = e2s1 /. P[j__][m_] :> P[j] /. s2b;
        killed0 = killed1 = {}; done = False;
        While[!done,
          done = True;
          mok = mos[[1+k]];
          Cases[
            {mok},
            MM[i_e, j_e, {{r_?NumberQ}}] /;
                ((i /. e2b0) === (j /. e2b1))
              :> (
                mok = Plus[
                    mok /. {MM[i, _, _] -> 0, MM[_, j, _] -> 0},
                   Expand[-Plus @@ Flatten[Outer[
                              Function[{M1, M2},
                                MM[M1[[1]], M2[[2]], Last[VC[
                                      Cobordism[M1[[1]] /. e2s0, j /. e2s1,
                                        M1[[3,1,1]]],
                                      Cobordism[j /. e2s1, 
                                        i /. e2s0, {{1/r}}],
                                      Cobordism[i /. e2s0, M2[[2]] /. e2s1,
                                        M2[[3,1,1]]]
                                      ]]
                                  ]
                                ],
                              Cases[{mok}, MM[i1_e, j, mm1_] /; i1=!=i, 
                                Infinity],
                              Cases[{mok}, MM[i, j1_e, mm2_] /; j1=!= j, 
                                Infinity]
                              ]]]
                    ];
                mos[[1+k]] = (((mok //. 
                              a_*MM[i1_, j1_, mm_] :> 
                                MM[i1,j1, Expand[a*mm]]) //. 
                          MM[i1_, j1_, mm1_] + 
                              MM[i1_, j1_, mm2_] :> 
                            MM[i1, j1, mm1+mm2])
                      /. MM[_, _, {{0}}] -> 0);
                done = False;
                AppendTo[killed0, i]; AppendTo[killed1, j]
                ),
            Infinity, 1]
          ];
        obs[[1+k]] = obs[[1+k]] /. ((#->0)& /@ killed0);
        obs[[1+k+1]] = obs[[1+k+1]] /. ((#->0)& /@ killed1);
        If[k>0,
          mos[[1+k-1]] = mos[[1+k-1]] /.
              MM[i_e, j_e, mm_] /; MemberQ[killed0, j] :> 0
          ];
        If[k<l-1,
          mos[[1+k+1]] = mos[[1+k+1]] /.
              MM[i_e, j_e, mm_] /; MemberQ[killed1, i] :> 0
          ],
        {k,0,l-1}
        ];
      ReTag[Kom[f, obs, mos]]
      ];

KhComplex[X[i_,j_,k_,l_]]/;(j-l==1||l-j>1):=Kom[0, (* + xing *)
      Objects[
          e[1]Smoothing[Q P[i,j] P[k,l]],
          e[1]Smoothing[Q^2 P[i,l] P[j,k]]
          ]/.P[m_,n_]:>P[m,n][Min[m,n]],
      Morphisms[MM[e[1],e[1],{{1}}]]
      ];
KhComplex[X[i_,j_,k_,l_]]/;(l-j==1||j-l>1):=Kom[-1, (* - xing *)
      Objects[
          e[1]Smoothing[Q^(-2) P[i,j] P[k,l]],
          e[1]Smoothing[Q^(-1) P[i,l] P[j,k]]
          ]/.P[m_,n_]:>P[m,n][Min[m,n]],
      Morphisms[MM[e[1],e[1],{{1}}]]
      ];
KhComplex[pd_PD] /; (Length[pd] > 1) := Module[
    {kom},
    kom = KhComplex[First@pd];
    Do[
      kom = HC[kom, KhComplex[pd[[i]]]];
      kom = DeLoop[kom];
      kom = Contract[kom],
      {i,2,Length[pd]}
      ];
    kom
    ]

KhPoly[kom_Kom] := Module[
      {f, obs, mos},
      {f, obs, mos} = List @@ kom;
      If[Union[List @@ mos] =!= {0}, Error,
        Plus @@ Expand[t^(f-1) * t^Range[Length[obs]] * (
                List @@ obs /. e[i_]Smoothing[s_] :> s /. Q -> q
                )]
        ]
      ];

Kh[Knot[n_, k_]] := (
  Needs["KnotTheory`Kh4Knots`"];
  Unset[Kh[Knot[n1_, k1_]]];
  Kh[Knot[n, k]]
)
Kh[Knot[11, t_, k_]] := (
  Needs["KnotTheory`Kh4Knots11`"];
  Unset[Kh[Knot[11, t1_, k1_]]];
  Kh[Knot[11, t, k]]
)
Kh[Link[n_, t_, k_]] := (
  Needs["KnotTheory`Kh4Links`"];
  Unset[Kh[Link[n1_, t1_, k1_]]];
  Kh[Link[n, t, k]]
)
Kh[TorusKnot[m_, n_]] := (
  Needs["KnotTheory`Kh4TorusKnots`"];
  Unset[Kh[TorusKnot[m1_, n1_]]];
  Kh[TorusKnot[m,n]]
)

latestJavaKh = "JavaKh-v2";

Options[Kh] = {
  ExpansionOrder -> Automatic,
  Program -> latestJavaKh,
  Modulus -> 0,
  Universal -> False,
  JavaOptions -> ""
};

Kh[L_, opts___] := Kh[L, opts] = Module[
  {
    L1, pos, inside, L2, f, cl,
    eo = (ExpansionOrder /. {opts} /. Options[Kh]),
    prog = (Program /. {opts} /. Options[Kh] /. {"JavaKh" -> latestJavaKh}),
    modulus = (Modulus /. {opts} /. Options[Kh]),
    universal = (Universal /. {opts} /. Options[Kh]),
    javaoptions = (JavaOptions /. {opts} /. Options[Kh]),
    classpath
  },
  L1 = PD[L];
  Switch[prog,
  "FastKh", (
    CreditMessage["The Khovanov homology program FastKh was written by Dror Bar-Natan."];
    If[eo === Automatic,
      L2 = List @@ L1; L1 = PD[]; inside = {};
      While[Length[L2] > 0,
        pos = Last[Ordering[(Length[Intersection[List @@ #, inside]])& /@ L2]];
        AppendTo[L1, L2[[pos]]];
        inside = Union[inside, List @@ L2[[pos]]];
        L2 = Delete[L2, pos]
      ]
    ];
    Function @@ {KhPoly[KhComplex[L1]] /. {q -> #1, t -> #2}}
  ),
  "JavaKh-v1", (
    CreditMessage["The Khovanov homology program JavaKh-v1 was written by Jeremy Green in the summer of 2005 at the University of Toronto."];
    f = OpenWrite["pd", PageWidth -> Infinity];
    WriteString[f, ToString[L1]];
    Close[f];
    classpath = JavaKhv1ClassPath[]; 
    cl = StringJoin[
      "!java -classpath \"", classpath,
      "\" ", javaoptions, " org.katlas.JavaKh.JavaKh ",
      If[universal, "-U", If[modulus === Null, "-Z", "-mod "<>ToString[modulus]]],
      " < pd 2> JavaKh.log"
    ];
    f = OpenRead[cl];
    out = Read[f, Expression];
    Close[f];
    If[out == EndOfFile, 
        Print["Something went wrong running JavaKh; nothing was returned. The command line was: "];
        Print[cl];
        Print["There may have been an error log produced by Java: "];
        FilePrint["JavaKh.log"];
        Return[$Failed]
    ];
    out = StringReplace[out, {
      "q" -> "#1", "t" -> "#2", "Z" -> "ZMod"
    }];
    ToExpression[out <> "&"]
  ),
  "JavaKh-v2", (
    CreditMessage["The Khovanov homology program JavaKh-v2 is an update of Jeremy Green's program JavaKh-v1, written by Scott Morrison in 2008 at Microsoft Station Q."];
    f = OpenWrite["pd", PageWidth -> Infinity];
    WriteString[f, ToString[L1]];
    Close[f];
    classpath = JavaKhv2ClassPath[]; 
    cl = StringJoin[
      "!java -classpath \"", classpath,
      "\" ", javaoptions, " org.katlas.JavaKh.JavaKh ",
      If[eo =!= Automatic, " -O", ""],
      If[universal, "-U -Z", If[modulus === Null, "-Z", "--mod "<>ToString[modulus]]],
      " < pd 2> JavaKh.log"
    ];
    f = OpenRead[cl];
    out = Read[f, Expression];
    Close[f];
    If[out == EndOfFile, 
        Print["Something went wrong running JavaKh; nothing was returned. The command line was: "];
        Print[cl];
        Print["There may have been an error log produced by Java: "];
        FilePrint["JavaKh.log"];
        Return[$Failed]
    ];
    out = StringReplace[out, {
      "q" -> "#1", "t" -> "#2", "Z" -> "ZMod"
    }];
    ToExpression[out <> "&"]
  )
  ]
]

JavaKhv1ClassPath[] := ToFileName[KnotTheoryDirectory[], "JavaKh-v1"]

JavaKhv2ClassPath[] := Module[{JavaKhDirectory, jarDirectory, classDirectory, pathCharacter}, 
    JavaKhDirectory = ToFileName[KnotTheoryDirectory[], "JavaKh-v2"];
    jarDirectory = ToFileName[JavaKhDirectory, "jars"];
    classDirectory = ToFileName[JavaKhDirectory, "bin"];
    pathCharacter = If[$PathnameSeparator == "\\", ";", ":"];
    StringJoin[
        classDirectory, 
        pathCharacter , ToFileName[jarDirectory, "commons-cli-1.0.jar"],
        pathCharacter , ToFileName[jarDirectory, "commons-io-1.2.jar"],
        pathCharacter , ToFileName[jarDirectory, "commons-logging-1.1.jar"],
        pathCharacter , ToFileName[jarDirectory, "log4j-1.2.12.jar"]
    ]
]

TabularKh[kh_]:=TabularKh[kh,{}]
TabularKh[khG_,highlight_List]:=
  Module[{kh, out,width,minr,maxr,minj,maxj,j,r,c,critical,chi},
    kh = khG /. {Global`t -> t, Global`q -> q};
    minr=Exponent[kh,t,Min];
    maxr=Exponent[kh,t,Max];
    minj=Exponent[kh,q,Min];
    maxj=Exponent[kh,q,Max];
    width=N[100/(maxr-minr+5)];
    out=StringJoin["<table border=1>\n","<tr align=center>\n",
        "<td width="<>ToString[2width]<>
          "%><table cellpadding=0 cellspacing=0>\n",
        "  <tr><td>\\</td><td>&nbsp;</td><td>r</td></tr>\n",
        "<tr><td>&nbsp;</td><td>&nbsp;\\&nbsp;</td><td>&nbsp;</td></tr>\n",
        "<tr><td>j</td><td>&nbsp;</td><td>\\</td></tr>\n","</table></td>\n"];
    Do[out=out<>"<td width="<>ToString[width]<>"%>"<>ToString[r]<>"</td>",{r,minr,maxr}];
    out=out<>"<td width="<>ToString[2width]<>"%>&chi;</td></tr>\n";
    Do[out=out<>"<tr align=center><td>"<>ToString[j]<>"</td>";
      chi=0;
      Do[
        c=Coefficient[Expand[kh*t^(1-minr)*q^(1-minj)],t^(r+1-minr)*q^(j+1-minj)];
        chi+=(-1)^r*c;
        critical=MemberQ[highlight,j-2r];
        out=
          out<>Which[critical&&c!=0,
              "<td bgcolor=yellow>"<>ToString[c]<>"</td>",
              critical&&c==0,
              "<td bgcolor=yellow>&nbsp;</td>",!critical&&c!=0,
              "<td bgcolor=red>"<>ToString[c]<>"</td>",!critical&&c==0,
              "<td>&nbsp;</td>"],{r,minr,maxr}];
      out=out<>"<td>"<>ToString[chi]<>"</td></tr>\n",{j,maxj,minj,-2}];
    out=out<>"</table>"]

End[]; EndPackage[]
