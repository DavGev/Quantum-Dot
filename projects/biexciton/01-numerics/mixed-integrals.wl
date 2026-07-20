(* ::Package:: *)

(* ============================================================================
   mixed-integrals.wl  --  norm / interaction / kinetic integrals, energy,
                           and variational minimization with a live plot
   ----------------------------------------------------------------------------
   Same NIntegrate structure as the Biexciton.nb, with the density swapped to
   psiWeightBiexcitonMixed (arbitrary states) and no memoization (results depend
   on the global state configuration).

   Depends on: definitions.wl, mixed-correlation.wl, mixed-density.wl.
   ============================================================================ *)

(* wipe any stale definitions from a previous Get (old argument patterns would
   otherwise survive a re-Get and shadow updated ones -- e.g. an older
   minimizeBiexciton[a,c,maxIter] downvalue shadowing the current 4-argument
   one). bxRunArchive is deliberately NOT cleared: the live session archive
   survives a re-Get, and a fresh kernel loads it from bxArchiveFile below. *)
ClearAll[bxRmax, bxMaxPoints, bxPrecisionGoal, bxAccuracyGoal,
  bxIntegrate, bxIntegrateUniform, bxIntegrateIS, bxImportanceSampling,
  bxRadFromV, bxRadJacobian, bxUFromV, bxUJacobian,
  bxRefMix, bxRefGrid, bxStateMaps,
  bxWeight, bxQuadratureCheck, bxQuadratureCheckAll,
  normDirectBiexciton, normCrossBiexciton,
  interactionDirectBiexciton, interactionCrossBiexciton,
  kineticElectronDirectBiexciton, kineticElectronCrossBiexciton,
  kineticHoleDirectBiexciton, kineticHoleCrossBiexciton,
  energyCorrectionBiexciton, energyCorrectionBiexcitonQuiet,
  totalEnergyBiexciton,
  bxStallIterations, bxStallTol,
  bxOptPrecisionGoal, bxOptAccuracyGoal, bxConfigKey,
  bxHistory, bxSteps, bxHistoryConfig, bxHistoryStaleQ,
  bxConvergencePlot, bxOptimum, bxSimplexAround, bxNearestArchiveKey,
  minimizeBiexciton,
  bxArchiveFile, bxSaveArchive, bxProgressFile, bxLog, bxVerbose,
  bxConfigLabel];

(* ---- integration controls -------------------------------------------------
   NIntegrate stops when its error < Max[10^-bxAccuracyGoal, |I| 10^-bxPrecisionGoal].
   The integrals here are small (norm ~ 5*10^-3), so a low AccuracyGoal would be
   met almost immediately (absolute tol > the integral itself), leaving each
   evaluation badly under-sampled. We therefore keep AccuracyGoal high so the
   RELATIVE PrecisionGoal governs, and give MaxPoints enough room to reach it. *)
bxRmax = 0.9;              (* radial cutoff as a fraction of a *)
bxMaxPoints = 2*10^5;      (* Monte-Carlo budget per integral *)
bxPrecisionGoal = 2;       (* relative accuracy per integral (~1%) *)
bxAccuracyGoal = Infinity; (* disable the ABSOLUTE criterion entirely: the norms
   can be ~10^-8 (small a,c or extreme \[Alpha],\[Beta]), where any finite AccuracyGoal
   makes NIntegrate "converge" instantly with O(100%) error. With Infinity the
   relative PrecisionGoal always governs and MaxPoints caps the cost. *)

(* shared 11-fold measure; integrand is a pure Function of the integration
   variables in the order (r1,u1,r2,u2,ra,ua,rb,ub,\[Theta]1,\[Theta]2,\[Theta]b). *)

(* ---- importance-sampled integration -----------------------------------------
   The physical weight confines every particle to ~1 rB (in-plane Gaussian of
   the orbitals) while the raw box is (a bxRmax)^4-sized in the radials, so
   uniform(-QMC) points almost never land inside the support: the raw integrals
   are ~10^-8 and converge hopelessly slowly (verified: <P^2> vs <Q^2>, exactly
   equal analytically, differ by O(1) numerically at any tested budget).

   Fix: change variables per particle so a separable REFERENCE density becomes
   the uniform measure on (0,1):
     radial  r = Finv[v],  reference pdf \[Proportional] \[Omega] r Exp[-\[Omega] r^2/2]  (ground radial),
     axial   u = Ginv[x],  reference pdf 2 Sin[\[Pi] u]^2         (\[Nu] = 1 axial).
   The Jacobians cancel the reference density inside bxWeight pointwise, so
   NIntegrate sees an O(1) integrand; only the (orbital ratio) x Jastrow
   structure remains to resolve. Set bxImportanceSampling = False to recover
   the raw uniform rule for comparison. *)
bxImportanceSampling = True;

