(* ::Package:: *)



(* :Title: PaVeReduce														*)

(*
	This software is covered by the GNU General Public License 3.
	Copyright (C) 1990-2016 Rolf Mertig
	Copyright (C) 1997-2016 Frederik Orellana
	Copyright (C) 2014-2016 Vladyslav Shtabovenko
*)

(* :Summary:	Reduction of Passarino-Veltman coefficient functions into
				Passarino Veltman scalar functions							*)

(* ------------------------------------------------------------------------ *)

PaVeReduce::usage =
"PaVeReduce[expr] reduces all Passarino-Veltman integrals \
(i.e. all PaVe's) in expr down to scalar A0, B0, C0 and D0.";

Begin["`Package`"]
End[]

Begin["`PaVeReduce`Private`"]

pvrVerbose::usage="";

Options[ PaVeReduce ] = {
	Dimension -> True,
	FCVerbose -> False,
	IsolateNames->False,
	Mandelstam->{},
	PaVeOrderList -> {},
	WriteOutPaVe -> False,
	BReduce -> False
};

PaVeReduce[x_, opts:OptionsPattern[]] :=
	Block[ {op, wriout, nnx = x, res},
		op=Join[FilterRules[Options[PaVeReduce], Except[{opts}]], {opts}];
		wriout = OptionValue[WriteOutPaVe];

		If [OptionValue[FCVerbose]===False,
			pvrVerbose=$VeryVerbose,
			If[MatchQ[OptionValue[FCVerbose], _Integer?Positive | 0],
				pvrVerbose=OptionValue[FCVerbose]
			];
		];

		FCPrint[1,"PaVeReduce: Entering with: ", nnx, FCDoControl->pvrVerbose];


		If[ !FreeQ[nnx, StandardMatrixElement],
			nnx = Expand2[nnx, StandardMatrixElement];
		];


		If[ StringQ[wriout] && (Head[x] === PaVe),
			res  = pavitp@@Join[{nnx, wriout}, op],
			res = pavereduce[nnx, op]
		];

		If[ OptionValue[BReduce],
			FCPrint[1,"PaVeReduce: Setting the BReduce option to all B-functions", FCDoControl->pvrVerbose];
			res = res /. (h:B0|B00|B1|B11)[a_,b_,c_,ops___]:> h[a,b,c,BReduce->True,ops]
		];

		FCPrint[1,"PaVeReduce: Leaving with: ", nnx, FCDoControl->pvrVerbose];

		res
	];

(* These are the ultimate formulas for the reduction of coefficient
	functions. The reference is: Techniques for the calculation of
	electroweak radiative correctinos at the one-loop level and ...,
	by A. Denner (slightly rewritten by R.M),
	to appear in Fortschritte der Physik, 1993
*)
(* ***************************************************************** *)
(* Notation :    pij = (pi - pj)^2;  where p0 = (0,0,0,0), i.e.,
								p10 = p1^2, etc.  *)
(* ***************************************************************** *)
PaVeBr[i__, p_List, m_List, OptionsPattern[]] :=
	tT[Length[m]][i][Join[p, m]];

