---
name: mathematica-run-cells
description: >
  How to OPEN a Wolfram Mathematica notebook (.nb) and EVALUATE its cells on the
  user's machine through the computer-use tools. Use whenever the user asks to
  "run" / "evaluate" / "execute" a cell, the first cell, a section, the whole
  notebook, or the initialization cells of a .nb file — anything that requires
  driving the Mathematica front end (not just reading the file). Covers the
  Wolfram access grant (the window is owned by wolframnb.exe, not "Wolfram"),
  waiting for kernel start, the click-to-focus-before-typing gotcha, evaluating
  via Shift+Enter or the Evaluation menu, editing code inside a cell before
  running, confirming success vs. errors, aborting, and saving. Pair with
  gdrive-file-ops when the .nb lives on the G:\ drive.
---

# Running cells in a Mathematica notebook

The notebook runs on the **user's machine**, driven through computer-use
(screenshot + click + key). The sandbox shell cannot evaluate Wolfram code — use
it only to cross-check logic in another language. This skill is the fast,
reliable path; it folds in the failure modes hit when doing it the slow way.

## 1. Grant access — request BOTH names at once

The Start-menu entry is **`Wolfram 14.3`**, but the actual notebook window is
owned by the process **`wolframnb.exe`** (the front end). If you grant only
`Wolfram 14.3`, the notebook window gets **masked** in screenshots (you'll see a
note that `wolframnb.exe ... got hidden`). Avoid the extra round-trip:

```
request_access(apps=["Wolfram 14.3", "wolframnb.exe"],
               clipboardWrite=true,   # enables the clipboard fast-path for typing
               reason="Open and evaluate cells in a Mathematica notebook.")
```

Add `File Explorer` too if you intend to open the file by double-clicking it.
(Names are matched against the installed-apps list and are case-insensitive.)

## 2. Open / focus the notebook — pick by situation

**First check (one screenshot answers it): is the target notebook already the
frontmost window?** (Title bar reads `Name.nb - Wolfram`, full UI on top, nothing
covering it.) This is very common — you were just working in it, and it usually
stays frontmost even across a user message. If so, **do no raising at all — skip
straight to §3/§4.** The `left_click` that begins the evaluate batch (§5) selects
the cell *and* re-grabs keyboard focus, which is the only focus hand-off needed; a
taskbar click or double-click here is wasted.

Otherwise it's open-but-behind, or closed — both raise cleanly with **no new window
and no kernel restart** (verified by the `In[n]:=` counter climbing, e.g.
In[4]→In[5]). Choose by which is fewer steps:

- **Open but behind + File Explorer is NOT already at the folder → TASKBAR ICON.**
  `left_click` the red Wolfram taskbar icon. It skips folder navigation entirely
  and is position-independent — the fastest path. If several notebooks are open the
  icon expands to thumbnails; click the one whose title matches (one extra click).
- **Already open + File Explorer already showing the folder, OR notebook CLOSED →
  DOUBLE-CLICK the `.nb`** in File Explorer. One double-click when the folder is
  already shown; if closed, this opens the file directly.
- **Don't** drive File Explorer to the file when it's parked elsewhere just to
  focus an already-open notebook — you'd navigate first (`Ctrl+L`, type the full
  path, Enter), which is the slow part and needs the exact path. (Measured once:
  ~30 s vs ~25 s for the taskbar; structurally more steps too.)

**Cold start (Wolfram not running):** double-clicking the `.nb` launches it and
opens the file directly. You still get the red "Initializing kernels…" splash and
the "Welcome to Wolfram Mathematica" window — that's Wolfram's start-up screen (its
"Show at startup" setting), **not** a side effect of how you opened the file. Wait
out the splash, then close the Welcome window with its **`X`** (never **Quit**); the
notebook is open behind it.

⚠️ **Do NOT use `open_application("Wolfram 14.3")` / `"Wolframnb"` to focus an
already-open notebook.** There is no focus-only form — it re-runs the launcher and
spawns a fresh Welcome / mini launcher panel every time (the stray window the user
must close; its **Quit** button can exit the whole app + kernel). Reserve it for a
cold start only if File Explorer isn't a convenient route.

- Any click (taskbar included) is allowed only when the current frontmost app is
  itself in the allowlist (e.g. File Explorer or the notebook window).
- **After raising the window the scroll position may differ** — screenshot (and
  `Ctrl+Home` if needed) to re-confirm the target cell **before** clicking to
  evaluate, or you'll evaluate the wrong cell.
- Title bar reads `Name.nb - Wolfram`; an asterisk (`Name.nb *`) means unsaved
  changes.

## 3. Locate the target cell

- `Ctrl+Home` jumps to the very top; `Ctrl+End` to the bottom. Use the right-edge
  scrollbar thumb position to confirm you're at the top before calling something
  "the first cell".
