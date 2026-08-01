(* ::Package:: *)

(* ============================================================================
   Parallel safeguarded raw pattern-search campaign for the six geometries
   remaining after the validated (a,c) = (5,1) trial.

   The global queue, rather than each geometry, owns the eight subkernels. This
   keeps the workers occupied across geometries while preserving the estimator
   used in the successful trial:

     - X kinetic correction is analytical;
     - X Coulomb numerator and norm are independent AdaptiveQuasiMonteCarlo
       integrations;
     - XX uses the raw P+Q norm, six Coulomb terms, and all four kinetic terms;
     - phi_a = 0 removes only the redundant global rotation;
     - all three remaining XX angles cover [0,2 Pi];
     - there is no reflection folding or particle-exchange multiplicity;
     - H (or V for X) and N do not share fixed Sobol points.

   Every returned candidate is checkpointed by the master kernel. Re-evaluating
   a stage resubmits only missing candidates.
   ============================================================================ *)

pscSourceFile = $InputFileName;
pscDirectory = DirectoryName[pscSourceFile];

Get[FileNameJoin[{
  pscDirectory, "Main-State-Raw-Minimization-a5-c1.wl"}]];

ClearAll[
  pscGeometryKey, pscParameterKey, pscCandidateKey, pscSavedRun,
  pscStartXAlpha, pscStartXXParameters, pscSingleParticle,
  pscParseMaxPointsMessage, pscTimedIntegral, pscRatioError,
  pscEvaluateTask, pscCandidateCompleteQ, pscFindCandidate,
  pscParameterRows, pscParametersCompleteQ, pscRunCandidates,
  pscPrepareKernels, pscCloseKernels, pscExportCSV, pscCheckpoint,
  pscXStep, pscXInitialParameters, pscXRefinementParameters,
  pscRunXInitial, pscRunXRefinement, pscBestXRow,
  pscXXSteps, pscShiftParameter, pscXXInitialParameters,
  pscRunXXInitial, pscXXInitialBestRow, pscCompareBudgets,
  pscRunXXVerification, pscXXFirstDecision, pscXXAcceptedCenter,
  pscXXAxisScores, pscXXRefinementAxes, pscXXRefinementParameters,
  pscRunXXRefinement, pscXXRefinementBestRow,
  pscRunXXFinalVerification, pscXXFinalDecision, pscFinalXXParameters,
  pscGeometryConfiguration, pscConfiguration, pscGeometrySummary,
  pscSummary, pscCandidateTable, pscDecisionTable, pscXPlot];

(* ---- approved campaign configuration ------------------------------------ *)

pscGeometries = N@{
  {5, 0.5}, {5, 1.5}, {5, 2}, {3, 1}, {7, 1}, {10, 1}};

pscWorkerCount = 8;
pscXBudget = 2*10^6;
pscXXSearchBudget = 10^6;
pscXXVerifyBudget = 2*10^6;
pscMinimumImprovementRy = 0.02;
pscRefinementDirectionCount = 2;

