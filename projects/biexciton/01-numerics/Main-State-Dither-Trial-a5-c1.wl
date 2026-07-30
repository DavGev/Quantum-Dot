(* ============================================================================
   Dithered symmetry-diagnostic trial for the main biexciton at (a,c)=(5,1).

   Purpose:
     Determine whether the persistent symmetry-identity discrepancies seen with
     "BisectionDithering" -> 0 are caused by deterministic midpoint
     stratification. The production optimum is held fixed.

   Scope:
     - AdaptiveQuasiMonteCarlo, BisectionDithering -> 0.1
     - 1,000,000 points, PrecisionGoal -> 4, AccuracyGoal -> Infinity
     - three reproducible RandomSeed values
     - seven selected XX diagnostic integrals only
     - no minimization and no production-file writes

   Evaluate through Main-State-Dither-Trial-a5-c1.nb.
   ============================================================================ *)

ditherTrialDirectory = DirectoryName[$InputFileName];
ditherTrialRoot = ParentDirectory[ditherTrialDirectory, 3];
ditherTrialExcitonDirectory =
  FileNameJoin[{
    ParentDirectory[ditherTrialDirectory, 2], "exciton", "01-numerics"}];

Get[FileNameJoin[{
  ditherTrialRoot, "shared", "numerics", "definitions.wl"}]];
(* The biexciton correlation/density files depend on definitions from the
   exciton framework in the same order used by the production notebook. *)
Get[FileNameJoin[{
  ditherTrialExcitonDirectory, "mixed-correlation.wl"}]];
Get[FileNameJoin[{
  ditherTrialExcitonDirectory, "mixed-density.wl"}]];
Get[FileNameJoin[{
  ditherTrialExcitonDirectory, "mixed-integrals.wl"}]];
Get[FileNameJoin[{ditherTrialDirectory, "mixed-correlation.wl"}]];
Get[FileNameJoin[{ditherTrialDirectory, "mixed-density.wl"}]];
Get[FileNameJoin[{ditherTrialDirectory, "mixed-integrals.wl"}]];

ClearAll[
  ditherTrialKey, ditherTrialLog, ditherTrialTimed,
  ditherTrialIntegrateIS, ditherTrialSpread, ditherTrialSelectedCheck,
  ditherTrialExportCSV, ditherTrialCheckpoint, ditherTrialRunSeed];

ditherTrialA = 5.;
ditherTrialC = 1.;
ditherTrialMaxPoints = 10^6;
ditherTrialPrecisionGoal = 4;
ditherTrialAccuracyGoal = Infinity;
ditherTrialBisectionDithering = 0.1;
ditherTrialSeeds = {104729, 130363, 155921};
ditherTrialGroundState = {1, 0, 0};

ditherTrialProductionFile =
  FileNameJoin[{
    ditherTrialDirectory, "main-state-production-results.wxf"}];
ditherTrialOutputFile =
  FileNameJoin[{
    ditherTrialDirectory, "main-state-dither-trial-a5-c1-results.wxf"}];
ditherTrialIntegralCSV =
  FileNameJoin[{
    ditherTrialDirectory, "main-state-dither-trial-a5-c1-integrals.csv"}];
ditherTrialSummaryCSV =
  FileNameJoin[{
    ditherTrialDirectory, "main-state-dither-trial-a5-c1-summary.csv"}];
ditherTrialAggregateCSV =
  FileNameJoin[{
    ditherTrialDirectory, "main-state-dither-trial-a5-c1-aggregate.csv"}];
ditherTrialLogFile =
  FileNameJoin[{
    ditherTrialDirectory, "main-state-dither-trial-a5-c1.log"}];

