---
name: gdrive-file-ops
description: >
  CRITICAL FILE-ACCESS RULE for Google Drive File Stream (the G: drive on
  Windows): the sandboxed Linux shell (Bash) CANNOT see anything under G:\ — it
  sees an empty mount, so cat/ls/find/grep/mv WILL falsely report files as
  missing. Use the Read tool to read, Glob to list/find, Grep to search, Write to
  create, and Edit to modify any G:\ file; use a PowerShell script (run by the
  user) for moves/renames/deletes; stage copies in the session outputs folder to
  compile or run anything that depends on G:\ files. Always pass the explicit
  G:\ path to Glob/Grep/Read (they default to the scratchpad, not the project).
  For large Mathematica .nb files, Read/Grep fail (size limit; embedded binary
  reads as "binary file" with no content) — read the NotebookFileOutline at the
  end of the file for structure, then Read input cells by line range. Use this
  skill whenever reading, creating, modifying, organizing, or running files in a
  G:\ project.
---

# Google Drive (G:) file operations

Folders on the `G:` drive are **Google Drive File Stream** mounts. The desktop
file tools (Read / Write / Edit / Glob / Grep) reach them through the app, but
the sandboxed Linux shell only sees an empty bind mount. **Treat Bash as having
no access to anything under `G:\`** and use the methods below. These apply to
every project on the drive, regardless of folder layout.

## Reading

- **Always pass the explicit `G:\` path.** `Glob`, `Grep`, and `Read` default to
  the session scratchpad (the `outputs` cwd), **not** the connected project. A
  bare `Glob "**/*.nb"` returns *"No files found"* even when the files exist —
  give it `path: "G:\...\project"`. When in doubt, `Glob` with the project root
  first to confirm the layout, then narrow.
- **Read** a file with the `Read` tool using its absolute Windows path
  (`G:\...`). Works for text, PDFs (rendered per page), and images.
- **List / find** files with `Glob` (e.g. `**/*.pdf`, `subdir/**/*`), not
  `ls`/`find` in Bash.
- **Search inside** files with `Grep`, not `grep`/`rg` in Bash.
- **Very large text files** (exports, logs): `Grep` for the tokens you need to
  get line numbers, then `Read` with `offset`/`limit` around them rather than
  reading the whole file. ⚠️ This fails on files with embedded binary — see the
  Mathematica `.nb` note below.
- ❌ Do **not** use Bash (`cat`, `head`, `ls`, `find`, `grep`) on `G:\` paths —
  the mount is empty and will report files as missing even when they exist.

## Large Mathematica notebooks (.nb) and other binary-laced text

Saved `.nb` files embed **cached graphics output as base64 plus raw binary
thumbnails**, so a notebook with a few figures is routinely **5–6 MB** even
though its actual code is a few KB. Two consequences:

- **`Read` rejects them** (>256 KB limit). Don't read the whole file.
- **`Grep` is useless on them** — the embedded NUL bytes make it report
  *"binary file matches"* with **no content and no line numbers**, so the
  "Grep then Read" trick above does not work here.

Read the structure instead, in this order:

1. **`Read` the last ~350 lines** of the file. The `(*NotebookFileOutline … *)`
   block at the very end is a compact index of every cell — its style
   (`"Title"`, `"Section"`, `"Input"`, `"Output"`, …), byte offset, and size.
   This is your map of the document without the bulk. (To find the end, `Read`
   at a large `offset`; the warning tells you the real line count.)
2. **`Read` the input-code regions with `offset`/`limit`.** Code lives in
   `Cell[BoxData[ …RowBox… ], "Input"]` blocks near the top and interspersed
   between the graphics blobs; the huge `"Output"` / `"CachedBoxData"` cells are
   the unreadable bloat — skip over them using the sizes from the outline.
3. The header fields `NotebookDataLength` / `NotebookOptionsPosition` (first ~10
   lines) give a quick sense of total size before you commit to reading.

To keep notebooks reviewable and small in the first place, suggest the user run
**Cell ▸ Delete All Output** before saving, or maintain the code as a `.wl`
package (plain text — `Read`/`Grep`/`Edit` all work normally on `.wl`).

## Writing

- Create files with the `Write` tool addressed to the `G:\` path directly. Works
  for any text file; it saves straight into the Drive folder (and syncs).
- For long files, write a skeleton first, then extend with `Edit`.
- ⚠️ A project's `.claude\` directory is **protected** and cannot be written in a
  Cowork session. Keep project skills/config in a normal folder, or install
  skills through Settings → Capabilities.
- ⚠️ Writes are only allowed inside the **connected** folder. Paths elsewhere on
  `G:\` (other projects not mounted in this session) are blocked — ask the user
  to connect that folder first.

## Editing

- Use the `Edit` tool (exact string replacement) on the `G:\` path; Read the file
  first. This works normally — no special handling.

## Moving / renaming

- ❌ Bash `mv` does **not** work (folder invisible to the shell).
- Text files *could* be relocated by Read → Write-to-new-path → delete-original,
  but **binary files (PDF, images, Office docs, notebooks, archives, …) cannot**
  be reproduced through the text tools.
- ✅ For any move / rename / bulk reorganization, generate a **PowerShell script**
  for the user to run on their machine, then present it. Robust conventions:
  - `Move-Item -LiteralPath … -Destination … -Force`.
  - Create destinations with `New-Item -ItemType Directory -Force`.
  - For non-ASCII filenames, move a folder's contents with a wildcard /
    `Get-ChildItem … | ForEach-Object { Move-Item … }` instead of typing names.
  - Warn-don't-fail on missing items so the script is safe to re-run.
  - Launch past the execution policy without changing system settings:
    `powershell -ExecutionPolicy Bypass -File "G:\...\script.ps1"`.

## Deleting

- The file tools do not delete by default. Either let the user delete, or fold
  the removal into the PowerShell script (`Remove-Item -LiteralPath … -Recurse
  -Force`, guarded by a check that nothing unexpected remains).

## Running code / building against project files

- The sandbox cannot read `G:\`, so it cannot compile or run files in place when
  they depend on project data (LaTeX, Python, R, build tools, etc.).
- ✅ To verify, **stage copies in the scratchpad** — the session `outputs`
  directory is visible to Bash — and build/run there (e.g. copy a `.tex` plus a
  wrapper and run `pdflatex`; copy a script and its inputs and run it).
- Self-contained logic with no file dependency can be prototyped freely in the
  sandbox; only file *access* under `G:\` is blocked.
- App-bound documents (Mathematica, Excel, etc.) are run on the user's machine;
  use the sandbox only to cross-check logic in another language.

## Sharing results

- After creating or updating files, surface them with the present-files tool so
  the user can open them from the Drive folder. Don't print raw paths as the
  deliverable.

## Quick decision guide

| Task                              | Use                                  |
|-----------------------------------|--------------------------------------|
| Read a file on G:\                | `Read`                               |
| List / find files                 | `Glob`                               |
| Search file contents              | `Grep`                               |
| Create / overwrite a text file    | `Write`                              |
| Modify a text file                | `Edit`                               |
| Move / rename / bulk-organize     | generate a **PowerShell** script     |
| Delete                            | PowerShell script, or ask the user   |
| Compile / run against files       | stage copies in `outputs`, run there |