(* Preserve the validated raw trial's integration settings. *)
rawMinPrecisionGoal = 4;
rawMinAccuracyGoal = Infinity;
rawMinBisectionDithering = 0;

pscProductionFile = FileNameJoin[{
  pscDirectory, "main-state-production-results.wxf"}];
pscOutputFile = FileNameJoin[{
  pscDirectory, "main-state-raw-pattern-search-remaining-results.wxf"}];
pscCandidateCSV = FileNameJoin[{
  pscDirectory, "main-state-raw-pattern-search-remaining-candidates.csv"}];
pscIntegralCSV = FileNameJoin[{
  pscDirectory, "main-state-raw-pattern-search-remaining-integrals.csv"}];
pscSummaryCSV = FileNameJoin[{
  pscDirectory, "main-state-raw-pattern-search-remaining-summary.csv"}];

pscProductionStore = Import[pscProductionFile, "WXF"];

pscGeometryKey[geometry : {_?NumericQ, _?NumericQ}] :=
  StringRiffle[ToString[#, InputForm] & /@ N[geometry], "|"];

pscSavedRun[geometry : {_?NumericQ, _?NumericQ}] :=
  Lookup[
    Lookup[pscProductionStore, "runs", <||>],
    pscGeometryKey[geometry], Missing["GeometryNotFound"]];

pscStartXAlpha[geometry : {_?NumericQ, _?NumericQ}] :=
  pscSavedRun[geometry]["X"]["alpha"];

pscStartXXParameters[geometry : {_?NumericQ, _?NumericQ}] :=
  N[pscSavedRun[geometry]["XX"]["params"]];

pscSingleParticle[
   geometry : {_?NumericQ, _?NumericQ}, system_String] :=
  pscSavedRun[geometry][system]["singleParticle"];

pscStartData = Association@Table[
  pscGeometryKey[geometry] -> <|
    "geometry" -> geometry,
    "XAlpha" -> pscStartXAlpha[geometry],
    "XXParameters" -> pscStartXXParameters[geometry],
    "XSingleParticleRy" -> pscSingleParticle[geometry, "X"],
    "XXSingleParticleRy" -> pscSingleParticle[geometry, "XX"]|>,
  {geometry, pscGeometries}];

If[
  ! And @@ Table[
      With[{run = pscSavedRun[geometry]},
        AssociationQ[run] &&
          NumericQ[pscStartXAlpha[geometry]] &&
          MatchQ[
            pscStartXXParameters[geometry],
            {_?NumericQ, _?NumericQ, _?NumericQ, _?NumericQ}]],
      {geometry, pscGeometries}],
  Print[
    "At least one requested geometry has no complete numeric production " <>
      "warm start in ", pscProductionFile];
  Abort[]];

pscConfigurationSignature = <|
  "implementation" -> "parallel-raw-pattern-search-campaign-v1",
  "geometries" -> pscGeometries,
  "workers" -> pscWorkerCount,
  "XBudget" -> pscXBudget,
  "XXSearchBudget" -> pscXXSearchBudget,
  "XXVerifyBudget" -> pscXXVerifyBudget,
  "minimumImprovementRy" -> pscMinimumImprovementRy,
  "refinementDirectionCount" -> pscRefinementDirectionCount,
  "starts" -> pscStartData|>;

pscCandidateRows = {};
pscKernelsPrepared = False;

If[FileExistsQ[pscOutputFile],
  pscPrevious = Quiet[Check[Import[pscOutputFile, "WXF"], $Failed]];
  If[
    AssociationQ[pscPrevious] &&
      Lookup[pscPrevious, "schemaVersion", Missing[]] === 1 &&
      Lookup[pscPrevious, "configuration", Missing[]] ===
        pscConfigurationSignature,
    pscCandidateRows = Lookup[pscPrevious, "candidates", {}],
    If[$KernelID === 0,
      Print[
        "Existing remaining-geometry checkpoint is incompatible and will " <>
          "not be reused: ", pscOutputFile]]]];

pscParameterKey[parameters_List] :=
  StringRiffle[ToString[#, InputForm] & /@ N[parameters], "|"];

pscCandidateKey[
   geometry : {_?NumericQ, _?NumericQ}, system_String,
   budget_Integer, parameters_List] :=
  StringRiffle[{
    pscGeometryKey[geometry], system, ToString[budget, InputForm],
    pscParameterKey[parameters]}, "::"];

(* NIntegrate's OutputForm sometimes places a scientific-notation exponent
   on the line before the mantissa. Both layouts are handled here. *)
pscParseMaxPointsMessage[text_String] := Module[
  {normalized, plain, scientific, clean, numbers},
  normalized = StringReplace[text, WhitespaceCharacter .. -> " "];
  clean[token_] :=
    StringReplace[token, RegularExpression["`[0-9.]*"] -> ""];

  plain = StringCases[
    normalized,
    RegularExpression[
      "NIntegrate obtained\\s+([^\\s]+)\\s+and\\s+([^\\s]+)\\s+for"] ->
      {"$1", "$2"}];
  If[plain =!= {},
    numbers = Quiet[Check[ToExpression /@ (clean /@ First[plain]), $Failed]];
    If[MatchQ[numbers, {_?NumericQ, _?NumericQ}],
      Return[<|
        "messageIntegralEstimate" -> numbers[[1]],
        "reportedErrorEstimate" -> numbers[[2]]|>, Module]]];

  scientific = StringCases[
    normalized,
    RegularExpression[
      "after\\s+[0-9]+\\s+(-?[0-9]+)\\s+integrand evaluations\\.\\s+" <>
      "NIntegrate obtained\\s+([^\\s]+)\\s+and\\s+([^\\s]+)\\s+" <>
      "10\\s+for"] -> {"$2", "$3", "$1"}];
  If[scientific === {}, Return[<||>, Module]];
  numbers = Quiet[Check[
    ToExpression /@ (clean /@ First[scientific]), $Failed]];
  If[
    MatchQ[numbers, {_?NumericQ, _?NumericQ, _Integer}],
    <|
      "messageIntegralEstimate" -> numbers[[1]],
      "reportedErrorEstimate" -> numbers[[2]]*10^numbers[[3]]|>,
    <||>]];

SetAttributes[pscTimedIntegral, HoldAll];
pscTimedIntegral[label_, expression_] := Module[
  {labelValue = label, messageFile, stream, timing, seconds, value,
   messageText, messageTags, parsed, error, relativeError, hitMaxPoints},

  messageFile = FileNameJoin[{
    $TemporaryDirectory,
    "raw-campaign-message-k" <> ToString[$KernelID] <> "-" <>
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
  parsed = pscParseMaxPointsMessage[messageText];
  error = Lookup[parsed, "reportedErrorEstimate", Missing["NotReported"]];
  relativeError = If[
    NumericQ[error] && NumericQ[value] && value != 0,
    Abs[error/value], Missing["NotAvailable"]];
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

pscRatioError[
   numeratorResult_Association, normResult_Association,
   ratio_?NumericQ] := Module[{nError, dError, numerator, norm},
  nError = Lookup[
    numeratorResult, "reportedErrorEstimate", Missing["NotReported"]];
  dError = Lookup[
    normResult, "reportedErrorEstimate", Missing["NotReported"]];
  numerator = numeratorResult["value"];
  norm = normResult["value"];
  If[
    And @@ (NumericQ /@ {nError, dError, numerator, norm}) &&
      numerator != 0 && norm != 0,
    Abs[ratio] Sqrt[(nError/numerator)^2 + (dError/norm)^2],
    Missing["NotAvailable"]]];

pscEvaluateTask[task_Association] := Module[
  {geometry, system, parameters, budget, stage, singleParticle,
   started, normResult, numeratorResult, kinetic, norm, numerator,
   correction, total, roughError, status},

  geometry = N[task["geometry"]];
  system = task["system"];
  parameters = N[task["parameters"]];
  budget = task["budget"];
  stage = task["stage"];
  singleParticle = task["singleParticleRy"];
  started = DateString["ISODateTime"];

  Block[{rawMinA = geometry[[1]], rawMinC = geometry[[2]]},
    If[system === "X",
      normResult = pscTimedIntegral[
        "normDenominator",
        rawMinXNormIntegral[parameters[[1]], budget]];
      numeratorResult = pscTimedIntegral[
        "coulombNumerator",
        rawMinXCoulombIntegral[parameters[[1]], budget]];
      kinetic = rawMinXAnalyticKinetic[parameters[[1]]],

      normResult = pscTimedIntegral[
        "normDenominator",
        rawMinXXNormIntegral[parameters, budget]];
      numeratorResult = pscTimedIntegral[
        "hamiltonianNumerator",
        rawMinXXHamiltonianIntegral[parameters, budget]];
      kinetic = Missing["NotApplicable"]]];

  norm = normResult["value"];
  numerator = numeratorResult["value"];
  correction = Which[
    ! NumericQ[norm] || norm <= 10^-12 || ! NumericQ[numerator],
      Missing["InvalidIntegral"],
    system === "X", kinetic + numerator/norm,
    Abs[numerator/norm] >= 100, Missing["EnergyCap"],
    True, numerator/norm];
  total = If[NumericQ[correction], singleParticle + correction, Missing[]];
  roughError = If[
    NumericQ[correction],
    pscRatioError[numeratorResult, normResult, numerator/norm],
    Missing["NotAvailable"]];
  status = If[NumericQ[correction], "complete", "failed"];

  <|
    "candidateKey" ->
      pscCandidateKey[geometry, system, budget, parameters],
    "stage" -> stage,
    "geometryKey" -> pscGeometryKey[geometry],
    "a" -> geometry[[1]],
    "c" -> geometry[[2]],
    "system" -> system,
    "budget" -> budget,
    "parameters" -> parameters,
    "parameterKey" -> pscParameterKey[parameters],
    "norm" -> norm,
    "numeratorRy" -> numerator,
    "analyticKineticRy" -> kinetic,
    "correctionRy" -> correction,
    "roughCorrectionErrorRy" -> roughError,
    "singleParticleRy" -> singleParticle,
    "totalRy" -> total,
    "elapsedSeconds" ->
      Total[Lookup[{normResult, numeratorResult}, "seconds", 0.]],
    "workerKernel" -> $KernelID,
    "status" -> status,
    "source" -> "parallel-pattern-search-remaining",
    "started" -> started,
    "completed" -> DateString["ISODateTime"],
    "integrals" -> {normResult, numeratorResult}|>];

pscCandidateCompleteQ[row_Association] :=
  Lookup[row, "status", ""] === "complete" &&
    NumericQ[Lookup[row, "correctionRy", Missing[]]];

pscFindCandidate[
   geometry : {_?NumericQ, _?NumericQ}, system_String,
   budget_Integer, parameters_List] := Module[
  {key = pscCandidateKey[geometry, system, budget, parameters], matches},
  matches = Select[
    pscCandidateRows,
    Lookup[#, "candidateKey", Missing[]] === key &&
      pscCandidateCompleteQ[#] &];
  If[matches === {}, Missing["NotEvaluated"], Last[matches]]];

pscParameterRows[
   geometry : {_?NumericQ, _?NumericQ}, system_String,
   budget_Integer, parametersList_List] :=
  pscFindCandidate[geometry, system, budget, #] & /@ parametersList;

pscParametersCompleteQ[
   geometry : {_?NumericQ, _?NumericQ}, system_String,
   budget_Integer, parametersList_List] :=
  And @@ (AssociationQ /@
    pscParameterRows[geometry, system, budget, parametersList]);

pscExportCSV[file_String, rows_List, columns_List] :=
  Export[
    file,
    Prepend[
      (Lookup[#, columns, Missing["NotAvailable"]] & /@ rows), columns],
    "CSV"];

pscCheckpoint[] := Module[
  {candidateColumns, integralColumns, candidateFlat, integralFlat,
   summaryRows, summaryColumns},
  If[$KernelID =!= 0, Return[Null, Module]];

  Export[
    pscOutputFile,
    <|
      "schemaVersion" -> 1,
      "updated" -> DateString["ISODateTime"],
      "configuration" -> pscConfigurationSignature,
      "candidates" -> pscCandidateRows|>,
    "WXF"];

  candidateFlat = KeyDrop[#, {"integrals"}] & /@ pscCandidateRows;
  candidateColumns = {
    "candidateKey", "stage", "geometryKey", "a", "c", "system",
    "budget", "parameters", "parameterKey", "norm", "numeratorRy",
    "analyticKineticRy", "correctionRy", "roughCorrectionErrorRy",
    "singleParticleRy", "totalRy", "elapsedSeconds", "workerKernel",
    "status", "source", "started", "completed"};
  pscExportCSV[pscCandidateCSV, candidateFlat, candidateColumns];

  integralFlat = Flatten[
    Function[row,
      Function[integral,
        Join[
          KeyTake[row, {
            "candidateKey", "stage", "geometryKey", "a", "c", "system",
            "budget", "parameters", "parameterKey", "workerKernel",
            "source"}],
          integral]] /@ Lookup[row, "integrals", {}]] /@ pscCandidateRows,
    1];
  integralColumns = {
    "candidateKey", "stage", "geometryKey", "a", "c", "system",
    "budget", "parameters", "parameterKey", "workerKernel", "source",
    "integral", "seconds", "value", "hitMaxPoints",
    "messageIntegralEstimate", "reportedErrorEstimate",
    "relativeErrorEstimate", "messageText"};
  pscExportCSV[pscIntegralCSV, integralFlat, integralColumns];

  summaryRows = pscGeometrySummary /@ pscGeometries;
  summaryColumns = {
    "a", "c", "XBestAlpha", "XCorrectionRy", "XRoughErrorRy",
    "XTotalRy", "XXFinalParameters", "XXCorrectionRy",
    "XXRoughErrorRy", "XXTotalRy", "bindingRy",
    "bindingRoughErrorRy", "firstMoveAccepted", "finalMoveAccepted",
    "candidateCount", "totalIntegralHours"};
  pscExportCSV[pscSummaryCSV, summaryRows, summaryColumns]];

pscPrepareKernels[] := Module[{loaded},
  If[$KernelID =!= 0, Return[$Failed, Module]];
  If[$KernelCount =!= pscWorkerCount,
    CloseKernels[];
    LaunchKernels[pscWorkerCount]];
  loaded = With[{source = pscSourceFile},
    ParallelEvaluate[Quiet[Check[Get[source]; True, False]]]];
  pscKernelsPrepared = And @@ loaded;
  Print[
    "Parallel workers prepared: ", $KernelCount,
    ". Campaign source loaded successfully on all workers: ",
    pscKernelsPrepared];
  <|
    "processorCount" -> $ProcessorCount,
    "kernelCount" -> $KernelCount,
    "loaded" -> pscKernelsPrepared|>];

pscCloseKernels[] := (
  If[$KernelID === 0, CloseKernels[]];
  pscKernelsPrepared = False;
  $KernelCount);

pscRunCandidates[
   stage_String, system_String, requests_List, budget_Integer] := Module[
  {tasks, missing, jobs, result, finishedJob, remaining},

  If[! TrueQ[pscKernelsPrepared] || $KernelCount =!= pscWorkerCount,
    pscPrepareKernels[]];
  If[! TrueQ[pscKernelsPrepared], Return[$Failed, Module]];

  tasks = DeleteDuplicatesBy[
    Function[request,
      <|
        "stage" -> stage,
        "geometry" -> N[request["geometry"]],
        "system" -> system,
        "budget" -> budget,
        "parameters" -> N[request["parameters"]],
        "singleParticleRy" ->
          pscSingleParticle[request["geometry"], system]|>] /@ requests,
    pscCandidateKey[
      Lookup[#, "geometry"], Lookup[#, "system"], Lookup[#, "budget"],
      Lookup[#, "parameters"]] &];
  missing = Select[
    tasks,
    MissingQ[pscFindCandidate[
      #["geometry"], #["system"], #["budget"], #["parameters"]]] &];

  Print[
    stage, ": ", Length[tasks], " requested; ", Length[missing],
    " missing; ", Length[tasks] - Length[missing], " reused."];
  If[missing === {}, Return[
    pscFindCandidate[
      #["geometry"], #["system"], #["budget"], #["parameters"]] & /@
        tasks,
    Module]];

  jobs = Composition[ParallelSubmit, pscEvaluateTask] /@ missing;
  remaining = jobs;
  While[remaining =!= {},
    {result, finishedJob, remaining} = WaitNext[remaining];
    If[AssociationQ[result],
      AppendTo[pscCandidateRows, result];
      pscCheckpoint[];
      Print[
        stage, ": completed (", result["geometryKey"], ") ",
        result["parameterKey"], " on kernel ", result["workerKernel"],
        "; correction = ", result["correctionRy"],
        "; remaining = ", Length[remaining]],
      Print[
        stage, ": a worker returned a non-association result: ", result]]];

  pscFindCandidate[
    #["geometry"], #["system"], #["budget"], #["parameters"]] & /@
      tasks];

(* ---- X: high-budget grid and half-step refinement ----------------------- *)

pscXStep[geometry : {_?NumericQ, _?NumericQ}] :=
  Clip[0.07 pscStartXAlpha[geometry], {0.04, 0.06}];

pscXInitialParameters[geometry : {_?NumericQ, _?NumericQ}] :=
  ({#} &) /@
    (pscStartXAlpha[geometry] +
      pscXStep[geometry] {-2, -1, 0, 1, 2});

pscRunXInitial[] := pscRunCandidates[
  "X-initial-grid", "X",
  Flatten[
    Table[
      <|"geometry" -> geometry, "parameters" -> parameters|>,
      {geometry, pscGeometries},
      {parameters, pscXInitialParameters[geometry]}],
    1],
  pscXBudget];

pscXRefinementParameters[geometry : {_?NumericQ, _?NumericQ}] := Module[
  {initialParameters, initialRows, bestRow, bestAlpha, halfStep},
  initialParameters = pscXInitialParameters[geometry];
  If[! pscParametersCompleteQ[
      geometry, "X", pscXBudget, initialParameters],
    Return[{}, Module]];
  initialRows = pscParameterRows[
    geometry, "X", pscXBudget, initialParameters];
  bestRow = First@MinimalBy[
    initialRows, Lookup[#, "correctionRy", Infinity] &];
  bestAlpha = bestRow["parameters"][[1]];
  halfStep = pscXStep[geometry]/2;
  {{bestAlpha - halfStep}, {bestAlpha + halfStep}}];

pscRunXRefinement[] := Module[{requests},
  requests = Flatten[
    Table[
      <|"geometry" -> geometry, "parameters" -> parameters|>,
      {geometry, pscGeometries},
      {parameters, pscXRefinementParameters[geometry]}],
    1];
  If[requests === {},
    Print["Run pscRunXInitial[] before X refinement."];
    Return[$Failed, Module]];
  pscRunCandidates[
    "X-half-step-refinement", "X", requests, pscXBudget]];

pscBestXRow[geometry : {_?NumericQ, _?NumericQ}] := Module[
  {parameters, rows},
  parameters = DeleteDuplicates@Join[
    pscXInitialParameters[geometry], pscXRefinementParameters[geometry]];
  rows = DeleteMissing@pscParameterRows[
    geometry, "X", pscXBudget, parameters];
  If[rows === {}, Missing["NotEvaluated"],
    First@MinimalBy[rows, Lookup[#, "correctionRy", Infinity] &]]];

(* ---- XX: local stencil, verification, and directional refinement -------- *)

pscXXSteps[
   geometry : {_?NumericQ, _?NumericQ}, parameters_List] := {
  Clip[0.12 parameters[[1]], {0.05, 0.10}],
  Clip[0.25 parameters[[2]], {0.02, 0.06}],
  Clip[0.08 Abs[parameters[[3]]], {0.15, 0.25}],
  Clip[0.10 parameters[[4]], {0.15, 0.25}]};

pscShiftParameter[
   parameters_List, axis_Integer, displacement_?NumericQ] := Module[
  {shifted = N[parameters]},
  shifted[[axis]] += displacement;
  If[MemberQ[{1, 2, 4}, axis],
    shifted[[axis]] = Max[0.001, shifted[[axis]]]];
  If[axis === 3,
    shifted[[axis]] = Clip[shifted[[axis]], {-0.999, 4.999}]];
  shifted];

pscXXInitialParameters[geometry : {_?NumericQ, _?NumericQ}] := Module[
  {center = pscStartXXParameters[geometry], steps},
  steps = pscXXSteps[geometry, center];
  DeleteDuplicates@Join[
    {center},
    Flatten[
      Table[{
        pscShiftParameter[center, axis, -steps[[axis]]],
        pscShiftParameter[center, axis, steps[[axis]]]},
        {axis, 4}],
      1]]];

pscRunXXInitial[] := pscRunCandidates[
  "XX-initial-stencil", "XX",
  Flatten[
    Table[
      <|"geometry" -> geometry, "parameters" -> parameters|>,
      {geometry, pscGeometries},
      {parameters, pscXXInitialParameters[geometry]}],
    1],
  pscXXSearchBudget];

pscXXInitialBestRow[geometry : {_?NumericQ, _?NumericQ}] := Module[
  {parameters = pscXXInitialParameters[geometry], rows},
  If[! pscParametersCompleteQ[
      geometry, "XX", pscXXSearchBudget, parameters],
    Return[Missing["StencilIncomplete"], Module]];
  rows = pscParameterRows[geometry, "XX", pscXXSearchBudget, parameters];
  First@MinimalBy[rows, Lookup[#, "correctionRy", Infinity] &]];

pscCompareBudgets[
   geometry : {_?NumericQ, _?NumericQ}, centerParameters_List,
   candidateParameters_List] := Module[
  {centerLow, centerHigh, candidateLow, candidateHigh,
   deltaLow, deltaHigh, disagreement, threshold, accepted, reason},

  centerLow = pscFindCandidate[
    geometry, "XX", pscXXSearchBudget, centerParameters];
  centerHigh = pscFindCandidate[
    geometry, "XX", pscXXVerifyBudget, centerParameters];
  candidateLow = pscFindCandidate[
    geometry, "XX", pscXXSearchBudget, candidateParameters];
  candidateHigh = pscFindCandidate[
    geometry, "XX", pscXXVerifyBudget, candidateParameters];
  If[! And @@ (AssociationQ /@
      {centerLow, centerHigh, candidateLow, candidateHigh}),
    Return[<|
      "geometry" -> geometry, "status" -> "missing evaluations",
      "accepted" -> False|>, Module]];

  deltaLow = candidateLow["correctionRy"] - centerLow["correctionRy"];
  deltaHigh = candidateHigh["correctionRy"] - centerHigh["correctionRy"];
  disagreement = Abs[deltaHigh - deltaLow];
  threshold = Max[pscMinimumImprovementRy, disagreement];
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
    "geometry" -> geometry,
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

pscRunXXVerification[] := Module[{requests},
  If[! And @@ (AssociationQ[pscXXInitialBestRow[#]] & /@ pscGeometries),
    Print["Run pscRunXXInitial[] before first verification."];
    Return[$Failed, Module]];
  requests = Flatten@Table[
    With[{best = pscXXInitialBestRow[geometry]},
      (<|"geometry" -> geometry, "parameters" -> #|> &) /@
        DeleteDuplicates[{
          pscStartXXParameters[geometry], best["parameters"]}]],
    {geometry, pscGeometries}];
  pscRunCandidates[
    "XX-first-verification", "XX", requests, pscXXVerifyBudget];
  Association@Table[
    pscGeometryKey[geometry] -> pscXXFirstDecision[geometry],
    {geometry, pscGeometries}]];

pscXXFirstDecision[geometry : {_?NumericQ, _?NumericQ}] := Module[
  {best = pscXXInitialBestRow[geometry]},
  If[! AssociationQ[best],
    <|
      "geometry" -> geometry, "status" -> "initial stencil incomplete",
      "accepted" -> False|>,
    pscCompareBudgets[
      geometry, pscStartXXParameters[geometry], best["parameters"]]]];

pscXXAcceptedCenter[geometry : {_?NumericQ, _?NumericQ}] := Module[
  {decision = pscXXFirstDecision[geometry]},
  If[TrueQ[Lookup[decision, "accepted", False]],
    decision["candidateParameters"], pscStartXXParameters[geometry]]];

pscXXAxisScores[geometry : {_?NumericQ, _?NumericQ}] := Module[
  {center, steps, centerRow, rows, score},
  center = pscStartXXParameters[geometry];
  If[! pscParametersCompleteQ[
      geometry, "XX", pscXXSearchBudget,
      pscXXInitialParameters[geometry]],
    Return[{}, Module]];
  steps = pscXXSteps[geometry, center];
  centerRow = pscFindCandidate[
    geometry, "XX", pscXXSearchBudget, center];
  Table[
    rows = pscParameterRows[
      geometry, "XX", pscXXSearchBudget,
      {
        pscShiftParameter[center, axis, -steps[[axis]]],
        pscShiftParameter[center, axis, steps[[axis]]]}];
    score = Min[Lookup[rows, "correctionRy"]] - centerRow["correctionRy"];
    <|"axis" -> axis, "scoreRy" -> score|>,
    {axis, 4}]];

pscXXRefinementAxes[geometry : {_?NumericQ, _?NumericQ}] :=
  Lookup[
    Take[
      SortBy[
        pscXXAxisScores[geometry], Lookup[#, "scoreRy", Infinity] &],
      UpTo[pscRefinementDirectionCount]],
    "axis"];

pscXXRefinementParameters[geometry : {_?NumericQ, _?NumericQ}] := Module[
  {center, halfSteps, axes},
  If[Lookup[pscXXFirstDecision[geometry], "status", ""] =!= "complete",
    Return[{}, Module]];
  center = pscXXAcceptedCenter[geometry];
  halfSteps =
    pscXXSteps[geometry, pscStartXXParameters[geometry]]/2;
  axes = pscXXRefinementAxes[geometry];
  If[axes === {}, Return[{}, Module]];
  DeleteDuplicates@Flatten[
    Table[{
      pscShiftParameter[center, axis, -halfSteps[[axis]]],
      pscShiftParameter[center, axis, halfSteps[[axis]]]},
      {axis, axes}],
    1]];

pscRunXXRefinement[] := Module[{requests},
  requests = Flatten[
    Table[
      <|"geometry" -> geometry, "parameters" -> parameters|>,
      {geometry, pscGeometries},
      {parameters, pscXXRefinementParameters[geometry]}],
    1];
  If[requests === {},
    Print["Run pscRunXXVerification[] before refinement."];
    Return[$Failed, Module]];
  pscRunCandidates[
    "XX-directional-refinement", "XX", requests, pscXXSearchBudget]];

pscXXRefinementBestRow[geometry : {_?NumericQ, _?NumericQ}] := Module[
  {center, parameters, rows},
  center = pscXXAcceptedCenter[geometry];
  parameters = DeleteDuplicates@Join[
    {center}, pscXXRefinementParameters[geometry]];
  If[parameters === {center},
    Return[
      pscFindCandidate[geometry, "XX", pscXXSearchBudget, center], Module]];
  If[! pscParametersCompleteQ[
      geometry, "XX", pscXXSearchBudget, parameters],
    Return[Missing["RefinementIncomplete"], Module]];
  rows = pscParameterRows[
    geometry, "XX", pscXXSearchBudget, parameters];
  First@MinimalBy[rows, Lookup[#, "correctionRy", Infinity] &]];

pscRunXXFinalVerification[] := Module[{requests},
  If[! And @@ (AssociationQ[pscXXRefinementBestRow[#]] & /@ pscGeometries),
    Print["Run pscRunXXRefinement[] before final verification."];
    Return[$Failed, Module]];
  requests = Flatten@Table[
    With[
      {center = pscXXAcceptedCenter[geometry],
       best = pscXXRefinementBestRow[geometry]},
      (<|"geometry" -> geometry, "parameters" -> #|> &) /@
        DeleteDuplicates[{center, best["parameters"]}]],
    {geometry, pscGeometries}];
  pscRunCandidates[
    "XX-final-verification", "XX", requests, pscXXVerifyBudget];
  Association@Table[
    pscGeometryKey[geometry] -> pscXXFinalDecision[geometry],
    {geometry, pscGeometries}]];

pscXXFinalDecision[geometry : {_?NumericQ, _?NumericQ}] := Module[
  {center = pscXXAcceptedCenter[geometry],
   best = pscXXRefinementBestRow[geometry]},
  If[! AssociationQ[best],
    <|
      "geometry" -> geometry, "status" -> "refinement incomplete",
      "accepted" -> False|>,
    pscCompareBudgets[geometry, center, best["parameters"]]]];

pscFinalXXParameters[geometry : {_?NumericQ, _?NumericQ}] := Module[
  {center = pscXXAcceptedCenter[geometry],
   decision = pscXXFinalDecision[geometry]},
  If[TrueQ[Lookup[decision, "accepted", False]],
    decision["candidateParameters"], center]];

(* ---- reporting ---------------------------------------------------------- *)

pscGeometryConfiguration[geometry : {_?NumericQ, _?NumericQ}] := <|
  "geometry" -> geometry,
  "XStartAlpha" -> pscStartXAlpha[geometry],
  "XStep" -> pscXStep[geometry],
  "XInitialParameters" -> pscXInitialParameters[geometry],
  "XXStartParameters" -> pscStartXXParameters[geometry],
  "XXSteps" ->
    pscXXSteps[geometry, pscStartXXParameters[geometry]],
  "XXInitialParameters" -> pscXXInitialParameters[geometry]|>;

pscConfiguration[] := Join[
  pscConfigurationSignature,
  <|
    "geometryConfigurations" ->
      Association@Table[
        pscGeometryKey[geometry] -> pscGeometryConfiguration[geometry],
        {geometry, pscGeometries}],
    "XKinetic" -> "analytic alpha^2 (1 + m_e/m_h)",
    "angularTreatment" ->
      "phi_a=0; all remaining relative angles cover [0,2 Pi]",
    "sampling" ->
      "independent adaptive QMC calls for numerator and denominator"|>];

pscGeometrySummary[geometry : {_?NumericQ, _?NumericQ}] := Module[
  {xBest, firstDecision, finalDecision, finalParameters, finalRow,
   xError, xxError, binding, bindingError, geometryRows},
  xBest = Quiet[Check[pscBestXRow[geometry], Missing[]]];
  firstDecision = Quiet[Check[pscXXFirstDecision[geometry], <||>]];
  finalDecision = Quiet[Check[pscXXFinalDecision[geometry], <||>]];
  finalParameters = Quiet[Check[pscFinalXXParameters[geometry], Missing[]]];
  finalRow = If[ListQ[finalParameters],
    pscFindCandidate[
      geometry, "XX", pscXXVerifyBudget, finalParameters], Missing[]];
  xError = If[AssociationQ[xBest],
    Lookup[xBest, "roughCorrectionErrorRy", Missing[]], Missing[]];
  xxError = If[AssociationQ[finalRow],
    Lookup[finalRow, "roughCorrectionErrorRy", Missing[]], Missing[]];
  binding = If[AssociationQ[xBest] && AssociationQ[finalRow],
    2 xBest["totalRy"] - finalRow["totalRy"], Missing[]];
  bindingError = If[NumericQ[xError] && NumericQ[xxError],
    Sqrt[(2 xError)^2 + xxError^2], Missing[]];
  geometryRows = Select[
    pscCandidateRows, Lookup[#, "geometryKey", ""] ===
      pscGeometryKey[geometry] &];

  <|
    "a" -> geometry[[1]],
    "c" -> geometry[[2]],
    "XBestAlpha" ->
      If[AssociationQ[xBest], xBest["parameters"][[1]], Missing[]],
    "XCorrectionRy" ->
      If[AssociationQ[xBest], xBest["correctionRy"], Missing[]],
    "XRoughErrorRy" -> xError,
    "XTotalRy" -> If[AssociationQ[xBest], xBest["totalRy"], Missing[]],
    "XXFinalParameters" -> finalParameters,
    "XXCorrectionRy" ->
      If[AssociationQ[finalRow], finalRow["correctionRy"], Missing[]],
    "XXRoughErrorRy" -> xxError,
    "XXTotalRy" ->
      If[AssociationQ[finalRow], finalRow["totalRy"], Missing[]],
    "bindingRy" -> binding,
    "bindingRoughErrorRy" -> bindingError,
    "firstMoveAccepted" ->
      Lookup[firstDecision, "accepted", Missing[]],
    "finalMoveAccepted" ->
      Lookup[finalDecision, "accepted", Missing[]],
    "candidateCount" -> Length[geometryRows],
    "totalIntegralHours" ->
      Total[Lookup[geometryRows, "elapsedSeconds", 0.]]/3600.|>];

pscSummary[] := Dataset[pscGeometrySummary /@ pscGeometries];

pscCandidateTable[] := Dataset[
  KeyDrop[#, "integrals"] & /@ pscCandidateRows];

pscDecisionTable[] := Dataset@Table[
  <|
    "geometry" -> geometry,
    "firstDecision" -> pscXXFirstDecision[geometry],
    "finalDecision" -> pscXXFinalDecision[geometry]|>,
  {geometry, pscGeometries}];

pscXPlot[] := Module[{plots},
  plots = Table[
    With[{rows = Select[
       pscCandidateRows,
       Lookup[#, "geometryKey", ""] === pscGeometryKey[geometry] &&
         Lookup[#, "system", ""] === "X" &&
         Lookup[#, "budget", Missing[]] === pscXBudget &&
         pscCandidateCompleteQ[#] &]},
      If[rows === {},
        Graphics[Text["No X evaluations for " <>
          ToString[geometry, InputForm]]],
        ListPlot[
          SortBy[
            ({#1["parameters"][[1]], #1["correctionRy"]} &) /@ rows,
            First],
          Joined -> True, Mesh -> All, Frame -> True,
          FrameLabel -> {"alpha_X", "X correction (Ry)"},
          PlotLabel -> "(a,c) = " <> ToString[geometry, InputForm],
          PlotRange -> All, ImageSize -> 300]]],
    {geometry, pscGeometries}];
  GraphicsGrid[Partition[plots, 2], ImageSize -> 700]];

If[$KernelID === 0,
  Print[
    "Remaining-geometry raw pattern-search campaign loaded for ",
    Length[pscGeometries], " geometries. Reusable candidates: ",
    Length[pscCandidateRows],
    ". Review pscConfiguration[], then run pscPrepareKernels[]."]];

