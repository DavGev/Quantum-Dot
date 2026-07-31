(* ============================================================================
   Gauge-fixed, otherwise fully unreduced H/N benchmark at (a,c) = (5,1).

   Approved estimator:
     - AdaptiveQuasiMonteCarlo, independently adaptive H and N integrals;
     - no fixed/shared Sobol point set;
     - one complete Hamiltonian-correction numerator H and one norm
       denominator N for each of X and XX;
     - the redundant global rotation is removed by fixing hole a at phi_a=0;
     - every remaining relative angle spans [0,2 Pi];
     - XX uses raw G (P+Q), all six Coulomb terms, and the explicit kinetic
       contributions of e1, e2, ha, and hb;
     - no reflection folding and no particle-exchange multiplicities.

   Existing importance-sampling coordinate maps and radial cutoffs are kept.
   Stored production optima are held fixed; no minimization is performed.
   This file changes no production setting and writes only
   main-state-raw-gauge-trial-a5-c1-* files. Each integral is checkpointed.

   Evaluate through Main-State-Raw-Gauge-Trial-a5-c1.nb.
   ============================================================================ *)

gaugeTrialDirectory = DirectoryName[$InputFileName];
gaugeTrialRoot = ParentDirectory[gaugeTrialDirectory, 3];
gaugeTrialExcitonDirectory =
  FileNameJoin[{
    ParentDirectory[gaugeTrialDirectory, 2], "exciton", "01-numerics"}];

Get[FileNameJoin[{
  gaugeTrialRoot, "shared", "numerics", "definitions.wl"}]];
Get[FileNameJoin[{
  gaugeTrialExcitonDirectory, "mixed-correlation.wl"}]];
Get[FileNameJoin[{
  gaugeTrialExcitonDirectory, "mixed-density.wl"}]];
Get[FileNameJoin[{
  gaugeTrialExcitonDirectory, "mixed-integrals.wl"}]];
Get[FileNameJoin[{gaugeTrialDirectory, "mixed-correlation.wl"}]];
Get[FileNameJoin[{gaugeTrialDirectory, "mixed-density.wl"}]];
Get[FileNameJoin[{gaugeTrialDirectory, "mixed-integrals.wl"}]];

ClearAll[
  gaugeTrialKey, gaugeTrialLog, gaugeTrialParseMaxPointsMessage,
  gaugeTrialExportCSV, gaugeTrialCheckpoint, gaugeTrialTimed,
  gaugeTrialReducedReference, gaugeTrialFullRawReference,
  gaugeTrialXIntegrateIS, gaugeTrialXXIntegrateIS,
  gaugeTrialXMeasure, gaugeTrialXXMeasure,
  gaugeTrialXNorm, gaugeTrialXHamiltonian,
  gaugeTrialXXNorm, gaugeTrialXXHamiltonian,
  gaugeTrialRunBudget, gaugeTrialSummary];

gaugeTrialA = 5.;
gaugeTrialC = 1.;
gaugeTrialBudgets = {10^6, 2*10^6};
gaugeTrialPrecisionGoal = 4;
gaugeTrialAccuracyGoal = Infinity;
gaugeTrialBisectionDithering = 0;
gaugeTrialGroundState = {1, 0, 0};

gaugeTrialProductionFile =
  FileNameJoin[{
    gaugeTrialDirectory, "main-state-production-results.wxf"}];
gaugeTrialReducedReferenceFile =
  FileNameJoin[{
    gaugeTrialDirectory,
    "main-state-convergence-trial-a5-c1-results.wxf"}];
gaugeTrialFullRawReferenceFile =
  FileNameJoin[{
    gaugeTrialDirectory,
    "main-state-raw-trial-a5-c1-results.wxf"}];
gaugeTrialOutputFile =
  FileNameJoin[{
    gaugeTrialDirectory,
    "main-state-raw-gauge-trial-a5-c1-results.wxf"}];
gaugeTrialIntegralCSV =
  FileNameJoin[{
    gaugeTrialDirectory,
    "main-state-raw-gauge-trial-a5-c1-integrals.csv"}];
gaugeTrialSummaryCSV =
  FileNameJoin[{
    gaugeTrialDirectory,
    "main-state-raw-gauge-trial-a5-c1-summary.csv"}];
