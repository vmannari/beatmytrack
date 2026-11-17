<!-- EDITOR-FINISH-20261117 -->
## Editor card styling, centring and menu visibility repaired (2026-11-17)
EF01-EF04 supersede the rejected mixed card colours and split alignment: shared opaque shell/neutral tiles, centred groups and captions, consistent category glyphs and selection outlines. Native Labels restore readable captions, including disabled states and redraw recovery. Colour preview no longer paints over its caption. Bounded brush/document popovers scroll above the footer; Area actions stay on one row. Import fits short landscapes and file browsers show readable filename lists. Native904/0 per desktop renderer, surfaces53/0, parser583/0 and stable task inputs pass. One hundred native after views plus five retained before views cover English tools, properties, dropdowns, population, Help/Share, naming/exit and unconfirmed import/export. Initial menu overflow/cropped views retained. Exact private checkpoint preserves preceding/concurrent controller/vehicle work and shared index. Owner visual, physical Android and player acceptance remain; prior unrelated findings retained. No owner-save/process, clipboard, confirmed import/export, live service or deployment action. [Scope, menus, views and validation](EDITOR_FINISH_2026_11_17.md).
<!-- /EDITOR-FINISH-20261117 -->

<!-- EDITOR-SPACE-20261117 -->
## Editor shelves, naming and material controls refined (2026-11-17)
ES01-ES04 supersede the rejected cramped sizing: matching full-width shelves, header68to56, picker216to132 and surfaces130to64 logical units. Materials anchor left, painting controls right; flat biome swatches replace framed terrain miniatures. One document-name control, New track display, first-Save naming and correct saved My circuit handling retain cancellation/history. Object previews preserve aspect and fill their row; existing placement/reselection transactions remain. Native528/0 per desktop renderer, workflow253/0, surfaces53/0, retained headless interactions152/0, parser583/0 and scoped copy48/0 pass. Fifty-four native before/after views, source fence and reversible private checkpoint preserve preceding/concurrent work and shared index. Two full-localization failures reproduce in preceding-source controls; initial clipping/rail rejection and earlier kerb/authoring findings retained. Owner appearance, physical Android and player acceptance remain; no owner-save/process, live service, export or deployment action. [Revision, views, checks and limits](EDITOR_SPACE_2026_11_17.md).
<!-- /EDITOR-SPACE-20261117 -->

<!-- EDITOR-COHESION-20261116 -->
The owner rejected this pass's visual composition as fragmented. The [subsequent composition and object-flow revision](EDITOR_COHESION_2026_11_16.md) supersedes its floating controls, always-open object browser, and occupied-tap requirement to switch to Select manually. The current editor uses one header and one contextual dock; occupied taps select on release, and empty-ground presses can preview/aim an object before release. The history/recovery protections and unchanged saved-track format remain. The historical receipts below describe the preceding delivery, not owner appearance acceptance.
<!-- /EDITOR-COHESION-20261116 -->

# Track editor UX audit, design and implementation

Date: 2026-11-16. Requirements UX01–UX08 below. This is a source inspection and scripted heuristic assessment, not a study of player behaviour. Two-minute first creation and enjoyable thirty-minute authoring remain player-test targets. Android hardware validation is outstanding.

## Executive assessment

The current editor is considerably more capable than the brief's minimum. It has seven modular road types (Straight, Taper, Curve, S-bend, Hairpin, Bridge, Spline), independent pieces, endpoint and labelled geometry handles, snapping, overlap cycling, free/line/area paint, object variants and runs, multi-selection, asynchronous preparation, bounded history, WIP recovery, issue focusing, untimed practice and verified publication. Preserve these. No new geometry model or document version is needed.

The five highest-impact problems found in the inspected implementation are:

