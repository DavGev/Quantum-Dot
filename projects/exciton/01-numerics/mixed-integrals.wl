(* ::Package:: *)

(* ============================================================================
   mixed-integrals.wl  --  exciton norm / interaction integrals + energy
   ----------------------------------------------------------------------------
   Mirrors the biexciton framework (projects/biexciton/01-numerics and the
   Computational Design Log note):
     - ClearAll header, so a re-Get never leaves stale downvalues;
     - AccuracyGoal -> Infinity, so the relative PrecisionGoal governs at any
       integral scale and "converged" cannot fire on the absolute criterion;
     - importance-sampled integration with the reference adapted to the
       configured states (exElectronState / exHoleState) + ground floor;
     - quadrature diagnostics from exact identities (exQuadratureCheck);
     - per-configuration run history, archived to disk, warm starts;
     - totalEnergyExciton = single-particle energies + correction.

   The kinetic term is analytic, \[Alpha]^2 (1 + m\:2091/m\:2095), and orbital-independent:
   it comes from the Jastrow factor F = Exp[-\[Alpha] rEH] with |\[Del]F|^2 = \[Alpha]^2 F^2 and
   |\[Del]rEH|^2 = 1, and the Jastrow cross term vanishes by stationary-state
   continuity even for complex (excited) orbitals.

   Depends on: definitions.wl, mixed-correlation.wl, mixed-density.wl.
   ============================================================================ *)

(* wipe any stale definitions from a previous Get (old argument patterns would
   otherwise survive a re-Get and shadow updated ones). exRunArchive is
   deliberately NOT cleared: the live session archive survives a re-Get, and a
   fresh kernel loads it from exArchiveFile below. *)
ClearAll[exRmax, exMaxPoints, exPrecisionGoal, exAccuracyGoal,
  exImportanceSampling, exRefMix, exRefGrid, exStateMaps,
  exIntegrate, exIntegrateUniform, exIntegrateIS,
  normExciton, interactionExciton, exQuadratureCheck,
  energyCorrectionExciton, energyCorrectionExcitonQuiet,
  totalEnergyExciton,
  exStallIterations, exStallTol,
  exOptPrecisionGoal, exOptAccuracyGoal, exConfigKey,
  exHistory, exSteps, exHistoryConfig, exHistoryStaleQ,
  exConfigLabel, exConvergencePlot, exOptimum, exSimplexAround,
  exNearestArchiveKey, minimizeExciton,
  exArchiveFile, exSaveArchive];

(* ---- integration controls -------------------------------------------------- *)
exRmax = 0.9;              (* radial cutoff as a fraction of a *)
exMaxPoints = 2*10^5;      (* Monte-Carlo budget per integral *)
exPrecisionGoal = 3;       (* relative accuracy per integral (~0.1%) *)
exAccuracyGoal = Infinity; (* absolute criterion disabled: any finite value can
   exceed the integral itself and make NIntegrate "converge" instantly with
   O(100%) error (see the biexciton Computational Design Log). *)

(* ---- state-adapted importance sampling --------------------------------------
   Same construction as the biexciton bxStateMaps, but the electron and hole
   are distinguishable: each particle's reference is ITS OWN orbital density
   plus a ground-state floor (weight exRefMix) that keeps the reference
   strictly positive, so the Jacobian stays bounded at orbital nodes.
   Maps are tabulated inverse CDFs, memoized per (\[Omega], rmax, state). *)
exImportanceSampling = True;
exRefMix = 0.1;
exRefGrid = 2048;

exStateMaps[\[Omega]_, rmax_, state_] := exStateMaps[\[Omega], rmax, state] =
  Module[{rpdf, updf, rgrid, ugrid, rvals, uvals, rcdf, ucdf, rtot, utot},
   rpdf[r_] := (1 - exRefMix) \[Psi]r[state[[2]], state[[3]]][\[Omega], r]^2 r +
     exRefMix \[Omega] r Exp[-\[Omega] r^2/2]/(2 \[Pi]);
   updf[u_] := (1 - exRefMix) 2 Sin[state[[1]] \[Pi] u]^2 +
     exRefMix 2 Sin[\[Pi] u]^2;
   rgrid = N@Subdivide[0, rmax, exRefGrid];
   ugrid = N@Subdivide[0, 1, exRefGrid];
   rvals = rpdf /@ rgrid;
   uvals = updf /@ ugrid;
   rcdf = Prepend[Accumulate[(Most[rvals] + Rest[rvals])/2], 0.] rmax/exRefGrid;
   ucdf = Prepend[Accumulate[(Most[uvals] + Rest[uvals])/2], 0.]/exRefGrid;
   rtot = Last[rcdf]; utot = Last[ucdf];
   <|"rFromV" -> Interpolation[Transpose[{rcdf/rtot, rgrid}]],
     "rJac" -> Function[r, rtot/rpdf[r]],
     "uFromX" -> Interpolation[Transpose[{ucdf/utot, ugrid}]],
     "uJac" -> Function[u, utot/updf[u]]|>];