gaugeTrialLogFile =
  FileNameJoin[{
    gaugeTrialDirectory,
    "main-state-raw-gauge-trial-a5-c1.log"}];

gaugeTrialKey[aa_?NumericQ, cc_?NumericQ] :=
  StringRiffle[ToString[#, InputForm] & /@ N[{aa, cc}], "|"];

gaugeTrialProductionStore =
  Import[gaugeTrialProductionFile, "WXF"];
gaugeTrialSavedRun =
  Lookup[
    Lookup[gaugeTrialProductionStore, "runs", <||>],
    gaugeTrialKey[gaugeTrialA, gaugeTrialC],
    Missing["GeometryNotFound"]];

If[
  ! AssociationQ[gaugeTrialSavedRun] ||
    ! AssociationQ[Lookup[gaugeTrialSavedRun, "X", Missing[]]] ||
    ! AssociationQ[Lookup[gaugeTrialSavedRun, "XX", Missing[]]],
  Print[
    "No complete stored X/XX production result exists for ",
    {gaugeTrialA, gaugeTrialC}, " in ", gaugeTrialProductionFile];
  Abort[]];

gaugeTrialSavedX = gaugeTrialSavedRun["X"];
gaugeTrialSavedXX = gaugeTrialSavedRun["XX"];
gaugeTrialAlpha = gaugeTrialSavedX["alpha"];
gaugeTrialXXParameters = gaugeTrialSavedXX["params"];

If[
  ! NumericQ[gaugeTrialAlpha] ||
    ! MatchQ[
      gaugeTrialXXParameters,
      {_?NumericQ, _?NumericQ, _?NumericQ, _?NumericQ}],
  Print[
    "The stored optimum parameters are not numeric: ",
    <|
      "XAlpha" -> gaugeTrialAlpha,
      "XXParameters" -> gaugeTrialXXParameters|>];
  Abort[]];

(* Match the ground-state production configuration exactly. *)
exElectronState = gaugeTrialGroundState;
exHoleState = gaugeTrialGroundState;
bxElectronStates = {gaugeTrialGroundState, gaugeTrialGroundState};
bxHoleStates = {gaugeTrialGroundState, gaugeTrialGroundState};
bxEtaE = 1;
bxEtaH = 1;

(* Same-budget reduced and fully raw results are read-only references. *)
gaugeTrialReducedReferenceStore =
  If[
    FileExistsQ[gaugeTrialReducedReferenceFile],
    Quiet[Check[
      Import[gaugeTrialReducedReferenceFile, "WXF"], <||>]],
    <||>];
gaugeTrialReducedReferenceResults =
  If[
    AssociationQ[gaugeTrialReducedReferenceStore],
    Lookup[gaugeTrialReducedReferenceStore, "budgetResults", {}],
    {}];

gaugeTrialFullRawReferenceStore =
  If[
    FileExistsQ[gaugeTrialFullRawReferenceFile],
    Quiet[Check[
      Import[gaugeTrialFullRawReferenceFile, "WXF"], <||>]],
    <||>];
gaugeTrialFullRawReferenceResults =
  If[
    AssociationQ[gaugeTrialFullRawReferenceStore],
    Lookup[gaugeTrialFullRawReferenceStore, "budgetResults", {}],
    {}];

gaugeTrialReducedReference[budget_Integer] := Module[{matches},
  matches =
    Select[
      gaugeTrialReducedReferenceResults,
      Lookup[#, "budget", Missing[]] === budget &];
  If[matches === {}, Missing["NotAvailable"], Last[matches]]];

gaugeTrialFullRawReference[budget_Integer] := Module[{matches},
  matches =
    Select[
      gaugeTrialFullRawReferenceResults,
      Lookup[#, "budget", Missing[]] === budget &];
  If[matches === {}, Missing["NotAvailable"], Last[matches]]];

gaugeTrialIntegralRows = {};
gaugeTrialBudgetResults = {};
gaugeTrialCurrentBudget = Missing["NotRunning"];

(* Resume only checkpoints produced by this exact estimator and optimum. *)
If[FileExistsQ[gaugeTrialOutputFile],
  gaugeTrialPrevious =
    Quiet[Check[Import[gaugeTrialOutputFile, "WXF"], $Failed]];
  If[
    AssociationQ[gaugeTrialPrevious] &&
      Lookup[gaugeTrialPrevious, "schemaVersion", Missing[]] === 1 &&
      Lookup[
        gaugeTrialPrevious, "implementation", Missing[]] ===
          "gauge-fixed-raw-combined-HN-v1" &&
      Lookup[
        gaugeTrialPrevious, "fixedParameters", Missing[]] ===
          <|
            "XAlpha" -> gaugeTrialAlpha,
            "XXParameters" -> gaugeTrialXXParameters|>,
    gaugeTrialIntegralRows =
      Lookup[gaugeTrialPrevious, "integrals", {}];
    gaugeTrialBudgetResults =
      Lookup[gaugeTrialPrevious, "budgetResults", {}],
    Print[
      "Existing gauge-trial checkpoint is incompatible and will not be reused: ",
      gaugeTrialOutputFile]]];

gaugeTrialLog[text_String] := Module[
  {stream = OpenAppend[gaugeTrialLogFile]},
  WriteString[stream, DateString["ISODateTime"], "  ", text, "\n"];
  Close[stream]];

(* Parse both ordinary decimal errors and the multiline scientific notation
   used in some NIntegrate::maxp messages. The original text is always saved. *)
gaugeTrialParseMaxPointsMessage[text_String] := Module[
  {normalized, matches, clean, numbers},
  normalized =
    StringReplace[text, WhitespaceCharacter .. -> " "];
  normalized =
    StringReplace[
      normalized,
      RegularExpression[
        "([0-9.]+)\\s+10\\s+(-?[0-9]+)"] -> "$1*^$2"];
  matches =
    StringCases[
      normalized,
      RegularExpression[
        "NIntegrate obtained\\s+([^\\s]+)\\s+and\\s+([^\\s]+)\\s+for"] ->
        {"$1", "$2"}];
  If[matches === {}, Return[<||>]];
  clean[token_] :=
    StringReplace[token, RegularExpression["`[0-9.]*"] -> ""];
  numbers =
    Quiet[Check[
      ToExpression /@ (clean /@ First[matches]), $Failed]];
  If[
    MatchQ[numbers, {_?NumericQ, _?NumericQ}],
    <|
      "messageIntegralEstimate" -> numbers[[1]],
      "reportedErrorEstimate" -> numbers[[2]]|>,
    <||>]];

gaugeTrialExportCSV[file_String, rows_List, columns_List] :=
  Export[
    file,
    Prepend[
      (Lookup[#, columns, Missing["NotAvailable"]] & /@ rows),
      columns],
    "CSV"];

gaugeTrialCheckpoint[] := Module[
  {payload, integralColumns, summaryColumns},
  payload = <|
    "schemaVersion" -> 1,
    "implementation" -> "gauge-fixed-raw-combined-HN-v1",
    "updated" -> DateString["ISODateTime"],
    "geometry" -> <|"a" -> gaugeTrialA, "c" -> gaugeTrialC|>,
    "budgets" -> gaugeTrialBudgets,
    "precisionGoal" -> gaugeTrialPrecisionGoal,
    "accuracyGoal" -> gaugeTrialAccuracyGoal,
    "bisectionDithering" -> gaugeTrialBisectionDithering,
    "sampling" -> "independent AdaptiveQuasiMonteCarlo calls for H and N",
    "sourceProductionResult" -> gaugeTrialProductionFile,
    "sourceReducedConvergenceResult" ->
      gaugeTrialReducedReferenceFile,
    "sourceFullRawResult" -> gaugeTrialFullRawReferenceFile,
    "fixedParameters" -> <|
      "XAlpha" -> gaugeTrialAlpha,
      "XXParameters" -> gaugeTrialXXParameters|>,
    "budgetResults" -> gaugeTrialBudgetResults,
    "integrals" -> gaugeTrialIntegralRows|>;
  Export[gaugeTrialOutputFile, payload, "WXF"];

  integralColumns = {
    "budget", "system", "integral", "seconds", "value",
    "hitMaxPoints", "messageIntegralEstimate",
    "reportedErrorEstimate", "relativeErrorEstimate", "messageText"};
  gaugeTrialExportCSV[
    gaugeTrialIntegralCSV, gaugeTrialIntegralRows, integralColumns];

  summaryColumns = {
    "budget", "precisionGoal",
    "XNorm", "XHamiltonianNumeratorRy",
    "XCorrectionRy", "XTotalRy",
    "XXNorm", "XXHamiltonianNumeratorRy",
    "XXCorrectionRy", "XXTotalRy",
    "bindingRy",
    "reducedReferenceBindingRy", "bindingShiftFromReducedRy",
    "fullRawReferenceBindingRy", "bindingShiftFromFullRawRy",
    "XCorrectionShiftFromReducedRy",
    "XXCorrectionShiftFromReducedRy",
    "integralCount", "maxPointsWarningCount", "elapsedSeconds"};
  gaugeTrialExportCSV[
    gaugeTrialSummaryCSV, gaugeTrialBudgetResults, summaryColumns]];

(* Every completed integral is saved immediately and reused on restart. H and N
   remain independent NIntegrate calls and are never forced onto common points. *)
SetAttributes[gaugeTrialTimed, HoldAll];
gaugeTrialTimed[system_, label_, expression_] := Module[
  {systemValue = system, labelValue = label, cached, messageFile,
   messageStream, timing, seconds, value, messageText, messageTags,
   parsed, errorEstimate, relativeErrorEstimate, hitMaxPoints, row},

  cached =
    Select[
      gaugeTrialIntegralRows,
      Lookup[#, "budget", Missing[]] === gaugeTrialCurrentBudget &&
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
      "main-state-raw-gauge-message-" <> CreateUUID[] <> ".txt"}];
  messageStream =
    OpenWrite[messageFile, CharacterEncoding -> "UTF-8"];

  timing = CheckAbort[
    Block[{$Messages = {messageStream}, $MessageList = {}},
      With[{answer = AbsoluteTiming[expression]},
        messageTags = $MessageList;
        answer]],
    Close[messageStream];
    Quiet[DeleteFile[messageFile]];
    gaugeTrialCheckpoint[];
    Abort[]];

  Close[messageStream];
  {seconds, value} = timing;
  messageText = Quiet[Check[Import[messageFile, "Text"], ""]];
  Quiet[DeleteFile[messageFile]];

  parsed = gaugeTrialParseMaxPointsMessage[messageText];
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
      "budget" -> gaugeTrialCurrentBudget,
      "system" -> systemValue,
      "integral" -> labelValue,
      "seconds" -> seconds,
      "value" -> value,
      "hitMaxPoints" -> hitMaxPoints,
      "relativeErrorEstimate" -> relativeErrorEstimate,
      "messageText" -> messageText|>,
    parsed];
  AppendTo[gaugeTrialIntegralRows, row];
  gaugeTrialCheckpoint[];

  Print[
    systemValue, " / ", labelValue, ": ",
    NumberForm[seconds, {Infinity, 2}], " s",
    If[
      NumericQ[relativeErrorEstimate],
      "  (reported relative error " <>
        ToString[ScientificForm[relativeErrorEstimate, 3]] <> ")",
      ""]];
  gaugeTrialLog[
    StringRiffle[
      ToString[#, InputForm] & /@
        {
          gaugeTrialCurrentBudget, systemValue, labelValue, seconds,
          value, hitMaxPoints, relativeErrorEstimate},
      "\t"]];
  value];

(* ---- gauge-fixed importance-sampled integration -------------------------- *)

gaugeTrialXIntegrateIS[integrand_, budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[gaugeTrialA, gaugeTrialC],
      rmax = gaugeTrialA exRmax},
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
          integrand[r1, u1, \[Phi]1, ra, ua] *
            me["rJac"][r1] mh["rJac"][ra] *
            me["uJac"][u1] mh["uJac"][ua]],
        {v1, 0, 1}, {x1, 0, 1}, {va, 0, 1}, {xa, 0, 1},
        {\[Phi]1, 0, 2 \[Pi]},
        Method -> {
          "AdaptiveQuasiMonteCarlo",
          "BisectionDithering" -> gaugeTrialBisectionDithering,
          "MaxPoints" -> budget},
        AccuracyGoal -> gaugeTrialAccuracyGoal,
        PrecisionGoal -> gaugeTrialPrecisionGoal,
        WorkingPrecision -> MachinePrecision]]];

gaugeTrialXXIntegrateIS[integrand_, budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[gaugeTrialA, gaugeTrialC],
      rmax = gaugeTrialA bxRmax},
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
            ra, ua, rb, ub, \[Phi]b] *
            me["rJac"][r1] me["rJac"][r2] *
            mh["rJac"][ra] mh["rJac"][rb] *
            me["uJac"][u1] me["uJac"][u2] *
            mh["uJac"][ua] mh["uJac"][ub]],
        {v1, 0, 1}, {x1, 0, 1}, {v2, 0, 1}, {x2, 0, 1},
        {va, 0, 1}, {xa, 0, 1}, {vb, 0, 1}, {xb, 0, 1},
        {\[Phi]1, 0, 2 \[Pi]}, {\[Phi]2, 0, 2 \[Pi]},
        {\[Phi]b, 0, 2 \[Pi]},
        Method -> {
          "AdaptiveQuasiMonteCarlo",
          "BisectionDithering" -> gaugeTrialBisectionDithering,
          "MaxPoints" -> budget},
        AccuracyGoal -> gaugeTrialAccuracyGoal,
        PrecisionGoal -> gaugeTrialPrecisionGoal,
        WorkingPrecision -> MachinePrecision]]];