1. **Recovery has competing meanings.** `run_undo` changes committed history even with a pending road; Ctrl+Z instead deletes that preview. Both can traverse history during a live pointer transaction. Surface previews can disappear as a side effect of restoring unrelated history.
2. **Selection is too easy to turn into a road edit.** Objects use a six-unit movement threshold and snap the displacement; roads start at three units and snap the absolute position. An off-grid section can shift on the untouched axis. Its neighbours are independently stored and should stay exact.
3. **Camera discovery depends on recall.** Two-finger pan/zoom is described, but one-finger navigation competes with construction. Fit view takes Map → Fit view, and there is no visible touch alternative to multi-touch navigation.
4. **Editing context is incompletely retained.** The large view dictionary and separate restoration list omit settings such as road snapping; dormant tool orientation/paint protection and container colour can reset when the canvas is rebuilt. Tool choices must survive testing just as camera/history already do.
5. **System state is computed but mostly hidden.** Save-state logic builds useful messages, then hides the control except on errors. Road guidance does not progress from construction to closure/start/testing. Utility buttons default to 38 logical units, below the 48-unit design floor.

The corresponding improvements are: one undo policy, deliberate road dragging, two compact view controls, one shared view-state capture/restore contract, and concise visible save/progress feedback with adequate utility targets. These take priority over new art or a wholesale menu rebuild.

## Evidence and research

Sources checked on 2026-11-16:

