(* ============================================================================
   Timed fixed-parameter convergence trial for the main states at (a,c)=(5,1).

   This file is intentionally isolated from the production campaign:
     - it imports the already stored X and XX optimum parameters;
     - it does not call either minimizer;
     - all integration controls are localized with Block;
     - it writes only main-state-convergence-trial-a5-c1-* files.

   Evaluate through Main-State-Convergence-Trial-a5-c1.nb.
   ============================================================================ *)

trialDirectory = DirectoryName[$InputFileName];
trialRoot = ParentDirectory[trialDirectory, 3];
trialExcitonDirectory =
  FileNameJoin[{ParentDirectory[trialDirectory, 2], "exciton", "01-numerics"}];

Get[FileNameJoin[{trialRoot, "shared", "numerics", "definitions.wl"}]];
Get[FileNameJoin[{trialExcitonDirectory, "mixed-correlation.wl"}]];
Get[FileNameJoin[{trialExcitonDirectory, "mixed-density.wl"}]];
Get[FileNameJoin[{trialExcitonDirectory, "mixed-integrals.wl"}]];
Get[FileNameJoin[{trialDirectory, "mixed-correlation.wl"}]];
Get[FileNameJoin[{trialDirectory, "mixed-density.wl"}]];
Get[FileNameJoin[{trialDirectory, "mixed-integrals.wl"}]];

ClearAll[
  trialKey, trialLog, trialParseMaxPointsMessage, trialTimed,
  trialWithTimedExcitonIntegrals, trialWithTimedBiexcitonIntegrals,
  trialDiagnosticMax, trialCheckpoint, trialExportCSV, trialRunBudget];

trialA = 5.;
trialC = 1.;
trialBudgets = {10^6, 2*10^6, 5*10^6};
(* A deliberately demanding diagnostic goal makes MaxPoints, rather than early
   termination, determine each convergence-sweep sample size. *)
trialPrecisionGoal = 4;
trialGroundState = {1, 0, 0};

trialResultFile =
  FileNameJoin[{trialDirectory, "main-state-production-results.wxf"}];
trialOutputFile =
  FileNameJoin[{trialDirectory, "main-state-convergence-trial-a5-c1-results.wxf"}];
trialIntegralCSV =
  FileNameJoin[{trialDirectory, "main-state-convergence-trial-a5-c1-integrals.csv"}];
trialSummaryCSV =
  FileNameJoin[{trialDirectory, "main-state-convergence-trial-a5-c1-summary.csv"}];
trialLogFile =
  FileNameJoin[{trialDirectory, "main-state-convergence-trial-a5-c1.log"}];