ditherTrialKey[aa_?NumericQ, cc_?NumericQ] :=
  StringRiffle[ToString[#, InputForm] & /@ N[{aa, cc}], "|"];

ditherTrialStore = Import[ditherTrialProductionFile, "WXF"];
ditherTrialSavedRun =
  Lookup[
    Lookup[ditherTrialStore, "runs", <||>],
    ditherTrialKey[ditherTrialA, ditherTrialC],
    Missing["GeometryNotFound"]];

If[
  ! AssociationQ[ditherTrialSavedRun] ||
    ! AssociationQ[Lookup[ditherTrialSavedRun, "XX", Missing[]]],
  Print[
    "No stored main-biexciton production result exists for ",
    {ditherTrialA, ditherTrialC}, " in ", ditherTrialProductionFile];
  Abort[]];

ditherTrialXXParameters = ditherTrialSavedRun["XX"]["params"];
If[
  ! MatchQ[
    ditherTrialXXParameters,
    {_?NumericQ, _?NumericQ, _?NumericQ, _?NumericQ}],
  Print[
    "The stored biexciton parameters are not numeric: ",
    ditherTrialXXParameters];
  Abort[]];

(* Match the main-state production configuration. *)
bxElectronStates = {ditherTrialGroundState, ditherTrialGroundState};
bxHoleStates = {ditherTrialGroundState, ditherTrialGroundState};
bxEtaE = 1;
bxEtaH = 1;

ditherTrialIntegralRows = {};
ditherTrialSeedResults = {};
ditherTrialAggregateRows = {};
ditherTrialCurrentSeed = Missing["NotRunning"];

If[FileExistsQ[ditherTrialLogFile], DeleteFile[ditherTrialLogFile]];

ditherTrialLog[text_String] := Module[
  {stream = OpenAppend[ditherTrialLogFile]},
  WriteString[stream, DateString["ISODateTime"], "  ", text, "\n"];
  Close[stream]];

SetAttributes[ditherTrialTimed, HoldAll];
ditherTrialTimed[label_, expression_] := Module[
  {labelValue = label, messageFile, messageStream, timing, seconds, value,
   messageText, messageTags, hitMaxPoints, row},

  messageFile =
    FileNameJoin[{
      $TemporaryDirectory,
      "main-state-dither-message-" <> CreateUUID[] <> ".txt"}];
  messageStream =
    OpenWrite[messageFile, CharacterEncoding -> "UTF-8"];

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

  hitMaxPoints =
    StringContainsQ[messageText, "NIntegrate::maxp"] ||
      ! FreeQ[messageTags, NIntegrate::maxp];

  row = <|
    "seed" -> ditherTrialCurrentSeed,
    "integral" -> labelValue,
    "seconds" -> seconds,
    "value" -> value,
    "hitMaxPoints" -> hitMaxPoints,
    "messageText" -> messageText|>;
  AppendTo[ditherTrialIntegralRows, row];

  Print[
    "seed ", ditherTrialCurrentSeed, " / ", labelValue, ": ",
    NumberForm[seconds, {Infinity, 2}], " s"];
  ditherTrialLog[
    StringRiffle[
      ToString[#, InputForm] & /@
        {ditherTrialCurrentSeed, labelValue, seconds, value, hitMaxPoints},
      "\t"]];
  value];

(* This is the production importance-sampling transformation with only the
   adaptive-stratification controls changed. The same seed is deliberately
   reused for all seven integrals within one replicate (common random numbers);
   the three replicates use independent seeds. *)
ditherTrialIntegrateIS[
   aa_?NumericQ, cc_?NumericQ, integrand_, seed_Integer] :=
  With[
    {\[Omega] = \[HBar]\[Omega]00[aa, cc], rmax = aa bxRmax},
    With[
      {me = bxStateMaps[\[Omega], rmax, bxElectronStates],
       mh = bxStateMaps[\[Omega], rmax, bxHoleStates]},
      NIntegrate[
        Module[
          {r1 = me["rFromV"][v1], r2 = me["rFromV"][v2],
           ra = mh["rFromV"][va], rb = mh["rFromV"][vb],
           u1 = me["uFromX"][x1], u2 = me["uFromX"][x2],
           ua = mh["uFromX"][xa], ub = mh["uFromX"][xb]},
          integrand[
            r1, u1, r2, u2, ra, ua, rb, ub,
            \[Theta]1, \[Theta]2, \[Theta]b] *
            me["rJac"][r1] me["rJac"][r2] *
            mh["rJac"][ra] mh["rJac"][rb] *
            me["uJac"][u1] me["uJac"][u2] *
            mh["uJac"][ua] mh["uJac"][ub]],
        {v1, 0, 1}, {x1, 0, 1}, {v2, 0, 1}, {x2, 0, 1},
        {va, 0, 1}, {xa, 0, 1}, {vb, 0, 1}, {xb, 0, 1},
        {\[Theta]1, 0, 2 \[Pi]}, {\[Theta]2, 0, 2 \[Pi]},
        {\[Theta]b, 0, \[Pi]},
        Method -> {
          "AdaptiveQuasiMonteCarlo",
          "BisectionDithering" -> ditherTrialBisectionDithering,
          "RandomSeed" -> seed,
          "MaxPoints" -> ditherTrialMaxPoints},
        AccuracyGoal -> ditherTrialAccuracyGoal,
        PrecisionGoal -> ditherTrialPrecisionGoal,
        WorkingPrecision -> MachinePrecision]]];

ditherTrialSpread[x_?NumericQ, y_?NumericQ] :=
  2 Abs[x - y]/Abs[x + y];

ditherTrialSelectedCheck[seed_Integer] := Module[
  {\[Alpha], \[Beta], \[Gamma], \[Delta], \[Omega],
   intD, intX, one, vFull, vReduced, attractionR1a, attractionR1b,
   nP, nQ, vP, vQ, vR, xA, xB},

  {\[Alpha], \[Beta], \[Gamma], \[Delta]} = ditherTrialXXParameters;
  \[Omega] = \[HBar]\[Omega]00[ditherTrialA, ditherTrialC];

  intD[label_String, extra_, aa_?NumericQ, bb_?NumericQ] :=
    ditherTrialTimed[
      label,
      ditherTrialIntegrateIS[
        ditherTrialA, ditherTrialC,
        Function[
          {r1, u1, r2, u2, ra, ua, rb, ub,
           \[Theta]1, \[Theta]2, \[Theta]b},
          With[
            {g = Gcorr[ditherTrialA, ditherTrialC][
                u1, r1, u2, r2, ua, ra, ub, rb,
                \[Theta]1, \[Theta]2, \[Theta]b, \[Gamma], \[Delta]],
             p = Pcorr[ditherTrialA, ditherTrialC][
                u1, r1, u2, r2, ua, ra, ub, rb,
                \[Theta]1, \[Theta]2, \[Theta]b, aa, bb]},
            bxWeight[ditherTrialA, ditherTrialC, \[Omega]][
              u1, r1, \[Theta]1, u2, r2, \[Theta]2,
              ua, ra, ub, rb, \[Theta]b] *
              g^2 p^2 *
              extra[
                r1, u1, r2, u2, ra, ua, rb, ub,
                \[Theta]1, \[Theta]2, \[Theta]b, aa, bb]]],
        seed]];

  intX[label_String, extra_] :=
    ditherTrialTimed[
      label,
      ditherTrialIntegrateIS[
        ditherTrialA, ditherTrialC,
        Function[
          {r1, u1, r2, u2, ra, ua, rb, ub,
           \[Theta]1, \[Theta]2, \[Theta]b},
          With[
            {g = Gcorr[ditherTrialA, ditherTrialC][
                u1, r1, u2, r2, ua, ra, ub, rb,
                \[Theta]1, \[Theta]2, \[Theta]b, \[Gamma], \[Delta]],
             p = Pcorr[ditherTrialA, ditherTrialC][
                u1, r1, u2, r2, ua, ra, ub, rb,
                \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]],
             q = Qcorr[ditherTrialA, ditherTrialC][
                u1, r1, u2, r2, ua, ra, ub, rb,
                \[Theta]1, \[Theta]2, \[Theta]b, \[Alpha], \[Beta]]},
            bxWeight[ditherTrialA, ditherTrialC, \[Omega]][
              u1, r1, \[Theta]1, u2, r2, \[Theta]2,
              ua, ra, ub, rb, \[Theta]b] *
              g^2 p q *
              extra[
                r1, u1, r2, u2, ra, ua, rb, ub,
                \[Theta]1, \[Theta]2, \[Theta]b]]],
        seed]];

  one =
    Function[
      {r1, u1, r2, u2, ra, ua, rb, ub,
       \[Theta]1, \[Theta]2, \[Theta]b, aa, bb},
      1];

  vFull =
    Function[
      {r1, u1, r2, u2, ra, ua, rb, ub,
       \[Theta]1, \[Theta]2, \[Theta]b, aa, bb},
      2 (
        1/rPair[ditherTrialA, ditherTrialC][
          u1, r1, \[Theta]1, u2, r2, \[Theta]2] +
        1/rPair[ditherTrialA, ditherTrialC][
          ua, ra, 0, ub, rb, \[Theta]b]) -
      2 (
        1/rPair[ditherTrialA, ditherTrialC][
          u1, r1, \[Theta]1, ua, ra, 0] +
        1/rPair[ditherTrialA, ditherTrialC][
          u1, r1, \[Theta]1, ub, rb, \[Theta]b] +
        1/rPair[ditherTrialA, ditherTrialC][
          u2, r2, \[Theta]2, ua, ra, 0] +
        1/rPair[ditherTrialA, ditherTrialC][
          u2, r2, \[Theta]2, ub, rb, \[Theta]b])];

  vReduced =
    Function[
      {r1, u1, r2, u2, ra, ua, rb, ub,
       \[Theta]1, \[Theta]2, \[Theta]b, aa, bb},
      2 (
        1/rPair[ditherTrialA, ditherTrialC][
          u1, r1, \[Theta]1, u2, r2, \[Theta]2] +
        1/rPair[ditherTrialA, ditherTrialC][
          ua, ra, 0, ub, rb, \[Theta]b]) -
      4 (
        1/rPair[ditherTrialA, ditherTrialC][
          u1, r1, \[Theta]1, ua, ra, 0] +
        1/rPair[ditherTrialA, ditherTrialC][
          u1, r1, \[Theta]1, ub, rb, \[Theta]b])];

  attractionR1a =
    Function[
      {r1, u1, r2, u2, ra, ua, rb, ub,
       \[Theta]1, \[Theta]2, \[Theta]b},
      1/rPair[ditherTrialA, ditherTrialC][
        u1, r1, \[Theta]1, ua, ra, 0]];

  attractionR1b =
    Function[
      {r1, u1, r2, u2, ra, ua, rb, ub,
       \[Theta]1, \[Theta]2, \[Theta]b},
      1/rPair[ditherTrialA, ditherTrialC][
        u1, r1, \[Theta]1, ub, rb, \[Theta]b]];

  nP = intD["normP", one, \[Alpha], \[Beta]];
  nQ = intD["normQ", one, \[Beta], \[Alpha]];
  vP = intD["interactionFullP", vFull, \[Alpha], \[Beta]];
  vQ = intD["interactionFullQ", vFull, \[Beta], \[Alpha]];
  vR = intD["interactionReduced", vReduced, \[Alpha], \[Beta]];
  xA = intX["crossAttractionR1a", attractionR1a];
  xB = intX["crossAttractionR1b", attractionR1b];

  <|
    "seed" -> seed,
    "values" -> <|
      "normP" -> nP, "normQ" -> nQ,
      "interactionFullP" -> vP, "interactionFullQ" -> vQ,
      "interactionReduced" -> vR,
      "crossAttractionR1a" -> xA, "crossAttractionR1b" -> xB|>,
    "normSpread" -> ditherTrialSpread[nP, nQ],
    "interactionPQSpread" -> ditherTrialSpread[vP, vQ],
    "interactionReductionSpread" -> ditherTrialSpread[vP, vR],
    "crossAttractionSpread" -> ditherTrialSpread[xA, xB]|>];

ditherTrialExportCSV[file_String, rows_List, columns_List] :=
  Export[
    file,
    Prepend[
      (Lookup[#, columns, Missing["NotAvailable"]] & /@ rows),
      columns],
    "CSV"];

ditherTrialCheckpoint[] := Module[
  {payload, integralColumns, summaryColumns, grouped, aggregateColumns},

  grouped =
    GroupBy[ditherTrialIntegralRows, Lookup[#, "integral"] &];
  ditherTrialAggregateRows =
    KeyValueMap[
      Function[
        {label, rows},
        <|
          "integral" -> label,
          "replicates" -> Length[rows],
          "meanValue" -> Mean[Lookup[rows, "value"]],
          "standardDeviation" ->
            If[Length[rows] >= 2,
              StandardDeviation[Lookup[rows, "value"]],
              Missing["NeedTwoSeeds"]],
          "meanSeconds" -> Mean[Lookup[rows, "seconds"]]|>],
      grouped];

  payload = <|
    "schemaVersion" -> 1,
    "updated" -> DateString["ISODateTime"],
    "geometry" -> <|"a" -> ditherTrialA, "c" -> ditherTrialC|>,
    "maxPoints" -> ditherTrialMaxPoints,
    "precisionGoal" -> ditherTrialPrecisionGoal,
    "accuracyGoal" -> ditherTrialAccuracyGoal,
    "bisectionDithering" -> ditherTrialBisectionDithering,
    "seeds" -> ditherTrialSeeds,
    "sourceProductionResult" -> ditherTrialProductionFile,
    "fixedXXParameters" -> ditherTrialXXParameters,
    "seedResults" -> ditherTrialSeedResults,
    "aggregateIntegrals" -> ditherTrialAggregateRows,
    "integrals" -> ditherTrialIntegralRows|>;
  Export[ditherTrialOutputFile, payload, "WXF"];

  integralColumns = {
    "seed", "integral", "seconds", "value",
    "hitMaxPoints", "messageText"};
  ditherTrialExportCSV[
    ditherTrialIntegralCSV, ditherTrialIntegralRows, integralColumns];

  summaryColumns = {
    "seed", "normSpread", "interactionPQSpread",
    "interactionReductionSpread", "crossAttractionSpread",
    "diagnosticMax", "elapsedSeconds"};
  ditherTrialExportCSV[
    ditherTrialSummaryCSV, ditherTrialSeedResults, summaryColumns];

  aggregateColumns = {
    "integral", "replicates", "meanValue",
    "standardDeviation", "meanSeconds"};
  ditherTrialExportCSV[
    ditherTrialAggregateCSV,
    ditherTrialAggregateRows,
    aggregateColumns]];

ditherTrialRunSeed[seed_Integer] := Module[
  {started, check, elapsed, diagnosticMax, result},

  ditherTrialCurrentSeed = seed;
  started = AbsoluteTime[];
  Print[
    "\n=== Dithered XX diagnostic at (a,c) = ",
    {ditherTrialA, ditherTrialC},
    ", seed = ", seed, " ==="];
  ditherTrialLog["START seed=" <> ToString[seed, InputForm]];

  check = ditherTrialSelectedCheck[seed];
  elapsed = AbsoluteTime[] - started;
  diagnosticMax =
    Max[{
      check["normSpread"],
      check["interactionPQSpread"],
      check["interactionReductionSpread"],
      check["crossAttractionSpread"]}];

  result = <|
    "seed" -> seed,
    "normSpread" -> check["normSpread"],
    "interactionPQSpread" -> check["interactionPQSpread"],
    "interactionReductionSpread" ->
      check["interactionReductionSpread"],
    "crossAttractionSpread" -> check["crossAttractionSpread"],
    "diagnosticMax" -> diagnosticMax,
    "elapsedSeconds" -> elapsed|>;
  AppendTo[ditherTrialSeedResults, result];
  ditherTrialCheckpoint[];
  ditherTrialLog[
    "DONE seed=" <> ToString[seed, InputForm] <>
      " elapsedSeconds=" <> ToString[elapsed, InputForm]];
  Print[Dataset[{result}]];
  result];

ditherTrialLog[
  "TRIAL START geometry=" <>
    ToString[{ditherTrialA, ditherTrialC}, InputForm] <>
  " maxPoints=" <> ToString[ditherTrialMaxPoints, InputForm] <>
  " dithering=" <>
    ToString[ditherTrialBisectionDithering, InputForm] <>
  " XXParameters=" <> ToString[ditherTrialXXParameters, InputForm]];

Scan[ditherTrialRunSeed, ditherTrialSeeds];

ditherTrialCheckpoint[];
ditherTrialLog["TRIAL COMPLETE"];

Dataset[ditherTrialSeedResults]
