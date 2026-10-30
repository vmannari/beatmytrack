# Track editor review fixes — 28 October 2026

Seven findings from [the review](TRACK_EDITOR_REVIEW_2026_10_28.md) are corrected. TER-P01 has working preparation optimizations, but its long width-update and cold-practice waits remain open. The final stress observation is 4.95 s / 26.97 s; this pass does not establish an end-to-end latency improvement over the original review's 4.33 s / 26.87 s. No phone test was performed.

## Changes and remaining work

| Finding | Result |
| --- | --- |
| TER-C01: accepted edits exceed recoverable limits | Aggregate road length, paint points, object/tyre/memory capacity, hidden scenery and compact UTF-8 size are admitted before confirmation. Rejection retains pending work. Committed property edits and released drags also pass admission, with rollback on rejection. Near the byte ceiling, admission checks the exact derived lap that the writer will save. Existing limits remain. |
| TER-C02: cancellation commits | Esc, platform cancellation and explicit gesture cancellation restore the captured domains and cancel the history transaction. They do not emit a successful finish or autosave moved data. |
| TER-C03: accept overlaps direction | The square acceptance target moves clear of the start-arrow circle. Drawing and input use the same rectangle. Real taps are checked across eight headings and three scales. |
| TER-U01: Night too dark | Night defaults to brighter authoring illumination. Map → Race lighting restores the exact original race lighting; switching back restores authoring light. Track/race lighting and saved data are unchanged by this control. |
| TER-P01: preparation waits | Optional native packed-stream copying/splitting preserves exact arrays and upload limits. Native edge sampling decodes outline dictionaries once per call. Graphics preparation shares equivalent material programs and skips repeated batches after a bounded draw. Stress batches fall from 70 to 34; the final covered world/effect draw remains. **Cold readiness and final width-update latency are still unresolved.** |
| TER-P02: synchronous large history | Immutable 64-object blocks reuse unchanged values and allocation accounting. An exact initial checkpoint is prepared during editor setup. Forty 4,096-object captures measure 3.139 ms median / 4.209 ms p95 / 5.270 ms max, versus the review's 11.647 / 18.249 / 20.451 ms. Setup costs 24.258 ms before pointer input. Conservative retained accounting rises to 4,791,792 bytes, within the original shared 8 MiB bound and 40-state limit. |
| TER-U02: invisible rejection | Parameter and geometry rejection use the visible editor hint path. |
| TER-C04: Share excludes previews | Share resolves active and hidden road, paint and object-run previews through Confirm / Discard / Cancel. Confirm saves the committed document; Discard removes pending work; Cancel retains it. The current modal is hidden before opening the next one. No actual share, clipboard or external message was invoked by the checks. |

The two new interface strings have entries in English and all eleven other approved catalogues. The translation sheet and focused checks are retained; this does not make the wider catalogue audit green.

## Verification

The pinned engine is `4.7.2.stable.official.ed1daf0bf`. Direct runs use isolated offline workspace profiles and Dummy audio. The preferred `scripts/dev.ps1 -Action CheckScript -ScriptPath res://tests/test_editor_admission_bytes.gd` also passes. Its generated project/build-identity bytes were archived and restored only after matching that invocation's receipt.

| Check | Actual result |
| --- | --- |
| Focused correctness, gestures, lighting and Share | 78 checks, zero failures in each of headless, Compatibility and desktop Vulkan Mobile |
| Durable byte boundary, including route expansion | 10 checks, zero failures; 1,048,519-byte admitted document round-trips exactly |
| Graphics preparation and final native pixels | 91 checks, zero failures in each graphical renderer |
| Packed stream equivalence | 41 checks, zero failures |
| Native/scalar roads, five themes, spline and bridge fixtures | 115 checks, zero failures |
| Retained workflow | 254 checks, zero failures |
| T05–T11 history, editing and memory | 321 checks, zero failures |
| T11–T15 session, gestures and ownership | 305 checks, zero failures |
| Existing save/recovery review fixes | 69 checks, zero failures |
| Regional road preparation | 269 checks, zero failures |
| Current creator capacity corpus | 2,730 checks, zero failures; six currently selectable cars |
| Retained App stress profile | 60 original assertions, zero failures |
| App | 141 checks, zero failures |
| Compiler raster goldens | 8 checks, zero failures; no regenerated goldens |
| Tyre equivalence | 13,200 exact whole-state comparisons |
| Exportable source parse | 486 scripts, zero failures |
| Actual editor views | Six saved captures per graphical renderer, zero capture failures |
| Windows and Android ARM64/x86-64 native builds | Pass; both Android ELF load segments retain 16 KiB alignment |

