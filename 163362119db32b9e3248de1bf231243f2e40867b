# Editor usability review fixes — 2026-10-29

EU-U01, EU-U02, EU-U03 and EU-R01 are addressed. EU-P01 remains open for
cold first-practice loading.

The responsive header gives Undo and Redo their own hit targets when the
Issues action appears or disappears. The action container ignores pointer
input in its empty area. Clicking an already-highlighted object card enters
placement and preserves its chosen variant, size, orientation and run mode.

Fit view is available in Map, as well as via the existing F shortcut. It
frames the circuit within the area left by the current authoring panels;
larger circuits can zoom out further without jumping on the next zoom. The
small-screen feedback and paint toolbar avoid the rail and save status. The
object control strip scrolls without a scrollbar expanding it into the
palette. Road dimension labels are placed around the acceptance button,
handles, other labels, start controls and available canvas area.

Desert relief traversal now checks node and build lifetime after yielded
frames before accessing children. The reconstructed original emits four
script errors in the retirement fixture; the corrected source emits none.

On the original review track, controlled Edit here returns measured 23–34 ms
for the mouse-up handler and 36–61 ms to the first frame. The earlier 14.577 s
helper step included waits and is not a clean return-latency measurement.
Cold first practice still took roughly 20–29 seconds in limited local desktop
runs. Batching and a final-draw trial were reverted: their whole-load gains
were marginal or within noise, while batching increased the longest
non-cancellable draw. No claim is made that this remaining delay is fixed.

Actual checks, using Godot 4.7.2 and isolated offline storage:

- Fit/labels: 1046/0 headless; 1051/0 each Compatibility and desktop Mobile.
  These include actual Map/Fit mouse and touch input, 960×540 and 1280×720,
  large-map fit, label collisions, panel separation, and unchanged documents.
- Header: 549/0 headless; 561/0 each Compatibility and desktop Mobile.
  Actual mouse and touch Undo/Redo cover visible/hidden Issues and resizing.
- Object-card activation: 74/0 headless and 79/0 each graphical renderer;
  the matching original-browser control has eight failures. Retained object
  properties now pass 119/0 in Compatibility, including the two prior
  960×540 strip failures.
- Relief retirement: 6/0 each mode with no script errors. Retained editor
  placement 205/0 and preparation 269/0 headless pass.
- Existing editor workflow 254/0 and App 141/0 pass headless. The retained
  editor-review fixture reports 78/1: its Night racing-light expectation
  is 0.045/0.025 while current TrackTheme specifies 0.055/0.030. The retained
  jump fixture reports the same seven failures with the original and updated
  object browser. The broad translation-authoring reader encounters the
  existing tab-formatted track_editor_review_fixes.tsv; the new Fit view key
  independently matches all twelve locale catalogues and placeholder checks.

The retained review fixture wrote into its historical evidence folder. Its
new 78/1 results were archived here; the prior 78/0 results were reconstructed
semantically from the original preserved log, without a claim of byte-identical
restoration. That fixture also updated its own historical probe storage.

The source-only [review patch](evidence/editor-usability-fixes-2026-10-29/task.patch)
uses reconstructed task-start copies and excludes other workspace changes.
It applies forward to those copies, reverse-checks against the current source,
and its forward and reverse contents match all 29 recorded file hashes. It is
not a claim that the whole shared workspace was frozen. Commands, receipts,
screenshots, profiling and limits are in the [report](evidence/editor-usability-fixes-2026-10-29/report.json).

Godot reported an offline sandbox certificate-store warning. One final Mobile
header run reported four leaked ObjectDB instances and one resource at exit
after its assertions passed; an earlier Mobile header run exited without those
cleanup warnings. No physical-device test was performed. Reload/rebuild and
owner acceptance, including touch usability and actual device loading, remain.
