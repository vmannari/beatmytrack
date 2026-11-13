# Road-piece materials — 2026-10-27

RPM01: In Track, select a placed road piece or an unplaced preview, then choose
**Asphalt** or **Gravel**. These controls are available in Grass and Storm. They
change that piece only. Selecting the current material preserves the highlighted
choice without adding a history entry.

RPM02: The optional piece `surface` field accepts only `asphalt` and `gravel`.
Omission inherits the document's existing material; legacy `dirt` maps to the loose
surface. The normal WIP save, JSON exchange, undo/redo and Test drive paths retain
the choice. Other themes retain the stored selection but use their existing biome
material. The current v5 JSON schema documents this optional extension.

RPM03: Gravel uses native surface 2, including the existing 0.8 grip and 2.0
resistance. No car configuration, shared physics arithmetic or rules version is
changed. Ground pieces use joined mouths for both material classification and
presentation. Gravel bends omit asphalt kerbs and white edge markings. The stone
finish is matte and darker in Storm. Mixed roads share a continuous five-centimetre
roadbed so changing the finish does not create a height step.

RPM04: Bridge material belongs to its deck and ramp approaches; the ground below
remains independent. Shader material flags, preview masks, section-cache inputs
and first-transition dirty-tile handling cover material edits. Visual kit 215
invalidates older disposable road meshes. Existing creator documents without this
field retain compiler-27 and their canonical output/content hashes; selected
materials enter the ordinary document hash. The existing eight complete-track
goldens and 377 road-piece checks pass without regenerated fixtures.

The runtime scope is `game/core/app.gd`, the editor's `road_pieces.gd`,
`track_compiler.gd`, `editor_canvas.gd`, `creator_preview_masks.gd`, `road_update.gd`,
and the track's `native_track_visual.gd`, `creator_road.gdshaderinc`,
`road_surface_height.gd`, `road_kerbs.gd`, `creator_bridges.gd`,
`creator_bridge_visual.gd`, `bridge_road.gdshaderinc`, `surface_detail.gdshaderinc`
and `surface_shader_variants.gd`. The focused test is
`game/tests/test_road_piece_materials.gd`. Format documentation and the v5 JSON
schema are updated. Concurrent jump-profile and guardrail changes are preserved
and excluded from this task's source patch.

Actual checks use the pinned Godot 4.7.2 build through `scripts/dev.ps1`. All App
saves and caches use task-specific `APPDATA` directories under
`build/road-piece-materials-2026-10-27`. The API URL is empty. Results, screenshots,
safe synthetic requests and the source-only patch are in
`docs/evidence/road-piece-materials-2026-10-27`; `report.json` records exact logs,
source hashes and final results.

- Focused headless: 120 checks, zero failures. Covers every ground piece kind,
  independent bridge layers, strict invalid values, material seams, cached
  recompilation, save/reload, actual controls, undo/redo and actual Test drive.
- Compatibility desktop: 128 checks, zero failures, including every shape and
  repeated material selection, with native screenshots and actual Test drive.
- Mobile desktop: 102 checks, zero failures, with native screenshots and actual
  Test drive in both themes. This renderer runs on the desktop GPU.
- Existing road pieces: 377 checks, zero failures, including five-lap drives.
- Existing compiler raster: eight original complete-track goldens, zero failures.
- Existing editor workflow: 254 checks, zero failures.
- Existing App: 141 checks, zero failures.
- Full GDScript parser: 1,345 scripts, zero failures after concurrent class import.
- A separately staged, presentation-free verifier with 89 canonical inputs
  accepts both synthetic material documents. Both content hashes match the client
  exactly. This is local canonical verification, not a live publication.
- The schema's optional material enum matches the runtime enum. Full Python
  `jsonschema` validation was unavailable because that package is not installed;
  no dependency was added.

Commands used (each engine test uses the task-specific APPDATA described above):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_road_piece_materials.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_road_piece_materials.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_road_piece_materials.gd -Graphical -RenderingMethod mobile -EngineVerbose
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_road_pieces.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compiler_raster.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_workflow.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_app.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
python backend/deploy/stage_verifier.py --destination build/road-piece-materials-2026-10-27/verifier/game
```

The staged project was imported using the same pinned engine, then its
`res://backend/runner.gd` was run twice with `--input=<theme>-request.json` and
`--output=<theme>-verifier.json`. Report receipts include both response files.

Initial findings are retained: Windows script execution policy required the
explicit per-process Bypass invocation; sandboxed engine startup could not read
Windows certificates or default logs, so tests used isolated data and approved
certificate access. Two fixture errors were corrected (a StringName top-level key
and selecting a piece before switching editor categories). Visual review caught
the round-sample cap material seam, which was replaced with joined-mouth
classification and explicit assertions. Compatibility runs reported one ObjectDB
instance at shutdown; the Mobile run did not repeat it. Mobile verbose
logs contain driver overlay and texture-format conversion warnings. Concurrent
JumpProfiles class registration temporarily interrupted App regression parsing;
the retry passes. A separate import attempt hit a locked native geometry DLL; no
owner process was stopped and no successful import is claimed for that attempt.

Owner acceptance: reload the current client, select a straight, bend, spline or
bridge in Grass/Storm, switch materials, undo/redo, reopen the draft and Test drive.
Review the stone finish, joined transitions, touch selection and sustained frame
times on the intended device. Publishing these new documents requires matching
API/worker source rollout; no cloud deployment or live publication was performed.
No physical-device attachment check or physical-device test was performed. No APK,
real authentication/purchase, owner-save mutation, owner-process restart,
main-index staging, commit or merge was performed.
