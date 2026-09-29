# Ajorata contour and kerb follow-up (2026-09-29)

Requirements: V02/V04/V05/Q01; owner-marked Ajorata screenshot.

Tight, wide S-bends and width transitions can bunch offset-outline samples into a small zigzag inside a piece. Endpoint-only rounding does not address those. Kit 89 fairs locally abrupt internal contours using samples 1.2 m along either side, fades the change near joined endpoints, and limits each contour vertex displacement to 0.25 m. Road, white line and shoulder use the resulting outline.

Creator kerb rendering now constructs its strips from that same visual contour, keeping the established height profile, taper and stripe spacing. Isolated decorative runs shorter than 2 m are omitted. Native remix kerbs retain their native rendering. Desert/winter handling is unchanged. Canonical contact triangles, heights, surface cells, track documents, driving rules and camera are unchanged; decorative kerb locations can consequently differ slightly from their canonical contacts. This is a bounded presentation correction, not track editing or a physics revision.

Changed files: `game/track/visual_road_join.gd`, `game/track/native_track_visual.gd`, `game/tests/test_shoulders.gd`, this document/evidence, status and phase plan. Unrelated working changes remain excluded from the checkpoint.

Actual validation through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and pinned Godot 4.7.2:

- `-Action TestShoulders`: existing overlap/nearest-road regression passes; 71 join checks and 18 internal-contour checks pass. Tests cover bounded smoothing, fixed endpoints, retained mesh triangulation, absence of short decorative runs, and unchanged source/contact data. The first contour fixture had no pieces and correctly failed its nonempty-mesh assertion; replaced with an actual hairpin fixture before the final passing run.
- `-Action TestKerbs`: 31 checks, zero failures, including canonical vehicle/kerb crossing responses.
- `-Action TestSurfaceProfile`: final 928 checks, zero failures.
- `-Action CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_acf29166cceaaa42.json"`: Ajorata before and final captures pass; native cells preserved, zero bad road normals, all twelve route views saved. Final views 8 and 10 inspected. Shoulder vertices 30,192 versus 30,483 before; asphalt vertices 6,171 versus 6,180 before.
- Same CaptureStyle command with `track_5765ff853b63dea5.json`: Curvy regression capture passes and view 5 inspected; earlier rounded joins retained.
- Android SDK `adb.exe devices`: no attached phone. No Android export, installation or device test.

[Before](evidence/ajorata-joins/before.png) / [After](evidence/ajorata-joins/after.png), [opposite view](evidence/ajorata-joins/after-opposite.png), [Curvy regression](evidence/ajorata-joins/curvy-regression.png).

Remaining acceptance: owner review of the marked corrections and physical-phone appearance, moving-camera stability, loading time and frame pacing. The harness pause/countdown overlay remains visible. These checks do not certify every authored corner or junction on every track.
