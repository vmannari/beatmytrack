# Current creator format and admission limits

Reviewed 2026-10-27. External creator documents must use **creator-track-v5**.
The native loader accepts **surface-grid-v2**. Earlier creator/native versions and
Coast imports are unsupported; older-format conversion is not offered. Existing
player files are preserved rather than deleted when they cannot be imported.

The executable contract is [TrackDocument](../game/editor/track_document.gd),
[CreatorLimits](../game/editor/creator_limits.gd),
[TrackCompiler](../game/editor/track_compiler.gd) and
[TrackLibrary](../game/persistence/track_library.gd). The structural interchange
schema is [creator-track-v5.schema.json](schemas/creator-track-v5.schema.json).
Domain validation and compilation also enforce geometry, aggregate capacity and
memory constraints that JSON Schema alone does not establish.

| Constraint | Current bound |
|---|---|
| JSON document | 1,048,576 bytes (1 MiB) |
| Placed objects | 4,096 |
| Expanded tyre stacks | 4,096 independently; a tyre wall counts as six |
| Conservative prop estimate | 128 MiB; provisional admission estimate, not measured process memory |
| Road sections | 96, up to 4,000 m combined sampled length |
| Route points | 4–96, coordinates within ±120 m |
| Road/node width | 6–20 m |
| Track name | 1–40 characters, no control characters |
| Track ID | 1–48 lowercase ASCII letters/digits/underscores; reserved device names excluded |
| Removed scenery keys | At most 256, each at most 40 characters |

Themes are Grass (`pine`), Desert (`desert`), Night (`night_city`), Winter (`winter`)
and Storm (`storm`). The v5 document supports road pieces, painted layout, authored
objects/hazards, start-line pose and scenery settings, with strict allowlists.
The route is derived from connected pieces for the current UI; manual waypoint
editing is retired. Authoring and playable-route validation are distinct so that
unfinished work can be recovered without claiming it is ready to race.

Grass and Storm road pieces accept an optional `surface` of `"asphalt"` or
`"gravel"`. An omitted value inherits the document's `surface`, with legacy
`"dirt"` using the loose surface. The editor exposes these choices for the selected
piece and unplaced preview. Other themes retain stored choices but use their
existing biome material. Bridges apply their choice to the deck and ramp
approaches independently of the ground below. Gravel uses existing native surface
2 (0.8 grip, 2.0 resistance), the Desert road's warm compacted finish, and no
asphalt bend kerbs. Visual material joins blend through connected road cells up
to three metres on either side; asphalt markings fade through the transition.
Ground and bridge blends use independent channels. Driving material boundaries
still use the exact authored road mouths. See
[compacted finish and gradual joins](ROAD_MATERIAL_BLENDS_2026_10_27.md).

This is an optional v5 extension: documents without piece materials keep their
existing canonical output and hashes. A changed piece material is included in the
document content hash. Visual kit 216 retires older presentation caches. Hosting
new material tracks requires the matching client and API/worker source rollout;
this local implementation does not deploy those services. See
[road-piece materials](ROAD_PIECE_MATERIALS_2026_10_27.md) for actual checks and
screenshots.

Compiler identity is **creator-compiler-27**. Geometry is shared by editor preview,
practice, racing and canonical verification. Desert compilation normalizes the road
surface to the structural road cell and applies compacted-sand biome semantics.
Local saved documents and editor WIP recovery are separate. File exchange and local
drafts are free; hosted publishing uses the account's service entitlements.

See [creator capacity and matching canonical bundle](CREATOR_CAPACITY_2026_10_23.md),
[current import/editor policy](EDITOR_T11_T15_2026_10_23.md),
[WIP workflow](EDITOR_WIP_WORKFLOW.md) and [menu guide](MENUS_AND_CREATOR.md).
Physical-device capacity and sustained performance acceptance remain open.

## Historical format/compiler checkpoints

All v1–v3 declarations, byte limits, compiler identities and test results below
refer to those earlier builds. They do not authorize accepting those formats now.

---

# Object extension checkpoint (2026-09-14)

Creator-track-v5 now accepts optional object `scale` (0.5-3, default 1; tyre walls remain 1) and optional `hidden_scenery` (up to 256 coordinate keys, each at most 40 characters). New kinds: `boulder`, `slate`, `cliff`, `oil`, `puddle`, `jump`. Existing v5 documents remain valid. Compiler-7 includes deterministic solid woodland scenery; saved deletions suppress regeneration. See [CREATOR_HAZARDS.md](CREATOR_HAZARDS.md) and [current schema](schemas/creator-track-v5.schema.json). The sections below retain historical compiler evidence.

# Local creator format

Superseded by **creator-track-v3**: separate map painting, optional road helper, lap route and native remixes. [Current contract and verification](FREE_FORM_EDITOR.md). V1/V2 descriptions below are historical; no backward compatibility is maintained.

At the v2 checkpoint: **creator-track-v2**, with per-node widths, sharp/smooth corners and built-in objects. See [EDITOR_V2.md](EDITOR_V2.md) and the [v2 schema](schemas/creator-track-v2.schema.json). The owner explicitly waives backward compatibility for user tracks; v1 is unsupported. The following records the historical first implementation.

2026-09-12 owner-authorized local creator slice. Requirements: T01 (bounded non-scriptable format), T02 (closed route and geometry validation), T03 foundations (version identity), T04 (unlimited local drafts and free file exchange), V05 (shared editor/driving geometry). Public publishing, hosted challenges, accounts and competition verification are outside this slice.