(* A factor 2 Pi restores the analytically integrated global azimuth. There is
   no second factor: the remaining relative-angle domains are not folded. *)
gaugeTrialXMeasure[\[Omega]_][r1_, u1_, \[Phi]1_, ra_, ua_] :=
  2 \[Pi] *
  psiWeightExcitonMixed[
    gaugeTrialA, gaugeTrialC, \[Omega]][u1, r1, ua, ra] *
  r1 ra;

gaugeTrialXXMeasure[\[Omega]_][
   r1_, u1_, \[Phi]1_, r2_, u2_, \[Phi]2_,
   ra_, ua_, rb_, ub_, \[Phi]b_] :=
  2 \[Pi] *
  bxPairDensity[
    \[Omega], bxEtaE,
    bxElectronStates[[1]], bxElectronStates[[2]]][
      u1, r1, \[Phi]1, u2, r2, \[Phi]2] *
  bxPairDensity[
    \[Omega], bxEtaH,
    bxHoleStates[[1]], bxHoleStates[[2]]][
      ua, ra, 0, ub, rb, \[Phi]b] *
  r1 r2 ra rb;

(* ---- exciton: one denominator and one complete numerator ---------------- *)

gaugeTrialXNorm[budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[gaugeTrialA, gaugeTrialC],
      \[Alpha] = gaugeTrialAlpha},
    gaugeTrialXIntegrateIS[
      Function[
        {r1, u1, \[Phi]1, ra, ua},
        With[
          {
            dist = rPair[gaugeTrialA, gaugeTrialC][
              u1, r1, \[Phi]1, ua, ra, 0]},
          gaugeTrialXMeasure[\[Omega]][
            r1, u1, \[Phi]1, ra, ua] *
          Exp[-2 \[Alpha] dist]]],
      budget]];