(* shared 5-fold measure; integrand is a pure Function of (r1, u1, ra, ua, \[Theta]). *)
exIntegrateUniform[a_, c_, integrand_] :=
  NIntegrate[
   integrand[r1, u1, ra, ua, \[Theta]],
   {r1, 0, a exRmax}, {u1, 0, 1}, {ra, 0, a exRmax}, {ua, 0, 1}, {\[Theta], 0, \[Pi]},
   Method -> {"AdaptiveQuasiMonteCarlo", "BisectionDithering" -> 0,
     "MaxPoints" -> exMaxPoints},
   AccuracyGoal -> exAccuracyGoal, PrecisionGoal -> exPrecisionGoal,
   WorkingPrecision -> MachinePrecision];

exIntegrateIS[a_, c_, integrand_] :=
  With[{\[Omega] = \[HBar]\[Omega]00[a, c], rmax = a exRmax},
   With[{me = exStateMaps[\[Omega], rmax, exElectronState],
         mh = exStateMaps[\[Omega], rmax, exHoleState]},
    NIntegrate[
     Module[{r1 = me["rFromV"][v1], u1 = me["uFromX"][x1],
       ra = mh["rFromV"][va], ua = mh["uFromX"][xa]},
      integrand[r1, u1, ra, ua, \[Theta]] *
       me["rJac"][r1] mh["rJac"][ra] me["uJac"][u1] mh["uJac"][ua]],
     {v1, 0, 1}, {x1, 0, 1}, {va, 0, 1}, {xa, 0, 1}, {\[Theta], 0, \[Pi]},
     Method -> {"AdaptiveQuasiMonteCarlo", "BisectionDithering" -> 0,
       "MaxPoints" -> exMaxPoints},
     AccuracyGoal -> exAccuracyGoal, PrecisionGoal -> exPrecisionGoal,
     WorkingPrecision -> MachinePrecision]]];

exIntegrate[a_, c_, integrand_] :=
  If[TrueQ[exImportanceSampling],
   exIntegrateIS[a, c, integrand],
   exIntegrateUniform[a, c, integrand]];

(* ---- normalization -------------------------------------------------------- *)
normExciton[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ] :=
  Module[{\[Omega] = \[HBar]\[Omega]00[a, c]},
   exIntegrate[a, c,
    Function[{r1, u1, ra, ua, \[Theta]},
     4 \[Pi] psiWeightExcitonMixed[a, c, \[Omega]][u1, r1, ua, ra] *
       Exp[-2 \[Alpha] rEH[a, c][u1, r1, ua, ra, \[Theta]]] *
       r1 ra]]];

(* ---- Coulomb interaction (Rydberg units: -2/r) ----------------------------- *)
interactionExciton[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ] :=
  Module[{\[Omega] = \[HBar]\[Omega]00[a, c]},
   exIntegrate[a, c,
    Function[{r1, u1, ra, ua, \[Theta]},
     With[{dist = rEH[a, c][u1, r1, ua, ra, \[Theta]]},
      4 \[Pi] psiWeightExcitonMixed[a, c, \[Omega]][u1, r1, ua, ra] *
        Exp[-2 \[Alpha] dist] *
        (-2/dist) *
        r1 ra]]]];

(* ---- quadrature diagnostics -------------------------------------------------
   Two exact identities:
   (1) normExciton[a, c, 0] = 1 for ANY state configuration: the orbitals are
       normalized and the gauge factors (4\[Pi], electron azimuth fixed, \[Theta] on
       (0,\[Pi])) cancel exactly. An ABSOLUTE test of measure + rule.
   (2) swapping the electron and hole STATES leaves norm and interaction
       invariant: rEH is symmetric and the density factorizes (relabel
       1 <-> a). A relative test at the working \[Alpha]. Trivial (bit-identical)
       when the two states are already equal -- rely on (1) there. *)
