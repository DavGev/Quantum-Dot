---
name: mathematica-create-notebook
description: >
  How to CREATE a new Wolfram Mathematica notebook (.nb) — the fast way. A .nb is a
  plain-text Wolfram Language expression, so the optimized path is to WRITE THE FILE
  DIRECTLY to disk with the Write tool (a minimal `Notebook[{Cell[...]}]` template),
  skipping the front end, the launcher, and the Welcome window entirely. Use
  whenever the task is to make/scaffold a new notebook, drop in a code cell, or
  generate a .nb from a template. Covers the minimal valid template, cell/box
  structure, string escaping, where to write (Documents vs. G:\ drive), and how to
  open + verify it in Wolfram. Pair with `mathematica-run-cells` to open and
  evaluate the result.
---

# Creating a new Mathematica notebook

**Key insight (verified): a `.nb` is just a plain-text Wolfram Language
expression.** You do NOT need the front end to create one. Writing the file
directly with the Write tool is far faster and cleaner than driving the GUI (New
Notebook → type cells → Save), and it sidesteps every pain point of launching
Wolfram (the launcher spawning a Welcome window, kernel init, etc.).

## 1. Write the file directly — minimal template

This is a complete, valid notebook with one evaluatable `Print["Hello World"]`
Input cell. Verified to open in Wolfram 14.3 with no corruption/version warning
and to evaluate correctly:

```mathematica
(* Content-type: application/vnd.wolfram.mathematica *)

(*** Wolfram Notebook File ***)
(* http://www.wolfram.com/nb *)

Notebook[{
Cell[BoxData[
 RowBox[{"Print", "[", "\"Hello World\"", "]"}]], "Input"]
}]
```

Write it straight to the target folder, e.g.
`…/projects/biexciton/01-numerics/HelloWorld.nb`. That's the entire deliverable —
no GUI step required.

### How the structure works
- `Notebook[{ cell1, cell2, … }]` is the whole document. Options
  (`WindowSize`, `FrontEndVersion`, cache, …) are **optional** — omit them; Wolfram
  fills in defaults on open. Adding a wrong `FrontEndVersion` only risks a harmless
  version-mismatch message, so leave it out.
- The three leading `(* … *)` comment lines are the conventional notebook header.
  They help the OS/Wolfram recognize the file as a notebook; keep them.
- A code cell is `Cell[BoxData[ <boxes> ], "Input"]`.
- `<boxes>` for `Print["Hello World"]` is
  `RowBox[{"Print", "[", "\"Hello World\"", "]"}]` — the expression split into
  syntax tokens (`Print`, `[`, the string, `]`).
- **String escaping:** a string literal `"Hello World"` becomes the box
  `"\"Hello World\""` (outer quotes delimit the box, inner `\"` are the literal
  quote characters). Mathematica's own longer form `"\"\<Hello World\>\""` is also
  valid on read, but the simple `\"…\"` form is enough.

### Even simpler cell form (lighter to author)
A plain-string Input cell also opens and evaluates — the front end parses the text
into boxes on load:

```mathematica
Cell["Print[\"Hello World\"]", "Input"]
```

Use `BoxData[RowBox[…]]` when you want the canonical, guaranteed round-trip form;
use the plain string when you just need readable code fast. (The template above
uses the canonical form, which is what was tested.)

### More cells / structure
- Multiple cells: comma-separate them in the `Notebook[{…}]` list, in order.
- A section title: `Cell["My Title", "Section"]`; a text cell:
  `Cell["some prose", "Text"]`; an initialization cell:
  `Cell[BoxData[…], "Input", InitializationCell->True]`.

## 2. Where to write it
- **Under Documents (mounted):** the Write tool and the sandbox shell both work.
- **Under `G:\` (Google Drive File Stream):** the sandbox shell CANNOT see `G:\` —
  use the **Write tool** with the explicit `G:\…` path (see `gdrive-file-ops`).
- Make sure the destination folder already exists; write the `.nb` into it.

## 3. Open & verify (don't assume it's valid)
A malformed box expression can open blank or mis-rendered, so verify:

1. Open the new `.nb` — double-click it in File Explorer (if Wolfram is already
   running it opens directly, **no Welcome window**; window opens at default size,
   not maximized). See `mathematica-run-cells` §2 for the open/focus decision tree.
2. Confirm it renders correctly (e.g. the cell shows `Print["Hello World"]`, not raw
   `RowBox[…]` text or an error).
3. Evaluate the cell (`Shift+Enter`) and confirm the expected output — for the
   template, **`Hello World`** prints below the input. It runs in the already-open
   kernel (the `In[n]:=` counter just keeps climbing).

## 4. Saving
- The file you wrote IS the deliverable; it's clean (just the input cell).
- Evaluating in the GUI marks the window modified (`Name.nb *`) because it adds
  `In[]/Out[]` labels and any print/output cells. **Only `Ctrl+S` if you want that
  evaluated state persisted** — otherwise leave it; the on-disk file stays minimal.

## Quick procedure
1. `Write` the `.nb` to the target folder using the §1 template (swap in your
   code/cells).
2. Double-click it in File Explorer to open (no GUI authoring needed).
3. Verify it renders, then `Shift+Enter` to confirm it evaluates.
4. Save only if you want the evaluated output embedded.
