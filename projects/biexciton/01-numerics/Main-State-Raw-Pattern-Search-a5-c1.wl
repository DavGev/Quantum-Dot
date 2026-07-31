(* ::Package:: *)

(* ============================================================================
   Parallel, safeguarded raw pattern search at (a,c) = (5,1).

   This driver reuses the validated global-rotation-fixed raw estimator from
   Main-State-Raw-Minimization-a5-c1.wl. It changes only the parameter-search
   strategy:

     - X: a 2*10^6-point one-dimensional grid followed by a half-step scan;
     - XX: center plus +/- coordinate steps at 10^6 points;
     - the center moves only after a candidate is lower at both 10^6 and
       2*10^6 points and the high-budget improvement exceeds the observed
       cross-budget disagreement and 0.02 Ry;
     - refinement uses half steps along only the two most promising axes;
     - independent candidates run on eight parallel subkernels;
     - H (or V for X) and N remain independent AdaptiveQuasiMonteCarlo calls.

   Worker kernels never write shared state. The master checkpoints each result
   as WaitNext returns it, so completed candidates survive interruptions.
   ============================================================================ *)

psSourceFile = $InputFileName;
psDirectory = DirectoryName[psSourceFile];

Get[FileNameJoin[{
  psDirectory, "Main-State-Raw-Minimization-a5-c1.wl"}]];

ClearAll[
  psParameterKey, psCandidateKey, psParseMaxPointsMessage, psTimedIntegral,
  psEvaluateTask, psFindCandidate, psCandidateCompleteQ, psRunCandidates,
  psPrepareKernels, psCloseKernels, psExportCSV, psCheckpoint,
  psCSVAssociations, psSeedXXCenter, psIntegralFromGaugeRow,
  psXStep, psXInitialParameters, psXRefinementParameters,
  psRunXInitial, psRunXRefinement, psBestXRow,
  psXXSteps, psShiftParameter, psXXInitialParameters,
  psRunXXInitial, psXXInitialBestRow, psCompareBudgets,
  psRunXXVerification, psXXFirstDecision, psXXAcceptedCenter,
  psXXAxisScores, psXXRefinementAxes, psXXRefinementParameters,
  psRunXXRefinement, psXXRefinementBestRow, psRunXXFinalVerification,
  psXXFinalDecision, psFinalXXParameters, psConfiguration, psSummary,
  psCandidateTable, psXPlot, psXXInitialPlot];

(* ---- approved configuration --------------------------------------------- *)

psWorkerCount = 8;
psXBudget = 2*10^6;
psXXSearchBudget = 10^6;
psXXVerifyBudget = 2*10^6;
psMinimumImprovementRy = 0.02;
psRefinementDirectionCount = 2;