bxRadFromV[\[Omega]_, rmax_][v_] :=
  Sqrt[-(2/\[Omega]) Log[1 - v (1 - Exp[-\[Omega] rmax^2/2])]];
bxRadJacobian[\[Omega]_, rmax_][r_] :=          (* dr/dv = (1 - e^{-\[Omega] rmax^2/2})/(\[Omega] r e^{-\[Omega] r^2/2}) *)
  (1 - Exp[-\[Omega] rmax^2/2]) Exp[\[Omega] r^2/2]/(\[Omega] r);
bxUFromV =                                 (* inverse CDF of 2 Sin[\[Pi] u]^2, built once at load *)
  Interpolation[Table[{N[u - Sin[2 Pi u]/(2 Pi)], u}, {u, 0, 1, 1/4096}]];
bxUJacobian[u_] := 1/(2 Sin[\[Pi] u]^2);

(* ---- state-adapted reference maps -------------------------------------------
   The ground-orbital reference under-samples excited configurations (the
   r^{2|m|} ring of m != 0 orbitals, Laguerre nodes for n > 0, multi-lobe axial
   profiles for \[Nu] > 1). Each particle is therefore mapped through the inverse
   CDF of ITS pair's own reference: the average of the pair's two orbital
   densities plus a ground-state floor (weight bxRefMix) that keeps the
   reference strictly positive, so the Jacobian stays bounded at orbital nodes.
   The antisymmetrized pair density cannot outrun the reference: by AM-GM the
   interference term obeys |\[Chi](I)\[Chi](J)| <= [n1+n2](I)[n1+n2](J)/4.
   Maps are tabulated inverse CDFs, memoized per (\[Omega], rmax, state list); the
   ground configuration reproduces the analytic maps above. *)
bxRefMix = 0.1;    (* weight of the ground-state floor in the reference *)
bxRefGrid = 2048;  (* CDF tabulation resolution *)

bxStateMaps[\[Omega]_, rmax_, states_] := bxStateMaps[\[Omega], rmax, states] =
  Module[{rpdf, updf, rgrid, ugrid, rvals, uvals, rcdf, ucdf, rtot, utot},
   rpdf[r_] := (1 - bxRefMix) Mean[Map[
        (\[Psi]r[#[[2]], #[[3]]][\[Omega], r]^2 r) &, states]] +
     bxRefMix \[Omega] r Exp[-\[Omega] r^2/2]/(2 \[Pi]);
   updf[u_] := (1 - bxRefMix) Mean[Map[(2 Sin[#[[1]] \[Pi] u]^2) &, states]] +
     bxRefMix 2 Sin[\[Pi] u]^2;
   rgrid = N@Subdivide[0, rmax, bxRefGrid];
   ugrid = N@Subdivide[0, 1, bxRefGrid];
   rvals = rpdf /@ rgrid;
   uvals = updf /@ ugrid;
   rcdf = Prepend[Accumulate[(Most[rvals] + Rest[rvals])/2], 0.] rmax/bxRefGrid;
   ucdf = Prepend[Accumulate[(Most[uvals] + Rest[uvals])/2], 0.]/bxRefGrid;
   rtot = Last[rcdf]; utot = Last[ucdf];
   <|"rFromV" -> Interpolation[Transpose[{rcdf/rtot, rgrid}]],
     "rJac" -> Function[r, rtot/rpdf[r]],
     "uFromX" -> Interpolation[Transpose[{ucdf/utot, ugrid}]],
     "uJac" -> Function[u, utot/updf[u]]|>];

bxIntegrateUniform[a_, c_, integrand_] :=
  NIntegrate[
   integrand[r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b],
   {r1, 0, a bxRmax}, {u1, 0, 1}, {r2, 0, a bxRmax}, {u2, 0, 1},
   {ra, 0, a bxRmax}, {ua, 0, 1}, {rb, 0, a bxRmax}, {ub, 0, 1},
   {\[Theta]1, 0, 2 \[Pi]}, {\[Theta]2, 0, 2 \[Pi]}, {\[Theta]b, 0, \[Pi]},
   Method -> {"AdaptiveQuasiMonteCarlo", "BisectionDithering" -> 0,
     "MaxPoints" -> bxMaxPoints},
   AccuracyGoal -> bxAccuracyGoal, PrecisionGoal -> bxPrecisionGoal,
   WorkingPrecision -> MachinePrecision];

bxIntegrateIS[a_, c_, integrand_] :=
  With[{\[Omega] = \[HBar]\[Omega]00[a, c], rmax = a bxRmax},
   With[{me = bxStateMaps[\[Omega], rmax, bxElectronStates],
         mh = bxStateMaps[\[Omega], rmax, bxHoleStates]},
   NIntegrate[
    Module[{r1 = me["rFromV"][v1], r2 = me["rFromV"][v2],
      ra = mh["rFromV"][va], rb = mh["rFromV"][vb],
      u1 = me["uFromX"][x1], u2 = me["uFromX"][x2],
      ua = mh["uFromX"][xa], ub = mh["uFromX"][xb]},
     integrand[r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b] *
      me["rJac"][r1] me["rJac"][r2] mh["rJac"][ra] mh["rJac"][rb] *
      me["uJac"][u1] me["uJac"][u2] mh["uJac"][ua] mh["uJac"][ub]],
    {v1, 0, 1}, {x1, 0, 1}, {v2, 0, 1}, {x2, 0, 1},
    {va, 0, 1}, {xa, 0, 1}, {vb, 0, 1}, {xb, 0, 1},
    {\[Theta]1, 0, 2 \[Pi]}, {\[Theta]2, 0, 2 \[Pi]}, {\[Theta]b, 0, \[Pi]},
    Method -> {"AdaptiveQuasiMonteCarlo", "BisectionDithering" -> 0,
      "MaxPoints" -> bxMaxPoints},
    AccuracyGoal -> bxAccuracyGoal, PrecisionGoal -> bxPrecisionGoal,
    WorkingPrecision -> MachinePrecision]]];

bxIntegrate[a_, c_, integrand_] :=
  If[TrueQ[bxImportanceSampling],
   bxIntegrateIS[a, c, integrand],
   bxIntegrateUniform[a, c, integrand]];

(* the density weight, evaluated at the current integration point *)
bxWeight[a_, c_, \[Omega]_][u1_, r1_, \[Theta]1_, u2_, r2_, \[Theta]2_, ua_, ra_, ub_, rb_, \[Theta]b_] :=
  4 \[Pi] psiWeightBiexcitonMixed[a, c, \[Omega]][
     u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b] *
   r1 r2 ra rb;

(* ---- normalization --------------------------------------------------------
   The "direct" integrands use the symmetrized estimator (P^2 + Q^2)/2 instead
   of P^2: analytically identical (relabeling gives \[Integral]P^2 = \[Integral]Q^2), but exactly
   \[Alpha]<->\[Beta] symmetric for the FIXED quasi-Monte-Carlo point set, so swapping \[Alpha],\[Beta]
   now returns bit-identical results instead of differing by integration error. *)
normDirectBiexciton[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ,
   \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ] :=
  With[{\[Omega] = \[HBar]\[Omega]00[a, c]},
   bxIntegrate[a, c,
Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b},
     With[{g = Gcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Gamma], \[Delta]],
           p = Pcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]],
           q = Qcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]]},
      bxWeight[a, c, \[Omega]][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b] g^2 (p^2 + q^2)/2]]]];