gaugeTrialXHamiltonian[budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[gaugeTrialA, gaugeTrialC],
      \[Alpha] = gaugeTrialAlpha},
    gaugeTrialXIntegrateIS[
      Function[
        {r1, u1, \[Phi]1, ra, ua},
        Module[{dist, f2, ge, gh, kinetic, potential},
          dist = rPair[gaugeTrialA, gaugeTrialC][
            u1, r1, \[Phi]1, ua, ra, 0];
          f2 = Exp[-2 \[Alpha] dist];
          ge = -\[Alpha] gradR[gaugeTrialA, gaugeTrialC][
            u1, r1, \[Phi]1, ua, ra, 0];
          gh = -\[Alpha] gradR[gaugeTrialA, gaugeTrialC][
            ua, ra, 0, u1, r1, \[Phi]1];
          kinetic =
            dotGrad[ge, ge] +
            (m\:2091/m\:2095) dotGrad[gh, gh];
          potential = -2/dist;
          gaugeTrialXMeasure[\[Omega]][
            r1, u1, \[Phi]1, ra, ua] *
          f2 (kinetic + potential)]],
      budget]];

(* ---- biexciton: raw P+Q denominator and complete H numerator ------------- *)

gaugeTrialXXNorm[budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[gaugeTrialA, gaugeTrialC],
      \[Alpha] = gaugeTrialXXParameters[[1]],
      \[Beta] = gaugeTrialXXParameters[[2]],
      \[Gamma] = gaugeTrialXXParameters[[3]],
      \[Delta] = gaugeTrialXXParameters[[4]]},
    gaugeTrialXXIntegrateIS[
      Function[
        {
          r1, u1, \[Phi]1, r2, u2, \[Phi]2,
          ra, ua, rb, ub, \[Phi]b},
        Module[{dab, d1a, d1b, d2a, d2b, g, p, q},
          dab = rPair[gaugeTrialA, gaugeTrialC][
            ua, ra, 0, ub, rb, \[Phi]b];
          d1a = rPair[gaugeTrialA, gaugeTrialC][
            u1, r1, \[Phi]1, ua, ra, 0];
          d1b = rPair[gaugeTrialA, gaugeTrialC][
            u1, r1, \[Phi]1, ub, rb, \[Phi]b];
          d2a = rPair[gaugeTrialA, gaugeTrialC][
            u2, r2, \[Phi]2, ua, ra, 0];
          d2b = rPair[gaugeTrialA, gaugeTrialC][
            u2, r2, \[Phi]2, ub, rb, \[Phi]b];
          g = dab^\[Gamma] Exp[-\[Delta] dab];
          p = Exp[-\[Alpha] (d1a + d2b) - \[Beta] (d1b + d2a)];
          q = Exp[-\[Beta] (d1a + d2b) - \[Alpha] (d1b + d2a)];
          gaugeTrialXXMeasure[\[Omega]][
            r1, u1, \[Phi]1, r2, u2, \[Phi]2,
            ra, ua, rb, ub, \[Phi]b] *
          g^2 (p + q)^2]],
      budget]];