exQuadratureCheck[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ] :=
  Module[{sp, n0, n, v, nS, vS},
   sp[x_, y_] := 2 Abs[x - y]/Abs[x + y];
   n0 = normExciton[a, c, 0.];
   n = normExciton[a, c, \[Alpha]];
   v = interactionExciton[a, c, \[Alpha]];
   With[{s1 = exElectronState, s2 = exHoleState},
    Block[{exElectronState = s2, exHoleState = s1},
     nS = normExciton[a, c, \[Alpha]];
     vS = interactionExciton[a, c, \[Alpha]]]];
   <|"normAlpha0" -> <|"value" -> n0, "exact" -> 1, "error" -> Abs[n0 - 1]|>,
     "normSwap" -> <|"config" -> n, "swapped" -> nS, "relSpread" -> sp[n, nS]|>,
     "interactionSwap" ->
      <|"config" -> v, "swapped" -> vS, "relSpread" -> sp[v, vS]|>,
     "maxPoints" -> exMaxPoints|>];

(* ---- assembled energy correction (\[Alpha]^2 kinetic + V/N) ------------------------ *)
energyCorrectionExciton[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ] :=
  Module[{norm, pot, kinetic},
   norm = normExciton[a, c, \[Alpha]];
   pot = interactionExciton[a, c, \[Alpha]];
   kinetic = \[Alpha]^2 (1 + m\:2091/m\:2095);
   kinetic + pot/norm];

energyCorrectionExcitonQuiet[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ] :=
  Quiet[
   energyCorrectionExciton[a, c, \[Alpha]],
   {NIntegrate::maxp, NIntegrate::ncvb}];

(* ---- total energy: single-particle energies + correction ------------------- *)
totalEnergyExciton[a_?NumericQ, c_?NumericQ, \[Alpha]_?NumericQ] :=
  Module[{sp, corr},
   sp = Ee[a, c, 0] @@ exElectronState + Eh[a, c, 0] @@ exHoleState;
   corr = energyCorrectionExcitonQuiet[a, c, \[Alpha]];
   <|"singleParticle" -> sp, "correction" -> corr, "total" -> sp + corr,
     "config" -> exConfigKey[a, c]|>];

(* ---- minimization with per-configuration history ----------------------------
   Same bookkeeping as minimizeBiexciton: history keyed by configuration,
   archived to disk (survives kernel restarts), warm start ONLY from a run
   with the exact same configuration, save-on-abort via CheckAbort. The
   optimizer goals sit one order below exPrecisionGoal, so the stopping
   tolerance stays above the integration noise floor. *)
exOptPrecisionGoal = 2;
exOptAccuracyGoal = 2;