normCrossBiexciton[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ,
   \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ] :=
  With[{\[Omega] = \[HBar]\[Omega]00[a, c]},
   bxIntegrate[a, c,
Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b},
     With[{g = Gcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Gamma], \[Delta]],
           p = Pcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]],
           q = Qcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]]},
      bxWeight[a, c, \[Omega]][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b] g^2 p q]]]];

(* ---- quadrature diagnostic --------------------------------------------------
   <P^2> and <Q^2> are EXACTLY equal (relabel electrons 1<->2; the pair density
   is symmetric by construction), so their spread on the fixed QMC point set is
   a rigorous lower bound on the quadrature error at (\[Alpha],\[Beta],\[Gamma],\[Delta]).
   relSpread >> 10^-bxPrecisionGoal means the point budget is insufficient
   there and energy values (and minima!) at those parameters cannot be trusted.
   Rerun with increasing bxMaxPoints: the two halves must converge together. *)
bxQuadratureCheck[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ,
   \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ] :=
  With[{\[Omega] = \[HBar]\[Omega]00[a, c]},
   Module[{half, nP, nQ},
    half[a1_, b1_] := bxIntegrate[a, c,
  Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b},
       With[{g = Gcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Gamma], \[Delta]],
             p = Pcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, a1, b1]},
        bxWeight[a, c, \[Omega]][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b] g^2 p^2]]];
    nP = half[\[Alpha], \[Beta]];   (* <P^2> *)
    nQ = half[\[Beta], \[Alpha]];   (* <Q^2>, identical to <P^2> in exact arithmetic *)
    <|"normP2" -> nP, "normQ2" -> nQ,
      "relSpread" -> 2 Abs[nP - nQ]/Abs[nP + nQ],
      "maxPoints" -> bxMaxPoints|>]];

(* Full diagnostic suite: one exact identity per term class. Each pair of
   numbers is EXACTLY equal analytically; the relative spread is a lower bound
   on the quadrature error of that term at (\[Alpha],\[Beta],\[Gamma],\[Delta]).
     norm                 <P^2>          = <Q^2>            (1<->2)
     interaction          <P^2 Vfull>    = <Q^2 Vfull>      (1<->2)
     interactionReduction <P^2 Vreduced> = <P^2 Vfull>      (S_eh = (1<->2)(a<->b))
     crossAttraction      <PQ/r1a>       = <PQ/r1b>         (a<->b)
     kineticElectron      <P^2 De1P>     = <Q^2 De1Q>       (a<->b)
     kineticHole          <P^2 DhaP>     = <Q^2 DhaQ>       (1<->2)
   Runs 12 integrals -- budget accordingly (Block bxMaxPoints if needed). *)