gaugeTrialXXHamiltonian[budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[gaugeTrialA, gaugeTrialC],
      \[Alpha] = gaugeTrialXXParameters[[1]],
      \[Beta] = gaugeTrialXXParameters[[2]],
      \[Gamma] = gaugeTrialXXParameters[[3]],
      \[Delta] = gaugeTrialXXParameters[[4]]},
    gaugeTrialXXIntegrateIS[
      Function[
        {
          r1, u1, \[Phi]1, r2, u2, \[Phi]2,
          ra, ua, rb, ub, \[Phi]b},
        Module[
          {
            d12, dab, d1a, d1b, d2a, d2b, g, p, q, potential,
            gr1a, gr1b, gr2a, gr2b,
            gra1, gra2, grab, grb1, grb2, grba,
            gA, gB,
            e1P, e1Q, e2P, e2Q,
            haP, haQ, hbP, hbQ,
            gradE1, gradE2, gradHa, gradHb, kinetic},

          d12 = rPair[gaugeTrialA, gaugeTrialC][
            u1, r1, \[Phi]1, u2, r2, \[Phi]2];
          dab = rPair[gaugeTrialA, gaugeTrialC][
            ua, ra, 0, ub, rb, \[Phi]b];
          d1a = rPair[gaugeTrialA, gaugeTrialC][
            u1, r1, \[Phi]1, ua, ra, 0];
          d1b = rPair[gaugeTrialA, gaugeTrialC][
            u1, r1, \[Phi]1, ub, rb, \[Phi]b];
          d2a = rPair[gaugeTrialA, gaugeTrialC][
            u2, r2, \[Phi]2, ua, ra, 0];
          d2b = rPair[gaugeTrialA, gaugeTrialC][
            u2, r2, \[Phi]2, ub, rb, \[Phi]b];

          g = dab^\[Gamma] Exp[-\[Delta] dab];
          p = Exp[-\[Alpha] (d1a + d2b) - \[Beta] (d1b + d2a)];
          q = Exp[-\[Beta] (d1a + d2b) - \[Alpha] (d1b + d2a)];

          potential =
            2 (1/d12 + 1/dab) -
            2 (1/d1a + 1/d1b + 1/d2a + 1/d2b);

          gr1a = gradR[gaugeTrialA, gaugeTrialC][
            u1, r1, \[Phi]1, ua, ra, 0];
          gr1b = gradR[gaugeTrialA, gaugeTrialC][
            u1, r1, \[Phi]1, ub, rb, \[Phi]b];
          gr2a = gradR[gaugeTrialA, gaugeTrialC][
            u2, r2, \[Phi]2, ua, ra, 0];
          gr2b = gradR[gaugeTrialA, gaugeTrialC][
            u2, r2, \[Phi]2, ub, rb, \[Phi]b];

          gra1 = gradR[gaugeTrialA, gaugeTrialC][
            ua, ra, 0, u1, r1, \[Phi]1];
          gra2 = gradR[gaugeTrialA, gaugeTrialC][
            ua, ra, 0, u2, r2, \[Phi]2];
          grab = gradR[gaugeTrialA, gaugeTrialC][
            ua, ra, 0, ub, rb, \[Phi]b];
          grb1 = gradR[gaugeTrialA, gaugeTrialC][
            ub, rb, \[Phi]b, u1, r1, \[Phi]1];
          grb2 = gradR[gaugeTrialA, gaugeTrialC][
            ub, rb, \[Phi]b, u2, r2, \[Phi]2];
          grba = gradR[gaugeTrialA, gaugeTrialC][
            ub, rb, \[Phi]b, ua, ra, 0];

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

          gradE1 = p e1P + q e1Q;
          gradE2 = p e2P + q e2Q;
          gradHa = p haP + q haQ;
          gradHb = p hbP + q hbQ;

          kinetic =
            dotGrad[gradE1, gradE1] +
            dotGrad[gradE2, gradE2] +
            (m\:2091/m\:2095) (
              dotGrad[gradHa, gradHa] +
              dotGrad[gradHb, gradHb]);

          gaugeTrialXXMeasure[\[Omega]][
            r1, u1, \[Phi]1, r2, u2, \[Phi]2,
            ra, ua, rb, ub, \[Phi]b] *
          g^2 (kinetic + (p + q)^2 potential)]],
      budget]];

