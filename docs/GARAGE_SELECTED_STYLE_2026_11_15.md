# Garage selected-state refinement

15 November 2026. GSS01: replace the cramped Selected row with a compact status badge. GSS02: keep the car title and photograph clear at compact sizes and in translated layouts. GSS03: preserve the distinction between browsing a car and equipping it, along with existing mouse, touch and keyboard selection.

The equipped car now carries a small upper-right badge, inset 10 logical pixels from the card edges. A dark navy surface, fine muted-gold border, gold checkmark, off-white 14px Barlow body text and a small shadow replace the all-gold condensed uppercase row against the lower border. The car name gets its own centered footer with vertical padding. The badge grows to its translated text. Its entire overlay passes input through to the existing car button. The browsed-car border and title, saved selection, model/handling, photographs and menu header retain their existing behavior.

Only `game/ui/garage_page.gd` changes at runtime. The three status documents receive this task's summary. The native capture utility and disposable runner are retained under `docs/evidence/garage-selected-2026-11-15/`; the temporary engine-side capture script was removed after review. No new permanent test or asset dependency was added.

Native views: [before, Rally equipped while browsing Kart](evidence/garage-selected-2026-11-15/gl_compatibility-before/kart-1280.png), [Kart selected, full Garage](evidence/garage-selected-2026-11-15/gl_compatibility-review/kart-1280.png), [selected card](evidence/garage-selected-2026-11-15/gl_compatibility-review/kart-1280-card.png), [compact Garage](evidence/garage-selected-2026-11-15/gl_compatibility-review/kart-960.png), [German](evidence/garage-selected-2026-11-15/gl_compatibility-review/kart-960-de.png), [Japanese](evidence/garage-selected-2026-11-15/gl_compatibility-review/kart-960-ja.png), and [desktop Mobile](evidence/garage-selected-2026-11-15/mobile-review/kart-1280.png).

Actual checks used the pinned Godot 4.7.2, disposable APPDATA/records and an empty backend URL. Commands and exit codes are recorded individually in the evidence directory. The runner was invoked as `python build/garage-selected-2026-11-15/run.py NAME SCRIPT [--direct]`; the durable copy at `docs/evidence/garage-selected-2026-11-15/run.py` works with the same arguments. To repeat the visual review, temporarily copy the archived capture utility back to the recorded `game/tests/` path and remove it afterward.

| Name | Script | Result |
| --- | --- | --- |
| `headless-parser` | `res://tests/check_model_refinement_parse.gd` through `scripts/dev.ps1 -Action TestScript` | 577 scripts, 0 failures |
| `headless-selection` | `res://tests/test_garage_selection_feedback.gd`, direct pinned engine | 20 checks, 0 failures |
| `gl_compatibility-selection` | same, native Compatibility | 23 checks, 0 failures |
| `mobile-selection` | same, desktop Mobile | 23 checks, 0 failures |
| `gl_compatibility-review`, `mobile-review` | temporary `res://tests/capture_garage_selected_review.gd` | 22 actual-App states per renderer; 44 layout/equipped-state observations per renderer, 0 findings |
| `gl_compatibility-before`, `gl_compatibility-after` | `res://tests/test_garage_reference.gd` | 894 checks, 12 failures on each; exact same twelve stock-portrait size/alpha findings |

The capture review selects all six cars through the actual selection action, browses Volt with Kart still equipped, and captures 960×540, 1280×720, 1720×900 and 2560×1354 layouts. It changes all twelve installation languages live. Each recorded state has exactly one equipped badge on the correct car; that badge fits inside an 8px inset and clears the title. Screenshots were inspected in both desktop renderers. Existing selection feedback covers actual mouse/touch input, cancellation, deferred construction and saved-selection preservation.

The broad reference suite remains **unqualified**: its twelve existing failures reproduce exactly on the task-start source and final source. These concern fallback photographs instead of the expected sharp transparent stock portraits; this styling task does not rebake unrelated assets or weaken assertions. The final Compatibility reference run also retains the known two-object/one-resource shutdown diagnostic; native capture and selection runs exit cleanly. An initial observation-reader attempt used Windows' default text encoding and failed on translated text; explicit UTF-8 reads produced the accepted validation receipt.

The checked task-only source patch applies and reverses byte-exactly in a disposable private Git repository. Existing uncommitted Garage/header/model work is included only as surrounding context, never reverted or staged. The raw shared index hash changed during the session; no task command staged, reset or committed that index. The private checkpoint separately verifies the index stays byte-exact during its own operations. `dev.ps1` refreshed generated build identity as usual; incidental generated metadata is excluded from this source patch. Standard build retention was applied at completion; its receipt records any recent/protected output above the 20 GiB target.

Reload the game to review the change. Owner appearance acceptance and physical-device qualification remain. No physical-device test/query, export, backend request, deployment, owner-save/process action or main-index staging was performed. “AAA” is the visual ambition, not a verified certification or device-quality claim.