bxQuadratureCheckAll[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ,
   \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ] :=
  With[{\[Omega] = \[HBar]\[Omega]00[a, c]},
   Module[{intD, intX, sp, lg, one, vFull, vRed, attr1a, attr1b, de, dh,
     nP, nQ, vP, vQ, vR, xA, xB, keP, keQ, khP, khQ},
    bxLog["quadratureCheck: start  " <> bxConfigLabel[bxConfigKey[a, c]] <>
      "  maxPoints=" <> ToString[bxMaxPoints]];
    lg[tag_, v_] := (bxLog["  check " <> tag <> " = " <> ToString[v]]; v);
    (* direct-type integral: weight g^2 P(aa,bb)^2 extra[coords, aa, bb] *)
    intD[extra_, aa_, bb_] := bxIntegrate[a, c,
      Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b},
       With[{g = Gcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Gamma], \[Delta]],
             p = Pcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, aa, bb]},
        bxWeight[a, c, \[Omega]][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b] g^2 p^2 *
         extra[r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b, aa, bb]]]];
    (* cross-type integral: weight g^2 P Q extra[coords] *)
    intX[extra_] := bxIntegrate[a, c,
      Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b},
       With[{g = Gcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Gamma], \[Delta]],
             p = Pcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]],
             q = Qcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]]},
        bxWeight[a, c, \[Omega]][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b] g^2 p q *
         extra[r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b]]]];
    sp[x_, y_] := 2 Abs[x - y]/Abs[x + y];
    one = Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b, aa, bb}, 1];
    (* Rydberg Coulomb 2/r; full potential, NO symmetry reduction *)
    vFull = Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b, aa, bb},
      2 (1/rPair[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2] +
         1/rPair[a, c][ua, ra, 0, ub, rb, \[Theta]b]) -
      2 (1/rPair[a, c][u1, r1, \[Theta]1, ua, ra, 0] +
         1/rPair[a, c][u1, r1, \[Theta]1, ub, rb, \[Theta]b] +
         1/rPair[a, c][u2, r2, \[Theta]2, ua, ra, 0] +
         1/rPair[a, c][u2, r2, \[Theta]2, ub, rb, \[Theta]b])];
    (* reduced potential as used in interactionDirectBiexciton *)
    vRed = Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b, aa, bb},
      2 (1/rPair[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2] +
         1/rPair[a, c][ua, ra, 0, ub, rb, \[Theta]b]) -
      4 (1/rPair[a, c][u1, r1, \[Theta]1, ua, ra, 0] +
         1/rPair[a, c][u1, r1, \[Theta]1, ub, rb, \[Theta]b])];
    attr1a = Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b},
      1/rPair[a, c][u1, r1, \[Theta]1, ua, ra, 0]];
    attr1b = Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b},
      1/rPair[a, c][u1, r1, \[Theta]1, ub, rb, \[Theta]b]];
    (* kinetic kernels at the (aa,bb) of the enclosing half *)
    de = Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b, aa, bb},
      DeP[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, aa, bb, \[Gamma], \[Delta]]];
    dh = Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b, aa, bb},
      DhP[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, aa, bb, \[Gamma], \[Delta]]];
    nP = lg["normP", intD[one, \[Alpha], \[Beta]]];
    nQ = lg["normQ", intD[one, \[Beta], \[Alpha]]];
    vP = lg["intFullP", intD[vFull, \[Alpha], \[Beta]]];
    vQ = lg["intFullQ", intD[vFull, \[Beta], \[Alpha]]];
    vR = lg["intReduced", intD[vRed, \[Alpha], \[Beta]]];
    xA = lg["crossR1a", intX[attr1a]];
    xB = lg["crossR1b", intX[attr1b]];
    keP = lg["kinEP", intD[de, \[Alpha], \[Beta]]];
    keQ = lg["kinEQ", intD[de, \[Beta], \[Alpha]]];
    khP = lg["kinHP", intD[dh, \[Alpha], \[Beta]]];
    khQ = lg["kinHQ", intD[dh, \[Beta], \[Alpha]]];
    bxLog["quadratureCheck: done"];
    <|"norm" -> <|"P" -> nP, "Q" -> nQ, "relSpread" -> sp[nP, nQ]|>,
      "interaction" -> <|"P" -> vP, "Q" -> vQ, "relSpread" -> sp[vP, vQ]|>,
      "interactionReduction" ->
       <|"full" -> vP, "reduced" -> vR, "relSpread" -> sp[vP, vR]|>,
      "crossAttraction" ->
       <|"r1a" -> xA, "r1b" -> xB, "relSpread" -> sp[xA, xB]|>,
      "kineticElectron" ->
       <|"P" -> keP, "Q" -> keQ, "relSpread" -> sp[keP, keQ]|>,
      "kineticHole" -> <|"P" -> khP, "Q" -> khQ, "relSpread" -> sp[khP, khQ]|>,
      "maxPoints" -> bxMaxPoints|>]];

