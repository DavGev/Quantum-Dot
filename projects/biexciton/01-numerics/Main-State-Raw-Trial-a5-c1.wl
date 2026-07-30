(* ============================================================================
   Fully unreduced fixed-parameter benchmark at (a,c) = (5,1).

   Purpose:
     Provide an independent numerical reference in which no particle-exchange
     or angular symmetry is used to reduce the X or XX energy integrals.

   "Fully unreduced" means:
     - every particle has its own azimuth in [0, 2 Pi];
     - the XX norm uses G^2 (P + Q)^2 pointwise;
     - the XX Coulomb integrand contains all six pair potentials;
     - the XX kinetic integrand contains e1, e2, ha, and hb explicitly;
     - the X kinetic correction is integrated explicitly rather than replaced
       by alpha^2 (1 + m_l/m_h).

   The existing importance-sampling coordinate maps and radial cutoff are
   retained. They are changes of integration variables, not symmetry
   reductions. Existing production optima are imported and held fixed.

   This file changes no production setting, performs no minimization, and
   writes only main-state-raw-trial-a5-c1-* result files. Individual integrals
   are checkpointed and reused after an interrupted run.

   Evaluate through Main-State-Raw-Trial-a5-c1.nb.
   ============================================================================ *)

rawTrialDirectory = DirectoryName[$InputFileName];
rawTrialRoot = ParentDirectory[rawTrialDirectory, 3];
rawTrialExcitonDirectory =
  FileNameJoin[{
    ParentDirectory[rawTrialDirectory, 2], "exciton", "01-numerics"}];

Get[FileNameJoin[{
  rawTrialRoot, "shared", "numerics", "definitions.wl"}]];
Get[FileNameJoin[{
  rawTrialExcitonDirectory, "mixed-correlation.wl"}]];
Get[FileNameJoin[{
  rawTrialExcitonDirectory, "mixed-density.wl"}]];
Get[FileNameJoin[{
  rawTrialExcitonDirectory, "mixed-integrals.wl"}]];
Get[FileNameJoin[{rawTrialDirectory, "mixed-correlation.wl"}]];
Get[FileNameJoin[{rawTrialDirectory, "mixed-density.wl"}]];
Get[FileNameJoin[{rawTrialDirectory, "mixed-integrals.wl"}]];

ClearAll[
  rawTrialKey, rawTrialLog, rawTrialParseMaxPointsMessage,
  rawTrialCheckpoint, rawTrialExportCSV, rawTrialTimed,
  rawTrialReducedReference,
  rawTrialXIntegrateIS, rawTrialXXIntegrateIS,
  rawTrialXMeasure, rawTrialXXMeasure,
  rawTrialXNorm, rawTrialXInteraction, rawTrialXKinetic,
  rawTrialXXNorm, rawTrialXXInteraction, rawTrialXXKinetic,
  rawTrialRunBudget, rawTrialSummary];

rawTrialA = 5.;
rawTrialC = 1.;
rawTrialBudgets = {10^6, 2*10^6};
rawTrialPrecisionGoal = 4;
rawTrialAccuracyGoal = Infinity;
rawTrialBisectionDithering = 0;
rawTrialGroundState = {1, 0, 0};

rawTrialProductionFile =
  FileNameJoin[{
    rawTrialDirectory, "main-state-production-results.wxf"}];
rawTrialReducedReferenceFile =
  FileNameJoin[{
    rawTrialDirectory,
    "main-state-convergence-trial-a5-c1-results.wxf"}];
rawTrialOutputFile =
  FileNameJoin[{
    rawTrialDirectory, "main-state-raw-trial-a5-c1-results.wxf"}];
rawTrialIntegralCSV =
  FileNameJoin[{
    rawTrialDirectory, "main-state-raw-trial-a5-c1-integrals.csv"}];
rawTrialSummaryCSV =
  FileNameJoin[{
    rawTrialDirectory, "main-state-raw-trial-a5-c1-summary.csv"}];
rawTrialLogFile =
  FileNameJoin[{
    rawTrialDirectory, "main-state-raw-trial-a5-c1.log"}];