- Each cell has a **cell bracket** down the right margin. Clicking a bracket
  selects the whole cell unambiguously (better than guessing where the code
  starts); Shift-click brackets to select a contiguous range of cells.
- To run a single cell you only need the **text cursor inside it** — a left-click
  anywhere in the cell is enough.

## 4. Evaluate

Verified shortcuts / menu (Mathematica 14.3, **Evaluation** menu):

| Goal                                   | Action                                              |
|----------------------------------------|-----------------------------------------------------|
| Evaluate the selected cell(s)          | **`Shift+Enter`** (= Evaluation ▸ Evaluate Cells)   |
| Evaluate in place (replace input)      | `Shift+Ctrl+Enter`                                  |
| Evaluate the **whole notebook**, top→bottom | Evaluation ▸ **Evaluate Notebook**            |
| Evaluate only initialization cells     | Evaluation ▸ **Evaluate Initialization Cells**      |
| Abort a running evaluation             | **`Alt+.`** (Evaluation ▸ Abort Evaluation)         |
| Start / restart kernel                 | Evaluation ▸ Start Kernel / Quit Kernel             |

`Shift+Enter` is the workhorse: put the cursor in the target cell, send it, done.
Note `Enter` alone (without Shift) just inserts a newline — it does **not**
evaluate.

**Reuse the running kernel — don't start a new one.** `Shift+Enter` evaluates in
whatever kernel is already attached to the notebook; it never spins up a second
one. A new kernel appears only when none is running, or if you relaunch the app
or use Quit/Start Kernel. Never do those just to run a cell — you'd wipe the
session's loaded definitions and have to re-evaluate the setup cells. The `In[n]:=`
counter incrementing (rather than resetting to `In[1]`) confirms you're in the
same session.

## 5. The focus gotcha — click the target, then type, in ONE batch

After a tool round-trip, keyboard focus can revert to Claude's own window. A bare
`type`/`key` then fails with *"Claude's own window still has keyboard focus."*
A click on the Wolfram window re-focuses it, so **combine focusing + evaluation in
a single `computer_batch`** instead of separate calls:

```
computer_batch([
  {action:"left_click", coordinate:[x,y]},   # focus + place cursor in the cell
  {action:"key", text:"shift+Return"},        # evaluate
  {action:"wait", duration:2},
  {action:"screenshot"}                        # verify result
])
```

(Inside a batch, all coordinates refer to the screenshot taken *before* the
batch.)

## 6. Editing code in a cell before running it

Mathematica tokenizes on punctuation, which makes surgical edits easy:

- **Double-click a word** to select just that token. In a string like
  `"constants.wl"`, the `.` is a separator, so a double-click on `constants`
  selects `constants` only — type the replacement (e.g. `definitions`) to get
  `"definitions.wl"` without disturbing the extension or quotes. **Zoom in to
  confirm the selection** before typing.
- Remember the focus rule: the first `type` after selecting may need the window
  focused first — do the double-click (which focuses) immediately before typing,
  in the same batch if possible.

## 7. Confirm success — don't assume

After evaluating, screenshot and check:

- The input cell gains an **`In[n]:=`** label and a paired **`Out[n]=`** appears
  (unless output is suppressed).
- A trailing **`;`** suppresses output. Mathematica may show a thin
  *"Assuming suppressed output | … show output"* suggestion bar — this is
  **informational, not an error**.
- **Errors** print as a red/orange message under the cell, e.g.
  `Get: Cannot open …`. Read it; a missing-file `Get` error usually means a
  wrong path/filename in the cell, not a kernel problem.
- **`Running…`** in the status area / a filled cell bracket means the kernel is
  still busy — `wait` and re-screenshot; `Alt+.` to abort if it's stuck.

## 8. Save

`Ctrl+S` saves in place (the title-bar `*` disappears). Save after editing a cell
so the fix persists. Saving is safe; **do not** use File ▸ Save As to a new
location unless asked.

## Quick procedure

1. `request_access(["Wolfram 14.3", "wolframnb.exe", "File Explorer"], clipboardWrite=true)`
2. **Focus/open the notebook — SKIP this entirely if it's already the frontmost
   window (go to step 4).** Open but behind + File Explorer elsewhere → `left_click`
   the Wolfram **taskbar icon** (pick the right thumbnail if several are open). File
   Explorer already at the folder, or notebook closed → **double-click the `.nb`**.
   Never `open_application` just to focus (it spawns a Welcome window). Cold start:
   wait out "Initializing kernels…", close any Welcome window with `X` (not Quit).
   After raising, re-confirm cell position by screenshot.
4. `Ctrl+Home`; locate the cell (click its bracket / click inside it).
5. One `computer_batch`: click the cell → `shift+Return` → wait → screenshot.
6. Verify `In[n]:=` + no red error (suppressed-output bar is fine).
7. `Ctrl+S` if you changed anything.

For whole-notebook or initialization runs, use the **Evaluation** menu items in
§4 instead of step 5.
