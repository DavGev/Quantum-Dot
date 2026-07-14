# Mathematica Style Guide

Coding conventions for the project notebooks, drawn from `Plots.nb`. These cover
how the notebooks are organized; visual/figure conventions live in
`plot-style.md`.

## Structure

- Open each notebook with a **parameter block**: bare assignments grouped on a
  few lines, terminated with `;` so nothing prints
  (`aMin = 2; aMax = 5;` … `cMin = 0.7; cMax = 2;`).
- Define **energies/quantities as pure functions of geometry**, e.g.
  `Energy[a_, c_][n_, nr_, m_] := …`, and apply them to a state tuple with
  `Energy[a, c] @@ state`. Keep a `states` list and a parallel `labels` list so
  curves, legends, and colors all index the same way.
- Build reusable **helpers** rather than repeating option blocks: `panelTag[ch_]`
  for panel letters, a `styles` directive vector, a `legendGrid`. Assign
  intermediate plots to names (`plotEc`, `plotEa`, …) and assemble the final
  figure from them.

## Idioms

- Style vectors via `Thread @ Directive[colors, AbsoluteThickness[1.2]]`.
- Colors by index from `ColorData[97, "ColorList"]`, sliced to `Length[states]`.
- Compose multi-panel figures with `Labeled[plot, panelTag["a"], {Left, Top},
  Spacings -> {0, 0}]` and lay panels out with `Grid`/`Row`.
- Legends as `MapThread[LineLegend[{#1}, {#2}, LabelStyle -> 11] &,
  {styles, labels}]`, then `Grid[Partition[#, 3], Alignment -> Center]`.

## Conventions

- Suppress side-effect output with trailing `;`; only the final figure cell prints.
- Set resolution explicitly on final plots (`PlotPoints -> 60–200`) rather than
  leaving it adaptive.
- Units: energies in Rydberg (Ry), lengths in effective Bohr radii (r_B), photon
  energy in meV — state the unit in the frame label, keep the quantity
  dimensionless-scaled in code where possible.
- Export figures with `Export[..., fig]` to PDF (vector) for manuscripts; PNG only
  for quick previews.