(* ---- interaction ---------------------------------------------------------- *)
interactionDirectBiexciton[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ,
   \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ] :=
  With[{\[Omega] = \[HBar]\[Omega]00[a, c]},
   bxIntegrate[a, c,
Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b},
     With[{r12 = rPair[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2],
           rab = rPair[a, c][ua, ra, 0, ub, rb, \[Theta]b],
           r1a = rPair[a, c][u1, r1, \[Theta]1, ua, ra, 0],
           r1b = rPair[a, c][u1, r1, \[Theta]1, ub, rb, \[Theta]b],
           g = Gcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Gamma], \[Delta]],
           p = Pcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]],
           q = Qcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]]},
      bxWeight[a, c, \[Omega]][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b] g^2 (p^2 + q^2)/2 *
       2 ((1/r12 + 1/rab) - 2 (1/r1a + 1/r1b))]]]];

interactionCrossBiexciton[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ,
   \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ] :=
  With[{\[Omega] = \[HBar]\[Omega]00[a, c]},
   bxIntegrate[a, c,
Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b},
     With[{r12 = rPair[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2],
           rab = rPair[a, c][ua, ra, 0, ub, rb, \[Theta]b],
           r1a = rPair[a, c][u1, r1, \[Theta]1, ua, ra, 0],
           g = Gcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Gamma], \[Delta]],
           p = Pcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]],
           q = Qcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]]},
      bxWeight[a, c, \[Omega]][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b] g^2 p q *
       2 ((1/r12 + 1/rab) - 4/r1a)]]]];

(* ---- kinetic kernels ------------------------------------------------------ *)
kineticElectronDirectBiexciton[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ,
   \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ] :=
  With[{\[Omega] = \[HBar]\[Omega]00[a, c]},
   bxIntegrate[a, c,
Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b},
     With[{g = Gcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Gamma], \[Delta]],
           p = Pcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]],
           q = Qcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]],
           dP = DeP[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Alpha], \[Beta], \[Gamma], \[Delta]],
           dQ = DeP[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Beta], \[Alpha], \[Gamma], \[Delta]]},
      bxWeight[a, c, \[Omega]][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b] g^2 (p^2 dP + q^2 dQ)/2]]]];

kineticElectronCrossBiexciton[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ,
   \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ] :=
  With[{\[Omega] = \[HBar]\[Omega]00[a, c]},
   bxIntegrate[a, c,
Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b},
     With[{g = Gcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Gamma], \[Delta]],
           p = Pcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]],
           q = Qcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]],
           x = Xe[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Alpha], \[Beta], \[Gamma], \[Delta]]},
      bxWeight[a, c, \[Omega]][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b] g^2 p q x]]]];

kineticHoleDirectBiexciton[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ,
   \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ] :=
  With[{\[Omega] = \[HBar]\[Omega]00[a, c]},
   bxIntegrate[a, c,
Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b},
     With[{g = Gcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Gamma], \[Delta]],
           p = Pcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]],
           q = Qcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]],
           dP = DhP[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Alpha], \[Beta], \[Gamma], \[Delta]],
           dQ = DhP[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Beta], \[Alpha], \[Gamma], \[Delta]]},
      bxWeight[a, c, \[Omega]][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b] g^2 (p^2 dP + q^2 dQ)/2]]]];

kineticHoleCrossBiexciton[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ,
   \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ] :=
  With[{\[Omega] = \[HBar]\[Omega]00[a, c]},
   bxIntegrate[a, c,
Function[{r1, u1, r2, u2, ra, ua, rb, ub, \[Theta]1, \[Theta]2, \[Theta]b},
     With[{g = Gcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Gamma], \[Delta]],
           p = Pcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]],
           q = Qcorr[a, c][u1, r1, u2, r2, ua, ra, ub, rb, \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]],
           x = Xh[a, c][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b, \[Alpha], \[Beta], \[Gamma], \[Delta]]},
      bxWeight[a, c, \[Omega]][u1, r1, \[Theta]1, u2, r2, \[Theta]2, ua, ra, ub, rb, \[Theta]b] g^2 p q x]]]];