trialKey[aa_?NumericQ, cc_?NumericQ] :=
  StringRiffle[ToString[#, InputForm] & /@ N[{aa, cc}], "|"];

trialStore = Import[trialResultFile, "WXF"];
trialSavedRun =
  Lookup[Lookup[trialStore, "runs", <||>], trialKey[trialA, trialC],
    Missing["GeometryNotFound"]];

If[! AssociationQ[trialSavedRun] ||
   ! AssociationQ[Lookup[trialSavedRun, "X", Missing[]]] ||
   ! AssociationQ[Lookup[trialSavedRun, "XX", Missing[]]],
  Print["No complete stored X/XX production result exists for ",
    {trialA, trialC}, " in ", trialResultFile];
  Abort[]];

trialSavedX = trialSavedRun["X"];
trialSavedXX = trialSavedRun["XX"];
trialAlpha = trialSavedX["alpha"];
trialXXParameters = trialSavedXX["params"];

If[! NumericQ[trialAlpha] ||
   ! MatchQ[trialXXParameters, {_?NumericQ, _?NumericQ, _?NumericQ, _?NumericQ}],
  Print["The stored optimum parameters are not numeric: ",
    <|"alpha" -> trialAlpha, "XXParameters" -> trialXXParameters|>];
  Abort[]];

(* Match the ground-state production configuration exactly. *)
exElectronState = trialGroundState;
exHoleState = trialGroundState;
bxElectronStates = {trialGroundState, trialGroundState};
bxHoleStates = {trialGroundState, trialGroundState};
bxEtaE = 1;
bxEtaH = 1;

trialIntegralRows = {};
trialBudgetResults = {};
trialCurrentBudget = Missing["NotRunning"];

If[FileExistsQ[trialLogFile], DeleteFile[trialLogFile]];

trialLog[text_String] := Module[{stream = OpenAppend[trialLogFile]},
  WriteString[stream, DateString["ISODateTime"], "  ", text, "\n"];
  Close[stream]];

(* Extract the two numerical fields printed by NIntegrate::maxp, when present.
   The raw message is retained as well, so a parser miss loses no information. *)
trialParseMaxPointsMessage[text_String] := Module[
  {matches, clean, numbers},
  matches = StringCases[text,
    RegularExpression[
      "NIntegrate obtained\\s+([^\\s]+)\\s+and\\s+([^\\s]+)\\s+for"] ->
      {"$1", "$2"}];
  If[matches === {}, Return[<||>]];
  clean[token_] :=
    StringReplace[token, RegularExpression["`[0-9.]*"] -> ""];
  numbers = Quiet[Check[ToExpression /@ (clean /@ First[matches]), $Failed]];
  If[MatchQ[numbers, {_?NumericQ, _?NumericQ}],
    <|"messageIntegralEstimate" -> numbers[[1]],
      "reportedErrorEstimate" -> numbers[[2]]|>,
    <||>]];

SetAttributes[trialTimed, HoldAll];
trialTimed[system_, stage_, label_, expression_] := Module[
  {systemValue = system, stageValue = stage, labelValue = label,
   messageFile, messageStream, timing, seconds, value, messageText,
   messageTags, parsed, errorEstimate, relativeErrorEstimate, hitMaxPoints,
   row},

  messageFile =
    FileNameJoin[{$TemporaryDirectory,
      "main-state-trial-message-" <> CreateUUID[] <> ".txt"}];
  messageStream = OpenWrite[messageFile, CharacterEncoding -> "UTF-8"];

  timing = CheckAbort[
    Block[{$Messages = {messageStream}, $MessageList = {}},
      With[{answer = AbsoluteTiming[expression]},
        messageTags = $MessageList;
        answer]],
    Close[messageStream];
    Quiet[DeleteFile[messageFile]];
    Abort[]];

  Close[messageStream];
  {seconds, value} = timing;
  messageText = Quiet[Check[Import[messageFile, "Text"], ""]];
  Quiet[DeleteFile[messageFile]];

  parsed = trialParseMaxPointsMessage[messageText];
  errorEstimate = Lookup[parsed, "reportedErrorEstimate", Missing["NotReported"]];
  relativeErrorEstimate =
    If[NumericQ[errorEstimate] && NumericQ[value] && value != 0,
      Abs[errorEstimate/value], Missing["NotAvailable"]];
  hitMaxPoints =
    StringContainsQ[messageText, "NIntegrate::maxp"] ||
      ! FreeQ[messageTags, NIntegrate::maxp];

  row = Join[
    <|"budget" -> trialCurrentBudget, "system" -> systemValue,
      "stage" -> stageValue, "integral" -> labelValue,
      "seconds" -> seconds, "value" -> value,
      "hitMaxPoints" -> hitMaxPoints,
      "relativeErrorEstimate" -> relativeErrorEstimate,
      "messageText" -> messageText|>,
    parsed];
  AppendTo[trialIntegralRows, row];

  Print[systemValue, " / ", stageValue, " / ", labelValue,
    ": ", NumberForm[seconds, {Infinity, 2}], " s",
    If[NumericQ[relativeErrorEstimate],
      "  (reported relative error " <>
        ToString[ScientificForm[relativeErrorEstimate, 3]] <> ")", ""]];
  trialLog[
    StringRiffle[
      ToString[#, InputForm] & /@
        {trialCurrentBudget, systemValue, stageValue, labelValue, seconds,
          value, hitMaxPoints, relativeErrorEstimate}, "\t"]];
  value];

SetAttributes[trialWithTimedExcitonIntegrals, HoldAll];
trialWithTimedExcitonIntegrals[stage_, labels_, expression_] := Module[
  {stageValue = stage, labelValues = labels, index = 0, value},
  value = Block[{
      exIntegrate =
        Function[{aa, cc, integrand},
          index++;
          trialTimed["X", stageValue,
            If[index <= Length[labelValues], labelValues[[index]],
              "unexpected-" <> ToString[index]],
            If[TrueQ[exImportanceSampling],
              exIntegrateIS[aa, cc, integrand],
              exIntegrateUniform[aa, cc, integrand]]]]},
    expression];
  If[index =!= Length[labelValues],
    Print["Warning: expected ", Length[labelValues],
      " exciton integrals in ", stageValue, " but evaluated ", index, "."]];
  value];

SetAttributes[trialWithTimedBiexcitonIntegrals, HoldAll];
trialWithTimedBiexcitonIntegrals[stage_, labels_, expression_] := Module[
  {stageValue = stage, labelValues = labels, index = 0, value},
  value = Block[{
      bxIntegrate =
        Function[{aa, cc, integrand},
          index++;
          trialTimed["XX", stageValue,
            If[index <= Length[labelValues], labelValues[[index]],
              "unexpected-" <> ToString[index]],
            If[TrueQ[bxImportanceSampling],
              bxIntegrateIS[aa, cc, integrand],
              bxIntegrateUniform[aa, cc, integrand]]]]},
    expression];
  If[index =!= Length[labelValues],
    Print["Warning: expected ", Length[labelValues],
      " biexciton integrals in ", stageValue, " but evaluated ", index, "."]];
  value];

(* Cases does not descend through nested Associations. Normalizing them first
   fixes the diagnosticMax=0 bug in the production notebook. *)
trialDiagnosticMax[check_Association] := Module[{tree, values},
  tree = check //. association_Association :> Normal[association];
  values = Join[
    Cases[tree, HoldPattern["relSpread" -> value_?NumericQ] :> value, Infinity],
    Cases[tree, HoldPattern["error" -> value_?NumericQ] :> value, Infinity]];
  Max[Prepend[values, 0.]]];

trialExportCSV[file_String, rows_List, columns_List] :=
  Export[file,
    Prepend[(Lookup[#, columns, Missing["NotAvailable"]] & /@ rows), columns],
    "CSV"];

trialCheckpoint[] := Module[{payload, integralColumns, summaryColumns},
  payload = <|
    "schemaVersion" -> 1,
    "updated" -> DateString["ISODateTime"],
    "geometry" -> <|"a" -> trialA, "c" -> trialC|>,
    "budgets" -> trialBudgets,
    "precisionGoal" -> trialPrecisionGoal,
    "sourceProductionResult" -> trialResultFile,
    "fixedParameters" ->
      <|"XAlpha" -> trialAlpha, "XXParameters" -> trialXXParameters|>,
    "budgetResults" -> trialBudgetResults,
    "integrals" -> trialIntegralRows|>;
  Export[trialOutputFile, payload, "WXF"];

  integralColumns = {"budget", "system", "stage", "integral", "seconds",
    "value", "hitMaxPoints", "messageIntegralEstimate",
    "reportedErrorEstimate", "relativeErrorEstimate", "messageText"};
  trialExportCSV[trialIntegralCSV, trialIntegralRows, integralColumns];

  summaryColumns = {"budget", "precisionGoal", "XCorrectionRy",
    "XXCorrectionRy", "bindingRy", "XTotalRy", "XXTotalRy",
    "XDiagnosticMax", "XXDiagnosticMax", "integralCount",
    "maxPointsWarningCount", "elapsedSeconds"};
  trialExportCSV[trialSummaryCSV, trialBudgetResults, summaryColumns]];

trialRunBudget[budget_Integer] := Module[
  {started, firstRow, xCorrection, xxCorrection, xCheck, xxCheck,
   xSingleParticle, xxSingleParticle, xTotal, xxTotal, binding,
   rowsThisBudget, elapsed, result},

  trialCurrentBudget = budget;
  started = AbsoluteTime[];
  firstRow = Length[trialIntegralRows] + 1;
  Print["\n=== Timed fixed-parameter trial at (a,c) = ",
    {trialA, trialC}, ", MaxPoints = ", budget, " ==="];
  trialLog["START budget=" <> ToString[budget, InputForm]];

  Block[{
    exMaxPoints = budget, bxMaxPoints = budget,
    exPrecisionGoal = trialPrecisionGoal,
    bxPrecisionGoal = trialPrecisionGoal,
    exAccuracyGoal = Infinity, bxAccuracyGoal = Infinity},

    xCorrection =
      trialWithTimedExcitonIntegrals[
        "energy",
        {"norm", "interaction"},
        energyCorrectionExciton[trialA, trialC, trialAlpha]];

    xCheck =
      trialWithTimedExcitonIntegrals[
        "diagnostic",
        {"normAlpha0", "normConfig", "interactionConfig",
          "normSwapped", "interactionSwapped"},
        exQuadratureCheck[trialA, trialC, trialAlpha]];

    xxCorrection =
      trialWithTimedBiexcitonIntegrals[
        "energy",
        {"normDirect", "normCross", "interactionDirect", "interactionCross",
          "kineticElectronDirect", "kineticElectronCross",
          "kineticHoleDirect", "kineticHoleCross"},
        energyCorrectionBiexciton[trialA, trialC,
          Sequence @@ trialXXParameters]];

    xxCheck =
      trialWithTimedBiexcitonIntegrals[
        "diagnostic",
        {"normP", "normQ", "interactionFullP", "interactionFullQ",
          "interactionReduced", "crossAttractionR1a", "crossAttractionR1b",
          "kineticElectronP", "kineticElectronQ",
          "kineticHoleP", "kineticHoleQ"},
        bxQuadratureCheckAll[trialA, trialC,
          Sequence @@ trialXXParameters]];
    ];

  xSingleParticle =
    Ee[trialA, trialC, 0] @@ trialGroundState +
      Eh[trialA, trialC, 0] @@ trialGroundState;
  xxSingleParticle = 2 xSingleParticle;
  xTotal = xSingleParticle + xCorrection;
  xxTotal = xxSingleParticle + xxCorrection;
  binding = 2 xTotal - xxTotal;
  rowsThisBudget = trialIntegralRows[[firstRow ;;]];
  elapsed = AbsoluteTime[] - started;

  result = <|
    "budget" -> budget,
    "precisionGoal" -> trialPrecisionGoal,
    "XCorrectionRy" -> xCorrection,
    "XXCorrectionRy" -> xxCorrection,
    "bindingRy" -> binding,
    "XTotalRy" -> xTotal,
    "XXTotalRy" -> xxTotal,
    "XDiagnosticMax" -> trialDiagnosticMax[xCheck],
    "XXDiagnosticMax" -> trialDiagnosticMax[xxCheck],
    "integralCount" -> Length[rowsThisBudget],
    "maxPointsWarningCount" ->
      Count[Lookup[rowsThisBudget, "hitMaxPoints"], True],
    "elapsedSeconds" -> elapsed|>;

  AppendTo[trialBudgetResults, result];
  trialCheckpoint[];
  trialLog["DONE budget=" <> ToString[budget, InputForm] <>
    " elapsedSeconds=" <> ToString[elapsed, InputForm]];
  Print[Dataset[{result}]];
  result];

trialLog["TRIAL START geometry=" <> ToString[{trialA, trialC}, InputForm] <>
  " alpha=" <> ToString[trialAlpha, InputForm] <>
  " XXParameters=" <> ToString[trialXXParameters, InputForm]];

Scan[trialRunBudget, trialBudgets];

trialCheckpoint[];
trialLog["TRIAL COMPLETE"];

Dataset[trialBudgetResults]
