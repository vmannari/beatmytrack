# Desert sandstone bridges — 2026-09-24

Requirements: V02/V04/V05/Q01; owner's supplied sandstone bridge reference. Presentation revision `desert-bridge-1` replaces desert steel rails with low masonry parapets, individual bevelled coping stones, capped posts, ramp abutments and a shallow arched soffit. Existing packed-sand deck shader is retained. Other themes retain steel construction.

Original code-authored geometry and masonry shading; the supplied image is visual direction only, not a shipping texture. Two mesh/material batches per bridge collection, as before. No new texture or dependency. Existing widths, ramp heights, rail collision strips, handling and camera remain unchanged. Full stone piers beneath the passable span would obstruct existing crossings; the shallow arch therefore maintains the canonical 2.20 m minimum clearance and does not add piers there.

Changed runtime files: `game/track/creator_bridge_visual.gd`, `game/track/desert_bridge_visual.gd`, `game/track/desert_bridge.gdshader` (and generated resource UIDs). Reproduction: `game/tests/capture_desert_bridge.gd` and `scripts/dev.ps1` action `CaptureDesertBridge`. Progress recorded in DEVELOPMENT_STATUS.md and PHASE_0_PLAN.md.

Actual commands, run using `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ...` and pinned Godot 4.7.2:

- `CheckScript -ScriptPath res://track/desert_bridge_visual.gd`: initially failed because the new global class had not been imported. `Import` then passed; subsequent graphical runs compiled and rendered the scripts/shader successfully.
- `TestConstruction`: 82 checks, 0 failures, five laps across upper/lower crossings, zero contacts. Existing two ObjectDB shutdown leak warnings remain.
- `TestBridgeContacts`: 16 checks, 0 failures, six Knit direction/offset runs with zero hits.
- `TestDesert`: 53 checks, 0 failures, including all five vehicle deterministic desert replays.
- `CaptureDesertBridge`: final pass; actual game scene and an evidence-only overview captured, collision cells preserved, sampled underpass clearance asserted. Initial smaller capture fixture failed route validation and was replaced with the established construction regression layout.

Desktop evidence inspected: [gameplay](evidence/desert-bridges/gameplay.png), [overview](evidence/desert-bridges/overview.png). This is an isolated synthetic crossing fixture, not a player save. The overview camera is capture-only. No player files are written.

Remaining acceptance: owner's visual review, phone driving under/over bridges and GPU/frame-time measurements. No phone test, Android export, installation or device discovery performed. Long spans use a shallow uninterrupted arch to preserve arbitrary ground crossings rather than the reference's multiple supported arches. No claim of exact hand-painted reference fidelity or measured mobile cost.

## Railing cap correction ? desert-bridge-2

Owner rejected the recessed tile appearance on the tops. Disabled shared smoothing on the desert stone batch so planar tops and bevels have independent normals; reduced bevel width from up to 5.5 cm to 2.2 cm. Changed `game/track/desert_bridge_visual.gd`; refreshed both evidence PNGs and progress documents. Requirements V02/V04/V05/Q01.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureDesertBridge` passed on pinned Godot 4.7.2. Gameplay image inspected: flat solid coping tops, narrow edge highlights, no former bowl-like shading. Capture also asserts unchanged collision cells and sampled underpass clearance. No physics change or new regression suite required for this shading/bevel correction. No phone test/export performed; owner visual acceptance and device review remain.