(* ---- assembled energy correction (K + V)/N -------------------------------- *)
energyCorrectionBiexciton[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ,
   \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ] :=
  Module[{lg, nD, nX, vD, vX, keD, keX, khD, khX, kinetic, interaction},
   lg[tag_, v_] := (If[TrueQ[bxVerbose],
      bxLog["  " <> tag <> " = " <> ToString[v]]]; v);
   nD = lg["normDirect", normDirectBiexciton[a, c, \[Alpha], \[Beta], \[Gamma], \[Delta]]];
   nX = lg["normCross", normCrossBiexciton[a, c, \[Alpha], \[Beta], \[Gamma], \[Delta]]];
   vD = lg["intDirect", interactionDirectBiexciton[a, c, \[Alpha], \[Beta], \[Gamma], \[Delta]]];
   vX = lg["intCross", interactionCrossBiexciton[a, c, \[Alpha], \[Beta], \[Gamma], \[Delta]]];
   keD = lg["kinEDirect", kineticElectronDirectBiexciton[a, c, \[Alpha], \[Beta], \[Gamma], \[Delta]]];
   keX = lg["kinECross", kineticElectronCrossBiexciton[a, c, \[Alpha], \[Beta], \[Gamma], \[Delta]]];
   khD = lg["kinHDirect", kineticHoleDirectBiexciton[a, c, \[Alpha], \[Beta], \[Gamma], \[Delta]]];
   khX = lg["kinHCross", kineticHoleCrossBiexciton[a, c, \[Alpha], \[Beta], \[Gamma], \[Delta]]];
   kinetic = 2 ((keD + keX) + (m\:2091/m\:2095) (khD + khX)); (* 2 = two electrons + two holes *)
   interaction = vD + vX;
   (kinetic + interaction)/(nD + nX)];

energyCorrectionBiexcitonQuiet[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ,
   \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ] :=
  Quiet[
   energyCorrectionBiexciton[a, c, \[Alpha], \[Beta], \[Gamma], \[Delta]],
   {NIntegrate::maxp, NIntegrate::ncvb}];

(* ---- total energy: sum of single-particle energies + correction -----------
   Uses the current global configuration (bxElectronStates, bxHoleStates).
   Single-particle energies from definitions.wl: Ee for electrons, Eh for holes
   (hole energies carry the m\:2091/m\:2095 factor). B = 0. *)
totalEnergyBiexciton[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ,
   \[Beta]_?NumericQ, \[Gamma]_?NumericQ, \[Delta]_?NumericQ] :=
  Module[{sp, corr},
   bxLog["totalEnergy: start  " <> bxConfigLabel[bxConfigKey[a, c]] <>
     "  maxPoints=" <> ToString[bxMaxPoints]];
   sp = Total[Ee[a, c, 0] @@@ bxElectronStates] +
     Total[Eh[a, c, 0] @@@ bxHoleStates];
   corr = Block[{bxVerbose = True},
     energyCorrectionBiexcitonQuiet[a, c, \[Alpha], \[Beta], \[Gamma], \[Delta]]];
   bxLog["totalEnergy: done  correction=" <> ToString[corr] <>
     "  total=" <> ToString[sp + corr]];
   <|"singleParticle" -> sp, "correction" -> corr, "total" -> sp + corr,
     "config" -> bxConfigKey[a, c]|>];

(* ---- variational minimization with a live convergence plot ----------------
   ALL run history is IN-MEMORY ONLY (kernel globals below); nothing is ever
   written to disk. It persists between evaluations within one kernel session
   and is gone after a kernel restart.

   bxHistory       : {objective, {\[Alpha],\[Beta],\[Gamma],\[Delta]}} for every evaluation of the
                     CURRENT run.
   bxSteps         : best objective at each NelderMead iteration (drives the
                     live error readout).
   bxHistoryConfig : the configuration (a, c, states, exchange signs) that
                     bxHistory/bxSteps were produced with.
   bxRunArchive    : previous runs keyed by configuration, so history from one
                     state configuration can never be mistaken for another's.
                     A new minimizeBiexciton run warm-starts NelderMead from the
                     archived best parameters ONLY if the configuration matches
                     exactly; otherwise it starts fresh.

   The optimizer's stopping tolerance MUST be looser than the integration accuracy
   bxPrecisionGoal, otherwise NMinimize keeps chasing sub-noise improvements and
   never terminates. bxOptPrecisionGoal ~ 1-2 (below bxPrecisionGoal = 3) is right. *)
(* stall guard: NelderMead's own convergence test rarely fires on a noisy
   objective (spurious noise-improvements keep the simplex from contracting),
   so runs otherwise grind to the MaxIterations cap at ~7 evaluations per
   iteration. Stop instead when the best value has improved by less than
   bxStallTol over the last bxStallIterations iterations -- i.e. the plateau
   criterion one applies to the convergence plot by eye. *)
bxStallIterations = 10;
bxStallTol = 0.02;   (* Ry; set to your per-evaluation noise scale *)