| Primary source | Established recommendation / observed pattern | Application and limit |
|---|---|---|
| [Nielsen Norman Group: ten usability heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/) | Visible status, recognition, consistency, user control, error prevention and constructive recovery | Make pending work and saving legible; one history policy. Heuristics predict risks; they do not establish task success rates. |
| [Android: accessibility defaults](https://developer.android.com/develop/ui/compose/accessibility/api-defaults) | Effective targets at least 48dp; visual artwork may be smaller | Use a 48 logical-unit floor for editor utility buttons and existing 48–56-unit handle regions. Godot units are not automatically Android dp; confirm physical size on hardware. |
| [Game Accessibility Guidelines: simpler controls](https://gameaccessibilityguidelines.com/ensure-controls-are-as-simple-as-possible-or-provide-a-simpler-alternative/) | Complex combinations can exclude players; provide a simpler alternative | Provide single-pointer camera control alongside pinch. Preserve desktop alternatives. |
| [Godot: InputEvent](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html) and [ScreenTouch](https://docs.godotengine.org/en/stable/classes/class_inputeventscreentouch.html) | GUI consumes input before unhandled shortcuts; native touches have independent indices and a cancellation flag | Keep canvas input in `_gui_input`, respect cancellation, and keep text fields out of editor shortcuts. Avoid duplicate emulated mouse actions. |
| [Nintendo: Super Mario Maker manual](https://microsite.nintendo-europe.com/super-mario-maker-manual/enGB/page_01.html) | Recognizable palette, visible undo, immediate play and return to creation | Preserve the editor's palette and prominent Test. This is an observed first-party interaction pattern, not evidence that Beat My Track meets its timing target. |
| [Trackmania: map review](https://doc.trackmania.com/create/map-review/submit-your-map-to-map-review/) | Validated maps are saved before submission to review | Separate exploratory driving from publication verification. Do not copy its access restrictions or add local creation limits. |

Each source is paraphrased. No claim of having conducted a Trackmania or Mario Maker user test is made.

| Principle | Assessment specific to this editor | Decision |
|---|---|---|
| Discoverability | Illustrated pieces and labels work; view navigation and next construction step need help | Visible view controls and staged road guidance |
| Recognition over recall | Layer, width and curve handles already expose specialist functions | Retain labels; keep shortcuts as accelerators |
| Progressive disclosure | Selection replaces the bottom palette with relevant controls | Retain; Map holds infrequent document actions |
| Direct manipulation | Endpoints, radius, angle, width and spline points are already direct | Fix jitter; avoid mandatory number entry |
| Immediate feedback | Road ghosts and object outlines work; recovery state is hidden | Visible compact save text; leave renderer preparation distinct from durable saves |
| Consistency | Pointer cancellation largely works; toolbar/keyboard Undo differ | One implementation for both |
| Error prevention | Placement release and bridge/admission checks exist | Add release-bound checks and retain all admission gates |
| Reversibility | Committed edits use bounded history; previews need a deliberate first undo stage | Cancel current draft before traversing history |
| Interaction economy | Repeat object taps and automatic road continuation already work | Fit becomes one tap; keep frequently used palette stable |
| Spatial stability | Header responsive fitting and panels are already established | Keep control slots stable and error/status placement bounded |
| Accessibility | Pinch has no visible single-pointer equivalent; small utility targets remain | Move-view mode, Fit and 48-unit utility floor |
| Player satisfaction | Accidental changes and uncertain saved state undermine confidence | Predictability before decorative animation |

Error prevention, reversibility and recognition are the strongest priorities: a new player must safely explore the construction toy before optimizing it. Exact drag threshold, control placement, wording and finger occlusion are design hypotheses requiring device/player observation. An offset placement cursor is **not** added without evidence it improves this editor's tap-to-place accuracy.

## Audit of the complete experience

### Navigation and presentation

`core/features/editor.gd` builds the editor over the real 3D world. The left rail currently says Track / Surfaces / Objects. Track mixes roads with the start line; rename it Road to match the actual construction category. Illustrated road cards are useful recognition cues. The bottom contextual strip, object browser and property strip already use existing themes; preserve those rather than introduce a sidebar inspector. Selected category, asset and selection outlines exist. Secondary horizontal scrolling can hide advanced road choices on compact screens; this remains a P2 discoverability question.

Biome selection is a full, illustrated step **before** Create. Current biome is intentionally immutable during editing (`run_set_document_value` rejects theme/biome). Do not add a misleading fourth editing mode that cannot manipulate anything. Add the current biome's label to Map so the environment is identifiable. A true in-place biome conversion is P2 because surface meaning, scenery, valid object variants and fitted visual preparation all need deliberate conversion semantics. Existing tracks and initial biome choice remain compatible.

### Construction and geometry

Choosing a piece creates a preview; after the first piece it begins at the last piece's exit and inherits width/heading. Tap relocates; drag inside moves; endpoint dots reshape; labelled handles expose applicable dimensions; a check commits. The existing topological model deliberately adjusts only the selected piece. A connected attachment stays anchored for local shape changes. Neighbours are not stretched to fill gaps. Open ends become issues; Connect repairs a nearby endpoint and Layer resolves overlap. Deletion produces an open end rather than silently bridging it. Preserve this predictable model.

The check control also deselects an already placed piece; this is not a second commit. Selection and movement share a pointer gesture, so jitter protection matters. Loop routing and checkpoints are generated by existing `RoadPieces.route_from_pieces` / compiler logic; players should not author navigation data. Bridges retain independent height/overpass validation.

### Touch, surfaces and objects

Native fingers are indexed, emulated mouse input is filtered, a second finger rolls back an active edit and converts to navigation, and application pause/focus loss rolls back the pointer transaction. Keep these controls. Check release bounds so a confirm tap dragged away cannot commit on release. Pinch must never stamp or paint. New Move-view mode is temporary camera intent over the same tool state, not another editing tool.

Free painting commits a stroke; line/area painting retain preview points until confirmation. Erasing is biome-aware restoration, not destructive removal of road pieces. Keep-road protection and surface modes exist. Objects have explicit Place/Select, repeat placement, runs, variant/rotation/size controls, group edits and enlarged hit testing with deterministic overlap cycling. Preserve explicit placement intent rather than auto-selecting an occupied object. Selected objects are outlined; no extra permanent on-canvas mini-panel is warranted.

### Test, save, validation and publication

Test already enters untimed practice; Edit here returns to the actual editor. Camera, document, session history and active tool generally survive. Complete the settings contract instead of changing the flow. Partial/open roads may be explored in practice; publishing still requires the existing closed route and verified drive. Do not make practice depend on publishing slots. Current issue focusing selects the relevant piece/object and supplies repair copy. WIP writes are separate from explicitly named originals, and exit/save dialogs protect unsaved work. Keep this distinction in a compact status line.

Cloud publication and external sharing are audited locally via existing lifecycle/fixtures only; this task does not publish a real track or contact an account service.

## Recommended cohesive interaction model and UI

The full-screen canvas stays primary. Left: Road / Surfaces / Objects, with one clearly selected category. Bottom: the active tool palette or selection controls. Header: track identity, Undo/Redo, issues, Map, Save, Test, Publish and Close. Use existing selected/pressed/disabled states and typography. Right lower edge: **Move view** toggle and **Fit view**, sharing the existing palette's safe margins. Compact non-interactive save text sits under the header; failure replaces it with a large Retry action. Guidance names the next construction step. Map shows biome and secondary document actions.

Tap a road card → manipulate its preview → check to place → choose the next card. Tap a placed piece → drag only after deliberate movement → release commits one edit. Empty ground pans outside placement modes. Move view allows any canvas drag to pan without altering the active selection, mode or previews; tap it again or choose another editing category/card to resume building. Pinch, wheel and desktop pan remain available. Fit never modifies the document or history.

Undo priority: active gesture rollback → active road preview discard / last line-area point removal / pending run cancellation → resolve hidden previews explicitly → undo committed edit. Redo cancels an active pointer first and refuses to overwrite a pending preview. Both toolbar and keyboard use that policy. Existing committed edits retain normal redo. Previews are not saved-track edits; cancelling them does not add document history.

Test is one action for a committed locally testable track. Pending work must be explicitly confirmed/discarded; no silent geometry commit on Test. Return preserves view and tool parameters. Issues retain location-based repair; publication retains the existing local verification, authentication and slot rules. Local creation stays unrestricted by publishing capacity.

## Interaction specifications

| State / interaction | Initial state and action | Immediate feedback → result | Cancel / undo | Edge cases |
|---|---|---|---|---|
| Idle / choose Road | Blank canvas; tap Straight/Curve | Preview and local handles appear; Road remains selected | Cancel/Undo discards preview | First piece stays in usable canvas area; later choices use last exit |
| Placement preview | Drag body/end/width/curve control; release | Preview moves/reshapes; snap remains visible | Second finger, focus loss or cancelled release restores prior preview | Bounds, admission, bridges retain existing validation |
| Confirm | Tap preview check | One committed piece; next-step guidance and save state update | Undo removes that piece; Redo restores it | Release outside check cancels activation |
| Element selected | Tap a piece/object | Selection outline and relevant controls | Tap away / Escape clears selection without mutation | Nearest hit wins; Layer/Next object resolves overlaps |
| Dragging | Deliberate movement beyond threshold | Only selected geometry changes; live feedback | Cancellation restores exact original; one Undo restores whole released drag | Snap displacement; preserve untouched coordinates and neighbours |
| Invalid placement | Move/confirm outside valid geometry/budget | Keep last valid geometry; visible reason | Cancel returns to prior state; no empty history entry | No assertion/budget weakening |
| Paint preview | Add line/area points, move dots | Pending surface visible; confirm shown when applicable | Undo removes one point; cancel discards; confirmed stroke is one history item | Degenerate/self-intersecting areas stay uncommitted |
| Object placement | Place selected asset on empty ground | One object; same asset remains armed | Undo removes the committed stamp | Occupied tap explains Select; large drag navigates, no accidental stamp |
| View navigation | Toggle Move view, drag / pinch / Fit | Selected toggle/camera responds; authoring state retained | Toggle off or select tool; no document Undo entry | Two fingers always cancel active edits; no phantom release stamp |
| Test / return | Tap enabled Test; use Edit here | Untimed practice; return to same camera/tool/settings/history | Existing practice exit; local saved copy protected | No slot check for local practice; incomplete previews remain explicit |
| Save / error | Edit, Save, failure or retry | Draft/saving/saved/pending status; failure Retry | Existing exit Cancel/Discard; history independent | Late writes fenced to document/storage; never label an unfinished write saved |
| Validate / publish | Tap issue or Publish | Focus affected selection; verified-publication flow retained | Existing confirmation cancel | No live upload in automated tests; slots apply only to publication |

## Prioritized implementation backlog

Complexity/risk are relative engineering assessments, not time estimates. Acceptance checks are automated where deterministic and visual where spatial.

| ID / priority | Issue and current behaviour | Proposed behaviour | Principle / benefit | Complexity / risk | Acceptance criteria | Components | Status |
|---|---|---|---|---|---|---|---|
| UX01 P0 | Toolbar Undo can delete committed work behind preview; shortcuts differ; live drag unsafe | One preview-aware history policy, gesture cancellation first, non-destructive Redo guard | Reversibility; safe exploration | Medium / medium | Toolbar and Ctrl+Z preserve committed document while cancelling active preview; area Undo removes last point; cancelled drag preserves redo; normal undo/redo exact | `core/features/editor.gd`, canvas, session | Implemented; validated below |
| UX02 P0 | Road starts at 3 units; absolute snap shifts stationary axis | Six-unit road threshold and displacement snapping | Error prevention; accurate selection | Low / medium | Four-unit jitter exact; deliberate off-grid move preserves stationary coordinate; neighbour bytes exact; cancelled drag exact | `editor/editor_canvas.gd` | Implemented; validated below |
| UX03 P0 | Canvas confirm release lacks explicit release-target check | Check release bounds before committing tap actions | Consistency; prevent accidental commits | Low / medium | Road/paint confirm released outside does not commit; touch cancellation and pinch never place | `editor/editor_canvas.gd` | Implemented; validated below |
| UX04 P1 | Pinch is required for reliable touch camera navigation; Fit nested | Two small labelled view controls independent of authoring mode | Accessibility/economy; one-pointer access | Medium / medium | Move view pans road/paint/object modes without document/history/previews changes; Fit one tap; choosing category/card exits navigation; safe-area bounds at 960/1280/wide | Canvas, editor composition | Implemented; validated below |
| UX05 P1 | Parallel capture/restore lists lose tool parameters | Shared view-state helper | Consistency/stability; seamless return | Medium / medium | All captured parameters round trip including dormant orientation, colour, snap and road protection; camera/history retained through actual practice return | New `editor/view_state.gd`, App, editor | Implemented; validated below |
| UX06 P1 | Save status hidden except failure; 38-unit Map utilities | Quiet visible save label, unchanged Retry path, 48-unit utility floor | Status/accessibility; confidence | Low / medium | Saving/pending/WIP/original distinguishable; normal status ignores input; error action ≥48; Map controls ≥48; no new overlap at tested sizes | Editor composition, `editor_style.gd` | Implemented; validated below |
| UX07 P1 | Track label broad; construction hint never advances | Road label; closure/start/continue guidance, active-view guidance; biome identity in Map | Recognition/feedback; obvious next step | Low / low | Blank directs first piece; connected loop directs start/test; unclosed road identifies open ends; no closed-loop claim for disconnected loops | Editor composition | Implemented; validated below |
| UX08 P1 | Cross-system regression risk | Focused scenario suite plus existing road/paint/practice/workflow/publication/parser regressions and native captures | Reliability; retain functioning tools | Medium / low | Record actual receipts, original controls, failed attempts and limits; no Android/player-time claim | `tests/test_editor_ux_2026_11_16.gd`, evidence | Validated with broader findings retained |
| P2 | Compact road strip hides far-end choices | Study basic/advanced grouping or visible scroll affordance | Discovery | Medium / medium | New players find every road without instruction; preserve expert speed | Road palette | Deferred hypothesis |
| P2 | Biome only chosen before Create | Design explicit undoable conversion before adding fourth category | Consistency | High / high | All biome surfaces/variants convert deliberately; no data loss | Creator/document/compiler/world | Deferred |
| P2 | Precision under finger / repetitive road choice | Device study of offset cursor and repeat-road action | Accuracy/economy | Medium / medium | Measured selection accuracy/tap reduction improves without competing placement models | Canvas/palette | Deferred hypothesis |

## Task-based heuristic assessment and workflow counts

Counts are deterministic minimum UI actions from an editor state, excluding deliberate geometry drags, driving time, startup, naming and menu entry. They are not measured player time. A gesture counts once.

| Scenario | Baseline steps / finding | Target after changes |
|---|---|---|
| First closed track | Four 90° curve defaults at shared radius: card + check ×4, Start line + ground tap, Test = 11 actions; default corners form a circle. Initial biome selection/Create adds 2 when default biome accepted | Same 11 authoring actions; staged next-step copy. Do not claim two-minute success without novice study |
| Adjust a curve | Select + drag handle = 2; jitter can modify off-grid section | Same 2; deliberate threshold, neighbouring pieces exact |
| Insert/remove section | Select + Delete = 2; replacement card + move/reshape + check; gaps remain explicit | Same geometry model; immediate Undo recovers; no unrelated deformation |
| Decorate | Objects + family/page + asset; repeat empty taps place; properties exposed only when relevant | Retain repeated stamps and runs; settings survive view rebuild/practice |
| Accidental change | Undo one tap, but preview may cause unrelated history loss | Undo one tap always addresses current pending operation first |
| Pan/zoom | Pinch one gesture; PC right/middle/Space and wheel; Fit 2 taps | Same gestures plus Move view toggle + drag; Fit 1 tap |
| Test and return | Test + Edit here = 2 control activations; some dormant settings lost | Same 2; complete view-state contract and history retained |
| Fix invalid track | Issue → move/Connect/Delete; current issue centering/copy exists | Preserve actionable focus and explain progress; verify no concealed pending preview loss |
| Experienced second track | Existing New → biome/Create; shortcuts 1–4, Q/E, Enter, Tab, Ctrl+Z/S | Same efficient accelerators; keyboard and touch history semantics agree |

## Validation record and remaining acceptance

UX01–UX07 are implemented and pass their desktop acceptance sequences. UX08 retains the broader gate findings below. Physical-device and real-player acceptance are outstanding. The first attempt to reuse `review_track_editor_2026_10_28.gd` hit a stale fixture: it did not await the now-asynchronous `_show_screen`, so `editor_world` was nil. The new harness uses the current awaited navigation contract; production is not changed to accommodate the old harness.

Required local checks: all seven road types and neighbours, closed loop, preview cancellation and actual pointer events, area/free painting, objects/runs, undo/redo, view navigation, serialization/WIP recovery, practice return, validation/local publication, production parse. Native before/after views at 960×540, 1280×720 and 1560×720, plus simulated safe-area insets. Desktop Compatibility and Mobile renderers are desktop tests. Physical dp size, display cutouts, sustained mobile response, finger occlusion, translations and real-player timing/satisfaction remain separate acceptance.

### Measured before/after and review

| Case | Original observation | Implemented observation |
|---|---|---|
| Four-pixel road jitter | `[-30.23, 0.37]` became `[-29.5, 0.5]` | Coordinates stay exactly `[-30.23, 0.37]` |
| Deliberate horizontal road drag | Absolute snap could move the stationary axis | `[-30.23, 0.37]` → `[-28.23, 0.37]`; neighbour exact |
| Toolbar Undo with a road preview | Removed the preceding committed object edit | Cancels preview; committed document and history retained |
| View reconstruction | Road snapping and inactive paint protection returned to `true` | Both remain `false`; dormant orientation/colour retained |
| Fit view | Map → Fit view, 2 taps | Fit view, 1 tap; removed duplicate Map entry |
| Closed default loop | Source-derived 8 road actions | Scripted four card choices + four confirm touches produce one closed connected lap; Undo/Redo exact |
| Practice return | Existing return flow, incomplete preference contract | Actual Test → Edit here retains document/history, zoom and dormant settings |

Native review retained the full-screen world, illustrated palette, existing geometry handles, header hierarchy and existing material language. Two view controls occupy the already reserved right gutter. The selected Move view state needed an explicit style refresh after enabling toggle mode; the final Mobile capture shows the cyan state clearly. Normal save state is a quiet non-interactive label; Retry remains an action only on failure. Map utilities are 48 units high and its scrollable content is capped to the available height. No extra modal or inspector was added to ordinary editing.

Before: [road construction](evidence/track-editor-ux-2026-11-16/before/01-road-idle-1280.png), [preview](evidence/track-editor-ux-2026-11-16/before/02-road-preview-1280.png), [compact objects](evidence/track-editor-ux-2026-11-16/before/06-objects-960.png).

After: [road construction](evidence/track-editor-ux-2026-11-16/after-mobile/01-road-idle-1280.png), [compact camera mode](evidence/track-editor-ux-2026-11-16/after-mobile/07-view-mode-960.png), [connected loop](evidence/track-editor-ux-2026-11-16/after-mobile/10-closed-loop.png), [return from actual practice](evidence/track-editor-ux-2026-11-16/after-mobile/09-practice-return.png), [surface preview](evidence/track-editor-ux-2026-11-16/after-mobile/04-surface-preview-1280.png), [simulated safe insets](evidence/track-editor-ux-2026-11-16/after-mobile/08-simulated-safe-area.png).

### Commands and interim receipts

All engine runs use the pinned `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`. Every new App fixture sets offline transport and workspace-owned track/record/cloud paths before startup. No owner data, real publication, deployment or owner process was changed.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_ux_2026_11_16.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_ux_2026_11_16.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File .tmp/track-editor-ux-20261116/validate.ps1
```

The batch invokes `TestScript` sequentially for `test_road_pieces`, `test_editor_workflow`, `test_surface_modes`, `test_editor_interactions_2026_11_14`, `test_local_draft_publication` and `test_editor_shipping_parse`; raw receipts are in [validation](evidence/track-editor-ux-2026-11-16/validation/). Final outcomes follow after completion.

The initial new headless run passed 109 of 110 checks and caught a single-precision Vector2 conversion on an untouched encoded road coordinate. The implementation now preserves original array values on the stationary axis; the exact check stays unchanged. An interaction-suite attempt during development retained its source-stability failure because files were still being edited. Its interaction assertions passed, but that run is not accepted as final. The first workflow run was 253/1 solely because it expected the intentionally replaced Track label; the test now checks Road with the same visibility condition.

New copy has eight authored messages in all twelve existing locales: 96 scoped catalogue/placeholder checks pass. The general translation-authoring suite has four errors on the **existing** tab-separated `scripts/translations/track_editor_review_fixes.tsv`, which its pipe-only reader rejects. This file is not changed or normalized by this task. Scoped additions parse without duplicates. Encoding unit tests pass 7/7 after using the scripts directory as their import root; the initial repository-root invocation failed its Python import path.

The surface fixture also needed to await the existing asynchronous `_show_screen` contract and bounded preparation before authoring. Its original failed invocation is retained; all substantive checks remain, and three readiness assertions were added. Final surface **53/0**, retained interaction **154/0**, workflow **253/0**, mocked local publication **31/0** and production parser **582/0** pass. The interaction rerun caught a newly introduced node-capturing Map layout lambda during rapid page replacement; a guarded bound callback replaces it, and the complete 154-check suite now exits cleanly.

The broad road suite retains **377 checks / 6 failures** on the exact rendered kerb-vertex comparison for radii 8/16/30 and both mirror directions. Its other 371 checks pass, including default/edited road geometry, snapping, serialization and two five-lap race probes with zero contacts. `road_pieces.gd`, `track_compiler.gd`, `native_track_visual.gd` and `road_surface_height.gd` are unmodified by this pass. The failing suite does not reference the edited UI/input classes. This is retained as an unqualified broader rendering gate; no expected vertex, lift, equality tolerance or assertion was changed.

### Delivery files

| Area | Files and purpose |
|---|---|
| Input and geometry manipulation | `game/editor/editor_canvas.gd`: camera intent, release-target guards, road jitter threshold and exact displacement-based movement |
| State | `game/editor/view_state.gd` plus one editor-specific line in `game/core/app.gd`: symmetric transient capture/restore, no saved-track format change |
| Presentation and commands | `game/core/features/editor.gd`, `game/editor/editor_style.gd`: common Undo policy, view controls, save feedback, bounded Map menu, road progress and utility sizes |
| Copy | `scripts/translations/track_editor_ux_2026_11_16.tsv`, twelve `game/localization/*.po`: eight new messages, with every preceding catalogue byte retained |
| Regression coverage | `game/tests/test_editor_ux_2026_11_16.gd`; `test_editor_workflow.gd` updates the deliberate Road label; `test_surface_modes.gd` awaits existing asynchronous navigation/readiness |
| Review | This plan, marked project status entries, `scripts/checkpoint_track_editor_ux.py`, native evidence and a forward/reverse-checked private source patch |

The App file also changed concurrently for header-picture loading. Only its editor-view capture line belongs to this pass. The private patch reconstructs its baseline from the current App with just that line reversed, so concurrent header work is exact on both sides. Generated build identity/version changes from the normal dev wrapper are retained and excluded from the authored patch.

### Remaining issues by priority

1. **P1 broader rendering gate:** investigate the six exact kerb-vertex failures before claiming full road-render qualification. This task does not alter their renderer/compiler inputs or redefine their expected geometry.
2. **P1 device acceptance:** measure effective dp targets, display cutouts, finger occlusion, pinch reliability, cold preparation, sustained frame time and responsiveness on Android hardware. The 48 logical-unit utility floor is not a claim that every physical device has passed 48dp sizing.
3. **P1 usability acceptance:** observe first-time players creating, testing and recovering a track without instruction; measure completion time/actions/errors and confidence. The scripted eight road actions and eleven-action minimum workflow do not verify the two-minute player target. Test creative depth and satisfaction in a thirty-minute session separately.
4. **P2 toolchain:** repair the unrelated pipe/tab mismatch in the existing translation-authoring input. All eight new rows and all twelve catalogue additions pass scoped checks; new copy still needs human language/fit review.
5. **P2 design hypotheses:** in-place biome conversion, compact advanced-road discovery, repeat-road controls and offset placement cursor require the studies/conversion semantics specified above. No competing placement model was added.

### Final acceptance receipts

| Validation | Final result |
|---|---|
| New UX sequences, desktop Compatibility | **134 checks / 0 failures** |
| New UX sequences, desktop Mobile | **134 checks / 0 failures** |
| Existing construction/workflow | **253 / 0** |
| Surface modes, painting/erasing and protection | **53 / 0**, including three added readiness checks |
| Retained interaction regressions | **154 / 0**, including its original source-stability check |
| Local publication, mocked service | **31 / 0** |
| Production script parser | **582 scripts / 0 failures** |
| Scoped authored messages | **96 / 0**, eight messages × twelve locales; original catalogue bytes retained |
| Encoding unit suite | **7 / 0** |
| Broader road suite | **377 / 6**, retained kerb-vertex gate findings described above |
| Existing translation-authoring suite | **7 tests / 4 errors**, retained pre-existing tab/pipe input mismatch |
| Pinned import | Passed |
| Visual review | **33 native PNGs**: seven before, thirteen after per desktop renderer |

The final three extra UX assertions verify that Undo resolves a preview hidden in another category, gives Undo-specific copy, and that cancelling that dialog preserves the hidden area. Compatibility was repeated after that last copy/check addition; both final renderer receipts are 134/0. Earlier 122/0 and 131/0 native runs and the rejected development attempts remain recorded, rather than being substituted for final coverage.

See [delivery.json](evidence/track-editor-ux-2026-11-16/delivery.json), [raw validation logs](evidence/track-editor-ux-2026-11-16/validation/), [image hashes](evidence/track-editor-ux-2026-11-16/native-images.json), [final source fence](evidence/track-editor-ux-2026-11-16/validation/source-fence.json) and [source checkpoint](evidence/track-editor-ux-2026-11-16/source-checkpoint.json). The private source patch is [source.patch](evidence/track-editor-ux-2026-11-16/source.patch). Its isolated repository verifies forward/reverse byte equality and whitespace; the shared index is not used for staging or committing.

Final checkpoint command: `python scripts/checkpoint_track_editor_ux.py`. The normal dev entry point ran standard build retention; recent/protected concurrent outputs remain above the target, and no task pin was created. Reload/rebuild the client to use these changes. There was no Android device test, export, live request/publication, deployment, owner-save edit or owner-process restart.
