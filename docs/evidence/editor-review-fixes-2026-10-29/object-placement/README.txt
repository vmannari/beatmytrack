OBJECT PALETTE ACTIVATION — 2026-10-29

An object card always activates placement, including when it was already
highlighted on entry. For grouped families, reselecting the card retains
the chosen variant. Existing size, orientation, line/curve placement and
separate jump-card choices remain intact.

Implementation: game/editor/object_browser.gd. New regression:
game/tests/test_object_palette_activation.gd and its generated UID. The
exact source at the start of this task is before/object_browser.gd.txt.

Actual pinned Godot 4.7.2 results, isolated APPDATA and offline records:
- New viewport input regression: 74/0 headless, 79/0 Compatibility and
  79/0 desktop Mobile. Both mouse and touch select the initial highlighted
  Rock, place two objects, and keep placement active. The same fixture tests
  Boulder variant/scale/rotation, five jump profiles and a guardrail curve.
- The identical regression against a separate project using the original
  object_browser.gd: 72 checks / 8 failures. The eight failures are the
  initial Rock activation and its consequences with mouse and touch.
- Retained jump-style fixture: 3365 checks / 7 failures under headless,
  identical with the original and corrected object browser. Five are its
  old assumption that the inline options container is hidden, and two are
  Sand rise viewport assertions. The 3358 other checks pass in both.
- Retained object-properties fixture: 119 checks / 2 failures under native
  Compatibility, identical with original and corrected object browser. Both
  concern the size/overlap of the controls at 960x540.

Copies of retained fixtures only redirect their evidence output to an owned
directory; original regression files were left untouched. The original
object-browser control uses a separate project at tmp/palette-activation-
old-20261029: editor directory copied, other project directories linked to
the active workspace, old object_browser copied over the control only. This
is a matched edited-source control, not a frozen whole-tree baseline.

Initial headless and Compatibility attempts in headless/ and compatibility/
retain a fixture timing defect: immediately pressing a newly rebuilt size
control before its layout settled hit the adjacent orientation control.
The regression was corrected to wait for layout; final2 results above pass.
The sandbox reported a root certificate store access error; the run used no
network or authentication. One headless run also retained a dummy-renderer
Garage texture warning; this did not occur in the two graphical final runs.

Native screenshots and logs are under compatibility-final2/ and
desktop-mobile-final/. No device test or owner-save mutation was performed.