bxOptPrecisionGoal = 1;    (* NMinimize relative stop tolerance (~10%). MUST stay
   strictly below bxPrecisionGoal: with equal goals the optimizer's tolerance
   sits at the integration noise floor and NelderMead shrink-loops for hours
   without converging (observed: 384 evaluations, best flat after ~185). *)
bxOptAccuracyGoal = 1;

bxConfigKey[aa_, cc_] := <|"a" -> aa, "c" -> cc,
   "electronStates" -> bxElectronStates, "holeStates" -> bxHoleStates,
   "etaE" -> bxEtaE, "etaH" -> bxEtaH|>;

bxHistory = {};
bxSteps = {};
bxHistoryConfig = Missing["NoRun"];

(* ---- archive persistence ---------------------------------------------------
   bxRunArchive is mirrored to a WXF file next to this .wl, so past runs
   survive kernel restarts. It is loaded here at Get time (unless the session
   already has a newer in-memory archive) and re-saved by minimizeBiexciton
   after every archived run. Delete the file to start clean. *)
bxArchiveFile = FileNameJoin[{
   With[{d = DirectoryName[$InputFileName]},
    If[d === "", Quiet[Check[NotebookDirectory[], Directory[]]], d]],
   "bx-run-archive.wxf"}];

bxSaveArchive[] := Export[bxArchiveFile, bxRunArchive, "WXF"];

