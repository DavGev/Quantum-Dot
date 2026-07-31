(* ::Package:: *)

(* ============================================================================
   Staged global-rotation-fixed raw minimization at (a,c) = (5,1).

   Numerical estimator:
     - independent AdaptiveQuasiMonteCarlo calls (no shared/fixed points);
     - the redundant global rotation is removed by fixing phi_a = 0;
     - all three remaining XX angles span [0, 2 Pi];
     - XX retains raw G (P+Q), all six Coulomb terms, and the explicit kinetic
       contributions of e1, e2, ha, and hb;
     - no reflection folding and no particle-exchange multiplicities;
     - X uses the exact kinetic correction alpha^2 (1 + m_e/m_h), so only its
       Coulomb numerator and norm denominator are integrated.

   Workflow:
     1. optimize at 10^5 MaxPoints per integral;
     2. re-evaluate both optimized states at 2*10^6 MaxPoints per integral.

   The existing reduced production result is read only and supplies the warm
   start. This workflow writes only main-state-raw-minimization-a5-c1-* files.
   Every completed integral and objective evaluation is checkpointed.
   ============================================================================ *)

rawMinDirectory = DirectoryName[$InputFileName];
rawMinRoot = ParentDirectory[rawMinDirectory, 3];
rawMinExcitonDirectory =
  FileNameJoin[{
    ParentDirectory[rawMinDirectory, 2], "exciton", "01-numerics"}];

Get[FileNameJoin[{rawMinRoot, "shared", "numerics", "definitions.wl"}]];
Get[FileNameJoin[{rawMinExcitonDirectory, "mixed-correlation.wl"}]];
Get[FileNameJoin[{rawMinExcitonDirectory, "mixed-density.wl"}]];
Get[FileNameJoin[{rawMinExcitonDirectory, "mixed-integrals.wl"}]];
Get[FileNameJoin[{rawMinDirectory, "mixed-correlation.wl"}]];
Get[FileNameJoin[{rawMinDirectory, "mixed-density.wl"}]];
Get[FileNameJoin[{rawMinDirectory, "mixed-integrals.wl"}]];

ClearAll[
  rawMinKey, rawMinParameterKey, rawMinLog, rawMinParseMaxPointsMessage,
  rawMinExportCSV, rawMinCheckpoint, rawMinTimedIntegral,
  rawMinXIntegrateIS, rawMinXXIntegrateIS, rawMinXMeasure, rawMinXXMeasure,
  rawMinXNormIntegral, rawMinXCoulombIntegral, rawMinXAnalyticKinetic,
  rawMinXXNormIntegral, rawMinXXHamiltonianIntegral,
  rawMinEvaluateX, rawMinEvaluateXX, rawMinHistoryFor,
  rawMinBestHistoryRow, rawMinBestParameters, rawMinBestValue,
  rawMinXSimplexAround, rawMinXXSimplexAround,
  rawMinXConvergencePlot, rawMinXXConvergencePlot,
  rawMinimizeX, rawMinimizeXX, rawMinFinalize, rawMinSummary,
  rawMinConfiguration];

(* ---- approved run configuration ----------------------------------------- *)

rawMinA = 5.;
rawMinC = 1.;
rawMinGroundState = {1, 0, 0};

rawMinOptimizationBudget = 10^5;
rawMinFinalBudget = 2*10^6;
rawMinPrecisionGoal = 4;
rawMinAccuracyGoal = Infinity;
rawMinBisectionDithering = 0;

rawMinXMaxIterations = 30;
rawMinXXMaxIterations = 25;
rawMinXStallIterations = 6;
rawMinXXStallIterations = 8;
rawMinXStallTolerance = 0.002;  (* Ry *)
rawMinXXStallTolerance = 0.02;  (* Ry *)
rawMinXOptPrecisionGoal = 2;
rawMinXOptAccuracyGoal = 2;
rawMinXXOptPrecisionGoal = 1;
rawMinXXOptAccuracyGoal = 1;

rawMinProductionFile =
  FileNameJoin[{rawMinDirectory, "main-state-production-results.wxf"}];
rawMinReferenceFile =
  FileNameJoin[{
    rawMinDirectory, "main-state-raw-gauge-trial-a5-c1-results.wxf"}];
rawMinOutputFile =
  FileNameJoin[{
    rawMinDirectory, "main-state-raw-minimization-a5-c1-results.wxf"}];
rawMinIntegralCSV =
  FileNameJoin[{
    rawMinDirectory, "main-state-raw-minimization-a5-c1-integrals.csv"}];
rawMinHistoryCSV =
  FileNameJoin[{
    rawMinDirectory, "main-state-raw-minimization-a5-c1-history.csv"}];
rawMinSummaryCSV =
  FileNameJoin[{
    rawMinDirectory, "main-state-raw-minimization-a5-c1-summary.csv"}];
rawMinLogFile =
  FileNameJoin[{
    rawMinDirectory, "main-state-raw-minimization-a5-c1.log"}];