breakdown[x_] :=
	If[ FreeQ[x,PaVe],
		x,
		FixedPoint[(#/.T->tT)&,x/.PaVe->PaVeBr]
	];

drop[] =
	{}; (* i.e. no index is an empty list *)
drop[x__] :=
	Drop[{x},-1];

(* A Kronecker delta *)
delt =
	If[ #1 === #2,
		1,
		0
	]&;
(* ***************************************************************** *)
(*                          pave21                                   *)
(* ***************************************************************** *)

(* This is only valid for UV - Divergences !! *)
$epsilon /:
	$epsilon^_Integer?Positive :=
		0;
$epsilon /:
	$epsilon A0[mm_] :=
		2 mm;
$epsilon /:
	$epsilon B0[_, _, _] :=
		2;
$epsilon /:
	$epsilon B1[_, _, _] :=
		-1;
$epsilon /:
	$epsilon C0[__] :=
		0;
$epsilon /:
	$epsilon D0[__] :=
		0;
$epsilon /:
	$epsilon T[3][1][_] :=
		0;
$epsilon /:
	$epsilon T[3][2][_] :=
		0;
$epsilon /:
	$epsilon T[4][ij__][_] :=
		0 /; Length[{ij}] < 4;

(* Things with head SmallVariable are discarded in this function *)
SetAttributes[demon, Listable];
HoldPattern[demon[demon[x_]]] :=
	demon[x];

null[_] :=
	0;
demon[0] =
	0;
demon[x_] :=
	MemSet[ demon[x],
		Block[	{nx = x, den}, (* This is quite tricky ... *)
				den =  Factor2[Denominator[nx]];
				If[ Head[den]=== Plus,
					nx = nx /. SmallVariable->null,
					(* Now:if there is something SmallVariable in the numerator*)
					nx = Factor2[nx] /. SmallVariable->null
				];
				Factor2[Numerator[nx]]/ Factor2[Denominator[nx]]
		]
	];

(* Calculate determinants only once. *)
det[x_List] :=
	det[x] = demon[ demon[Det[demon[x]]] // Factor2 ];

(* Remember:  pij = (pi - pj)^2, i.e, p1.p2 = 1/2 ( p10+p20-p12 ),
				with  p0 = (0,0,0,0) *)

(* {p10_, p12_, p20_, m02_,m12_,m22_} *)
kinmainv[2, {p10_, p12_, p20_, _, _, _}] :=
	1/demon[ p10 p20 -  (1/2 (p10+p20-p12) )^2 ] demon[{ {p20, -1/2 (p10+p20-p12)}, {-1/2 (p10+p20-p12), p10} }];

(* {p10_, p12_, p23_, p30_, p20_, p13_,m02_, m12_, m22_, m32_} *)
kinmainv[3, {p10_, p12_, p23_, p30_, p20_, p13_, _, _, _, _}] :=
	Block[ {p1p2, p1p3, p2p3},
		{p1p2, p1p3, p2p3} = demon[{p10-p12+p20, p10-p13+p30, p20-p23+p30}/2];
		1/det[{ {p10, p1p2, p1p3}, {p1p2, p20, p2p3}, {p1p3, p2p3, p30} }] *
		demon[ {{-p2p3^2 + p20*p30, p1p3*p2p3 - p1p2*p30, p1p2*p2p3 - p1p3*p20},
				{p1p3*p2p3 - p1p2*p30, -p1p3^2 + p10*p30, p1p2*p1p3 - p10*p2p3},
				{p1p2*p2p3 - p1p3*p20, p1p2*p1p3 - p10*p2p3, -p1p2^2 + p10*p20}}]
	];

(* Xinvdef  !!!!! No precaution is taken for 0 determinants !!!! *)
(* Only for B1 and B11 the Xinv[1][1,1] will not be used *)
Xinv[1][1,1][{pp_,_,_}] :=
	1/pp;

Xinv[2][i_, j_][a_] :=
	Xinv[2][i,j][a] = kinmainv[2, a][[i,j]];

Xinv[3][i_, j_][a_] :=
	Xinv[3][i,j][a] = kinmainv[3, a][[i,j]];

(* we put the SmallVariable - demon here *)
f[1][{pp_, m02_,m12_}] :=
	demon[ pp - m12 + m02 ];

(* {p10_,p12_,p20_, m02_,m12_,m22_}	*)
f[1][{p10_, _, _, m02_, m12_, _}] :=
	demon[ p10 - m12 + m02 ];

f[2][{_, _, p20_, m02_, _, m22_}] :=
	demon[ p20 - m22 + m02 ];
(* {p10_, p12_, p23_, p03_, p20_, p13_, m02_, m12_, m22_, m32_} *)
f[1][{p10_, _, _, _, _, _, m02_, m12_, _, _}] :=
	demon[ p10 - m12 + m02 ];

f[2][{_, _, _, _, p20_, _, m02_, _, m22_, _}] :=
	demon[ p20 - m22 + m02 ];

f[3][{_, _, _, p03_, _, _, m02_, _, _, m32_}] :=
	demon[ p03 - m32 + m02 ];

T[0][][___] :=
	0; (* in dimensional regularization *)

T[1][][{mm_}] :=
	A0[mm];

T[2][][{pp_, m12_, m22_}] :=
	B0[pp, m12, m22];

T[3][][{p10_,p12_,p20_, m02_,m12_,m22_}] :=
	C0[p10,p12,p20,m02,m12,m22];

T[4][][{p10_, p12_, p23_, p03_, p20_, p13_, m02_, m12_, m22_, m32_}] :=
	D0[p10,p12,p23,p03,p20,p13, m02,m12,m22,m32];

(* The translated argument lists obtained by canceling  *)

(* {pp_, m12_, m22_} *)

c[0][{_, _, m22_}] :=
	{m22};

c[1][{_, m12_, _}] :=
	{m12};

(* {p10_,p12_,p20_, m02_,m12_,m22_} *)
c[0][{_, p12_, _, _, m12_,m22_}] :=
	{p12, m22, m12};

c[1][{_, _, p20_, m02_, _, m22_}] :=
	{p20, m02, m22};

c[2][{p10_, _, _, m02_, m12_, _}] :=
	{p10, m02, m12};

(* {p10_, p12_, p23_, p03_, p20_, p13_, m02_, m12_, m22_, m32_} *)
c[0][{_, p12_, p23_, _, _, p13_, _, m12_, m22_, m32_}] :=
	{p13, p12, p23, m32, m12, m22};

c[1][{_, _, p23_, p03_, p20_, _, m02_, _, m22_, m32_}] :=
	{p20, p23, p03, m02, m22, m32};

c[2][{p10_, _, _, p03_, _, p13_, m02_, m12_, _, m32_}] :=
	{p10, p13, p03, m02, m12, m32};

c[3][{p10_, p12_, _, _, p20_, _, m02_, m12_, m22_, _}] :=
	{p10, p12, p20, m02, m12, m22};

(* getmdef *)
getm[{_}] :=
	0;

getm[{_,_,_}] :=
	1;

getm[{_,_,_,_,_,_}] :=
	2;

getm[{_,_,_,_,_,_,_,_,_,_}] :=
	3

pluep2[x__] :=
	Plus[x]/;!FreeQ2[{x}, {tT,B0,B1,B00,B11,C0,D0,T}];

(* equation  (4.18) of A. Denners review *)
tT[N_Integer][0,0, i___Integer][a_List] :=
	Block[ {P, M, k, epsi },
		P = 2 + Length[{i}];
		M = getm[a];
		1/(2 + P - M) (R[N, 0, 0][i][a] - Sum[ R[N, k][k, i][a], {k, M}])+
		Expand[( 1/(2 + P - M) epsi/(2 + P - M) (R[N, 0, 0][i][a] - Sum[ R[N, k][k, i][a], {k, M}])
			)/.Plus->pluep2 ]/.epsi->$epsilon/.pluep2->Plus] /; $LimitTo4 === True;

(* $dIM gets defined from the option of PaVeReduce *)
tT[N_Integer][0,0, i___Integer][a_List] :=
	Block[ {P, M, k, epsi },
		P = 2 + Length[{i}];
		M = getm[a];
		1/($dIM + P -2 - M) (R[N, 0, 0][i][a] - Sum[ R[N, k][k, i][a], {k, M}])] /; $LimitTo4 =!= True;

(* two special cases *)
R[n0__][j__][a_] :=
	(R[n0][Sequence @@ Sort[{j}]][a] ) /; !OrderedQ[{j}];

R[n0__][{}][a_] :=
	R[n0][][a];

T[n0__][j__][a_] :=
	(T[n0][Sequence @@ Sort[{j}]][a] ) /; !OrderedQ[{j}];

(* special B-stuff*)
tT[2][1][{p10_,m02_,m12_}] :=
	B1[p10,  m02, m12];

(* XXX *)
tT[2][1,1][{p10_,m02_,m12_}] :=
	B11[p10, m02, m12] /; ($LimitTo4===True) || (p10 === 0);

tT[2][0,0,1][{p10_,0,0}] :=
	If[ $LimitTo4,
		p10/36 + (p10*B0[p10, 0, 0])/24,
		-(p10*B0[p10, 0, 0])/(8*(1 - $dIM))
	];

tT[2][1,1,1][{p10_,0,0}] :=
	If[ $LimitTo4,
		-1/12 - B0[p10, 0, 0]/4,
		((2 + $dIM)*B0[p10, 0, 0])/(8*(1 - $dIM))
	];

(* (4.18), *)
tT[N_Integer][k_Integer,i___Integer][a_List] :=
(*tT[N][k,i][a] =*)
	Block[ {P, M ,r, kp },
		P = 1 + Length[{i}];
		M = getm[a];
		Sum[ Xinv[M][k, kp][a]  ( R[N,kp][i][a] -
		Sum[ delt[ kp,{i}[[r]] ] (T[N]@@Join[{0,0}, Delete[{i},r]])[a], {r, P-1}]), {kp, M}]
	];

(* no M's in i *)
R[N_Integer, 0, 0][i___Integer][a_List] :=
	Block[ {q,P,M},
		q = Length[{i}];
		P = 2 + q;
		M = getm[a];
		demon[a[[-N]]] T[N][i][a]  + T[N-1][i][ c[0][a] ]
	] /; FreeQ[{i}, getm[a]];

R[N_Integer,0,0][i___Integer, mm:(_Integer)..][a_List] :=
	Block[ {q,M,P,j,k},
		q = Length[{i}];
		M = getm[a];
		P = Length[{mm}] + 2 + q;
		demon[ a[[-N]] ] T[N][i, mm][a] +
		(* here was the tough bug found by Ralph Schuster ... *)
		(-1)^(P - q) ( T[N - 1][i][c[0][a]] + Sum[
		Binomial[P - 2 - q, j] * Sum @@ Prepend[ Array[List[k[#], M - 1]&, j],
		(T[N-1]@@Join[{i}, Array[k,j]])[c[0][a]]], {j,P - 2 - q}])
	] /; ({mm}[[1]] === getm[a]);

(* 4.19 , no M's*)
R[N_Integer, k_Integer][i___Integer][a_List] :=
	Block[ {q,P,M},
		q = Length[{i}];
		P = 1 + q;
		M = getm[a];
		1/2( (T[N - 1] @@ til[i][k])[ c[k][a] ] theta[k, i] - f[k][a] T[N][i][a] - T[N - 1][i][c[0][a]])
	]/; FreeQ[{i}, getm[a]];

R[N_Integer,k_Integer][i___Integer, mm:(_Integer)..][a_List] :=
	Block[ {q, P, M, kk, j},
		q = Length[{i}];
		P = Length[{mm}] + 1 + q;
		M = getm[a];
		1/2( (T[N-1] @@ til[i,mm][k])[c[k][a]] theta[k, i, mm] -
		f[k][a] T[N][i,mm][a] -(-1)^(P - 1 - q) (T[N - 1][i][c[0][a]] +
		Sum[Binomial[P - 1 - q, j]  Sum@@Prepend[Array[List[kk[#], M -1 ]&,j], (T[N - 1]@@Join[{i},
		Array[kk, j]])[c[0][a]]], {j, P - 1 - q} ]))
	] /;({mm}[[1]] === getm[a]);

(* 4.20 *)
(* thetadef *)
theta[k_Integer, i___Integer] :=
	1 /; FreeQ[{i}, k];

theta[k_Integer, i___Integer] :=
	0 /;!FreeQ[{i}, k];

tm[a_Integer, b_Integer] :=
	a /; a<=b;

tm[a_Integer, b_Integer] :=
	(a-1) /; a > b;

til[][_] = {};

til[x__][k_] :=
	Map[tm[#,k]&, {x}];

collect3[x__] :=
	Collect2[x, Factoring -> True];

(* Decomposition down to scalar integrals *)
(* ****************************************************************** *)

cancel[x_] :=
	Cancel[x/.Plus->pll]/.pll->Plus;

pavitp[xXX_PaVe, dir_, opts:OptionsPattern[]] :=
	Block[ {nx, file, temp, set,xxx,a,abbs,abbstr,dir1},

		paV[xy__, p_List, m_List, paveopts:OptionsPattern[]] :=
			PaVe[xy,C,p,C,m,paveopts];
		xxx = paV@@xXX;

		(*Changed 18/9-2000, F.Orellana*)
		abbs = DownValues[Abbreviation] /. Abbreviation -> Identity /. HoldPattern -> Identity;

		nx = StringReplace[ ToString[InputForm[xxx/.abbs], PageWidth -> 222], $Abbreviations];
		nx = StringJoin[dir, nx, ".s"];

		FCPrint[2,"nx  =", nx];
		If[ Streams[nx] === {},
			(*Mac fix, 18/9-2000, F.Orellana*)
			file = FileType[nx];

			If[ file === File,
				FCPrint[2,"file  =", file];
				temp = (Get@@{nx})//PaVeOrder;
				(* If something went wrong in writing the file *)
				If[ Head[temp]=!=Plus,
					file = {}
				]
			];

			If[ file =!= File && file =!= Directory,
				temp = FixedPoint[ReleaseHold, PaVeReduce[xXX, WriteOutPaVe->False,opts]]//PaVeOrder;
				FCPrint[2,"writing result to ",nx];
				OpenWrite @@ {nx, FormatType -> InputForm };
				WriteString @@ {nx, "( "};
				Write @@ {nx, temp};
				WriteString @@ {nx, "  ) "};
				Close @@ {nx};
			],
			temp = PaVeReduce[xXX, WriteOutPaVe->False,opts]//PaVeOrder;
		];
		temp
	];

(*
pavereduce[0,___]:=0;
pavereduce[w_,___]:=w/;NTerms[w]===1 && FreeQ[w,PaVe];

(*
pavereduce[ a_ b_,ops___ ]:=cancel[ a pavereduce[ b,ops] ]/;
													FreeQ[a,PaVe]&&!FreeQ[a,StandardMatrixElement];
*)

pavereduce[a_Times, ops___] :=
	cancel[ SelectFree[SelectNotFree[a,StandardMatrixElement],PaVe] *
pavereduce[a/SelectFree[SelectNotFree[a,StandardMatrixElement],PaVe]
				]  ] /;
		SelectFree[SelectNotFree[a,StandardMatrixElement],PaVe] =!= 1;
*)


(* ********************************************************************** *)

(* This default setting of Dimension results --- together with
	$LimitTo4 = True --- into dimensional regularization
	(for the ultraviolett divergencies ) with
	the limit Dimension -> 4 being taken.
	If the option Dimension is set to some explicit variable (d for instance),
	no limit is taken and d occurs in the result.
*)

(* Gram determinant for a 2-point function	*)
gramDet[{p10_}]:=
	gramDet[{p10}] =
		Expand[2 p10]

(* Gram determinant for a 3-point function	*)
gramDet[{p10_, p12_, p20_}]:=
	gramDet[{p10, p12, p20}] =
		Expand[4 p10^2 p20^2 - (p10 - p12 + p20)^2];

(* Gram determinant for a 4-point function	*)
gramDet[{p10_, p12_, p23_, p30_, p20_, p13_}]:=
	gramDet[{p10, p12, p23, p30, p20, p13}]=
		Expand[8 (-(1/4) p20^2 (-p10 + p13 - p30)^2 + 1/4 (-p10 + p12 - p20) (-p10 + p13 - p30) (-p20 + p23 - p30) -
		1/4 p10^2 (-p20 + p23 - p30)^2 - 1/4 (-p10 + p12 - p20)^2 p30^2 + p10^2 p20^2 p30^2)];

pavereduce[exp_, OptionsPattern[]] :=
	exp /; FreeQ[exp, _PaVe, Heads -> True];

pavereduce[w_ , opts:OptionsPattern[]] :=
	Block[	{mpa,nw,nn,pre,re = 0},
			mpa = w/. StandardMatrixElement[__]->0;
			nw = w - mpa;
			re = pavereduce[mpa, opts];
			If[ Head[nw] === Plus,
				nn = Length[nw],
				nn = 1
			];
			For[ij = 1, ij<=nn, ij++,
				FCPrint[2,"breaking down # ", ij, " / ", nn];
				If[ nn===1,
					pre = PartitHead[nw,StandardMatrixElement],
					pre = PartitHead[nw[[ij]],StandardMatrixElement]
				];
				re = re + pre[[2]] pavereduce[ pre[[1]], opts]
			];
		re
	]/; !FreeQ[w, StandardMatrixElement];

pavereduce[pvli_List, opts:OptionsPattern[]] :=
	Block[ {i,set,le = Length[pvli],npvli},
		npvli = {};
		Do[ FCPrint[2," Working with # ",i," out of ",le];
			npvli = Append[npvli, pavereduce[pvli[[i]],opts]],
			{i,le}
		];
		npvli
	];

pavereduce[brex_, opts:OptionsPattern[]] :=
	Block[	{	t, mand, result, ij, tri, kkk, trick, dimen, msu, isok,
				is, pl2, paveorderli, breakx, cofun2,cofun, tvarS, paveProtect},

			FCPrint[3,"PaVeReduce: pavereduce: Entering with: ", brex, FCDoControl->pvrVerbose];


			paveorderli = OptionValue[PaVeReduce,{opts}, PaVeOrderList];
			mand = OptionValue[PaVeReduce,{opts}, Mandelstam];
			isok = OptionValue[PaVeReduce,{opts}, IsolateNames];
			dimen = OptionValue[PaVeReduce,{opts}, Dimension];


			If[ (dimen =!= True) && ($LimitTo4 =!= True),
				$dIM = dimen,
				$dIM = D
			];

			If[ !FreeQ[ brex, PaVe],
				breakx = Collect[brex, PaVe[__]],
				breakx = brex
			];

			isolateP[x__] :=
				Isolate[x, IsolateNames -> isok];

			tri[xx_  yy_] :=
				tri[xx] tri[yy];

			tri[any_ xx_] :=
				( any tri[xx] )/;FreeQ[any,Plus] || Head[any]===PaVe;

			tri[any_ ] :=
				any /;FreeQ[any,Plus] || Head[any]===PaVe;

			mand = mand /. SmallVariable->Identity;

			If[ mand==={},
				If[ ($LimitTo4 === False ) && (Head[brex] === PaVe),
					tvarS = Variables[ Join @@ Take[brex, -2] ];
					trick[z_] :=
						Collect2[z, tvarS],
					trick[z_] :=
						z
				],
				trick[z_] :=
					trick[z] = TrickMandelstam[z,mand]//Factor2
			];

			msu = {};

			pl2[x__] :=
				kkk[ Plus[x] ]/; FreeQ2[{x}, {A0,B0,B1,B00,B11,C0,D0,PaVe}];

			backpc[a_,b_,c_,d_,e_,f_] :=
				PaVeOrder[C0[a,b,c,d,e,f], PaVeOrderList -> paveorderli];

			backpd[a_] :=
				D0[a];

			backpd[a_,b_,c_,d_,e_,f_,m1_,m2_,m3_,m4_] :=
				PaVeOrder[ D0[a,b,c,d,e,f,m1,m2,m3,m4], PaVeOrderList -> paveorderli];

			pluep[yy__] :=
				Plus[yy]/;!FreeQ2[{yy}, {$epsilon,A0,B0,B1,B00,B11}];

			FCPrint[3,"PaVeReduce: pavereduce: Staring reduction.", FCDoControl->pvrVerbose];
			breakx = breakx/.msu;

			(*	Currently, the reduction is not implemented for pentagons and other higher point function	*)
			breakx = breakx /. {
				PaVe[i_,j___,  moms_List, ml_List, ops:OptionsPattern[]]/;
					MatchQ[{i,j}, {Integer___}] && Length[moms]>6 :>
						paveProtect[i,j,  moms, ml, ops]
			};
			(*	Check for vanishing Gram determinants in bubbles, triangles and boxes!
				Exceptions are B0, B1, B00, B11, and B001 where alternative reduction is avaliable *)
			breakx = breakx /. {
				PaVe[i_,j___,  moms_List, ml_List, ops:OptionsPattern[]]/;
					MatchQ[{i,j}, {Integer___}] && gramDet[moms]===0 && FreeQ[moms,SmallVariable] &&
					!(Length[moms]===1 && ({i,j}==={0} || {i,j}==={1} || {i,j}==={0,0} || {i,j}==={1,1} || {i,j}==={0,0,1})) :>
						paveProtect[i,j,  moms, ml, ops]
			};

			t =  breakdown[breakx];

			FCPrint[3,"PaVeReduce: pavereduce: First stage done: ", t, FCDoControl->pvrVerbose];

			t = t/.C0->backpc/.D0->backpd/.paveProtect->PaVe;

			FCPrint[3,"PaVeReduce: pavereduce: Second stage done: ", t, FCDoControl->pvrVerbose];

			If[ !FreeQ[t, HoldForm],
				t = FixedPoint[ReleaseHold,t]
			];

			t = Collect[t, {A0[__],B0[__], B1[__], B00[__], B11[__], C0[__], D0[__], PaVe[__],
							HoldPattern[Dot[__]], HoldPattern[DOT[__]]}, Factor2];

			If[ !FreeQ[t, $epsilon],
				t = Expand[t/.Plus->pluep]/.$epsilon->0/.pluep->Plus
			];

			result = t;

			(* get the "linear" part *)
			FCPrint[2,"check4 ", MemoryInUse[]," MB used"];

			cofun[0] = 0;
			cofun[a_ b_] :=
				a cofun[b]/;!FreeQ2[a, {A0,B0,B1,B00,B11,C0,D0,PaVe} ];

			cofun2[0] = 0;

			cofun2[y_] :=
				y/;FreeQ[y,Plus];

			cofun2[yy_] :=
				trick[yy];

			FCPrint[2,"check7"];

			If[ isok=!=False && Head[result]=!=PaVe,
				result = cofun/@( result + nuLL );

				isolatefirst[a_ b_] :=
					(a isolatefirst[b])/; FreeQ2[a,{A0,B0,B1,B00,B11,C0,D0,PaVe}];

				isolatefirst[a_] :=
					a /; FreeQ2[a,{A0,B0,B1,B00,B11,C0,D0,PaVe}];

				result = isolatefirst /@ result;
				isolatetri[a_] :=
					isolateP[ trick[a] ];

				result = (result/.nuLL->0)/.isolatefirst->isolatetri/.cofun->cofun2
			];

			If[ isok=!=False,
				result = isolateP[ result ],
				result = trick /@ result
			];

			FCPrint[3,"PaVeReduce: pavereduce: Leaving with: ", result, FCDoControl->pvrVerbose];

			result
	]/;FreeQ[brex,StandardMatrixElement];

FCPrint[1,"PaVeReduce.m loaded."];
End[]
