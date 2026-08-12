(* ::Package:: *)

(*
  Authoritative data and plotting pipeline for the final main-state results.

  Energy data remain in effective Rydbergs throughout the canonical table and
  all energy figures. Conversion to eV is performed only inside the
  material-specific radiative-lifetime block. The final meV summary is loaded
  only for the requested conversion check and to preserve the already-finalized
  dimensionless optical-overlap block.
*)

ClearAll["Global`*"];

root = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
numDir = FileNameJoin[{root, "01-numerics"}];
figDir = FileNameJoin[{root, "03-figures"}];
paperDataDir = FileNameJoin[{root, "04-paper", "latex", "data"}];
paperFigDir = FileNameJoin[{root, "04-paper", "latex", "figures"}];
CreateDirectory[paperDataDir, CreateIntermediateDirectories -> True];
CreateDirectory[paperFigDir, CreateIntermediateDirectories -> True];

geometryOrder = {
  {5., 0.5}, {5., 1.}, {5., 1.5}, {5., 2.},
  {3., 1.}, {7., 1.}, {10., 1.}
};

headers = {
  "a/rB", "c/rB", "alpha_X", "alpha", "beta", "gamma", "delta",
  "E_X^0 (Ry)", "Delta E_X (Ry)", "Delta E_X error (Ry)",
  "E_X (Ry)", "E_X error (Ry)",
  "E_XX^0 (Ry)", "Delta E_XX (Ry)", "Delta E_XX error (Ry)",
  "E_XX (Ry)", "E_XX error (Ry)",
  "E_bind = 2 E_X - E_XX (Ry)", "E_bind error (Ry)",
  "N_X", "N_X error", "M_X", "M_X error", "|M_X|^2",
  "|M_X|^2 error"
};

ClearAll[importAssociations, asNumber, geometryOf, closeQ, parseParameters,
  firstValue, recoveredIntegralError, ratioError, selectedCandidate,
  integralRecord, assertTrue];