`game/editor/track_document.gd` owns `creator-track-v1`. The structural schema is [creator-track-v1.schema.json](schemas/creator-track-v1.schema.json). The original blueprint package/schema remains unchanged. A document contains exactly `schema`, `id`, `name`, `theme`, `surface`, `width` and `points`; all unknown properties are rejected. The three built-in themes are `pine`, `coast`, `desert`, and the road surface is `asphalt` or `dirt`. Theme selection does not alter surface semantics. No URLs, scripts, images, Resource files or arbitrary scene objects are loaded.

One loop has 4–24 control points in simulation X/Y metres, each between -120 and 120. Neighbouring points must be at least 8 m apart. Width is 8–14 m. The complete smoothed route must be 110–750 m, with minimum bend radius 0.65 times its width; crossings, folded turns and nearby overlapping road sections are rejected. These are bounded first-slice usability proposals. They do not guarantee an enjoyable course or a particular human lap time. The starter circuit's conservative diagnostic driver completes laps in roughly 21–22 seconds.

`TrackDocument.smooth_points(document)` evaluates the closed curve and samples at intervals no greater than 1 m. `TrackCompiler.compile(document)` validates and rasterizes that same route at 0.5 m resolution into `NativeTrack`, including its shoulder, distant perimeter, spawn, finish and four ordered checkpoints. `NativeTrack.from_data` accepts trusted compiled data without file I/O; external JSON must use the document validator/compiler. Native cells are authoritative for surfaces and collision; renderers and native previews consume the same cells. The simple handle interface is a current phone usability proposal; the package's original road-piece UI is not silently presented as implemented.

Compiler identity is `creator-compiler-1`. The SHA-256 identity includes the compiler version and canonical sorted-key document JSON, so revisions produce a different pinned content identity. Name/theme/identity edits also produce a new content hash in this local slice. This conservative rule is not a hosted immutable-version store. Existing in-memory compiled tracks retain deep-copied document metadata.

`game/persistence/track_library.gd` stores local tracks in `user://tracks` by validated ASCII ID. There is no document-count quota, paid capacity or retry gate. Each imported/exported JSON is at most 16,384 bytes, checked before parsing. Names are 1–40 characters without control characters; Windows device names and path separators are disallowed in IDs. Import returns validated data for the UI to review/save; it does not silently overwrite a local track. Export uses plain JSON suitable for file transfer. Android native share-sheet integration is a later platform adapter.

Writes use a same-directory temporary file, flush/close, read-back validation, and backup/commit renames. Reads prefer valid committed JSON, then a valid previous backup, then a first-save temporary. Recovery verifies the document ID against the requested filename; a corrupt primary never replaces a good backup. This covers interrupted application writes. Godot's flush/rename facilities do not promise preservation against all filesystem or hardware failures. Invalid geometry cannot be saved or test-driven through this API; the UI retains it until corrected/undone and must clearly show its unsaved state.

Changed domain files: `game/editor/track_document.gd`, `game/editor/track_compiler.gd`, `game/persistence/track_library.gd`, the isolated native-loading section of `game/track/native_track.gd`, `game/tests/test_creator.gd`, `game/tests/fixtures/creator_default.json`, this document and the schema. The canonical vehicle step and existing native track format are unchanged.

Actual Windows validation with pinned `4.7.2.stable.official.ed1daf0bf`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestCreator
```

Final wrapper execution exited 0; retained output is [creator-tests.txt](evidence/creator-tests.txt). During domain development the same suite also ran directly with the exact pinned console executable and `--headless --path game --script res://tests/test_creator.gd`.

86 checks passed with zero failures: hostile/oversized imports, IDs and type bounds, width endpoints, crossings/overlaps/sharp turns, native-road alignment, friendly display names, compiler golden dimensions/hash, content revision identity, file round trips, corrupt/missing-primary and first-save recovery, three complete laps in all three themes and exact complete JSON input replays in 8-tick batches. The starter geometry is 228 × 188 cells, 219 route samples, and 8,715 road cells. All three diagnostic runs had zero contacts. Pine/Coast asphalt laps: 21.670588 / 21.157394 / 21.155594 s; Desert dirt: 22.232017 / 21.603116 / 21.591164 s. These times describe conservative automated driving, not human acceptance or cross-device determinism.

The existing ignored `.tools/review/Scripts/python.exe` with `jsonschema.Draft202012Validator` checked schema correctness, accepted the checked-in starter fixture and rejected five invalid structural examples (control-character title, traversal/device IDs, short point list, Boolean width). No runtime dependency was added.

Remaining acceptance: physical-phone drag/pan/zoom and simultaneous controls, lifecycle behavior in an actual app stop/relaunch, safe areas and file selection on Android, eight of ten novice users creating/testing/sharing within five minutes, and human evaluation of edited route quality. No phone or Android share-sheet test was performed for this domain work. Three-lap timing currently uses the existing practice session; it is not a ranked shortcut verifier.


## Raised kerb contract ? 2026-09-15

Compiler-10 adds derived, shared kerb triangles to the in-memory native track. Saved creator documents remain v5. Exposed asphalt inside bends use the same RoadEdges construction for visual shoulders and canonical kerbs, with fitted white-ended runs, a 0.75 m untapered footprint and 0.10 m crown. Paint/obstacle masks suppress both appearance and support. Native source kerbs are inferred from concrete cells near asphalt; new-piece raster shoulders are excluded from that native path. Physics 0.21 versions the driving response; diagnostic schema 7 appends six kerb spring scalars at snapshot index 18. [Actual implementation, tests, new golden identity and limitations](RAISED_KERBS.md).