If[!AssociationQ[bxRunArchive],   (* don't clobber a live session archive on re-Get *)
 bxRunArchive = If[FileExistsQ[bxArchiveFile],
   Import[bxArchiveFile, "WXF"], <||>]];

(* one line appended per objective evaluation, so progress is visible from
   outside the kernel (FilePrint / tail) even mid-minimization; reset at the
   start of each run *)
bxProgressFile = FileNameJoin[{DirectoryName[bxArchiveFile], "bx-progress.log"}];

bxLog[s_String] := PutAppend[{DateString[], s}, bxProgressFile];
bxVerbose = False;   (* True: energyCorrectionBiexciton logs each of its 8
   integrals. Left False during minimization (one line per evaluation there);
   totalEnergyBiexciton switches it on for the finalization step. *)

bxConfigLabel[key_Association] :=
  StringJoin["e:", ToString[key["electronStates"]],
   "  h:", ToString[key["holeStates"]],
   "  \[Eta]:", ToString[{key["etaE"], key["etaH"]}],
   "  a=", ToString[key["a"]], " c=", ToString[key["c"]]];

(* True when the recorded history was produced under a DIFFERENT state
   configuration than the one currently set in the globals. *)
bxHistoryStaleQ[] :=
  bxHistory =!= {} && !MissingQ[bxHistoryConfig] &&
   bxHistoryConfig[[{"electronStates", "holeStates", "etaE", "etaH"}]] =!=
    <|"electronStates" -> bxElectronStates, "holeStates" -> bxHoleStates,
      "etaE" -> bxEtaE, "etaH" -> bxEtaH|>;

bxConvergencePlot[] :=
  If[Length[bxHistory] < 2, "collecting evaluations\[Ellipsis]",
   With[{best = FoldList[Min, bxHistory[[All, 1]]]},
    ListLinePlot[{bxHistory[[All, 1]], best},
     PlotLegends -> {"objective", "best"}, Mesh -> All, Frame -> True,
     FrameLabel -> {"function evaluation", "energy correction (Ry)"},
     PlotLabel -> Column[{
        If[MissingQ[bxHistoryConfig], Nothing,
         Style[bxConfigLabel[bxHistoryConfig], Gray, 11]],
        If[bxHistoryStaleQ[],
         Style["STALE: history is from a different state configuration",
          Red, Bold], Nothing],
        Row[{"best ", NumberForm[Last[best], 6],
          "     last-step \[CapitalDelta] ",
          If[Length[bxSteps] >= 2,
           ScientificForm[Abs[bxSteps[[-1]] - bxSteps[[-2]]], 2], "\[Dash]"]}]},
       Alignment -> Center],
     ImageSize -> 500]]];

bxOptimum[] :=
  If[bxHistory === {}, Missing["NoHistory"],
   With[{best = First@MinimalBy[bxHistory, First]},
    <|"energy" -> best[[1]], "params" -> best[[2]],
      "evaluations" -> Length[bxHistory],
      "config" -> bxHistoryConfig,
      "staleConfig" -> bxHistoryStaleQ[]|>]];

(* NelderMead initial simplex around a previous best point, clipped to stay
   strictly inside the search bounds. *)
bxSimplexAround[p_List] :=
  With[{lo = {0.001, 0.001, -0.999, 0.001}, hi = {9.999, 9.999, 4.999, 9.999}},
   Map[MapThread[Clip[#1, {#2, #3}] &, {#, lo, hi}] &,
    Join[{p}, Table[p + 0.2 UnitVector[4, i], {i, 4}]]]];

(* among archived runs with IDENTICAL states and exchange signs, the one whose
   geometry is closest to (a, c); the factor 10 on c reflects the stronger
   sensitivity to the small semiaxis. Used as a warm-start fallback: the
   optimal (\[Alpha],\[Beta],\[Gamma],\[Delta]) vary smoothly with geometry, so a neighbouring
   geometry's optimum is a far better simplex seed than a cold start. *)
bxNearestArchiveKey[key_] := Module[{cands},
   cands = Select[Keys[bxRunArchive],
     #[[{"electronStates", "holeStates", "etaE", "etaH"}]] ===
       key[[{"electronStates", "holeStates", "etaE", "etaH"}]] &];
   If[cands === {}, Missing["None"],
    First@SortBy[cands,
      ((#["a"] - key["a"])^2 + 10 (#["c"] - key["c"])^2) &]]];

(* start: Automatic = warm-start from the archived best of the SAME
   configuration if one exists, else from the nearest-geometry archived run
   with identical states (bxNearestArchiveKey); a list {\[Alpha],\[Beta],\[Gamma],\[Delta]} forces
   that start point; None forces a cold start. *)
minimizeBiexciton[a_?NumericQ, c_?NumericQ, maxIter_: 50, start_: Automatic] :=
  Module[{obj, key = bxConfigKey[a, c], init, method, result},
   (* archive the outgoing run under ITS OWN configuration *)
   If[bxHistory =!= {} && !MissingQ[bxHistoryConfig],
    bxRunArchive[bxHistoryConfig] =
     <|"history" -> bxHistory, "steps" -> bxSteps|>;
    bxSaveArchive[]];
   bxHistory = {}; bxSteps = {}; bxHistoryConfig = key;
   Quiet[DeleteFile[bxProgressFile]];
   bxLog["minimize: start  " <> bxConfigLabel[key]];
   init = Which[
     start === None, None,
     start =!= Automatic, start,
     KeyExistsQ[bxRunArchive, key],
      First[MinimalBy[bxRunArchive[key]["history"], First]][[2]],
     True,
      With[{nk = bxNearestArchiveKey[key]},
       If[MissingQ[nk], None,
        bxLog["warm start from nearest geometry: " <> bxConfigLabel[nk]];
        First[MinimalBy[bxRunArchive[nk]["history"], First]][[2]]]]];
   (* "PostProcess" -> False: for constrained problems NMinimize by default
      polishes the NelderMead result with a derivative-based FindMinimum.
      On a noisy objective the finite-difference derivatives are pure noise,
      the polish burns hundreds of evaluations at the noise floor, and it is
      invisible to StepMonitor -- so the stall guard cannot stop it. *)
   method = If[init === None,
     {"NelderMead", "PostProcess" -> False},
     {"NelderMead", "PostProcess" -> False,
      "InitialPoints" -> bxSimplexAround[init]}];
   obj[al_?NumericQ, be_?NumericQ, ga_?NumericQ, de_?NumericQ] :=
     With[{e = energyCorrectionBiexcitonQuiet[a, c, al, be, ga, de]},
      AppendTo[bxHistory, {e, {al, be, ga, de}}];
      PutAppend[<|"eval" -> Length[bxHistory], "E" -> e,
        "params" -> {al, be, ga, de}, "time" -> DateString[]|>,
       bxProgressFile]; e];
   result = CheckAbort[Monitor[
     Catch[
      NMinimize[
       {obj[\[Alpha], \[Beta], \[Gamma], \[Delta]],
        0 < \[Alpha] < 10 && 0 < \[Beta] < 10 && -1 < \[Gamma] < 5 && 0 < \[Delta] < 10},
       {\[Alpha], \[Beta], \[Gamma], \[Delta]},
       Method -> method, MaxIterations -> maxIter,
       AccuracyGoal -> bxOptAccuracyGoal, PrecisionGoal -> bxOptPrecisionGoal,
       StepMonitor :> (AppendTo[bxSteps, Min[bxHistory[[All, 1]]]];
         If[Length[bxSteps] > bxStallIterations &&
           bxSteps[[-bxStallIterations]] - bxSteps[[-1]] < bxStallTol,
          Throw[$Stalled, "bxStall"]])],
      "bxStall"],
     bxConvergencePlot[]], $Aborted];
   (* on a stall the best point is in the history; report it like NMinimize *)
   If[result === $Stalled,
    result = With[{best = First@MinimalBy[bxHistory, First]},
      {best[[1]], Thread[{\[Alpha], \[Beta], \[Gamma], \[Delta]} -> best[[2]]]}]];
   (* archive + save the finished (or aborted) run immediately, so it survives
      a kernel restart without waiting for the next minimizeBiexciton call *)
   If[bxHistory =!= {},
    bxRunArchive[key] = <|"history" -> bxHistory, "steps" -> bxSteps|>;
    bxSaveArchive[]];
   result];