importAssociations[path_] := Module[{table = Import[path, "CSV"]},
  AssociationThread[First[table], #] & /@ Rest[table]
];

asNumber[value_] := Which[
  NumericQ[value], N[value],
  StringQ[value] && StringLength[StringTrim[value]] > 0,
    N[ToExpression[StringTrim[value]]],
  True, Missing["NotNumeric"]
];

geometryOf[row_Association] := {
  asNumber[If[KeyExistsQ[row, "a/rB"], row["a/rB"], row["a"]]],
  asNumber[If[KeyExistsQ[row, "c/rB"], row["c/rB"], row["c"]]]
};

closeQ[x_?NumericQ, y_?NumericQ, tolerance_: 2.*^-12] :=
  Abs[x - y] <= tolerance Max[1., Abs[x], Abs[y]];

parseParameters[value_List] := N[value];
parseParameters[value_String] := Module[{parsed = ToExpression[value]},
  If[! ListQ[parsed], Return[Missing["InvalidParameters"]]];
  N[parsed]
];

firstValue[row_Association, keys_List] := Module[{key},
  key = SelectFirst[keys,
    KeyExistsQ[row, #] && row[#] =!= "" && ! MissingQ[row[#]] &,
    Missing["AbsentKey"]
  ];
  If[MissingQ[key], key, row[key]]
];

recoveredIntegralError[row_Association] := Module[
  {direct, message, coefficient, exponent},
  direct = Lookup[row, "reportedErrorEstimate", ""];
  If[NumericQ[direct], Return[N[direct]]];
  If[StringQ[direct] && StringLength[StringTrim[direct]] > 0,
    Return[asNumber[direct]]
  ];
  message = ToString[Lookup[row, "messageText", ""]];
  coefficient = StringCases[
    message, RegularExpression["and\\s+([0-9.]+)\\s+10"] -> "$1"];
  exponent = StringCases[
    message, RegularExpression["(?m)^\\s*(-\\d+)\\s*$"] -> "$1"];
  If[coefficient === {} || exponent === {},
    Missing["ErrorEstimateNotRecovered"],
    asNumber[First[coefficient]] 10.^asNumber[First[exponent]]
  ]
];

ratioError[numerator_, numeratorError_, denominator_, denominatorError_] :=
  Abs[numerator/denominator] Sqrt[
    (numeratorError/numerator)^2 + (denominatorError/denominator)^2
  ];

selectedCandidate[candidates_List, geometry_List, system_String,
    parameters_List, correction_?NumericQ] := Module[{matches},
  matches = Select[candidates,
    Lookup[#, "system", ""] === system &&
    asNumber[Lookup[#, "budget", 0]] == 2000000 &&
    And @@ MapThread[closeQ, {geometryOf[#], geometry}] &&
    Length[parseParameters[Lookup[#, "parameters", "{}"]]] == Length[parameters] &&
    And @@ MapThread[closeQ,
      {parseParameters[Lookup[#, "parameters", "{}"]], parameters}] &&
    closeQ[asNumber[Lookup[#, "correctionRy", Indeterminate]], correction] &
  ];
  If[matches === {}, Missing["RetainedCandidateNotFound"], Last[matches]]
];

integralRecord[integrals_List, candidate_Association, label_String,
    expectedValue_?NumericQ] := Module[{matches},
  matches = Select[integrals,
    Lookup[#, "candidateKey", ""] === candidate["candidateKey"] &&
    Lookup[#, "integral", ""] === label &&
    closeQ[asNumber[Lookup[#, "value", Indeterminate]], expectedValue] &
  ];
  If[matches === {}, Missing["IntegralRecordNotFound"], Last[matches]]
];

assertTrue[condition_, message_String] := If[! TrueQ[condition],
  Print["VALIDATION FAILURE: " <> message]; Exit[1]
];

(* Import and normalize the two refined result schemas. *)
a5Summary = First@importAssociations[
  FileNameJoin[{numDir, "main-state-raw-pattern-search-a5-c1-summary.csv"}]];
remainingSummary = importAssociations[
  FileNameJoin[{numDir, "main-state-raw-pattern-search-remaining-summary.csv"}]];
productionRows = importAssociations[
  FileNameJoin[{numDir, "main-state-production-summary-Ry.csv"}]];
meVRows = importAssociations[
  FileNameJoin[{numDir, "main-state-final-summary-meV.csv"}]];

a5Candidates = Join[#, <|"a" -> 5., "c" -> 1.|>] & /@
  importAssociations[FileNameJoin[
    {numDir, "main-state-raw-pattern-search-a5-c1-candidates.csv"}]];
a5Integrals = Join[#, <|"a" -> 5., "c" -> 1.|>] & /@
  importAssociations[FileNameJoin[
    {numDir, "main-state-raw-pattern-search-a5-c1-integrals.csv"}]];
remainingCandidates = importAssociations[FileNameJoin[
  {numDir, "main-state-raw-pattern-search-remaining-candidates.csv"}]];
remainingIntegrals = importAssociations[FileNameJoin[
  {numDir, "main-state-raw-pattern-search-remaining-integrals.csv"}]];

summaryByGeometry = Association[
  ({ToString[#[[1]], InputForm], ToString[#[[2]], InputForm]} -> #3) & @@@
    Join[
      {{5., 1., <|"row" -> a5Summary, "sourceGroup" -> "a5"|>}},
      ({geometryOf[#][[1]], geometryOf[#][[2]],
          <|"row" -> #, "sourceGroup" -> "remaining"|>} & /@ remainingSummary)
    ]
];
productionByGeometry = Association[
  ({ToString[geometryOf[#][[1]], InputForm],
      ToString[geometryOf[#][[2]], InputForm]} -> #) & /@ productionRows];
meVByGeometry = Association[
  ({ToString[geometryOf[#][[1]], InputForm],
      ToString[geometryOf[#][[2]], InputForm]} -> #) & /@ meVRows];

geometryKey[{a_, c_}] := {ToString[N[a], InputForm], ToString[N[c], InputForm]};

finalRows = Table[
  Module[
    {summaryInfo, summary, sourceGroup, alphaX, xCorrection, xxParameters,
     xxCorrection, candidates, integrals, xCandidate, xxCandidate,
     xNorm, xNumerator, xxNorm, xxNumerator, xNormRecord, xNumRecord,
     xxNormRecord, xxNumRecord, xNormError, xError, xxError,
     production, optical, eX0, eXX0, eX, eXX, eBind, eBindError},

    summaryInfo = summaryByGeometry[geometryKey[geometry]];
    summary = summaryInfo["row"];
    sourceGroup = summaryInfo["sourceGroup"];
    alphaX = asNumber[summary["XBestAlpha"]];
    xCorrection = asNumber[firstValue[
      summary, {"XCorrectionRy", "XBestCorrectionRy"}]];
    xxParameters = parseParameters[summary["XXFinalParameters"]];
    assertTrue[Length[xxParameters] == 4,
      "XXFinalParameters is not {alpha,beta,gamma,delta} at " <> ToString[geometry]];
    xxCorrection = asNumber[firstValue[
      summary, {"XXCorrectionRy", "XXFinalCorrectionRy"}]];

    {candidates, integrals} = If[sourceGroup === "a5",
      {a5Candidates, a5Integrals},
      {remainingCandidates, remainingIntegrals}
    ];
    xCandidate = selectedCandidate[
      candidates, geometry, "X", {alphaX}, xCorrection];
    xxCandidate = selectedCandidate[
      candidates, geometry, "XX", xxParameters, xxCorrection];
    assertTrue[AssociationQ[xCandidate] && AssociationQ[xxCandidate],
      "retained candidate not found at " <> ToString[geometry]];

    xNorm = asNumber[xCandidate["norm"]];
    xNumerator = asNumber[xCandidate["numeratorRy"]];
    xxNorm = asNumber[xxCandidate["norm"]];
    xxNumerator = asNumber[xxCandidate["numeratorRy"]];
    xNormRecord = integralRecord[
      integrals, xCandidate, "normDenominator", xNorm];
    xNumRecord = integralRecord[
      integrals, xCandidate, "coulombNumerator", xNumerator];
    xxNormRecord = integralRecord[
      integrals, xxCandidate, "normDenominator", xxNorm];
    xxNumRecord = integralRecord[
      integrals, xxCandidate, "hamiltonianNumerator", xxNumerator];
    assertTrue[And @@ (AssociationQ /@
      {xNormRecord, xNumRecord, xxNormRecord, xxNumRecord}),
      "retained integral record not found at " <> ToString[geometry]];

    xNormError = recoveredIntegralError[xNormRecord];
    xError = ratioError[xNumerator, recoveredIntegralError[xNumRecord],
      xNorm, xNormError];
    xxError = ratioError[xxNumerator, recoveredIntegralError[xxNumRecord],
      xxNorm, recoveredIntegralError[xxNormRecord]];
    If[sourceGroup === "remaining",
      assertTrue[closeQ[xError, asNumber[summary["XRoughErrorRy"]], 5.*^-8],
        "X rough error mismatch at " <> ToString[geometry]];
      assertTrue[closeQ[xxError, asNumber[summary["XXRoughErrorRy"]], 5.*^-8],
        "XX rough error mismatch at " <> ToString[geometry]];
    ];

    production = productionByGeometry[geometryKey[geometry]];
    optical = meVByGeometry[geometryKey[geometry]];
    eX0 = asNumber[production["E_X^0 (Ry)"]];
    eXX0 = asNumber[production["E_XX^0 (Ry)"]];
    eX = eX0 + xCorrection;
    eXX = eXX0 + xxCorrection;
    eBind = 2. xCorrection - xxCorrection;
    eBindError = Sqrt[(2. xError)^2 + xxError^2];

    assertTrue[closeQ[xNorm, asNumber[optical["N_X"]]],
      "retained X norm and optical summary disagree at " <> ToString[geometry]];
    If[sourceGroup === "remaining",
      assertTrue[closeQ[eX, asNumber[summary["XTotalRy"]]],
        "refined X total mismatch at " <> ToString[geometry]];
      assertTrue[closeQ[eXX, asNumber[summary["XXTotalRy"]]],
        "refined XX total mismatch at " <> ToString[geometry]];
    ];

    <|
      "a/rB" -> geometry[[1]], "c/rB" -> geometry[[2]],
      "alpha_X" -> alphaX,
      "alpha" -> xxParameters[[1]], "beta" -> xxParameters[[2]],
      "gamma" -> xxParameters[[3]], "delta" -> xxParameters[[4]],
      "E_X^0 (Ry)" -> eX0, "Delta E_X (Ry)" -> xCorrection,
      "Delta E_X error (Ry)" -> xError,
      "E_X (Ry)" -> eX, "E_X error (Ry)" -> xError,
      "E_XX^0 (Ry)" -> eXX0, "Delta E_XX (Ry)" -> xxCorrection,
      "Delta E_XX error (Ry)" -> xxError,
      "E_XX (Ry)" -> eXX, "E_XX error (Ry)" -> xxError,
      "E_bind = 2 E_X - E_XX (Ry)" -> eBind,
      "E_bind error (Ry)" -> eBindError,
      (* Preserve the finalized dimensionless optical block. *)
      "N_X" -> asNumber[optical["N_X"]],
      "N_X error" -> asNumber[optical["N_X error"]],
      "M_X" -> asNumber[optical["M_X"]],
      "M_X error" -> asNumber[optical["M_X error"]],
      "|M_X|^2" -> asNumber[optical["|M_X|^2"]],
      "|M_X|^2 error" -> asNumber[optical["|M_X|^2 error"]]
    |>
  ],
  {geometry, geometryOrder}
];

(* Canonical CSV export and identical paper-data copy. *)
rySummaryPath = FileNameJoin[{numDir, "main-state-final-summary-Ry.csv"}];
paperRySummaryPath = FileNameJoin[
  {paperDataDir, "main-state-final-summary-Ry.csv"}];
Export[rySummaryPath,
  Prepend[(Lookup[#, headers] & /@ finalRows), headers], "CSV"];
CopyFile[rySummaryPath, paperRySummaryPath, OverwriteTarget -> True];
assertTrue[FileHash[rySummaryPath] === FileHash[paperRySummaryPath],
  "canonical Ry CSV copies are not byte-identical"];

(* Algebraic and requested Ry-to-meV validation. *)
identityResiduals = Flatten@Table[
  {
    row["E_X (Ry)"] - row["E_X^0 (Ry)"] - row["Delta E_X (Ry)"],
    row["E_XX (Ry)"] - row["E_XX^0 (Ry)"] - row["Delta E_XX (Ry)"],
    row["E_XX^0 (Ry)"] - 2. row["E_X^0 (Ry)"],
    row["E_bind = 2 E_X - E_XX (Ry)"] -
      (2. row["Delta E_X (Ry)"] - row["Delta E_XX (Ry)"]),
    row["E_bind = 2 E_X - E_XX (Ry)"] -
      (2. row["E_X (Ry)"] - row["E_XX (Ry)"])
  },
  {row, finalRows}
];

(* This conversion is only a validation against the legacy final table. *)
effectiveRyMeV = 5.5638515646389;
conversionPairs = {
  {"E_X (Ry)", "E_X (meV)"},
  {"E_X error (Ry)", "E_X error (meV)"},
  {"E_XX (Ry)", "E_XX (meV)"},
  {"E_XX error (Ry)", "E_XX error (meV)"},
  {"E_bind = 2 E_X - E_XX (Ry)",
    "E_bind = 2 E_X - E_XX (meV)"},
  {"E_bind error (Ry)", "E_bind error (meV)"}
};
conversionResiduals = Flatten@Table[
  With[{legacy = meVByGeometry[geometryKey[{row["a/rB"], row["c/rB"]}]]},
    (effectiveRyMeV row[#[[1]]] - asNumber[legacy[#[[2]]]]) & /@
      conversionPairs
  ],
  {row, finalRows}
];

uniqueGeometries = DeleteDuplicates[
  Lookup[#, {"a/rB", "c/rB"}] & /@ finalRows];
assertTrue[Length[finalRows] == 7 && Length[uniqueGeometries] == 7,
  "canonical dataset does not contain exactly seven unique geometries"];
assertTrue[Max[Abs[identityResiduals]] < 10.^-12,
  "energy identities fail numerical precision"];
assertTrue[Max[Abs[conversionResiduals]] < 10.^-10,
  "Ry-to-meV conversion does not reproduce the final meV summary"];

(* Plot data: four points in each scan; (5,1) intentionally appears in both. *)
cScan = SortBy[Select[finalRows, closeQ[#1["a/rB"], 5.] &], #1["c/rB"] &];
aScan = SortBy[Select[finalRows, closeQ[#1["c/rB"], 1.] &], #1["a/rB"] &];
assertTrue[Lookup[cScan, "c/rB"] === {0.5, 1., 1.5, 2.},
  "axial scan ordering is wrong"];
assertTrue[Lookup[aScan, "a/rB"] === {3., 5., 7., 10.},
  "lateral scan ordering is wrong"];
assertTrue[MemberQ[Lookup[cScan, {"a/rB", "c/rB"}], {5., 1.}] &&
  MemberQ[Lookup[aScan, {"a/rB", "c/rB"}], {5., 1.}],
  "common geometry is missing from one scan"];

SetOptions[ListLinePlot, IntervalMarkers -> "Bars"];
fontFamily = "Times";
blue = RGBColor[0., 0.447, 0.698];
orange = RGBColor[0.835, 0.369, 0.];
green = RGBColor[0., 0.620, 0.451];
purple = RGBColor[0.800, 0.475, 0.655];
sky = RGBColor[0.337, 0.706, 0.914];
markers = {"●", "■", "◆", "▲", "▼"};

ClearAll[aroundSeries, plainSeries, panelPlot, panelLabel];
aroundSeries[scan_, xKey_, yKey_, errorKey_] :=
  ({asNumber[#1[xKey]], Around[asNumber[#1[yKey]], asNumber[#1[errorKey]]]} & /@ scan);
plainSeries[scan_, xKey_, yKey_] :=
  ({asNumber[#1[xKey]], asNumber[#1[yKey]]} & /@ scan);

panelLabel[graphic_, label_] := Labeled[
  graphic, Style[label, 15, Italic, FontFamily -> fontFamily], {{Left, Top}},
  Spacings -> {0, 0}
];

panelPlot[data_, xLabel_, yLabel_, styles_, plotMarkers_, plotRange_,
    zeroLine_: False, filling_: None] := ListLinePlot[
  data,
  Frame -> True,
  Axes -> False,
  FrameLabel -> {
    Style[xLabel, 12, Italic, FontFamily -> fontFamily],
    Style[yLabel, 12, Italic, FontFamily -> fontFamily]
  },
  FrameStyle -> Directive[Black, AbsoluteThickness[0.7]],
  FrameTicksStyle -> Directive[9, FontFamily -> fontFamily],
  BaseStyle -> {FontFamily -> fontFamily, 10},
  PlotStyle -> (Directive[#, AbsoluteThickness[1.35]] & /@ styles),
  PlotMarkers -> MapThread[{Style[#1, 9, #2], 9} &, {plotMarkers, styles}],
  PlotRange -> plotRange,
  PlotRangePadding -> Scaled[0.04],
  GridLines -> If[zeroLine, {None, {0}}, None],
  GridLinesStyle -> Directive[GrayLevel[0.55], Dashed, AbsoluteThickness[0.6]],
  Filling -> filling,
  FillingStyle -> Directive[Opacity[0.12], sky],
  ImagePadding -> {{58, 13}, {45, 12}},
  AspectRatio -> 0.75,
  ImageSize -> 360
];

(* Corrected biexciton energy in Ry. *)
figEXXRy = GraphicsRow[
  {
    panelLabel[
      panelPlot[
        {aroundSeries[cScan, "c/rB", "E_XX (Ry)", "E_XX error (Ry)"]},
        Row[{Style["c", Italic], "/", Subscript["r", "B"]}],
        Row[{Subscript[Style["E", Italic], "XX"], ", Ry"}],
        {blue}, {markers[[1]]}, All], "a)"],
    panelLabel[
      panelPlot[
        {aroundSeries[aScan, "a/rB", "E_XX (Ry)", "E_XX error (Ry)"]},
        Row[{Style["a", Italic], "/", Subscript["r", "B"]}],
        Row[{Subscript[Style["E", Italic], "XX"], ", Ry"}],
        {blue}, {markers[[1]]}, All], "b)"]
  },
  Spacings -> 0.25, ImageSize -> 760
];

(* Binding energy in Ry with zero-binding reference. *)
figBindingRy = GraphicsRow[
  {
    panelLabel[
      panelPlot[
        {aroundSeries[cScan, "c/rB",
          "E_bind = 2 E_X - E_XX (Ry)", "E_bind error (Ry)"]},
        Row[{Style["c", Italic], "/", Subscript["r", "B"]}],
        Row[{Subscript[Style["E", Italic], "bind"], ", Ry"}],
        {blue}, {markers[[1]]}, All, True], "a)"],
    panelLabel[
      panelPlot[
        {aroundSeries[aScan, "a/rB",
          "E_bind = 2 E_X - E_XX (Ry)", "E_bind error (Ry)"]},
        Row[{Style["a", Italic], "/", Subscript["r", "B"]}],
        Row[{Subscript[Style["E", Italic], "bind"], ", Ry"}],
        {blue}, {markers[[1]]}, All, True], "b)"]
  },
  Spacings -> 0.25, ImageSize -> 760
];

(* Compare two excitons with one biexciton. Their separation is E_bind. *)
twoXCorrection[scan_, xKey_] :=
  ({asNumber[#1[xKey]],
    Around[2. asNumber[#1["Delta E_X (Ry)"]],
      2. asNumber[#1["Delta E_X error (Ry)"]]]} & /@ scan);
xxCorrection[scan_, xKey_] :=
  aroundSeries[scan, xKey, "Delta E_XX (Ry)", "Delta E_XX error (Ry)"];

correctionLegend = LineLegend[
  {Directive[blue, AbsoluteThickness[1.35]],
   Directive[orange, AbsoluteThickness[1.35]]},
  {Row[{"2 ", Style["\[CapitalDelta]", Italic], Subscript[Style["E", Italic], "X"]}],
   Row[{Style["\[CapitalDelta]", Italic], Subscript[Style["E", Italic], "XX"]}]},
  LegendMarkers -> {markers[[1]], markers[[2]]},
  LegendLayout -> "Row", LabelStyle -> {10, FontFamily -> fontFamily}
];
figCorrectionsRy = Legended[
  GraphicsRow[
    {
      panelLabel[
        panelPlot[
          {twoXCorrection[cScan, "c/rB"], xxCorrection[cScan, "c/rB"]},
          Row[{Style["c", Italic], "/", Subscript["r", "B"]}],
          "correlation correction, Ry",
          {blue, orange}, markers[[{1, 2}]], All, False, {1 -> {2}}], "a)"],
      panelLabel[
        panelPlot[
          {twoXCorrection[aScan, "a/rB"], xxCorrection[aScan, "a/rB"]},
          Row[{Style["a", Italic], "/", Subscript["r", "B"]}],
          "correlation correction, Ry",
          {blue, orange}, markers[[{1, 2}]], All, False, {1 -> {2}}], "b)"]
    },
    Spacings -> 0.25, ImageSize -> 760
  ],
  Placed[correctionLegend, Below]
];

(* Optimized variational parameters. No uncertainty bars are assigned. *)
parameterLegend = LineLegend[
  {blue, orange, green, purple, sky},
  {Subscript[Style["\[Alpha]", Italic], "X"], Style["\[Alpha]", Italic],
   Style["\[Beta]", Italic], Style["\[Gamma]", Italic], Style["\[Delta]", Italic]},
  LegendMarkers -> markers,
  LegendLayout -> "Row", LabelStyle -> {10, FontFamily -> fontFamily}
];
parameterPanel[scan_, xKey_, keys_, colors_, usedMarkers_, xLabel_, label_] :=
  panelLabel[
    panelPlot[
      plainSeries[scan, xKey, #] & /@ keys,
      xLabel, "variational parameter (effective units)",
      colors, usedMarkers, All],
    label
  ];

figParameters = Legended[
  GraphicsGrid[
    {
      {
        parameterPanel[cScan, "c/rB", {"alpha_X", "alpha", "beta"},
          {blue, orange, green}, markers[[{1, 2, 3}]],
          Row[{Style["c", Italic], "/", Subscript["r", "B"]}], "a)"],
        parameterPanel[aScan, "a/rB", {"alpha_X", "alpha", "beta"},
          {blue, orange, green}, markers[[{1, 2, 3}]],
          Row[{Style["a", Italic], "/", Subscript["r", "B"]}], "b)"]
      },
      {
        parameterPanel[cScan, "c/rB", {"gamma", "delta"},
          {purple, sky}, markers[[{4, 5}]],
          Row[{Style["c", Italic], "/", Subscript["r", "B"]}], "c)"],
        parameterPanel[aScan, "a/rB", {"gamma", "delta"},
          {purple, sky}, markers[[{4, 5}]],
          Row[{Style["a", Italic], "/", Subscript["r", "B"]}], "d)"]
      }
    },
    Spacings -> {0.25, 0.2}, ImageSize -> 760
  ],
  Placed[parameterLegend, Below]
];

(* Material-specific optical conversion and radiative lifetime in ps. *)
vacuumPermittivity = 8.8541878128*^-12;
elementaryCharge = 1.602176634*^-19;
reducedPlanck = 1.054571817*^-34;
speedOfLight = 2.99792458*^8;
freeElectronMass = 9.1093837015*^-31;
gaasGapEV = 1.5192;
gaasElectronMassRatio = 0.067;
gaasKaneEnergyEV = 22.71;
gaasRelativePermittivity = 12.8;
gaasElectronMass = gaasElectronMassRatio freeElectronMass;

excitonEnergyEV[row_] := gaasGapEV +
  (effectiveRyMeV/1000.) row["E_X (Ry)"];
oscillatorStrengthX[row_] :=
  (gaasKaneEnergyEV/excitonEnergyEV[row]) row["|M_X|^2"];
tauXps[row_] := 10.^12 (
  2 Pi vacuumPermittivity gaasElectronMass speedOfLight^3 reducedPlanck^2)/(
  Sqrt[gaasRelativePermittivity] elementaryCharge^2
  (excitonEnergyEV[row] elementaryCharge)^2 oscillatorStrengthX[row]);
tauXXps[row_] := tauXps[row]/4.;
tauXErrorPs[row_] := tauXps[row] Norm[{
  ((effectiveRyMeV/1000.) row["E_X error (Ry)"])/excitonEnergyEV[row],
  row["|M_X|^2 error"]/row["|M_X|^2"]
}];
tauXXErrorPs[row_] := tauXErrorPs[row]/4.;

lifetimeRows = Join[#, <|
  "tau_X (ps)" -> tauXps[#], "tau_XX (ps)" -> tauXXps[#],
  "tau_X error (ps)" -> tauXErrorPs[#],
  "tau_XX error (ps)" -> tauXXErrorPs[#]
|>] & /@ finalRows;
cLifetimeScan = SortBy[
  Select[lifetimeRows, closeQ[#1["a/rB"], 5.] &], #1["c/rB"] &];
aLifetimeScan = SortBy[
  Select[lifetimeRows, closeQ[#1["c/rB"], 1.] &], #1["a/rB"] &];
lifetimeLegend = LineLegend[
  {blue, orange},
  {Subscript[Style["\[Tau]", Italic], "X"],
   Subscript[Style["\[Tau]", Italic], "XX"]},
  LegendMarkers -> markers[[{1, 2}]], LegendLayout -> "Row",
  LabelStyle -> {10, FontFamily -> fontFamily}
];
figLifetimes = Legended[
  GraphicsRow[
    {
      panelLabel[
        panelPlot[
          {aroundSeries[cLifetimeScan, "c/rB", "tau_X (ps)", "tau_X error (ps)"],
           aroundSeries[cLifetimeScan, "c/rB", "tau_XX (ps)", "tau_XX error (ps)"]},
          Row[{Style["c", Italic], "/", Subscript["r", "B"]}],
          Row[{Style["\[Tau]", Italic], ", ps"}],
          {blue, orange}, markers[[{1, 2}]], All], "a)"],
      panelLabel[
        panelPlot[
          {aroundSeries[aLifetimeScan, "a/rB", "tau_X (ps)", "tau_X error (ps)"],
           aroundSeries[aLifetimeScan, "a/rB", "tau_XX (ps)", "tau_XX error (ps)"]},
          Row[{Style["a", Italic], "/", Subscript["r", "B"]}],
          Row[{Style["\[Tau]", Italic], ", ps"}],
          {blue, orange}, markers[[{1, 2}]], All], "b)"]
    },
    Spacings -> 0.25, ImageSize -> 760
  ],
  Placed[lifetimeLegend, Below]
];

(* Vector PDF exports. New Ry energy figures do not overwrite the meV files. *)
exports = <|
  "Main-E_XX-Ry.pdf" -> figEXXRy,
  "Main-Binding-Energy-Ry.pdf" -> figBindingRy,
  "Main-Correlation-Corrections-Ry.pdf" -> figCorrectionsRy,
  "Main-Variational-Parameters.pdf" -> figParameters
|>;
KeyValueMap[
  Function[{name, graphic},
    sourcePath = FileNameJoin[{figDir, name}];
    paperPath = FileNameJoin[{paperFigDir, name}];
    Export[sourcePath, graphic, "PDF"];
    CopyFile[sourcePath, paperPath, OverwriteTarget -> True];
    assertTrue[FileHash[sourcePath] === FileHash[paperPath],
      "figure copy differs: " <> name]
  ],
  exports
];

(* This keeps the existing lifetime output material-specific and in ps. *)
Export[FileNameJoin[{figDir, "Main-Lifetimes.pdf"}], figLifetimes, "PDF"];

Print["Generated canonical Ry dataset and figures."];
Print["rows = ", Length[finalRows],
  "; unique geometries = ", Length[uniqueGeometries]];
Print["max identity residual (Ry) = ", Max[Abs[identityResiduals]]];
Print["max Ry-to-meV check residual = ", Max[Abs[conversionResiduals]]];
Print[FileNameJoin[{figDir, #}]] & /@ Keys[exports];