(* stall guard, as in the biexciton package: stop when the best value has
   improved by less than exStallTol over the last exStallIterations
   iterations (NelderMead's own test rarely fires on a noisy objective). *)
exStallIterations = 10;
exStallTol = 0.005;  (* Ry; exciton integrals run at PrecisionGoal 3 *)

exConfigKey[aa_, cc_] := <|"a" -> aa, "c" -> cc,
   "electronState" -> exElectronState, "holeState" -> exHoleState|>;

exHistory = {};
exSteps = {};
exHistoryConfig = Missing["NoRun"];

exArchiveFile = FileNameJoin[{
   With[{d = DirectoryName[$InputFileName]},
    If[d === "", Quiet[Check[NotebookDirectory[], Directory[]]], d]],
   "ex-run-archive.wxf"}];

exSaveArchive[] := Export[exArchiveFile, exRunArchive, "WXF"];

If[!AssociationQ[exRunArchive],   (* don't clobber a live session archive on re-Get *)
 exRunArchive = If[FileExistsQ[exArchiveFile],
   Import[exArchiveFile, "WXF"], <||>]];

exHistoryStaleQ[] :=
  exHistory =!= {} && !MissingQ[exHistoryConfig] &&
   exHistoryConfig[[{"electronState", "holeState"}]] =!=
    <|"electronState" -> exElectronState, "holeState" -> exHoleState|>;

exConfigLabel[key_Association] :=
  StringJoin["e:", ToString[key["electronState"]],
   "  h:", ToString[key["holeState"]],
   "  a=", ToString[key["a"]], " c=", ToString[key["c"]]];

exConvergencePlot[] :=
  If[Length[exHistory] < 2, "collecting evaluations\[Ellipsis]",
   With[{best = FoldList[Min, exHistory[[All, 1]]]},
    ListLinePlot[{exHistory[[All, 1]], best},
     PlotLegends -> {"objective", "best"}, Mesh -> All, Frame -> True,
     FrameLabel -> {"function evaluation", "energy correction (Ry)"},
     PlotLabel -> Column[{
        If[MissingQ[exHistoryConfig], Nothing,
         Style[exConfigLabel[exHistoryConfig], Gray, 11]],
        If[exHistoryStaleQ[],
         Style["STALE: history is from a different state configuration",
          Red, Bold], Nothing],
        Row[{"best ", NumberForm[Last[best], 6]}]}, Alignment -> Center],
     ImageSize -> 500]]];

exOptimum[] :=
  If[exHistory === {}, Missing["NoHistory"],
   With[{best = First@MinimalBy[exHistory, First]},
    <|"energy" -> best[[1]], "params" -> best[[2]],
      "evaluations" -> Length[exHistory],
      "config" -> exHistoryConfig,
      "staleConfig" -> exHistoryStaleQ[]|>]];

(* NelderMead initial simplex (2 points in 1D) around a previous best \[Alpha] *)
exSimplexAround[{al_}] :=
  {{Clip[al, {0.001, 9.999}]}, {Clip[al + 0.2, {0.001, 9.999}]}};

(* among archived runs with IDENTICAL states, the one whose geometry is
   closest to (a, c) -- warm-start fallback, as in the biexciton package. *)
exNearestArchiveKey[key_] := Module[{cands},
   cands = Select[Keys[exRunArchive],
     #[[{"electronState", "holeState"}]] ===
       key[[{"electronState", "holeState"}]] &];
   If[cands === {}, Missing["None"],
    First@SortBy[cands,
      ((#["a"] - key["a"])^2 + 10 (#["c"] - key["c"])^2) &]]];

(* start: Automatic = warm-start from the archived best of the SAME
   configuration if one exists, else from the nearest-geometry archived run
   with identical states; {\[Alpha]} forces that start; None = cold start. *)
minimizeExciton[a_?NumericQ, c_?NumericQ, maxIter_: 50, start_: Automatic] :=
  Module[{obj, key = exConfigKey[a, c], init, method, result},
   If[exHistory =!= {} && !MissingQ[exHistoryConfig],
    exRunArchive[exHistoryConfig] =
     <|"history" -> exHistory, "steps" -> exSteps|>;
    exSaveArchive[]];
   exHistory = {}; exSteps = {}; exHistoryConfig = key;
   init = Which[
     start === None, None,
     start =!= Automatic, start,
     KeyExistsQ[exRunArchive, key],
      First[MinimalBy[exRunArchive[key]["history"], First]][[2]],
     True,
      With[{nk = exNearestArchiveKey[key]},
       If[MissingQ[nk], None,
        First[MinimalBy[exRunArchive[nk]["history"], First]][[2]]]]];
   (* "PostProcess" -> False: see the biexciton package -- the default
      derivative polish spins on a noisy objective and evades the stall guard. *)
   method = If[init === None,
     {"NelderMead", "PostProcess" -> False},
     {"NelderMead", "PostProcess" -> False,
      "InitialPoints" -> exSimplexAround[init]}];
   obj[al_?NumericQ] :=
     With[{e = energyCorrectionExcitonQuiet[a, c, al]},
      AppendTo[exHistory, {e, {al}}]; e];
   result = CheckAbort[Monitor[
     Catch[
      NMinimize[
       {obj[\[Alpha]], 0 < \[Alpha] < 10}, \[Alpha],
       Method -> method, MaxIterations -> maxIter,
       AccuracyGoal -> exOptAccuracyGoal, PrecisionGoal -> exOptPrecisionGoal,
       StepMonitor :> (AppendTo[exSteps, Min[exHistory[[All, 1]]]];
         If[Length[exSteps] > exStallIterations &&
           exSteps[[-exStallIterations]] - exSteps[[-1]] < exStallTol,
          Throw[$Stalled, "exStall"]])],
      "exStall"],
     exConvergencePlot[]], $Aborted];
   If[result === $Stalled,
    result = With[{best = First@MinimalBy[exHistory, First]},
      {best[[1]], {\[Alpha] -> best[[2, 1]]}}]];
   If[exHistory =!= {},
    exRunArchive[key] = <|"history" -> exHistory, "steps" -> exSteps|>;
    exSaveArchive[]];
   result];