The unmodified whole-tree parser reports **one failing frozen Garage fixture** among 1,411 scripts: `tests/fixtures/parking_hall_before/garage_page.gd` calls the removed `_build_wash_requirement()`. Its dependent fixture App also emits a compile diagnostic. This pass preserves that failure; the separate exportable-source check explicitly excludes test fixtures. The current full localization audit reports **1,045 errors outside these two added messages**. Neither wider check is reported as passing.

The original review's `ellipse.json` practice witness failures remain recorded and are not reclassified by this pass. Successful retained editor-practice assertions do not establish that the original witness is fixed. The sandbox root-certificate-store diagnostic remains in direct logs. Earlier fixture/profiler parse errors, an accidentally requested nonexistent `test_app_flow.gd`, a slow byte-fixture construction stopped by its own PID, and the first Share modal diagnostic are retained; corrected final runs are identified separately. No assertion in an original test was removed or weakened.

## Performance evidence

The final 96-section Compatibility run retains 85 of 104 road nodes, with 18 uploads and 50 reuses. Width completion takes 4,948.597 ms. Synthetic drag handlers remain short: mean 0.557 ms / p95 0.865 ms. First practice takes 26,967.598 ms; repeat takes 2,023.555 ms; editor return takes 16.294 / 17.898 ms. Graphics preparation uses 34 batches on first entry and zero on repeat. The shared final covered preparation takes 9,314 ms on first entry; that includes effects and finishes, not isolated bridge GPU time.

The native splitter removes per-element script dispatch and produces byte-identical streams on the exercised channel/index/tile corpus. History measurements are isolated; other capacity-suite timings are not substituted for that profile. Earlier task runs vary between about 27 and 34 s for first practice and 4.6–6.2 s for width completion. Reduced work counts and faster components do not justify a reliable cold-latency claim. Outstanding work is a narrower profile and correction of compiler/preview work and actual cold rendering, while retaining cancellation, exact geometry, bounded residency and the covered final draw.

## Reviewable checkpoint and scope

Commands, exits, source hashes, observations, before copies, initial attempts and limitations are in [report.json](evidence/track-editor-fixes-2026-10-28/report.json). [task.patch](evidence/track-editor-fixes-2026-10-28/task.patch) contains only this task's source changes against captured task-start files. All 34 files are explicitly checked with isolated `git apply --check --verbose --whitespace=error-all`. It is a source checkpoint; native binaries are rebuilt from these sources, with active library hashes recorded separately.

App and Canvas are shared with concurrent editor, Garage, vehicle and Rivalry work. The checkpoint reconstructs only this task's hunks; current integrated files remain intact and their hashes are recorded independently. The two source-inventory entries already collected by concurrent localization work remain in `messages.pot`/`en.po`. No main-index staging, commit, merge or reset occurred.

Shipping changes are the App/Canvas admission and controls, EditorWorld lighting, history/session/memory, RoadSections, WorldRenderPreparation, the native stream helper/bindings and outline decoding. Native provenance and generated platform libraries refresh. Simulation, canonical handling, compiler/rules versions and published track contracts receive no intentional change from this task.

Native screenshots: [separate controls](evidence/track-editor-fixes-2026-10-28/native/gl_compatibility/01-separated-road-controls.png), [Night authoring](evidence/track-editor-fixes-2026-10-28/native/gl_compatibility/02-night-authoring.png), [lighting toggle](evidence/track-editor-fixes-2026-10-28/native/mobile/03-night-lighting-toggle.png), [race preview](evidence/track-editor-fixes-2026-10-28/native/gl_compatibility/04-night-race-preview.png), [Share resolution](evidence/track-editor-fixes-2026-10-28/native/mobile/05-share-preview-resolution.png).

Remaining acceptance includes reload into the rebuilt client, owner appearance/interaction approval and physical-device latency, gestures and long-session memory. No device attachment query/test, APK, authentication/purchase, owner-save/backend mutation, deployment or owner-process restart was performed. Desktop Vulkan Mobile is not a phone result.