rawTrialKey[aa_?NumericQ, cc_?NumericQ] :=
  StringRiffle[ToString[#, InputForm] & /@ N[{aa, cc}], "|"];

rawTrialProductionStore = Import[rawTrialProductionFile, "WXF"];
rawTrialSavedRun =
  Lookup[
    Lookup[rawTrialProductionStore, "runs", <||>],
    rawTrialKey[rawTrialA, rawTrialC],
    Missing["GeometryNotFound"]];

If[
  ! AssociationQ[rawTrialSavedRun] ||
    ! AssociationQ[Lookup[rawTrialSavedRun, "X", Missing[]]] ||
    ! AssociationQ[Lookup[rawTrialSavedRun, "XX", Missing[]]],
  Print[
    "No complete stored X/XX production result exists for ",
    {rawTrialA, rawTrialC}, " in ", rawTrialProductionFile];
  Abort[]];

rawTrialSavedX = rawTrialSavedRun["X"];
rawTrialSavedXX = rawTrialSavedRun["XX"];
rawTrialAlpha = rawTrialSavedX["alpha"];
rawTrialXXParameters = rawTrialSavedXX["params"];

(* The earlier fixed-parameter convergence trial supplies same-budget reduced
   energies when available. This is read-only; no reduced integral is rerun. *)
rawTrialReducedReferenceStore =
  If[
    FileExistsQ[rawTrialReducedReferenceFile],
    Quiet[Check[
      Import[rawTrialReducedReferenceFile, "WXF"],
      <||>]],
    <||>];
rawTrialReducedReferenceResults =
  If[
    AssociationQ[rawTrialReducedReferenceStore],
    Lookup[rawTrialReducedReferenceStore, "budgetResults", {}],
    {}];

rawTrialReducedReference[budget_Integer] := Module[{matches},
  matches =
    Select[
      rawTrialReducedReferenceResults,
      Lookup[#, "budget", Missing[]] === budget &];
  If[matches === {}, Missing["NotAvailable"], Last[matches]]];

If[
  ! NumericQ[rawTrialAlpha] ||
    ! MatchQ[
      rawTrialXXParameters,
      {_?NumericQ, _?NumericQ, _?NumericQ, _?NumericQ}],
  Print[
    "The stored optimum parameters are not numeric: ",
    <|
      "XAlpha" -> rawTrialAlpha,
      "XXParameters" -> rawTrialXXParameters|>];
  Abort[]];

(* Match the ground-state production configuration exactly. *)
exElectronState = rawTrialGroundState;
exHoleState = rawTrialGroundState;
bxElectronStates = {rawTrialGroundState, rawTrialGroundState};
bxHoleStates = {rawTrialGroundState, rawTrialGroundState};
bxEtaE = 1;
bxEtaH = 1;

rawTrialIntegralRows = {};
rawTrialBudgetResults = {};
rawTrialCurrentBudget = Missing["NotRunning"];

(* Resume only checkpoints produced by this exact implementation and optimum. *)
If[FileExistsQ[rawTrialOutputFile],
  rawTrialPrevious =
    Quiet[Check[Import[rawTrialOutputFile, "WXF"], $Failed]];
  If[
    AssociationQ[rawTrialPrevious] &&
      Lookup[rawTrialPrevious, "schemaVersion", Missing[]] === 1 &&
      Lookup[
        rawTrialPrevious, "implementation", Missing[]] ===
          "fully-unreduced-v1" &&
      Lookup[
        rawTrialPrevious, "fixedParameters", Missing[]] ===
          <|
            "XAlpha" -> rawTrialAlpha,
            "XXParameters" -> rawTrialXXParameters|>,
    rawTrialIntegralRows =
      Lookup[rawTrialPrevious, "integrals", {}];
    rawTrialBudgetResults =
      Lookup[rawTrialPrevious, "budgetResults", {}],
    Print[
      "Existing raw-trial checkpoint is incompatible and will not be reused: ",
      rawTrialOutputFile]]];

rawTrialLog[text_String] := Module[
  {stream = OpenAppend[rawTrialLogFile]},
  WriteString[stream, DateString["ISODateTime"], "  ", text, "\n"];
  Close[stream]];

(* Extract the value and error estimate printed by NIntegrate::maxp. *)
rawTrialParseMaxPointsMessage[text_String] := Module[
  {matches, clean, numbers},
  matches =
    StringCases[
      text,
      RegularExpression[
        "NIntegrate obtained\\s+([^\\s]+)\\s+and\\s+([^\\s]+)\\s+for"] ->
        {"$1", "$2"}];
  If[matches === {}, Return[<||>]];
  clean[token_] :=
    StringReplace[token, RegularExpression["`[0-9.]*"] -> ""];
  numbers =
    Quiet[Check[
      ToExpression /@ (clean /@ First[matches]),
      $Failed]];
  If[
    MatchQ[numbers, {_?NumericQ, _?NumericQ}],
    <|
      "messageIntegralEstimate" -> numbers[[1]],
      "reportedErrorEstimate" -> numbers[[2]]|>,
    <||>]];

rawTrialExportCSV[file_String, rows_List, columns_List] :=
  Export[
    file,
    Prepend[
      (Lookup[#, columns, Missing["NotAvailable"]] & /@ rows),
      columns],
    "CSV"];

rawTrialCheckpoint[] := Module[
  {payload, integralColumns, summaryColumns},
  payload = <|
    "schemaVersion" -> 1,
    "implementation" -> "fully-unreduced-v1",
    "updated" -> DateString["ISODateTime"],
    "geometry" -> <|"a" -> rawTrialA, "c" -> rawTrialC|>,
    "budgets" -> rawTrialBudgets,
    "precisionGoal" -> rawTrialPrecisionGoal,
    "accuracyGoal" -> rawTrialAccuracyGoal,
    "bisectionDithering" -> rawTrialBisectionDithering,
    "sourceProductionResult" -> rawTrialProductionFile,
    "sourceReducedConvergenceResult" -> rawTrialReducedReferenceFile,
    "fixedParameters" -> <|
      "XAlpha" -> rawTrialAlpha,
      "XXParameters" -> rawTrialXXParameters|>,
    "budgetResults" -> rawTrialBudgetResults,
    "integrals" -> rawTrialIntegralRows|>;
  Export[rawTrialOutputFile, payload, "WXF"];

  integralColumns = {
    "budget", "system", "integral", "seconds", "value",
    "hitMaxPoints", "messageIntegralEstimate",
    "reportedErrorEstimate", "relativeErrorEstimate", "messageText"};
  rawTrialExportCSV[
    rawTrialIntegralCSV, rawTrialIntegralRows, integralColumns];

  summaryColumns = {
    "budget", "precisionGoal",
    "XRawNorm", "XRawInteractionNumeratorRy",
    "XRawKineticNumeratorRy", "XRawCorrectionRy", "XRawTotalRy",
    "XXRawNorm", "XXRawInteractionNumeratorRy",
    "XXRawKineticNumeratorRy", "XXRawCorrectionRy", "XXRawTotalRy",
    "rawBindingRy", "reducedReferenceBindingRy", "bindingShiftRy",
    "reducedReferenceSource",
    "XCorrectionShiftRy", "XXCorrectionShiftRy",
    "integralCount", "maxPointsWarningCount", "elapsedSeconds"};
  rawTrialExportCSV[
    rawTrialSummaryCSV, rawTrialBudgetResults, summaryColumns]];

(* Each integral is saved immediately. Re-evaluating a partially completed
   budget reuses finished rows and continues with the first missing integral. *)
SetAttributes[rawTrialTimed, HoldAll];
rawTrialTimed[system_, label_, expression_] := Module[
  {systemValue = system, labelValue = label, cached, messageFile,
   messageStream, timing, seconds, value, messageText, messageTags,
   parsed, errorEstimate, relativeErrorEstimate, hitMaxPoints, row},

  cached =
    Select[
      rawTrialIntegralRows,
      Lookup[#, "budget", Missing[]] === rawTrialCurrentBudget &&
        Lookup[#, "system", Missing[]] === systemValue &&
        Lookup[#, "integral", Missing[]] === labelValue &&
        NumericQ[Lookup[#, "value", Missing[]]] &];
  If[cached =!= {},
    Print[
      systemValue, " / ", labelValue, ": using checkpointed value"];
    Return[Last[cached]["value"], Module]];

  messageFile =
    FileNameJoin[{
      $TemporaryDirectory,
      "main-state-raw-message-" <> CreateUUID[] <> ".txt"}];
  messageStream =
    OpenWrite[messageFile, CharacterEncoding -> "UTF-8"];

  timing = CheckAbort[
    Block[{$Messages = {messageStream}, $MessageList = {}},
      With[{answer = AbsoluteTiming[expression]},
        messageTags = $MessageList;
        answer]],
    Close[messageStream];
    Quiet[DeleteFile[messageFile]];
    rawTrialCheckpoint[];
    Abort[]];

  Close[messageStream];
  {seconds, value} = timing;
  messageText = Quiet[Check[Import[messageFile, "Text"], ""]];
  Quiet[DeleteFile[messageFile]];

  parsed = rawTrialParseMaxPointsMessage[messageText];
  errorEstimate =
    Lookup[parsed, "reportedErrorEstimate", Missing["NotReported"]];
  relativeErrorEstimate =
    If[
      NumericQ[errorEstimate] && NumericQ[value] && value != 0,
      Abs[errorEstimate/value],
      Missing["NotAvailable"]];
  hitMaxPoints =
    StringContainsQ[messageText, "NIntegrate::maxp"] ||
      ! FreeQ[messageTags, NIntegrate::maxp];

  row = Join[
    <|
      "budget" -> rawTrialCurrentBudget,
      "system" -> systemValue,
      "integral" -> labelValue,
      "seconds" -> seconds,
      "value" -> value,
      "hitMaxPoints" -> hitMaxPoints,
      "relativeErrorEstimate" -> relativeErrorEstimate,
      "messageText" -> messageText|>,
    parsed];
  AppendTo[rawTrialIntegralRows, row];
  rawTrialCheckpoint[];

  Print[
    systemValue, " / ", labelValue, ": ",
    NumberForm[seconds, {Infinity, 2}], " s",
    If[
      NumericQ[relativeErrorEstimate],
      "  (reported relative error " <>
        ToString[ScientificForm[relativeErrorEstimate, 3]] <> ")",
      ""]];
  rawTrialLog[
    StringRiffle[
      ToString[#, InputForm] & /@
        {
          rawTrialCurrentBudget, systemValue, labelValue, seconds,
          value, hitMaxPoints, relativeErrorEstimate},
      "\t"]];
  value];

(* ---- fully unreduced integration measures --------------------------------
   All physical azimuths are integrated independently. There is no 2 Pi gauge
   factor and no reflection factor. *)

rawTrialXIntegrateIS[integrand_, budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[rawTrialA, rawTrialC],
      rmax = rawTrialA exRmax},
    With[
      {
        me = exStateMaps[\[Omega], rmax, exElectronState],
        mh = exStateMaps[\[Omega], rmax, exHoleState]},
      NIntegrate[
        Module[
          {
            r1 = me["rFromV"][v1],
            u1 = me["uFromX"][x1],
            ra = mh["rFromV"][va],
            ua = mh["uFromX"][xa]},
          integrand[r1, u1, \[Phi]1, ra, ua, \[Phi]a] *
            me["rJac"][r1] mh["rJac"][ra] *
            me["uJac"][u1] mh["uJac"][ua]],
        {v1, 0, 1}, {x1, 0, 1}, {va, 0, 1}, {xa, 0, 1},
        {\[Phi]1, 0, 2 \[Pi]}, {\[Phi]a, 0, 2 \[Pi]},
        Method -> {
          "AdaptiveQuasiMonteCarlo",
          "BisectionDithering" -> rawTrialBisectionDithering,
          "MaxPoints" -> budget},
        AccuracyGoal -> rawTrialAccuracyGoal,
        PrecisionGoal -> rawTrialPrecisionGoal,
        WorkingPrecision -> MachinePrecision]]];

rawTrialXXIntegrateIS[integrand_, budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[rawTrialA, rawTrialC],
      rmax = rawTrialA bxRmax},
    With[
      {
        me = bxStateMaps[\[Omega], rmax, bxElectronStates],
        mh = bxStateMaps[\[Omega], rmax, bxHoleStates]},
      NIntegrate[
        Module[
          {
            r1 = me["rFromV"][v1],
            r2 = me["rFromV"][v2],
            ra = mh["rFromV"][va],
            rb = mh["rFromV"][vb],
            u1 = me["uFromX"][x1],
            u2 = me["uFromX"][x2],
            ua = mh["uFromX"][xa],
            ub = mh["uFromX"][xb]},
          integrand[
            r1, u1, \[Phi]1, r2, u2, \[Phi]2,
            ra, ua, \[Phi]a, rb, ub, \[Phi]b] *
            me["rJac"][r1] me["rJac"][r2] *
            mh["rJac"][ra] mh["rJac"][rb] *
            me["uJac"][u1] me["uJac"][u2] *
            mh["uJac"][ua] mh["uJac"][ub]],
        {v1, 0, 1}, {x1, 0, 1}, {v2, 0, 1}, {x2, 0, 1},
        {va, 0, 1}, {xa, 0, 1}, {vb, 0, 1}, {xb, 0, 1},
        {\[Phi]1, 0, 2 \[Pi]}, {\[Phi]2, 0, 2 \[Pi]},
        {\[Phi]a, 0, 2 \[Pi]}, {\[Phi]b, 0, 2 \[Pi]},
        Method -> {
          "AdaptiveQuasiMonteCarlo",
          "BisectionDithering" -> rawTrialBisectionDithering,
          "MaxPoints" -> budget},
        AccuracyGoal -> rawTrialAccuracyGoal,
        PrecisionGoal -> rawTrialPrecisionGoal,
        WorkingPrecision -> MachinePrecision]]];

rawTrialXMeasure[\[Omega]_][r1_, u1_, \[Phi]1_, ra_, ua_, \[Phi]a_] :=
  psiWeightExcitonMixed[
    rawTrialA, rawTrialC, \[Omega]][u1, r1, ua, ra] r1 ra;

rawTrialXXMeasure[\[Omega]_][
   r1_, u1_, \[Phi]1_, r2_, u2_, \[Phi]2_,
   ra_, ua_, \[Phi]a_, rb_, ub_, \[Phi]b_] :=
  bxPairDensity[
    \[Omega], bxEtaE,
    bxElectronStates[[1]], bxElectronStates[[2]]][
      u1, r1, \[Phi]1, u2, r2, \[Phi]2] *
  bxPairDensity[
    \[Omega], bxEtaH,
    bxHoleStates[[1]], bxHoleStates[[2]]][
      ua, ra, \[Phi]a, ub, rb, \[Phi]b] *
  r1 r2 ra rb;

(* ---- fully unreduced exciton integrals ----------------------------------- *)

rawTrialXNorm[budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[rawTrialA, rawTrialC],
      \[Alpha] = rawTrialAlpha},
    rawTrialXIntegrateIS[
      Function[
        {r1, u1, \[Phi]1, ra, ua, \[Phi]a},
        With[
          {
            dist = rPair[rawTrialA, rawTrialC][
              u1, r1, \[Phi]1, ua, ra, \[Phi]a]},
          rawTrialXMeasure[\[Omega]][
            r1, u1, \[Phi]1, ra, ua, \[Phi]a] *
          Exp[-2 \[Alpha] dist]]],
      budget]];

rawTrialXInteraction[budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[rawTrialA, rawTrialC],
      \[Alpha] = rawTrialAlpha},
    rawTrialXIntegrateIS[
      Function[
        {r1, u1, \[Phi]1, ra, ua, \[Phi]a},
        With[
          {
            dist = rPair[rawTrialA, rawTrialC][
              u1, r1, \[Phi]1, ua, ra, \[Phi]a]},
          rawTrialXMeasure[\[Omega]][
            r1, u1, \[Phi]1, ra, ua, \[Phi]a] *
          Exp[-2 \[Alpha] dist] (-2/dist)]],
      budget]];

rawTrialXKinetic[budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[rawTrialA, rawTrialC],
      \[Alpha] = rawTrialAlpha},
    rawTrialXIntegrateIS[
      Function[
        {r1, u1, \[Phi]1, ra, ua, \[Phi]a},
        Module[{dist, f2, ge, gh},
          dist = rPair[rawTrialA, rawTrialC][
            u1, r1, \[Phi]1, ua, ra, \[Phi]a];
          f2 = Exp[-2 \[Alpha] dist];
          ge = -\[Alpha] gradR[rawTrialA, rawTrialC][
            u1, r1, \[Phi]1, ua, ra, \[Phi]a];
          gh = -\[Alpha] gradR[rawTrialA, rawTrialC][
            ua, ra, \[Phi]a, u1, r1, \[Phi]1];
          rawTrialXMeasure[\[Omega]][
            r1, u1, \[Phi]1, ra, ua, \[Phi]a] *
          f2 (dotGrad[ge, ge] + (m\:2091/m\:2095) dotGrad[gh, gh])]],
      budget]];

(* ---- fully unreduced biexciton integrals ---------------------------------
   P and Q are both retained at every point. The four physical azimuths enter
   the six distances directly; no particle is used as an angular reference. *)

rawTrialXXNorm[budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[rawTrialA, rawTrialC],
      \[Alpha] = rawTrialXXParameters[[1]],
      \[Beta] = rawTrialXXParameters[[2]],
      \[Gamma] = rawTrialXXParameters[[3]],
      \[Delta] = rawTrialXXParameters[[4]]},
    rawTrialXXIntegrateIS[
      Function[
        {
          r1, u1, \[Phi]1, r2, u2, \[Phi]2,
          ra, ua, \[Phi]a, rb, ub, \[Phi]b},
        Module[{dab, d1a, d1b, d2a, d2b, g, p, q},
          dab = rPair[rawTrialA, rawTrialC][
            ua, ra, \[Phi]a, ub, rb, \[Phi]b];
          d1a = rPair[rawTrialA, rawTrialC][
            u1, r1, \[Phi]1, ua, ra, \[Phi]a];
          d1b = rPair[rawTrialA, rawTrialC][
            u1, r1, \[Phi]1, ub, rb, \[Phi]b];
          d2a = rPair[rawTrialA, rawTrialC][
            u2, r2, \[Phi]2, ua, ra, \[Phi]a];
          d2b = rPair[rawTrialA, rawTrialC][
            u2, r2, \[Phi]2, ub, rb, \[Phi]b];
          g = dab^\[Gamma] Exp[-\[Delta] dab];
          p = Exp[-\[Alpha] (d1a + d2b) - \[Beta] (d1b + d2a)];
          q = Exp[-\[Beta] (d1a + d2b) - \[Alpha] (d1b + d2a)];
          rawTrialXXMeasure[\[Omega]][
            r1, u1, \[Phi]1, r2, u2, \[Phi]2,
            ra, ua, \[Phi]a, rb, ub, \[Phi]b] *
          g^2 (p + q)^2]],
      budget]];

rawTrialXXInteraction[budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[rawTrialA, rawTrialC],
      \[Alpha] = rawTrialXXParameters[[1]],
      \[Beta] = rawTrialXXParameters[[2]],
      \[Gamma] = rawTrialXXParameters[[3]],
      \[Delta] = rawTrialXXParameters[[4]]},
    rawTrialXXIntegrateIS[
      Function[
        {
          r1, u1, \[Phi]1, r2, u2, \[Phi]2,
          ra, ua, \[Phi]a, rb, ub, \[Phi]b},
        Module[
          {d12, dab, d1a, d1b, d2a, d2b, g, p, q, potential},
          d12 = rPair[rawTrialA, rawTrialC][
            u1, r1, \[Phi]1, u2, r2, \[Phi]2];
          dab = rPair[rawTrialA, rawTrialC][
            ua, ra, \[Phi]a, ub, rb, \[Phi]b];
          d1a = rPair[rawTrialA, rawTrialC][
            u1, r1, \[Phi]1, ua, ra, \[Phi]a];
          d1b = rPair[rawTrialA, rawTrialC][
            u1, r1, \[Phi]1, ub, rb, \[Phi]b];
          d2a = rPair[rawTrialA, rawTrialC][
            u2, r2, \[Phi]2, ua, ra, \[Phi]a];
          d2b = rPair[rawTrialA, rawTrialC][
            u2, r2, \[Phi]2, ub, rb, \[Phi]b];
          g = dab^\[Gamma] Exp[-\[Delta] dab];
          p = Exp[-\[Alpha] (d1a + d2b) - \[Beta] (d1b + d2a)];
          q = Exp[-\[Beta] (d1a + d2b) - \[Alpha] (d1b + d2a)];
          potential =
            2 (1/d12 + 1/dab) -
            2 (1/d1a + 1/d1b + 1/d2a + 1/d2b);
          rawTrialXXMeasure[\[Omega]][
            r1, u1, \[Phi]1, r2, u2, \[Phi]2,
            ra, ua, \[Phi]a, rb, ub, \[Phi]b] *
          g^2 (p + q)^2 potential]],
      budget]];

rawTrialXXKinetic[budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[rawTrialA, rawTrialC],
      \[Alpha] = rawTrialXXParameters[[1]],
      \[Beta] = rawTrialXXParameters[[2]],
      \[Gamma] = rawTrialXXParameters[[3]],
      \[Delta] = rawTrialXXParameters[[4]]},
    rawTrialXXIntegrateIS[
      Function[
        {
          r1, u1, \[Phi]1, r2, u2, \[Phi]2,
          ra, ua, \[Phi]a, rb, ub, \[Phi]b},
        Module[
          {
            dab, d1a, d1b, d2a, d2b, g, p, q,
            gr1a, gr1b, gr2a, gr2b,
            gra1, gra2, grab, grb1, grb2, grba,
            gA, gB,
            e1P, e1Q, e2P, e2Q,
            haP, haQ, hbP, hbQ,
            gradE1, gradE2, gradHa, gradHb},

          dab = rPair[rawTrialA, rawTrialC][
            ua, ra, \[Phi]a, ub, rb, \[Phi]b];
          d1a = rPair[rawTrialA, rawTrialC][
            u1, r1, \[Phi]1, ua, ra, \[Phi]a];
          d1b = rPair[rawTrialA, rawTrialC][
            u1, r1, \[Phi]1, ub, rb, \[Phi]b];
          d2a = rPair[rawTrialA, rawTrialC][
            u2, r2, \[Phi]2, ua, ra, \[Phi]a];
          d2b = rPair[rawTrialA, rawTrialC][
            u2, r2, \[Phi]2, ub, rb, \[Phi]b];

          g = dab^\[Gamma] Exp[-\[Delta] dab];
          p = Exp[-\[Alpha] (d1a + d2b) - \[Beta] (d1b + d2a)];
          q = Exp[-\[Beta] (d1a + d2b) - \[Alpha] (d1b + d2a)];

          gr1a = gradR[rawTrialA, rawTrialC][
            u1, r1, \[Phi]1, ua, ra, \[Phi]a];
          gr1b = gradR[rawTrialA, rawTrialC][
            u1, r1, \[Phi]1, ub, rb, \[Phi]b];
          gr2a = gradR[rawTrialA, rawTrialC][
            u2, r2, \[Phi]2, ua, ra, \[Phi]a];
          gr2b = gradR[rawTrialA, rawTrialC][
            u2, r2, \[Phi]2, ub, rb, \[Phi]b];

          gra1 = gradR[rawTrialA, rawTrialC][
            ua, ra, \[Phi]a, u1, r1, \[Phi]1];
          gra2 = gradR[rawTrialA, rawTrialC][
            ua, ra, \[Phi]a, u2, r2, \[Phi]2];
          grab = gradR[rawTrialA, rawTrialC][
            ua, ra, \[Phi]a, ub, rb, \[Phi]b];
          grb1 = gradR[rawTrialA, rawTrialC][
            ub, rb, \[Phi]b, u1, r1, \[Phi]1];
          grb2 = gradR[rawTrialA, rawTrialC][
            ub, rb, \[Phi]b, u2, r2, \[Phi]2];
          grba = gradR[rawTrialA, rawTrialC][
            ub, rb, \[Phi]b, ua, ra, \[Phi]a];

          gA = (\[Gamma]/dab - \[Delta]) grab;
          gB = (\[Gamma]/dab - \[Delta]) grba;

          e1P = -\[Alpha] gr1a - \[Beta] gr1b;
          e1Q = -\[Beta] gr1a - \[Alpha] gr1b;
          e2P = -\[Alpha] gr2b - \[Beta] gr2a;
          e2Q = -\[Beta] gr2b - \[Alpha] gr2a;

          haP = gA - \[Alpha] gra1 - \[Beta] gra2;
          haQ = gA - \[Beta] gra1 - \[Alpha] gra2;
          hbP = gB - \[Alpha] grb2 - \[Beta] grb1;
          hbQ = gB - \[Beta] grb2 - \[Alpha] grb1;

          (* These are the four gradients of P+Q after the common G has
             been factored out. No representative-particle multiplier is
             used anywhere in this expression. *)
          gradE1 = p e1P + q e1Q;
          gradE2 = p e2P + q e2Q;
          gradHa = p haP + q haQ;
          gradHb = p hbP + q hbQ;

          rawTrialXXMeasure[\[Omega]][
            r1, u1, \[Phi]1, r2, u2, \[Phi]2,
            ra, ua, \[Phi]a, rb, ub, \[Phi]b] *
          g^2 (
            dotGrad[gradE1, gradE1] +
            dotGrad[gradE2, gradE2] +
            (m\:2091/m\:2095) (
              dotGrad[gradHa, gradHa] +
              dotGrad[gradHb, gradHb]))]],
      budget]];

(* ---- benchmark assembly and checkpointing -------------------------------- *)

rawTrialRunBudget[budget_Integer, force_: False] := Module[
  {
    completed,
    xNorm, xInteraction, xKinetic, xCorrection,
    xxNorm, xxInteraction, xxKinetic, xxCorrection,
    xSingleParticle, xxSingleParticle, xTotal, xxTotal, binding,
    reducedReference, reducedReferenceSource,
    referenceXCorrection, referenceXXCorrection,
    referenceXTotal, referenceXXTotal, referenceBinding,
    rowsThisBudget, elapsed, result},

  completed =
    Select[
      rawTrialBudgetResults,
      Lookup[#, "budget", Missing[]] === budget &];
  If[completed =!= {} && ! TrueQ[force],
    Print[
      "Budget ", budget,
      " is already complete; returning the checkpointed result."];
    Return[Last[completed], Module]];

  If[TrueQ[force],
    rawTrialIntegralRows =
      Select[
        rawTrialIntegralRows,
        Lookup[#, "budget", Missing[]] =!= budget &];
    rawTrialBudgetResults =
      Select[
        rawTrialBudgetResults,
        Lookup[#, "budget", Missing[]] =!= budget &];
    rawTrialCheckpoint[]];

  rawTrialCurrentBudget = budget;
  Print[
    "\n=== Fully unreduced fixed-parameter benchmark at (a,c) = ",
    {rawTrialA, rawTrialC}, ", MaxPoints = ", budget, " ==="];
  rawTrialLog["START budget=" <> ToString[budget, InputForm]];

  xNorm =
    rawTrialTimed["X", "rawNorm", rawTrialXNorm[budget]];
  xInteraction =
    rawTrialTimed[
      "X", "rawInteractionNumerator", rawTrialXInteraction[budget]];
  xKinetic =
    rawTrialTimed[
      "X", "rawKineticNumerator", rawTrialXKinetic[budget]];

  xxNorm =
    rawTrialTimed["XX", "rawNorm", rawTrialXXNorm[budget]];
  xxInteraction =
    rawTrialTimed[
      "XX", "rawInteractionNumerator", rawTrialXXInteraction[budget]];
  xxKinetic =
    rawTrialTimed[
      "XX", "rawKineticNumerator", rawTrialXXKinetic[budget]];

  If[
    ! And @@ (NumericQ /@
      {
        xNorm, xInteraction, xKinetic,
        xxNorm, xxInteraction, xxKinetic}) ||
      xNorm <= 0 || xxNorm <= 0,
    Print[
      "At least one raw integral is nonnumeric, or a norm is nonpositive. ",
      "The checkpoint has been retained, but no energy was assembled."];
    rawTrialCheckpoint[];
    Return[$Failed, Module]];

  xCorrection = (xKinetic + xInteraction)/xNorm;
  xxCorrection = (xxKinetic + xxInteraction)/xxNorm;

  xSingleParticle =
    Ee[rawTrialA, rawTrialC, 0] @@ exElectronState +
    Eh[rawTrialA, rawTrialC, 0] @@ exHoleState;
  xxSingleParticle =
    Total[Ee[rawTrialA, rawTrialC, 0] @@@ bxElectronStates] +
    Total[Eh[rawTrialA, rawTrialC, 0] @@@ bxHoleStates];
  xTotal = xSingleParticle + xCorrection;
  xxTotal = xxSingleParticle + xxCorrection;
  binding = 2 xTotal - xxTotal;

  reducedReference = rawTrialReducedReference[budget];
  If[
    AssociationQ[reducedReference],
    reducedReferenceSource = rawTrialReducedReferenceFile;
    referenceXCorrection =
      Lookup[reducedReference, "XCorrectionRy", Missing["NotAvailable"]];
    referenceXXCorrection =
      Lookup[reducedReference, "XXCorrectionRy", Missing["NotAvailable"]];
    referenceXTotal =
      Lookup[reducedReference, "XTotalRy", Missing["NotAvailable"]];
    referenceXXTotal =
      Lookup[reducedReference, "XXTotalRy", Missing["NotAvailable"]],
    reducedReferenceSource = rawTrialProductionFile;
    referenceXCorrection =
      Lookup[rawTrialSavedX, "correction", Missing["NotAvailable"]];
    referenceXXCorrection =
      Lookup[rawTrialSavedXX, "correction", Missing["NotAvailable"]];
    referenceXTotal =
      Lookup[rawTrialSavedX, "total", Missing["NotAvailable"]];
    referenceXXTotal =
      Lookup[rawTrialSavedXX, "total", Missing["NotAvailable"]]];
  referenceBinding =
    If[
      NumericQ[referenceXTotal] && NumericQ[referenceXXTotal],
      2 referenceXTotal - referenceXXTotal,
      Missing["NotAvailable"]];

  rowsThisBudget =
    Select[
      rawTrialIntegralRows,
      Lookup[#, "budget", Missing[]] === budget &];
  (* Sum the recorded integral times so this remains meaningful when a budget
     is resumed in a later kernel session. *)
  elapsed = Total[Lookup[rowsThisBudget, "seconds", 0.]];

  result = <|
    "budget" -> budget,
    "precisionGoal" -> rawTrialPrecisionGoal,
    "XRawNorm" -> xNorm,
    "XRawInteractionNumeratorRy" -> xInteraction,
    "XRawKineticNumeratorRy" -> xKinetic,
    "XRawCorrectionRy" -> xCorrection,
    "XRawTotalRy" -> xTotal,
    "XXRawNorm" -> xxNorm,
    "XXRawInteractionNumeratorRy" -> xxInteraction,
    "XXRawKineticNumeratorRy" -> xxKinetic,
    "XXRawCorrectionRy" -> xxCorrection,
    "XXRawTotalRy" -> xxTotal,
    "rawBindingRy" -> binding,
    "reducedReferenceBindingRy" -> referenceBinding,
    "bindingShiftRy" ->
      If[NumericQ[referenceBinding], binding - referenceBinding,
        Missing["NotAvailable"]],
    "reducedReferenceSource" -> reducedReferenceSource,
    "XCorrectionShiftRy" ->
      If[NumericQ[referenceXCorrection],
        xCorrection - referenceXCorrection,
        Missing["NotAvailable"]],
    "XXCorrectionShiftRy" ->
      If[NumericQ[referenceXXCorrection],
        xxCorrection - referenceXXCorrection,
        Missing["NotAvailable"]],
    "integralCount" -> Length[rowsThisBudget],
    "maxPointsWarningCount" ->
      Count[Lookup[rowsThisBudget, "hitMaxPoints"], True],
    "elapsedSeconds" -> elapsed|>;

  AppendTo[rawTrialBudgetResults, result];
  rawTrialCheckpoint[];
  rawTrialLog[
    "DONE budget=" <> ToString[budget, InputForm] <>
    " elapsedSeconds=" <> ToString[elapsed, InputForm]];
  Print[Dataset[{result}]];
  result];

rawTrialSummary[] := Dataset[rawTrialBudgetResults];

Print[
  "Fully unreduced benchmark loaded at (a,c) = ",
  {rawTrialA, rawTrialC}, ". Fixed parameters: ",
  <|
    "XAlpha" -> rawTrialAlpha,
    "XXParameters" -> rawTrialXXParameters|>,
  ". Run rawTrialRunBudget[10^6] first; completed integrals resume from ",
  rawTrialOutputFile, "."];