(* Preserve the last experiment's integration settings. *)
rawMinPrecisionGoal = 4;
rawMinAccuracyGoal = Infinity;
rawMinBisectionDithering = 0;

psStartXAlpha = rawMinStartXAlpha;
psStartXXParameters = rawMinStartXXParameters;

psOutputFile = FileNameJoin[{
  psDirectory, "main-state-raw-pattern-search-a5-c1-results.wxf"}];
psCandidateCSV = FileNameJoin[{
  psDirectory, "main-state-raw-pattern-search-a5-c1-candidates.csv"}];
psIntegralCSV = FileNameJoin[{
  psDirectory, "main-state-raw-pattern-search-a5-c1-integrals.csv"}];
psSummaryCSV = FileNameJoin[{
  psDirectory, "main-state-raw-pattern-search-a5-c1-summary.csv"}];
psGaugeIntegralCSV = FileNameJoin[{
  psDirectory, "main-state-raw-gauge-trial-a5-c1-integrals.csv"}];

psConfigurationSignature = <|
  "implementation" -> "parallel-raw-pattern-search-v1",
  "geometry" -> <|"a" -> rawMinA, "c" -> rawMinC|>,
  "workers" -> psWorkerCount,
  "XBudget" -> psXBudget,
  "XXSearchBudget" -> psXXSearchBudget,
  "XXVerifyBudget" -> psXXVerifyBudget,
  "minimumImprovementRy" -> psMinimumImprovementRy,
  "refinementDirectionCount" -> psRefinementDirectionCount,
  "startXAlpha" -> psStartXAlpha,
  "startXXParameters" -> psStartXXParameters|>;

psCandidateRows = {};
psKernelsPrepared = False;

If[FileExistsQ[psOutputFile],
  psPrevious = Quiet[Check[Import[psOutputFile, "WXF"], $Failed]];
  If[
    AssociationQ[psPrevious] &&
      Lookup[psPrevious, "schemaVersion", Missing[]] === 1 &&
      Lookup[psPrevious, "configuration", Missing[]] ===
        psConfigurationSignature,
    psCandidateRows = Lookup[psPrevious, "candidates", {}],
    If[$KernelID === 0,
      Print[
        "Existing pattern-search checkpoint is incompatible and will not be ",
        "reused: ", psOutputFile]]]];

psParameterKey[parameters_List] :=
  StringRiffle[ToString[#, InputForm] & /@ N[parameters], "|"];

psCandidateKey[system_String, budget_Integer, parameters_List] :=
  StringRiffle[{
    system, ToString[budget, InputForm], psParameterKey[parameters]}, "::"];

psParseMaxPointsMessage[text_String] := Module[
  {normalized, matches, clean, numbers},
  normalized = StringReplace[text, WhitespaceCharacter .. -> " "];
  normalized = StringReplace[
    normalized,
    RegularExpression["([0-9.]+)\\s+10\\s+(-?[0-9]+)"] -> "$1*^$2"];
  matches = StringCases[
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

(* This helper is used only inside one worker. It captures messages and timing
   but performs no shared-file writes. *)
SetAttributes[psTimedIntegral, HoldAll];
psTimedIntegral[label_, expression_] := Module[
  {labelValue = label, messageFile, stream, timing, seconds, value,
   messageText, messageTags, parsed, error, relativeError, hitMaxPoints},

  messageFile = FileNameJoin[{
    $TemporaryDirectory,
    "raw-pattern-message-k" <> ToString[$KernelID] <> "-" <>
      CreateUUID[] <> ".txt"}];
  stream = OpenWrite[messageFile, CharacterEncoding -> "UTF-8"];
  timing = CheckAbort[
    Block[{$Messages = {stream}, $MessageList = {}},
      With[{answer = AbsoluteTiming[expression]},
        messageTags = $MessageList;
        answer]],
    Close[stream];
    Quiet[DeleteFile[messageFile]];
    Abort[]];
  Close[stream];

  {seconds, value} = timing;
  messageText = Quiet[Check[Import[messageFile, "Text"], ""]];
  Quiet[DeleteFile[messageFile]];
  parsed = psParseMaxPointsMessage[messageText];
  error = Lookup[parsed, "reportedErrorEstimate", Missing["NotReported"]];
  relativeError = If[
    NumericQ[error] && NumericQ[value] && value != 0,
    Abs[error/value],
    Missing["NotAvailable"]];
  hitMaxPoints =
    StringContainsQ[messageText, "NIntegrate::maxp"] ||
      ! FreeQ[messageTags, NIntegrate::maxp];

  Join[
    <|
      "integral" -> labelValue,
      "seconds" -> seconds,
      "value" -> value,
      "hitMaxPoints" -> hitMaxPoints,
      "relativeErrorEstimate" -> relativeError,
      "messageText" -> messageText|>,
    parsed]];

psEvaluateTask[task_Association] := Module[
  {system, parameters, budget, stage, started, normResult,
   numeratorResult, kinetic, norm, numerator, correction, status},

  system = task["system"];
  parameters = N[task["parameters"]];
  budget = task["budget"];
  stage = task["stage"];
  started = DateString["ISODateTime"];

  If[system === "X",
    normResult = psTimedIntegral[
      "normDenominator",
      rawMinXNormIntegral[parameters[[1]], budget]];
    numeratorResult = psTimedIntegral[
      "coulombNumerator",
      rawMinXCoulombIntegral[parameters[[1]], budget]];
    kinetic = rawMinXAnalyticKinetic[parameters[[1]]],

    normResult = psTimedIntegral[
      "normDenominator",
      rawMinXXNormIntegral[parameters, budget]];
    numeratorResult = psTimedIntegral[
      "hamiltonianNumerator",
      rawMinXXHamiltonianIntegral[parameters, budget]];
    kinetic = Missing["NotApplicable"]];

  norm = normResult["value"];
  numerator = numeratorResult["value"];
  correction = Which[
    ! NumericQ[norm] || norm <= 10^-12 || ! NumericQ[numerator],
      Missing["InvalidIntegral"],
    system === "X", kinetic + numerator/norm,
    Abs[numerator/norm] >= 100, Missing["EnergyCap"],
    True, numerator/norm];
  status = If[NumericQ[correction], "complete", "failed"];

  <|
    "candidateKey" -> psCandidateKey[system, budget, parameters],
    "stage" -> stage,
    "system" -> system,
    "budget" -> budget,
    "parameters" -> parameters,
    "parameterKey" -> psParameterKey[parameters],
    "norm" -> norm,
    "numeratorRy" -> numerator,
    "analyticKineticRy" -> kinetic,
    "correctionRy" -> correction,
    "elapsedSeconds" ->
      Total[Lookup[{normResult, numeratorResult}, "seconds", 0.]],
    "workerKernel" -> $KernelID,
    "status" -> status,
    "source" -> "parallel-pattern-search",
    "started" -> started,
    "completed" -> DateString["ISODateTime"],
    "integrals" -> {normResult, numeratorResult}|>];

psCandidateCompleteQ[row_Association] :=
  Lookup[row, "status", ""] === "complete" &&
    NumericQ[Lookup[row, "correctionRy", Missing[]]];

psFindCandidate[system_String, budget_Integer, parameters_List] := Module[
  {key = psCandidateKey[system, budget, parameters], matches},
  matches = Select[
    psCandidateRows,
    Lookup[#, "candidateKey", Missing[]] === key &&
      psCandidateCompleteQ[#] &];
  If[matches === {}, Missing["NotEvaluated"], Last[matches]]];

psExportCSV[file_String, rows_List, columns_List] :=
  Export[
    file,
    Prepend[
      (Lookup[#, columns, Missing["NotAvailable"]] & /@ rows),
      columns],
    "CSV"];

psCheckpoint[] := Module[
  {candidateColumns, integralColumns, candidateFlat, integralFlat,
   summary, summaryRow, summaryColumns},
  If[$KernelID =!= 0, Return[Null, Module]];

  Export[
    psOutputFile,
    <|
      "schemaVersion" -> 1,
      "updated" -> DateString["ISODateTime"],
      "configuration" -> psConfigurationSignature,
      "candidates" -> psCandidateRows|>,
    "WXF"];

  candidateFlat = KeyDrop[#, {"integrals"}] & /@ psCandidateRows;
  candidateColumns = {
    "candidateKey", "stage", "system", "budget", "parameters",
    "parameterKey", "norm", "numeratorRy", "analyticKineticRy",
    "correctionRy", "elapsedSeconds", "workerKernel", "status",
    "source", "started", "completed"};
  psExportCSV[psCandidateCSV, candidateFlat, candidateColumns];

  integralFlat = Flatten[
    Function[row,
      Function[integral,
        Join[
          KeyTake[row, {
            "candidateKey", "stage", "system", "budget", "parameters",
            "parameterKey", "workerKernel", "source"}],
          integral]] /@ Lookup[row, "integrals", {}]] /@
      psCandidateRows,
    1];
  integralColumns = {
    "candidateKey", "stage", "system", "budget", "parameters",
    "parameterKey", "workerKernel", "source", "integral", "seconds",
    "value", "hitMaxPoints", "messageIntegralEstimate",
    "reportedErrorEstimate", "relativeErrorEstimate", "messageText"};
  psExportCSV[psIntegralCSV, integralFlat, integralColumns];

  summary = Quiet[Check[psSummary[], <||>]];
  summaryRow = <|
    "a" -> rawMinA,
    "c" -> rawMinC,
    "XBestAlpha" -> Lookup[summary, "XBestAlpha", Missing[]],
    "XBestCorrectionRy" -> Lookup[summary, "XBestCorrectionRy", Missing[]],
    "XXFinalParameters" -> Lookup[summary, "XXFinalParameters", Missing[]],
    "XXFinalCorrectionRy" -> Lookup[summary, "XXFinalCorrectionRy", Missing[]],
    "firstMoveAccepted" -> Lookup[summary, "firstMoveAccepted", Missing[]],
    "finalMoveAccepted" -> Lookup[summary, "finalMoveAccepted", Missing[]],
    "candidateCount" -> Length[psCandidateRows],
    "totalIntegralHours" ->
      Total[Lookup[psCandidateRows, "elapsedSeconds", 0.]]/3600.,
    "updated" -> DateString["ISODateTime"]|>;
  summaryColumns = Keys[summaryRow];
  psExportCSV[psSummaryCSV, {summaryRow}, summaryColumns]];

psPrepareKernels[] := Module[{loaded},
  If[$KernelID =!= 0, Return[$Failed, Module]];
  If[$KernelCount =!= psWorkerCount,
    CloseKernels[];
    LaunchKernels[psWorkerCount]];
  loaded = With[{source = psSourceFile},
    ParallelEvaluate[Quiet[Check[Get[source]; True, False]]]];
  psKernelsPrepared = And @@ loaded;
  Print[
    "Parallel workers prepared: ", $KernelCount,
    ". Source loaded successfully on all workers: ", psKernelsPrepared];
  <|
    "processorCount" -> $ProcessorCount,
    "kernelCount" -> $KernelCount,
    "loaded" -> psKernelsPrepared|>];

psCloseKernels[] := (
  If[$KernelID === 0, CloseKernels[]];
  psKernelsPrepared = False;
  $KernelCount);

psRunCandidates[
   stage_String, system_String, parametersList_List, budget_Integer] := Module[
  {tasks, missing, jobs, result, finishedJob, remaining},

  If[! TrueQ[psKernelsPrepared] || $KernelCount =!= psWorkerCount,
    psPrepareKernels[]];
  If[! TrueQ[psKernelsPrepared], Return[$Failed, Module]];

  tasks = DeleteDuplicatesBy[
    (<|
       "stage" -> stage,
       "system" -> system,
       "budget" -> budget,
       "parameters" -> N[#]|> &) /@ parametersList,
    psCandidateKey[
      Lookup[#, "system"], Lookup[#, "budget"],
      Lookup[#, "parameters"]] &];
  missing = Select[
    tasks,
    MissingQ[psFindCandidate[
      #["system"], #["budget"], #["parameters"]]] &];

  Print[
    stage, ": ", Length[tasks], " requested; ", Length[missing],
    " missing; ", Length[tasks] - Length[missing], " reused."];
  If[missing === {}, Return[
    psFindCandidate[system, budget, #] & /@ parametersList,
    Module]];

  jobs = Composition[ParallelSubmit, psEvaluateTask] /@ missing;
  remaining = jobs;
  While[remaining =!= {},
    {result, finishedJob, remaining} = WaitNext[remaining];
    If[AssociationQ[result],
      AppendTo[psCandidateRows, result];
      psCheckpoint[];
      Print[
        stage, ": completed ", result["parameterKey"],
        " on kernel ", result["workerKernel"],
        "; correction = ", result["correctionRy"],
        "; remaining = ", Length[remaining]],
      Print[
        stage, ": a worker returned a non-association result: ", result]]];

  psFindCandidate[system, budget, #] & /@ parametersList];

(* ---- seed the existing raw XX center results ----------------------------- *)

psCSVAssociations[file_String] := Module[{data},
  If[! FileExistsQ[file], Return[{}, Module]];
  data = Import[file, "CSV"];
  If[Length[data] < 2, {}, AssociationThread[First[data], #] & /@ Rest[data]]];

psIntegralFromGaugeRow[row_Association] := <|
  "integral" -> Lookup[row, "integral", Missing[]],
  "seconds" -> Lookup[row, "seconds", 0.],
  "value" -> Lookup[row, "value", Missing[]],
  "hitMaxPoints" -> Lookup[row, "hitMaxPoints", Missing[]],
  "messageIntegralEstimate" ->
    Lookup[row, "messageIntegralEstimate", Missing["NotReported"]],
  "reportedErrorEstimate" ->
    Lookup[row, "reportedErrorEstimate", Missing["NotReported"]],
  "relativeErrorEstimate" ->
    Lookup[row, "relativeErrorEstimate", Missing["NotAvailable"]],
  "messageText" -> Lookup[row, "messageText", ""]|>;

psSeedXXCenter[] := Module[
  {rows, selected, normRow, numeratorRow, norm, numerator, candidate, budget},
  If[$KernelID =!= 0, Return[Null, Module]];
  rows = psCSVAssociations[psGaugeIntegralCSV];
  Do[
    If[MissingQ[psFindCandidate["XX", budget, psStartXXParameters]],
      selected = Select[
        rows,
        Lookup[#, "system", ""] === "XX" &&
          Lookup[#, "budget", Missing[]] === budget &];
      normRow = SelectFirst[
        selected,
        Lookup[#, "integral", ""] === "normDenominator" &,
        Missing["NotFound"]];
      numeratorRow = SelectFirst[
        selected,
        Lookup[#, "integral", ""] === "hamiltonianNumerator" &,
        Missing["NotFound"]];
      If[AssociationQ[normRow] && AssociationQ[numeratorRow],
        norm = normRow["value"];
        numerator = numeratorRow["value"];
        candidate = <|
          "candidateKey" ->
            psCandidateKey["XX", budget, psStartXXParameters],
          "stage" -> "seed-existing-center",
          "system" -> "XX",
          "budget" -> budget,
          "parameters" -> N[psStartXXParameters],
          "parameterKey" -> psParameterKey[psStartXXParameters],
          "norm" -> norm,
          "numeratorRy" -> numerator,
          "analyticKineticRy" -> Missing["NotApplicable"],
          "correctionRy" -> numerator/norm,
          "elapsedSeconds" ->
            Total[Lookup[{normRow, numeratorRow}, "seconds", 0.]],
          "workerKernel" -> Missing["Historical"],
          "status" -> "complete",
          "source" -> "main-state-raw-gauge-trial-a5-c1",
          "started" -> Missing["Historical"],
          "completed" -> Missing["Historical"],
          "integrals" ->
            psIntegralFromGaugeRow /@ {normRow, numeratorRow}|>;
        AppendTo[psCandidateRows, candidate]]],
    {budget, {psXXSearchBudget, psXXVerifyBudget}}]];

(* ---- X: high-budget grid and half-step refinement ----------------------- *)

psXStep[] := Clip[0.07 psStartXAlpha, {0.04, 0.06}];

psXInitialParameters[] :=
  ({#} &) /@
    (psStartXAlpha + psXStep[] {-2, -1, 0, 1, 2});

psRunXInitial[] :=
  psRunCandidates[
    "X-initial-grid", "X", psXInitialParameters[], psXBudget];

psBestXRow[] := Module[{parameters, rows},
  parameters = DeleteDuplicates[
    Join[
      psXInitialParameters[],
      If[
        And @@ (NumericQ /@ Flatten[psXRefinementParameters[]]),
        psXRefinementParameters[],
        {}]]];
  rows = DeleteMissing[
    psFindCandidate["X", psXBudget, #] & /@ parameters];
  If[rows === {}, Missing["NotEvaluated"],
    First@MinimalBy[rows, Lookup[#, "correctionRy", Infinity] &]]];

psXRefinementParameters[] := Module[
  {initialRows, bestRow, bestAlpha, halfStep},
  initialRows = DeleteMissing[
    psFindCandidate["X", psXBudget, #] & /@ psXInitialParameters[]];
  If[initialRows === {}, Return[{}, Module]];
  bestRow = First@MinimalBy[
    initialRows, Lookup[#, "correctionRy", Infinity] &];
  bestAlpha = bestRow["parameters"][[1]];
  halfStep = psXStep[]/2;
  {{bestAlpha - halfStep}, {bestAlpha + halfStep}}];

psRunXRefinement[] := Module[{parameters = psXRefinementParameters[]},
  If[parameters === {},
    Print["Run psRunXInitial[] before X refinement."];
    Return[$Failed, Module]];
  psRunCandidates[
    "X-half-step-refinement", "X", parameters, psXBudget]];

(* ---- XX: local stencil, verification, and directional refinement -------- *)

psXXSteps[parameters_List] := {
  Clip[0.12 parameters[[1]], {0.05, 0.10}],
  Clip[0.25 parameters[[2]], {0.02, 0.06}],
  Clip[0.08 Abs[parameters[[3]]], {0.15, 0.25}],
  Clip[0.10 parameters[[4]], {0.15, 0.25}]};

psShiftParameter[
   parameters_List, axis_Integer, displacement_?NumericQ] := Module[
  {shifted = N[parameters]},
  shifted[[axis]] += displacement;
  If[MemberQ[{1, 2, 4}, axis], shifted[[axis]] = Max[0.001, shifted[[axis]]]];
  If[axis === 3, shifted[[axis]] = Clip[shifted[[axis]], {-0.999, 4.999}]];
  shifted];

psXXInitialParameters[] := Module[{steps = psXXSteps[psStartXXParameters]},
  DeleteDuplicates@Join[
    {N[psStartXXParameters]},
    Flatten[
      Table[
        {
          psShiftParameter[psStartXXParameters, axis, -steps[[axis]]],
          psShiftParameter[psStartXXParameters, axis, steps[[axis]]]},
        {axis, 4}],
      1]]];

psRunXXInitial[] :=
  psRunCandidates[
    "XX-initial-stencil", "XX", psXXInitialParameters[],
    psXXSearchBudget];

psXXInitialBestRow[] := Module[{rows},
  rows = DeleteMissing[
    psFindCandidate["XX", psXXSearchBudget, #] & /@
      psXXInitialParameters[]];
  If[rows === {}, Missing["NotEvaluated"],
    First@MinimalBy[rows, Lookup[#, "correctionRy", Infinity] &]]];

psCompareBudgets[centerParameters_List, candidateParameters_List] := Module[
  {centerLow, centerHigh, candidateLow, candidateHigh,
   deltaLow, deltaHigh, disagreement, threshold, accepted, reason},

  centerLow = psFindCandidate[
    "XX", psXXSearchBudget, centerParameters];
  centerHigh = psFindCandidate[
    "XX", psXXVerifyBudget, centerParameters];
  candidateLow = psFindCandidate[
    "XX", psXXSearchBudget, candidateParameters];
  candidateHigh = psFindCandidate[
    "XX", psXXVerifyBudget, candidateParameters];
  If[! And @@ (AssociationQ /@
      {centerLow, centerHigh, candidateLow, candidateHigh}),
    Return[<|"status" -> "missing evaluations", "accepted" -> False|>,
      Module]];

  deltaLow = candidateLow["correctionRy"] - centerLow["correctionRy"];
  deltaHigh = candidateHigh["correctionRy"] - centerHigh["correctionRy"];
  disagreement = Abs[deltaHigh - deltaLow];
  threshold = Max[psMinimumImprovementRy, disagreement];
  accepted =
    candidateParameters =!= centerParameters &&
      deltaLow < 0 && deltaHigh < 0 && -deltaHigh > threshold;
  reason = Which[
    candidateParameters === centerParameters, "center remained best",
    deltaLow >= 0, "candidate not lower at search budget",
    deltaHigh >= 0, "ranking reversed at verification budget",
    -deltaHigh <= threshold,
      "verified improvement does not exceed stability threshold",
    True, "accepted"];

  <|
    "status" -> "complete",
    "centerParameters" -> centerParameters,
    "candidateParameters" -> candidateParameters,
    "centerLowRy" -> centerLow["correctionRy"],
    "candidateLowRy" -> candidateLow["correctionRy"],
    "centerHighRy" -> centerHigh["correctionRy"],
    "candidateHighRy" -> candidateHigh["correctionRy"],
    "deltaLowRy" -> deltaLow,
    "deltaHighRy" -> deltaHigh,
    "crossBudgetDisagreementRy" -> disagreement,
    "acceptanceThresholdRy" -> threshold,
    "accepted" -> accepted,
    "reason" -> reason|>];

psRunXXVerification[] := Module[{best = psXXInitialBestRow[], parameters},
  If[! AssociationQ[best],
    Print["Run psRunXXInitial[] before verification."];
    Return[$Failed, Module]];
  parameters = DeleteDuplicates[{psStartXXParameters, best["parameters"]}];
  psRunCandidates[
    "XX-first-verification", "XX", parameters, psXXVerifyBudget];
  psXXFirstDecision[]];

psXXFirstDecision[] := Module[{best = psXXInitialBestRow[]},
  If[! AssociationQ[best],
    <|"status" -> "initial stencil incomplete", "accepted" -> False|>,
    psCompareBudgets[psStartXXParameters, best["parameters"]]]];

psXXAcceptedCenter[] := Module[{decision = psXXFirstDecision[]},
  If[TrueQ[Lookup[decision, "accepted", False]],
    decision["candidateParameters"],
    N[psStartXXParameters]]];

psXXAxisScores[] := Module[
  {center, steps, centerRow, rows, score},
  center = N[psStartXXParameters];
  steps = psXXSteps[center];
  centerRow = psFindCandidate["XX", psXXSearchBudget, center];
  If[! AssociationQ[centerRow], Return[{}, Module]];
  Table[
    rows = DeleteMissing[
      psFindCandidate["XX", psXXSearchBudget, #] & /@
        {
          psShiftParameter[center, axis, -steps[[axis]]],
          psShiftParameter[center, axis, steps[[axis]]]}];
    score = If[
      rows === {}, Infinity,
      Min[Lookup[rows, "correctionRy"]] - centerRow["correctionRy"]];
    <|"axis" -> axis, "scoreRy" -> score|>,
    {axis, 4}]];

psXXRefinementAxes[] :=
  Lookup[
    Take[
      SortBy[psXXAxisScores[], Lookup[#, "scoreRy", Infinity] &],
      UpTo[psRefinementDirectionCount]],
    "axis"];

psXXRefinementParameters[] := Module[
  {center, halfSteps, axes},
  center = psXXAcceptedCenter[];
  halfSteps = psXXSteps[psStartXXParameters]/2;
  axes = psXXRefinementAxes[];
  If[axes === {}, Return[{}, Module]];
  DeleteDuplicates@Flatten[
    Table[
      {
        psShiftParameter[center, axis, -halfSteps[[axis]]],
        psShiftParameter[center, axis, halfSteps[[axis]]]},
      {axis, axes}],
    1]];

psRunXXRefinement[] := Module[{parameters = psXXRefinementParameters[]},
  If[parameters === {},
    Print[
      "Run the initial stencil and first verification before refinement."];
    Return[$Failed, Module]];
  psRunCandidates[
    "XX-directional-refinement", "XX", parameters,
    psXXSearchBudget]];

psXXRefinementBestRow[] := Module[{center, candidates, rows},
  center = psXXAcceptedCenter[];
  candidates = DeleteDuplicates@Join[{center}, psXXRefinementParameters[]];
  rows = DeleteMissing[
    psFindCandidate["XX", psXXSearchBudget, #] & /@ candidates];
  If[rows === {}, Missing["NotEvaluated"],
    First@MinimalBy[rows, Lookup[#, "correctionRy", Infinity] &]]];

psRunXXFinalVerification[] := Module[
  {center = psXXAcceptedCenter[], best = psXXRefinementBestRow[], parameters},
  If[! AssociationQ[best],
    Print["Run psRunXXRefinement[] before final verification."];
    Return[$Failed, Module]];
  parameters = DeleteDuplicates[{center, best["parameters"]}];
  psRunCandidates[
    "XX-final-verification", "XX", parameters, psXXVerifyBudget];
  psXXFinalDecision[]];

psXXFinalDecision[] := Module[
  {center = psXXAcceptedCenter[], best = psXXRefinementBestRow[]},
  If[! AssociationQ[best],
    <|"status" -> "refinement incomplete", "accepted" -> False|>,
    psCompareBudgets[center, best["parameters"]]]];

psFinalXXParameters[] := Module[
  {center = psXXAcceptedCenter[], decision = psXXFinalDecision[]},
  If[TrueQ[Lookup[decision, "accepted", False]],
    decision["candidateParameters"],
    center]];

(* ---- reporting ---------------------------------------------------------- *)

psConfiguration[] := Join[
  psConfigurationSignature,
  <|
    "XStep" -> psXStep[],
    "XXSteps" -> psXXSteps[psStartXXParameters],
    "XInitialParameters" -> psXInitialParameters[],
    "XXInitialParameters" -> psXXInitialParameters[],
    "angularTreatment" ->
      "phi_a=0; all remaining relative angles cover [0,2 Pi]",
    "sampling" ->
      "independent adaptive QMC calls for numerator and denominator"|>];

psCandidateTable[] := Dataset[KeyDrop[#, "integrals"] & /@ psCandidateRows];

psSummary[] := Module[
  {xBest, firstDecision, refinementBest, finalDecision, finalParameters,
   finalRow},
  xBest = Quiet[Check[psBestXRow[], Missing["NotEvaluated"]]];
  firstDecision = Quiet[Check[psXXFirstDecision[], <||>]];
  refinementBest = Quiet[Check[psXXRefinementBestRow[], Missing[]]];
  finalDecision = Quiet[Check[psXXFinalDecision[], <||>]];
  finalParameters = Quiet[Check[psFinalXXParameters[], Missing[]]];
  finalRow = If[ListQ[finalParameters],
    psFindCandidate["XX", psXXVerifyBudget, finalParameters],
    Missing[]];

  <|
    "configuration" -> psConfiguration[],
    "XBestAlpha" -> If[AssociationQ[xBest], xBest["parameters"][[1]], Missing[]],
    "XBestCorrectionRy" ->
      If[AssociationQ[xBest], xBest["correctionRy"], Missing[]],
    "XXInitialBest" -> psXXInitialBestRow[],
    "XXFirstDecision" -> firstDecision,
    "firstMoveAccepted" -> Lookup[firstDecision, "accepted", Missing[]],
    "XXRefinementAxes" -> psXXRefinementAxes[],
    "XXRefinementBest" -> refinementBest,
    "XXFinalDecision" -> finalDecision,
    "finalMoveAccepted" -> Lookup[finalDecision, "accepted", Missing[]],
    "XXFinalParameters" -> finalParameters,
    "XXFinalCorrectionRy" ->
      If[AssociationQ[finalRow], finalRow["correctionRy"], Missing[]],
    "candidateCount" -> Length[psCandidateRows],
    "totalIntegralHours" ->
      Total[Lookup[psCandidateRows, "elapsedSeconds", 0.]]/3600.|>];

psXPlot[] := Module[{rows},
  rows = Select[
    psCandidateRows,
    Lookup[#, "system", ""] === "X" &&
      Lookup[#, "budget", Missing[]] === psXBudget &&
      psCandidateCompleteQ[#] &];
  If[rows === {}, Return["No X evaluations yet.", Module]];
  ListPlot[
    SortBy[
      ({#["parameters"][[1]], #["correctionRy"]} &) /@ rows,
      First],
    Joined -> True, Mesh -> All, Frame -> True,
    FrameLabel -> {"alpha_X", "X correction (Ry)"},
    PlotLabel -> "2 x 10^6-point X scan", ImageSize -> 520]];

psXXInitialPlot[] := Module[{center, steps, points, labels},
  center = psFindCandidate["XX", psXXSearchBudget, psStartXXParameters];
  steps = psXXSteps[psStartXXParameters];
  If[! AssociationQ[center], Return["Initial XX stencil is incomplete.", Module]];
  points = Table[
    With[
      {minus = psFindCandidate[
         "XX", psXXSearchBudget,
         psShiftParameter[psStartXXParameters, axis, -steps[[axis]]]],
       plus = psFindCandidate[
         "XX", psXXSearchBudget,
         psShiftParameter[psStartXXParameters, axis, steps[[axis]]]]},
      If[AssociationQ[minus] && AssociationQ[plus],
        {
          {-1, minus["correctionRy"]},
          {0, center["correctionRy"]},
          {1, plus["correctionRy"]}},
        {}]],
    {axis, 4}];
  labels = {"alpha", "beta", "gamma", "delta"};
  GraphicsGrid[
    Partition[
      MapThread[
        ListPlot[#1, Joined -> True, Mesh -> All, Frame -> True,
          FrameLabel -> {#2 <> " direction", "XX correction (Ry)"},
          PlotRange -> All, ImageSize -> 280] &,
        {points, labels}],
      2],
    ImageSize -> 600]];

If[$KernelID === 0,
  psSeedXXCenter[];
  Print[
    "Parallel raw pattern search loaded for (a,c) = (5,1). Existing XX ",
    "center evaluations reused: ",
    Count[
      psCandidateRows,
      row_ /; Lookup[row, "source", ""] ===
        "main-state-raw-gauge-trial-a5-c1"],
    ". Review psConfiguration[], then run psPrepareKernels[]."]];