rawMinKey[aa_?NumericQ, cc_?NumericQ] :=
  StringRiffle[ToString[#, InputForm] & /@ N[{aa, cc}], "|"];

rawMinProductionStore = Import[rawMinProductionFile, "WXF"];
rawMinSavedRun =
  Lookup[
    Lookup[rawMinProductionStore, "runs", <||>],
    rawMinKey[rawMinA, rawMinC],
    Missing["GeometryNotFound"]];

If[
  ! AssociationQ[rawMinSavedRun] ||
    ! AssociationQ[Lookup[rawMinSavedRun, "X", Missing[]]] ||
    ! AssociationQ[Lookup[rawMinSavedRun, "XX", Missing[]]],
  Print[
    "No complete stored X/XX production result exists for ",
    {rawMinA, rawMinC}, " in ", rawMinProductionFile];
  Abort[]];

rawMinStartXAlpha = rawMinSavedRun["X"]["alpha"];
rawMinStartXXParameters = rawMinSavedRun["XX"]["params"];

If[
  ! NumericQ[rawMinStartXAlpha] ||
    ! MatchQ[
      rawMinStartXXParameters,
      {_?NumericQ, _?NumericQ, _?NumericQ, _?NumericQ}],
  Print[
    "The stored warm-start parameters are not numeric: ",
    <|
      "XAlpha" -> rawMinStartXAlpha,
      "XXParameters" -> rawMinStartXXParameters|>];
  Abort[]];

exElectronState = rawMinGroundState;
exHoleState = rawMinGroundState;
bxElectronStates = {rawMinGroundState, rawMinGroundState};
bxHoleStates = {rawMinGroundState, rawMinGroundState};
bxEtaE = 1;
bxEtaH = 1;

rawMinIntegralRows = {};
rawMinXHistory = {};
rawMinXXHistory = {};
rawMinXSteps = {};
rawMinXXSteps = {};
rawMinOptimizationResults = <||>;
rawMinFinalResult = Missing["NotEvaluated"];

(* Resume only a checkpoint made by this exact implementation/configuration. *)
If[FileExistsQ[rawMinOutputFile],
  rawMinPrevious = Quiet[Check[Import[rawMinOutputFile, "WXF"], $Failed]];
  If[
    AssociationQ[rawMinPrevious] &&
      Lookup[rawMinPrevious, "schemaVersion", Missing[]] === 1 &&
      Lookup[rawMinPrevious, "implementation", Missing[]] ===
        "global-rotation-fixed-raw-staged-minimization-v1" &&
      Lookup[rawMinPrevious, "geometry", Missing[]] ===
        <|"a" -> rawMinA, "c" -> rawMinC|> &&
      Lookup[rawMinPrevious, "optimizationBudget", Missing[]] ===
        rawMinOptimizationBudget &&
      Lookup[rawMinPrevious, "finalBudget", Missing[]] ===
        rawMinFinalBudget &&
      Lookup[rawMinPrevious, "startingParameters", Missing[]] ===
        <|
          "XAlpha" -> rawMinStartXAlpha,
          "XXParameters" -> rawMinStartXXParameters|>,
    rawMinIntegralRows = Lookup[rawMinPrevious, "integrals", {}];
    rawMinXHistory = Lookup[rawMinPrevious, "XHistory", {}];
    rawMinXXHistory = Lookup[rawMinPrevious, "XXHistory", {}];
    rawMinXSteps = Lookup[rawMinPrevious, "XSteps", {}];
    rawMinXXSteps = Lookup[rawMinPrevious, "XXSteps", {}];
    rawMinOptimizationResults =
      Lookup[rawMinPrevious, "optimizationResults", <||>];
    rawMinFinalResult =
      Lookup[rawMinPrevious, "finalResult", Missing["NotEvaluated"]],
    Print[
      "Existing raw-minimization checkpoint is incompatible and will not be ",
      "reused: ", rawMinOutputFile]]];

rawMinParameterKey[parameters_List] :=
  StringRiffle[ToString[#, InputForm] & /@ N[parameters], "|"];

rawMinLog[text_String] := Module[{stream = OpenAppend[rawMinLogFile]},
  WriteString[stream, DateString["ISODateTime"], "  ", text, "\n"];
  Close[stream]];

rawMinParseMaxPointsMessage[text_String] := Module[
  {normalized, matches, clean, numbers},
  normalized = StringReplace[text, WhitespaceCharacter .. -> " "];
  normalized =
    StringReplace[
      normalized,
      RegularExpression["([0-9.]+)\\s+10\\s+(-?[0-9]+)"] -> "$1*^$2"];
  matches =
    StringCases[
      normalized,
      RegularExpression[
        "NIntegrate obtained\\s+([^\\s]+)\\s+and\\s+([^\\s]+)\\s+for"] ->
        {"$1", "$2"}];
  If[matches === {}, Return[<||>]];
  clean[token_] :=
    StringReplace[token, RegularExpression["`[0-9.]*"] -> ""];
  numbers = Quiet[Check[ToExpression /@ (clean /@ First[matches]), $Failed]];
  If[
    MatchQ[numbers, {_?NumericQ, _?NumericQ}],
    <|
      "messageIntegralEstimate" -> numbers[[1]],
      "reportedErrorEstimate" -> numbers[[2]]|>,
    <||>]];

rawMinExportCSV[file_String, rows_List, columns_List] :=
  Export[
    file,
    Prepend[
      (Lookup[#, columns, Missing["NotAvailable"]] & /@ rows),
      columns],
    "CSV"];

rawMinCheckpoint[] := Module[
  {payload, integralColumns, historyColumns, summaryColumns, histories,
   summaryRows},

  payload = <|
    "schemaVersion" -> 1,
    "implementation" ->
      "global-rotation-fixed-raw-staged-minimization-v1",
    "updated" -> DateString["ISODateTime"],
    "geometry" -> <|"a" -> rawMinA, "c" -> rawMinC|>,
    "optimizationBudget" -> rawMinOptimizationBudget,
    "finalBudget" -> rawMinFinalBudget,
    "precisionGoal" -> rawMinPrecisionGoal,
    "accuracyGoal" -> rawMinAccuracyGoal,
    "bisectionDithering" -> rawMinBisectionDithering,
    "sampling" ->
      "independent AdaptiveQuasiMonteCarlo numerator/denominator calls",
    "excitonKinetic" -> "analytic alpha^2 (1 + m_e/m_h)",
    "sourceProductionResult" -> rawMinProductionFile,
    "sourceFixedParameterReference" -> rawMinReferenceFile,
    "startingParameters" -> <|
      "XAlpha" -> rawMinStartXAlpha,
      "XXParameters" -> rawMinStartXXParameters|>,
    "XHistory" -> rawMinXHistory,
    "XXHistory" -> rawMinXXHistory,
    "XSteps" -> rawMinXSteps,
    "XXSteps" -> rawMinXXSteps,
    "optimizationResults" -> rawMinOptimizationResults,
    "finalResult" -> rawMinFinalResult,
    "integrals" -> rawMinIntegralRows|>;
  Export[rawMinOutputFile, payload, "WXF"];

  integralColumns = {
    "stage", "budget", "system", "integral", "parameters",
    "parameterKey", "seconds", "value", "hitMaxPoints",
    "messageIntegralEstimate", "reportedErrorEstimate",
    "relativeErrorEstimate", "messageText"};
  rawMinExportCSV[rawMinIntegralCSV, rawMinIntegralRows, integralColumns];

  histories = Join[rawMinXHistory, rawMinXXHistory];
  historyColumns = {
    "system", "evaluation", "budget", "parameters", "parameterKey",
    "norm", "numeratorRy", "analyticKineticRy", "correctionRy",
    "elapsedSeconds", "completed"};
  rawMinExportCSV[rawMinHistoryCSV, histories, historyColumns];

  summaryRows =
    If[
      AssociationQ[rawMinFinalResult],
      {<|
        "a" -> rawMinA,
        "c" -> rawMinC,
        "optimizationBudget" -> rawMinOptimizationBudget,
        "finalBudget" -> rawMinFinalBudget,
        "XAlpha" -> rawMinFinalResult["X"]["alpha"],
        "XAnalyticKineticRy" ->
          rawMinFinalResult["X"]["analyticKineticRy"],
        "XCoulombNumeratorRy" ->
          rawMinFinalResult["X"]["numeratorRy"],
        "XNorm" -> rawMinFinalResult["X"]["norm"],
        "XCorrectionRy" -> rawMinFinalResult["X"]["correctionRy"],
        "XTotalRy" -> rawMinFinalResult["X"]["totalRy"],
        "XXAlpha" -> rawMinFinalResult["XX"]["parameters"][[1]],
        "XXBeta" -> rawMinFinalResult["XX"]["parameters"][[2]],
        "XXGamma" -> rawMinFinalResult["XX"]["parameters"][[3]],
        "XXDelta" -> rawMinFinalResult["XX"]["parameters"][[4]],
        "XXHamiltonianNumeratorRy" ->
          rawMinFinalResult["XX"]["numeratorRy"],
        "XXNorm" -> rawMinFinalResult["XX"]["norm"],
        "XXCorrectionRy" -> rawMinFinalResult["XX"]["correctionRy"],
        "XXTotalRy" -> rawMinFinalResult["XX"]["totalRy"],
        "bindingRy" -> rawMinFinalResult["bindingRy"],
        "completed" -> rawMinFinalResult["completed"]|>},
      {}];
  summaryColumns = {
    "a", "c", "optimizationBudget", "finalBudget",
    "XAlpha", "XAnalyticKineticRy", "XCoulombNumeratorRy", "XNorm",
    "XCorrectionRy", "XTotalRy",
    "XXAlpha", "XXBeta", "XXGamma", "XXDelta",
    "XXHamiltonianNumeratorRy", "XXNorm", "XXCorrectionRy", "XXTotalRy",
    "bindingRy", "completed"};
  rawMinExportCSV[rawMinSummaryCSV, summaryRows, summaryColumns]];

(* A cached integral is reused only when stage, budget, system, label, and all
   variational parameters match. H/N calls remain independent. *)
SetAttributes[rawMinTimedIntegral, HoldAll];
rawMinTimedIntegral[
   stage_, system_, label_, parameters_, budget_, expression_] := Module[
  {stageValue = stage, systemValue = system, labelValue = label,
   parametersValue = N[parameters], budgetValue = budget, parameterKey,
   cached, messageFile, messageStream, timing, seconds, value, messageText,
   messageTags, parsed, errorEstimate, relativeErrorEstimate,
   hitMaxPoints, row},

  parameterKey = rawMinParameterKey[parametersValue];
  cached =
    Select[
      rawMinIntegralRows,
      Lookup[#, "stage", Missing[]] === stageValue &&
        Lookup[#, "budget", Missing[]] === budgetValue &&
        Lookup[#, "system", Missing[]] === systemValue &&
        Lookup[#, "integral", Missing[]] === labelValue &&
        Lookup[#, "parameterKey", Missing[]] === parameterKey &&
        NumericQ[Lookup[#, "value", Missing[]]] &];
  If[cached =!= {},
    Print[
      stageValue, " / ", systemValue, " / ", labelValue,
      ": using checkpointed value"];
    Return[Last[cached]["value"], Module]];

  messageFile =
    FileNameJoin[{
      $TemporaryDirectory,
      "main-state-raw-min-message-" <> CreateUUID[] <> ".txt"}];
  messageStream = OpenWrite[messageFile, CharacterEncoding -> "UTF-8"];

  timing = CheckAbort[
    Block[{$Messages = {messageStream}, $MessageList = {}},
      With[{answer = AbsoluteTiming[expression]},
        messageTags = $MessageList;
        answer]],
    Close[messageStream];
    Quiet[DeleteFile[messageFile]];
    rawMinCheckpoint[];
    Abort[]];

  Close[messageStream];
  {seconds, value} = timing;
  messageText = Quiet[Check[Import[messageFile, "Text"], ""]];
  Quiet[DeleteFile[messageFile]];

  parsed = rawMinParseMaxPointsMessage[messageText];
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
      "stage" -> stageValue,
      "budget" -> budgetValue,
      "system" -> systemValue,
      "integral" -> labelValue,
      "parameters" -> parametersValue,
      "parameterKey" -> parameterKey,
      "seconds" -> seconds,
      "value" -> value,
      "hitMaxPoints" -> hitMaxPoints,
      "relativeErrorEstimate" -> relativeErrorEstimate,
      "messageText" -> messageText|>,
    parsed];
  AppendTo[rawMinIntegralRows, row];
  rawMinCheckpoint[];

  Print[
    stageValue, " / ", systemValue, " / ", labelValue, ": ",
    NumberForm[seconds, {Infinity, 2}], " s",
    If[
      NumericQ[relativeErrorEstimate],
      "  (reported relative error " <>
        ToString[ScientificForm[relativeErrorEstimate, 3]] <> ")",
      ""]];
  rawMinLog[
    StringRiffle[
      ToString[#, InputForm] & /@
        {stageValue, budgetValue, systemValue, labelValue,
         parametersValue, seconds, value, hitMaxPoints,
         relativeErrorEstimate},
      "\t"]];
  value];

(* ---- global-rotation-fixed importance-sampled integration ---------------- *)

rawMinXIntegrateIS[integrand_, budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[rawMinA, rawMinC],
      rmax = rawMinA exRmax},
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
          "BisectionDithering" -> rawMinBisectionDithering,
          "MaxPoints" -> budget},
        AccuracyGoal -> rawMinAccuracyGoal,
        PrecisionGoal -> rawMinPrecisionGoal,
        WorkingPrecision -> MachinePrecision]]];

rawMinXXIntegrateIS[integrand_, budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[rawMinA, rawMinC],
      rmax = rawMinA bxRmax},
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
          "BisectionDithering" -> rawMinBisectionDithering,
          "MaxPoints" -> budget},
        AccuracyGoal -> rawMinAccuracyGoal,
        PrecisionGoal -> rawMinPrecisionGoal,
        WorkingPrecision -> MachinePrecision]]];

(* The 2 Pi factor restores the removed global azimuth. The remaining angle
   domains are not folded. *)
rawMinXMeasure[\[Omega]_][r1_, u1_, \[Phi]1_, ra_, ua_] :=
  2 \[Pi] *
  psiWeightExcitonMixed[
    rawMinA, rawMinC, \[Omega]][u1, r1, ua, ra] *
  r1 ra;

rawMinXXMeasure[\[Omega]_][
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

(* ---- exciton: analytical kinetic plus independently integrated V and N --- *)

rawMinXNormIntegral[\[Alpha]_?NumericQ, budget_Integer] :=
  With[{\[Omega] = \[HBar]\[Omega]00[rawMinA, rawMinC]},
    rawMinXIntegrateIS[
      Function[
        {r1, u1, \[Phi]1, ra, ua},
        With[
          {dist = rPair[rawMinA, rawMinC][
             u1, r1, \[Phi]1, ua, ra, 0]},
          rawMinXMeasure[\[Omega]][r1, u1, \[Phi]1, ra, ua] *
          Exp[-2 \[Alpha] dist]]],
      budget]];

rawMinXCoulombIntegral[\[Alpha]_?NumericQ, budget_Integer] :=
  With[{\[Omega] = \[HBar]\[Omega]00[rawMinA, rawMinC]},
    rawMinXIntegrateIS[
      Function[
        {r1, u1, \[Phi]1, ra, ua},
        With[
          {dist = rPair[rawMinA, rawMinC][
             u1, r1, \[Phi]1, ua, ra, 0]},
          rawMinXMeasure[\[Omega]][r1, u1, \[Phi]1, ra, ua] *
          Exp[-2 \[Alpha] dist] * (-2/dist)]],
      budget]];

rawMinXAnalyticKinetic[\[Alpha]_?NumericQ] :=
  \[Alpha]^2 (1 + m\:2091/m\:2095);

(* ---- biexciton: raw P+Q denominator and complete H numerator ------------- *)

rawMinXXNormIntegral[
   parameters : {_?NumericQ, _?NumericQ, _?NumericQ, _?NumericQ},
   budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[rawMinA, rawMinC],
      \[Alpha] = parameters[[1]], \[Beta] = parameters[[2]],
      \[Gamma] = parameters[[3]], \[Delta] = parameters[[4]]},
    rawMinXXIntegrateIS[
      Function[
        {r1, u1, \[Phi]1, r2, u2, \[Phi]2,
         ra, ua, rb, ub, \[Phi]b},
        Module[{dab, d1a, d1b, d2a, d2b, g, p, q},
          dab = rPair[rawMinA, rawMinC][
            ua, ra, 0, ub, rb, \[Phi]b];
          d1a = rPair[rawMinA, rawMinC][
            u1, r1, \[Phi]1, ua, ra, 0];
          d1b = rPair[rawMinA, rawMinC][
            u1, r1, \[Phi]1, ub, rb, \[Phi]b];
          d2a = rPair[rawMinA, rawMinC][
            u2, r2, \[Phi]2, ua, ra, 0];
          d2b = rPair[rawMinA, rawMinC][
            u2, r2, \[Phi]2, ub, rb, \[Phi]b];
          g = dab^\[Gamma] Exp[-\[Delta] dab];
          p = Exp[-\[Alpha] (d1a + d2b) - \[Beta] (d1b + d2a)];
          q = Exp[-\[Beta] (d1a + d2b) - \[Alpha] (d1b + d2a)];
          rawMinXXMeasure[\[Omega]][
            r1, u1, \[Phi]1, r2, u2, \[Phi]2,
            ra, ua, rb, ub, \[Phi]b] *
          g^2 (p + q)^2]],
      budget]];

rawMinXXHamiltonianIntegral[
   parameters : {_?NumericQ, _?NumericQ, _?NumericQ, _?NumericQ},
   budget_Integer] :=
  With[
    {
      \[Omega] = \[HBar]\[Omega]00[rawMinA, rawMinC],
      \[Alpha] = parameters[[1]], \[Beta] = parameters[[2]],
      \[Gamma] = parameters[[3]], \[Delta] = parameters[[4]]},
    rawMinXXIntegrateIS[
      Function[
        {r1, u1, \[Phi]1, r2, u2, \[Phi]2,
         ra, ua, rb, ub, \[Phi]b},
        Module[
          {
            d12, dab, d1a, d1b, d2a, d2b, g, p, q, potential,
            gr1a, gr1b, gr2a, gr2b,
            gra1, gra2, grab, grb1, grb2, grba,
            gA, gB, e1P, e1Q, e2P, e2Q,
            haP, haQ, hbP, hbQ,
            gradE1, gradE2, gradHa, gradHb, kinetic},

          d12 = rPair[rawMinA, rawMinC][
            u1, r1, \[Phi]1, u2, r2, \[Phi]2];
          dab = rPair[rawMinA, rawMinC][
            ua, ra, 0, ub, rb, \[Phi]b];
          d1a = rPair[rawMinA, rawMinC][
            u1, r1, \[Phi]1, ua, ra, 0];
          d1b = rPair[rawMinA, rawMinC][
            u1, r1, \[Phi]1, ub, rb, \[Phi]b];
          d2a = rPair[rawMinA, rawMinC][
            u2, r2, \[Phi]2, ua, ra, 0];
          d2b = rPair[rawMinA, rawMinC][
            u2, r2, \[Phi]2, ub, rb, \[Phi]b];

          g = dab^\[Gamma] Exp[-\[Delta] dab];
          p = Exp[-\[Alpha] (d1a + d2b) - \[Beta] (d1b + d2a)];
          q = Exp[-\[Beta] (d1a + d2b) - \[Alpha] (d1b + d2a)];

          potential =
            2 (1/d12 + 1/dab) -
            2 (1/d1a + 1/d1b + 1/d2a + 1/d2b);

          gr1a = gradR[rawMinA, rawMinC][
            u1, r1, \[Phi]1, ua, ra, 0];
          gr1b = gradR[rawMinA, rawMinC][
            u1, r1, \[Phi]1, ub, rb, \[Phi]b];
          gr2a = gradR[rawMinA, rawMinC][
            u2, r2, \[Phi]2, ua, ra, 0];
          gr2b = gradR[rawMinA, rawMinC][
            u2, r2, \[Phi]2, ub, rb, \[Phi]b];

          gra1 = gradR[rawMinA, rawMinC][
            ua, ra, 0, u1, r1, \[Phi]1];
          gra2 = gradR[rawMinA, rawMinC][
            ua, ra, 0, u2, r2, \[Phi]2];
          grab = gradR[rawMinA, rawMinC][
            ua, ra, 0, ub, rb, \[Phi]b];
          grb1 = gradR[rawMinA, rawMinC][
            ub, rb, \[Phi]b, u1, r1, \[Phi]1];
          grb2 = gradR[rawMinA, rawMinC][
            ub, rb, \[Phi]b, u2, r2, \[Phi]2];
          grba = gradR[rawMinA, rawMinC][
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

          rawMinXXMeasure[\[Omega]][
            r1, u1, \[Phi]1, r2, u2, \[Phi]2,
            ra, ua, rb, ub, \[Phi]b] *
          g^2 (kinetic + (p + q)^2 potential)]],
      budget]];

(* ---- energy evaluations and persistent histories ------------------------ *)

rawMinEvaluateX[
   \[Alpha]_?NumericQ, budget_Integer, stage_String,
   recordHistory_: False] := Module[
  {timing, norm, numerator, kinetic, correction, row, parameterKey},

  parameterKey = rawMinParameterKey[{\[Alpha]}];
  timing = AbsoluteTiming[
    norm = rawMinTimedIntegral[
      stage, "X", "normDenominator", {\[Alpha]}, budget,
      rawMinXNormIntegral[\[Alpha], budget]];
    numerator = rawMinTimedIntegral[
      stage, "X", "coulombNumerator", {\[Alpha]}, budget,
      rawMinXCoulombIntegral[\[Alpha], budget]];
    kinetic = rawMinXAnalyticKinetic[\[Alpha]];
    correction =
      If[
        NumericQ[norm] && norm > 10^-12 && NumericQ[numerator],
        kinetic + numerator/norm,
        100.];];

  row = <|
    "system" -> "X",
    "evaluation" -> Length[rawMinXHistory] + 1,
    "budget" -> budget,
    "parameters" -> N[{\[Alpha]}],
    "parameterKey" -> parameterKey,
    "norm" -> norm,
    "numeratorRy" -> numerator,
    "analyticKineticRy" -> kinetic,
    "correctionRy" -> correction,
    "elapsedSeconds" -> timing[[1]],
    "completed" -> DateString["ISODateTime"]|>;

  If[TrueQ[recordHistory],
    AppendTo[rawMinXHistory, row];
    rawMinCheckpoint[];
    Print[
      "X evaluation ", row["evaluation"], ": alpha = ",
      NumberForm[\[Alpha], 8], ", correction = ",
      NumberForm[correction, 10], " Ry"]];
  row];

rawMinEvaluateXX[
   parameters : {_?NumericQ, _?NumericQ, _?NumericQ, _?NumericQ},
   budget_Integer, stage_String, recordHistory_: False] := Module[
  {timing, norm, numerator, correction, row, parameterKey},

  parameterKey = rawMinParameterKey[parameters];
  timing = AbsoluteTiming[
    norm = rawMinTimedIntegral[
      stage, "XX", "normDenominator", parameters, budget,
      rawMinXXNormIntegral[parameters, budget]];
    numerator = rawMinTimedIntegral[
      stage, "XX", "hamiltonianNumerator", parameters, budget,
      rawMinXXHamiltonianIntegral[parameters, budget]];
    correction =
      If[
        NumericQ[norm] && norm > 10^-12 && NumericQ[numerator] &&
          Abs[numerator/norm] < 100,
        numerator/norm,
        100.];];

  row = <|
    "system" -> "XX",
    "evaluation" -> Length[rawMinXXHistory] + 1,
    "budget" -> budget,
    "parameters" -> N[parameters],
    "parameterKey" -> parameterKey,
    "norm" -> norm,
    "numeratorRy" -> numerator,
    "analyticKineticRy" -> Missing["NotApplicable"],
    "correctionRy" -> correction,
    "elapsedSeconds" -> timing[[1]],
    "completed" -> DateString["ISODateTime"]|>;

  If[TrueQ[recordHistory],
    AppendTo[rawMinXXHistory, row];
    rawMinCheckpoint[];
    Print[
      "XX evaluation ", row["evaluation"], ": parameters = ",
      NumberForm[parameters, 7], ", correction = ",
      NumberForm[correction, 10], " Ry"]];
  row];

rawMinHistoryFor["X"] := rawMinXHistory;
rawMinHistoryFor["XX"] := rawMinXXHistory;

rawMinBestHistoryRow[system_String] := Module[{history = rawMinHistoryFor[system]},
  If[
    history === {},
    Missing["NoHistory"],
    First@MinimalBy[history, Lookup[#, "correctionRy", Infinity] &]]];

rawMinBestParameters["X"] := Module[{best = rawMinBestHistoryRow["X"]},
  If[MissingQ[best], {rawMinStartXAlpha}, best["parameters"]]];
rawMinBestParameters["XX"] := Module[{best = rawMinBestHistoryRow["XX"]},
  If[MissingQ[best], rawMinStartXXParameters, best["parameters"]]];

rawMinBestValue[system_String] := Module[{best = rawMinBestHistoryRow[system]},
  If[MissingQ[best], Missing["NoHistory"], best["correctionRy"]]];

rawMinXSimplexAround[{al_?NumericQ}] :=
  {{Clip[al, {0.001, 9.999}]}, {Clip[al + 0.1, {0.001, 9.999}]}};

rawMinXXSimplexAround[parameters_List] :=
  With[
    {lo = {0.001, 0.001, -0.999, 0.001},
     hi = {9.999, 9.999, 4.999, 9.999}},
    Map[
      MapThread[Clip[#1, {#2, #3}] &, {#, lo, hi}] &,
      Join[
        {parameters},
        Table[parameters + 0.2 UnitVector[4, i], {i, 4}]]]];

rawMinXConvergencePlot[] :=
  If[
    Length[rawMinXHistory] < 2,
    "collecting X evaluations...",
    With[
      {values = Lookup[rawMinXHistory, "correctionRy"]},
      ListLinePlot[
        {values, FoldList[Min, values]},
        PlotLegends -> {"objective", "best"},
        Frame -> True,
        FrameLabel -> {"function evaluation", "X correction (Ry)"},
        PlotLabel -> Row[{"best = ", NumberForm[Min[values], 8]}],
        ImageSize -> 500]]];

rawMinXXConvergencePlot[] :=
  If[
    Length[rawMinXXHistory] < 2,
    "collecting XX evaluations...",
    With[
      {values = Lookup[rawMinXXHistory, "correctionRy"]},
      ListLinePlot[
        {values, FoldList[Min, values]},
        PlotLegends -> {"objective", "best"},
        Frame -> True,
        FrameLabel -> {"function evaluation", "XX correction (Ry)"},
        PlotLabel -> Row[{"best = ", NumberForm[Min[values], 8]}],
        ImageSize -> 500]]];

(* Each invocation warm-starts from the best checkpointed evaluation. An abort
   keeps all completed integrals and history; re-evaluate the cell to resume. *)
rawMinimizeX[maxIterations_: rawMinXMaxIterations] := Module[
  {obj, start, method, result, best},

  rawMinXSteps = {};
  start = rawMinBestParameters["X"];
  method = {
    "NelderMead", "PostProcess" -> False,
    "InitialPoints" -> rawMinXSimplexAround[start]};

  rawMinLog[
    "X minimization start; budget=" <>
      ToString[rawMinOptimizationBudget] <> "; start=" <>
      ToString[start, InputForm]];

  obj[al_?NumericQ] :=
    rawMinEvaluateX[
      al, rawMinOptimizationBudget, "optimization", True]["correctionRy"];

  result = CheckAbort[
    Monitor[
      Catch[
        NMinimize[
          {obj[\[Alpha]], 0 < \[Alpha] < 10},
          \[Alpha],
          Method -> method,
          MaxIterations -> maxIterations,
          AccuracyGoal -> rawMinXOptAccuracyGoal,
          PrecisionGoal -> rawMinXOptPrecisionGoal,
          StepMonitor :> (
            AppendTo[rawMinXSteps, rawMinBestValue["X"]];
            rawMinCheckpoint[];
            If[
              Length[rawMinXSteps] > rawMinXStallIterations &&
                rawMinXSteps[[-rawMinXStallIterations]] -
                  Last[rawMinXSteps] < rawMinXStallTolerance,
              Throw[$Stalled, "rawMinXStall"]])],
        "rawMinXStall"],
      rawMinXConvergencePlot[]],
    rawMinCheckpoint[];
    Abort[]];

  best = rawMinBestHistoryRow["X"];
  If[AssociationQ[best],
    AssociateTo[
      rawMinOptimizationResults,
      "X" -> <|
        "status" -> If[result === $Stalled, "stalled", "finished"],
        "parameters" -> best["parameters"],
        "correctionRy" -> best["correctionRy"],
        "evaluations" -> Length[rawMinXHistory],
        "budget" -> rawMinOptimizationBudget,
        "completed" -> DateString["ISODateTime"]|>]];
  rawMinCheckpoint[];
  rawMinOptimizationResults["X"]];

rawMinimizeXX[maxIterations_: rawMinXXMaxIterations] := Module[
  {obj, start, method, result, best},

  rawMinXXSteps = {};
  start = rawMinBestParameters["XX"];
  method = {
    "NelderMead", "PostProcess" -> False,
    "InitialPoints" -> rawMinXXSimplexAround[start]};

  rawMinLog[
    "XX minimization start; budget=" <>
      ToString[rawMinOptimizationBudget] <> "; start=" <>
      ToString[start, InputForm]];

  obj[al_?NumericQ, be_?NumericQ, ga_?NumericQ, de_?NumericQ] :=
    rawMinEvaluateXX[
      {al, be, ga, de}, rawMinOptimizationBudget,
      "optimization", True]["correctionRy"];

  result = CheckAbort[
    Monitor[
      Catch[
        NMinimize[
          {obj[\[Alpha], \[Beta], \[Gamma], \[Delta]],
           0 < \[Alpha] < 10 && 0 < \[Beta] < 10 &&
             -1 < \[Gamma] < 5 && 0 < \[Delta] < 10},
          {\[Alpha], \[Beta], \[Gamma], \[Delta]},
          Method -> method,
          MaxIterations -> maxIterations,
          AccuracyGoal -> rawMinXXOptAccuracyGoal,
          PrecisionGoal -> rawMinXXOptPrecisionGoal,
          StepMonitor :> (
            AppendTo[rawMinXXSteps, rawMinBestValue["XX"]];
            rawMinCheckpoint[];
            If[
              Length[rawMinXXSteps] > rawMinXXStallIterations &&
                rawMinXXSteps[[-rawMinXXStallIterations]] -
                  Last[rawMinXXSteps] < rawMinXXStallTolerance,
              Throw[$Stalled, "rawMinXXStall"]])],
        "rawMinXXStall"],
      rawMinXXConvergencePlot[]],
    rawMinCheckpoint[];
    Abort[]];

  best = rawMinBestHistoryRow["XX"];
  If[AssociationQ[best],
    AssociateTo[
      rawMinOptimizationResults,
      "XX" -> <|
        "status" -> If[result === $Stalled, "stalled", "finished"],
        "parameters" -> best["parameters"],
        "correctionRy" -> best["correctionRy"],
        "evaluations" -> Length[rawMinXXHistory],
        "budget" -> rawMinOptimizationBudget,
        "completed" -> DateString["ISODateTime"]|>]];
  rawMinCheckpoint[];
  rawMinOptimizationResults["XX"]];

(* ---- high-budget final evaluation --------------------------------------- *)

rawMinFinalize[] := Module[
  {xParameters, xxParameters, x, xx, xSingleParticle, xxSingleParticle,
   xTotal, xxTotal, binding},

  If[rawMinXHistory === {} || rawMinXXHistory === {},
    Print[
      "Run both rawMinimizeX[] and rawMinimizeXX[] before finalization."];
    Return[$Failed, Module]];

  xParameters = rawMinBestParameters["X"];
  xxParameters = rawMinBestParameters["XX"];

  Print[
    "Final evaluation at MaxPoints = ", rawMinFinalBudget,
    ". X alpha = ", xParameters[[1]],
    "; XX parameters = ", xxParameters];

  x = rawMinEvaluateX[
    xParameters[[1]], rawMinFinalBudget, "final", False];
  xx = rawMinEvaluateXX[
    xxParameters, rawMinFinalBudget, "final", False];

  xSingleParticle =
    Ee[rawMinA, rawMinC, 0] @@ exElectronState +
    Eh[rawMinA, rawMinC, 0] @@ exHoleState;
  xxSingleParticle =
    Total[Ee[rawMinA, rawMinC, 0] @@@ bxElectronStates] +
    Total[Eh[rawMinA, rawMinC, 0] @@@ bxHoleStates];
  xTotal = xSingleParticle + x["correctionRy"];
  xxTotal = xxSingleParticle + xx["correctionRy"];
  binding = 2 xTotal - xxTotal;

  rawMinFinalResult = <|
    "geometry" -> <|"a" -> rawMinA, "c" -> rawMinC|>,
    "optimizationBudget" -> rawMinOptimizationBudget,
    "finalBudget" -> rawMinFinalBudget,
    "X" -> Join[
      x,
      <|
        "alpha" -> xParameters[[1]],
        "singleParticleRy" -> xSingleParticle,
        "totalRy" -> xTotal|>],
    "XX" -> Join[
      xx,
      <|
        "parameters" -> xxParameters,
        "singleParticleRy" -> xxSingleParticle,
        "totalRy" -> xxTotal|>],
    "bindingRy" -> binding,
    "completed" -> DateString["ISODateTime"]|>;
  rawMinCheckpoint[];
  rawMinFinalResult];

rawMinConfiguration[] := <|
  "geometry" -> {rawMinA, rawMinC},
  "optimizationBudget" -> rawMinOptimizationBudget,
  "finalBudget" -> rawMinFinalBudget,
  "precisionGoal" -> rawMinPrecisionGoal,
  "accuracyGoal" -> rawMinAccuracyGoal,
  "bisectionDithering" -> rawMinBisectionDithering,
  "XMaxIterations" -> rawMinXMaxIterations,
  "XXMaxIterations" -> rawMinXXMaxIterations,
  "XStartAlpha" -> rawMinStartXAlpha,
  "XXStartParameters" -> rawMinStartXXParameters,
  "XKinetic" -> "analytic alpha^2 (1 + m_e/m_h)",
  "angularTreatment" ->
    "phi_a=0; all three remaining XX angles cover [0,2 Pi]",
  "sampling" -> "independent adaptive QMC calls"|>;

rawMinSummary[] := <|
  "configuration" -> rawMinConfiguration[],
  "XBestLowBudget" -> rawMinBestHistoryRow["X"],
  "XXBestLowBudget" -> rawMinBestHistoryRow["XX"],
  "optimizationResults" -> rawMinOptimizationResults,
  "finalResult" -> rawMinFinalResult,
  "integralCount" -> Length[rawMinIntegralRows],
  "XEvaluationCount" -> Length[rawMinXHistory],
  "XXEvaluationCount" -> Length[rawMinXXHistory]|>;

Print[
  "Staged global-rotation-fixed raw minimization loaded at (a,c) = ",
  {rawMinA, rawMinC}, ". Optimization MaxPoints = ",
  rawMinOptimizationBudget, "; final MaxPoints = ", rawMinFinalBudget,
  ". Warm start: ",
  <|
    "XAlpha" -> rawMinBestParameters["X"],
    "XXParameters" -> rawMinBestParameters["XX"]|>,
  ". Run rawMinimizeX[], rawMinimizeXX[], then rawMinFinalize[]."];
