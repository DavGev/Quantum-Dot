# Biexciton manuscript

This directory is a self-contained, journal-neutral LaTeX manuscript. The
local Git copy is the source of truth while drafting.

## Structure

- `main.tex`: document entry point
- `macros.tex`: notation and cross-reference settings
- `sections/`: manuscript and supplementary sections
- `references.bib`: bibliography
- `figures/`: production vector PDFs
- `data/`: machine-readable final numerical table
- `output/pdf/`: verified compiled manuscript

## Overleaf workflow without Premium

1. Finish and commit a local drafting milestone.
2. Create a ZIP whose root contains `main.tex`, `macros.tex`,
   `references.bib`, `sections/`, `figures/`, and `data/`.
3. Upload the ZIP as a new Overleaf project or replace the existing project
   at an agreed synchronization point.
4. If changes are made in Overleaf, download the complete source ZIP and
   reconcile it with this directory before resuming local edits.

Avoid editing the local and Overleaf copies independently between
synchronization points.

## Items still requiring author input

- Author list, affiliations, and corresponding-author email
- Funding and acknowledgments
- Target journal and journal-specific class/template
- Data/code repository URL or archival DOI
- Final decision on whether to include a separate geometry schematic