(* ---- assemble fixed-parameter energies ---------------------------------- *)

gaugeTrialRunBudget[budget_Integer, force_: False] := Module[
  {
    completed,
    xNorm, xHamiltonian, xCorrection,
    xxNorm, xxHamiltonian, xxCorrection,
    xSingleParticle, xxSingleParticle, xTotal, xxTotal, binding,
    reducedReference, fullRawReference,
    reducedBinding, fullRawBinding,
    reducedXCorrection, reducedXXCorrection,
    rowsThisBudget, elapsed, result},

  completed =
    Select[
      gaugeTrialBudgetResults,
      Lookup[#, "budget", Missing[]] === budget &];
  If[completed =!= {} && ! TrueQ[force],
    Print[
      "Budget ", budget,
      " is already complete; returning the checkpointed result."];
    Return[Last[completed], Module]];

  If[TrueQ[force],
    gaugeTrialIntegralRows =
      Select[
        gaugeTrialIntegralRows,
        Lookup[#, "budget", Missing[]] =!= budget &];
    gaugeTrialBudgetResults =
      Select[
        gaugeTrialBudgetResults,
        Lookup[#, "budget", Missing[]] =!= budget &];
    gaugeTrialCheckpoint[]];

  gaugeTrialCurrentBudget = budget;
  Print[
    "\n=== Gauge-fixed raw H/N benchmark at (a,c) = ",
    {gaugeTrialA, gaugeTrialC}, ", MaxPoints = ", budget, " ==="];
  gaugeTrialLog["START budget=" <> ToString[budget, InputForm]];

  xNorm =
    gaugeTrialTimed["X", "normDenominator", gaugeTrialXNorm[budget]];
  xHamiltonian =
    gaugeTrialTimed[
      "X", "hamiltonianNumerator",
      gaugeTrialXHamiltonian[budget]];

  xxNorm =
    gaugeTrialTimed["XX", "normDenominator", gaugeTrialXXNorm[budget]];
  xxHamiltonian =
    gaugeTrialTimed[
      "XX", "hamiltonianNumerator",
      gaugeTrialXXHamiltonian[budget]];

  If[
    ! And @@ (NumericQ /@
      {xNorm, xHamiltonian, xxNorm, xxHamiltonian}) ||
      xNorm <= 0 || xxNorm <= 0,
    Print[
      "At least one integral is nonnumeric, or a norm is nonpositive. ",
      "The checkpoint has been retained, but no energy was assembled."];
    gaugeTrialCheckpoint[];
    Return[$Failed, Module]];

  xCorrection = xHamiltonian/xNorm;
  xxCorrection = xxHamiltonian/xxNorm;

  xSingleParticle =
    Ee[gaugeTrialA, gaugeTrialC, 0] @@ exElectronState +
    Eh[gaugeTrialA, gaugeTrialC, 0] @@ exHoleState;
  xxSingleParticle =
    Total[Ee[gaugeTrialA, gaugeTrialC, 0] @@@ bxElectronStates] +
    Total[Eh[gaugeTrialA, gaugeTrialC, 0] @@@ bxHoleStates];
  xTotal = xSingleParticle + xCorrection;
  xxTotal = xxSingleParticle + xxCorrection;
  binding = 2 xTotal - xxTotal;

  reducedReference = gaugeTrialReducedReference[budget];
  reducedBinding =
    If[
      AssociationQ[reducedReference],
      Lookup[reducedReference, "bindingRy", Missing["NotAvailable"]],
      Missing["NotAvailable"]];
  reducedXCorrection =
    If[
      AssociationQ[reducedReference],
      Lookup[
        reducedReference, "XCorrectionRy", Missing["NotAvailable"]],
      Missing["NotAvailable"]];
  reducedXXCorrection =
    If[
      AssociationQ[reducedReference],
      Lookup[
        reducedReference, "XXCorrectionRy", Missing["NotAvailable"]],
      Missing["NotAvailable"]];

  fullRawReference = gaugeTrialFullRawReference[budget];
  fullRawBinding =
    If[
      AssociationQ[fullRawReference],
      Lookup[
        fullRawReference, "rawBindingRy", Missing["NotAvailable"]],
      Missing["NotAvailable"]];

  rowsThisBudget =
    Select[
      gaugeTrialIntegralRows,
      Lookup[#, "budget", Missing[]] === budget &];
  elapsed = Total[Lookup[rowsThisBudget, "seconds", 0.]];

  result = <|
    "budget" -> budget,
    "precisionGoal" -> gaugeTrialPrecisionGoal,
    "XNorm" -> xNorm,
    "XHamiltonianNumeratorRy" -> xHamiltonian,
    "XCorrectionRy" -> xCorrection,
    "XTotalRy" -> xTotal,
    "XXNorm" -> xxNorm,
    "XXHamiltonianNumeratorRy" -> xxHamiltonian,
    "XXCorrectionRy" -> xxCorrection,
    "XXTotalRy" -> xxTotal,
    "bindingRy" -> binding,
    "reducedReferenceBindingRy" -> reducedBinding,
    "bindingShiftFromReducedRy" ->
      If[NumericQ[reducedBinding],
        binding - reducedBinding, Missing["NotAvailable"]],
    "fullRawReferenceBindingRy" -> fullRawBinding,
    "bindingShiftFromFullRawRy" ->
      If[NumericQ[fullRawBinding],
        binding - fullRawBinding, Missing["NotAvailable"]],
    "XCorrectionShiftFromReducedRy" ->
      If[NumericQ[reducedXCorrection],
        xCorrection - reducedXCorrection, Missing["NotAvailable"]],
    "XXCorrectionShiftFromReducedRy" ->
      If[NumericQ[reducedXXCorrection],
        xxCorrection - reducedXXCorrection, Missing["NotAvailable"]],
    "integralCount" -> Length[rowsThisBudget],
    "maxPointsWarningCount" ->
      Count[Lookup[rowsThisBudget, "hitMaxPoints"], True],
    "elapsedSeconds" -> elapsed|>;

  AppendTo[gaugeTrialBudgetResults, result];
  gaugeTrialCheckpoint[];
  gaugeTrialLog[
    "DONE budget=" <> ToString[budget, InputForm] <>
    " elapsedSeconds=" <> ToString[elapsed, InputForm]];
  Print[Dataset[{result}]];
  result];

gaugeTrialSummary[] := Dataset[gaugeTrialBudgetResults];

Print[
  "Gauge-fixed raw H/N benchmark loaded at (a,c) = ",
  {gaugeTrialA, gaugeTrialC}, ". Fixed parameters: ",
  <|
    "XAlpha" -> gaugeTrialAlpha,
    "XXParameters" -> gaugeTrialXXParameters|>,
  ". H and N use independent AdaptiveQuasiMonteCarlo calls. Run ",
  "gaugeTrialRunBudget[10^6] first; completed integrals resume from ",
  gaugeTrialOutputFile, "."];
