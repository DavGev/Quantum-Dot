# Plot Style Guide

Conventions for all figures in this project, reverse-engineered from `Plots.nb`.
Follow these so every figure across the single-particle, exciton, and biexciton
papers looks like it came from the same hand.

## Global defaults

- **Font:** Times everywhere. Set it through `BaseStyle -> {FontFamily -> "Times"}`
  on the plot, and on every `Style`/`Row`/`Text` you add by hand.
- **Image size:** `ImageSize -> 500` for a standalone single-panel figure.
- **Theme:** 2-D line plots use `PlotTheme -> "Scientific"` (boxed frame, inward
  ticks, ticks on all four sides, no grid lines).
- **Color cycle:** the default Mathematica indexed scheme,
  `ColorData[97, "ColorList"]`, taken in order. Do not hand-pick colors — slice
  the list to the number of curves so colors stay consistent between figures
  that show the same set of states.
- **Line weight:** `AbsoluteThickness[1.2]` for data curves.

The canonical style vector (one `Directive` per curve):

```wolfram
styles = Thread @ Directive[
   ColorData[97, "ColorList"][[ ;; Length[states] ]],
   AbsoluteThickness[1.2]
];
```

## Frame labels

- Variable symbols are **italic**; units are **upright**, appended after a comma:
  `E_e, Ry` / `c, r_B` / `ℏω, meV`.
- Build labels with `Row` so the italic symbol and upright unit sit together;
  use `Subscript` for subscripted symbols.
- Rotate the y-label with `Rotate[…, -90 Degree]`.

```wolfram
FrameLabel -> {
   Row[{Style["c", Italic], ", ", Subscript[Style["r", Italic], "B"]},
       BaseStyle -> {FontFamily -> "Times"}],
   Rotate[Row[{Style[Subscript["E", "e"], Italic], ", Ry"},
              BaseStyle -> {FontFamily -> "Times"}], -90 Degree]
};
```

## Panel tags

Multi-panel figures (a, b, c, d) tag each panel with an italic letter in the
top-left, attached with `Labeled` rather than baked into the plot:

```wolfram
panelTag[ch_] := Row[{Style[ch, Italic], ")"},
   BaseStyle -> {FontFamily -> "Times", FontSize -> 14}];

plotA = Labeled[ Plot[ ... ], panelTag["a"], {Left, Top}, Spacings -> {0, 0} ];
```

## Legends

- One `LineLegend` per curve, label style size 11, paired with the same `styles`
  vector used for the plot.
- Lay them out as a shared legend `Grid`, partitioned **3 across**, centered —
  kept as a separate object (as in `Counlomb_legend`) so several panels share one
  legend instead of repeating it.

```wolfram
singleLegends = MapThread[
   LineLegend[{#1}, {#2}, LabelStyle -> 11] &, {styles, labels}];
legendGrid = Grid[Partition[singleLegends, 3], Alignment -> Center];
```

State labels themselves are Times, size 12.

## Plot ranges

Set `PlotRange` explicitly — do not rely on `Automatic` for final figures. Pin
both the domain and the value range, e.g.
`PlotRange -> {{cMin, cMax}, {0, 25}}`. Resolution: `PlotPoints -> 60–100` for
smooth line plots (up to 200 where a curve has sharp resonant features).

Domains used in the energy figures: `a ∈ [2, 5] r_B`, `c ∈ [0.7, 2] r_B`.
Energies are reported in **Rydberg (Ry)**; for optical spectra the photon energy
axis ℏω is in **meV**.

## 3-D geometry figures (the dot itself)

- `Graphics3D` with `Boxed -> False`, `Axes -> False`; build the body from a
  surface + bottom + rim and `Show` them together.
- Body color `RGBColor[0, 0, 2/3]` (deep blue) at `Opacity[0.4–0.6]`.
- Axes drawn as black `Arrow`s (`Directive[Black, Opacity[1], Thick]`) labelled
  with italic Times `Text` at size 16 (`a`, `a`, `c`).
- Keep the aspect strongly oblate (a ≫ c) to reflect the SOEQD geometry.

## Density / wavefunction slices (Ψ figures)

- `PlotPoints -> 80–200`, `Mesh -> None`.
- `Frame -> False`, `Axes -> False`, very oblate `AspectRatio -> 0.1` for the
  cross-sectional slice; `ImageSize -> 500`.
- Annotate each slice with its quantum numbers (ν, n, m) in italic Times.

## Quick checklist before exporting

1. Times font on labels, ticks, legend, and any hand-placed text.
2. `PlotTheme -> "Scientific"`, `Frame -> True`, explicit `PlotRange`.
3. Colors from `ColorData[97]`, `AbsoluteThickness[1.2]`.
4. Italic symbols, upright units, y-label rotated −90°.
5. Panel tags via `Labeled`; one shared 3-column legend grid.
6. `ImageSize -> 500`; export vector (PDF) for manuscripts, raster (PNG) only for previews.
