# Restrained editor jumps and natural bumps — 27 October 2026

EJS01–EJS04/Q01 implement the owner's request to reduce exaggerated jumps and offer different shapes, especially low Desert bumps.

New placements use **Low ramp** outside Desert and **Sand rise** in Desert. Under Objects, choose **Jumps & bumps**, then tap the selected tile again to choose a style. A selected placed jump has a direct style selector. Copy, size/rotation, undo/redo, pending tool state, test-drive return and local JSON keep the profile with the object.

| Style | Standard footprint, length × width | Height | Response |
|---|---|---|---|
| Low ramp | 6 × 5 m | 0.30 m | Small directional hop |
| Short kicker | 5 × 5 m | 0.48 m | Firmer short hop |
| Tabletop | 10 × 8 m | 0.36 m | Rounded approaches and flat crown; grounded |
| Rounded bump | 6 × 8 m | 0.16 m | Smooth two-way grounded rise |
| Sand rise | 12 × 10 m | 0.26 m | Broad rounded sand form; grounded |

The standard low ramp peaks at 0.344 m and the kicker at 0.637 m for a 14 m/s initial approach in the focused test. Their sampled high-speed peaks are bounded at 0.424/0.718 m. These are measured car heights above the ground, including the ramp height. Rounded profiles grant no canonical airtime or steering immunity. Sizes deliberately scale the authored geometry.

The formed decks remove the large arrow and external framing. Rounded earth profiles meet the ground at both ends and along their shoulders. Upward deck normals remove the initial diagonal striping. Sand shares the original compacted-road pigment/texture and fades only at the zero-height perimeter, retaining actual curved geometry and lighting.

The optional `jump_profile` field contains explicit versioned IDs. Omitted data preserves the original footprint, launch arithmetic, support and pitch exactly; existing files are not migrated or rewritten. Existing ramps become smaller only when the owner chooses a new style; Undo restores the exact original object without adding a profile. Other tracks, car hashes, shared physics/rules and compiler identifiers are unchanged. The new field changes its own document/content hash. `stage_verifier.py` includes the pure profile helper; editor controls live in a separate file and are not shipped in the data-only worker.

Actual checks, commands, source hashes and results are in [report.json](evidence/editor-jump-styles-2026-10-27/report.json). The focused suite covers JSON-input replay, rewind, live/frozen-worker state equality, rotations/scales, validation, mesh/support agreement, upward normals, edge blending, real palette and selected-object signals, persistence, copy and undo. It passes 3,312 headless checks and 3,316 checks in each desktop renderer. The actually staged data-only project checks all five profiles and seven cars across 10,500 exact state comparisons. Retained hazard212, App141 and parser1351 checks pass. The old speed-bump-width suite retains five failures in 362 checks, reproduced with task-start versions of the edited sources in an isolated project; no assertions were weakened. Source stability is recorded in the report.

Native views: [Compatibility comparison](evidence/editor-jump-styles-2026-10-27/gl_compatibility-profile-comparison.png), [Mobile comparison](evidence/editor-jump-styles-2026-10-27/mobile-profile-comparison.png), [Desert editor](evidence/editor-jump-styles-2026-10-27/gl_compatibility-desert-editor.png), [sand rise detail](evidence/editor-jump-styles-2026-10-27/gl_compatibility-sand-rise-detail.png). The comparison uses identical studio framing; the editor captures use the production planning camera. The straight test strip intentionally has no closed timed route, so its issue count is expected. Mobile means the desktop Vulkan Mobile renderer, not a phone measurement.

The logs retain the existing sandbox certificate error, initial fixture path/CRLF/StringName mistakes, the rejected striped surface, intermediate concurrent sign-in import errors and the first worker-import editor-settings write denial. Final assertions are distinguished from these initial attempts. [task.patch](evidence/editor-jump-styles-2026-10-27/task.patch) contains this task's runtime/schema/test changes; a disposable Git repository checks it against normalized task-start files. Concurrent account-layout and road-material edits in App are preserved and excluded from that patch.

Reload/rebuild the client to use the changes. Online publication of the new profile field needs a matching backend rollout, which was not performed. Owner appearance/feel and physical-device input, motion and performance acceptance remain. No physical-device attachment check or test, APK, live service change, purchase/authentication, owner-save change, owner-process restart, root-index staging, commit or merge was performed.
