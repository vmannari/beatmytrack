# Electric lower, softer front corners - 2026-10-27

The owner rejects the high, sharp front corners and asks for a less bulky, sportier front. This authorizes lowering the front shoulder and broadening its rolled transition, while retaining the earlier clean tapered hood and smooth nose requirements.

[Matched before/after viewer](evidence/electric-sporty-corners-2026-10-27/before-after.html). Source-matched v11 studio captures are compared with v12 using the same paint, camera and viewport. The live Garage/race views are separate.

## Requirements

- ESC01: Lower the outer front silhouette and let the corners fall away from the hood centre.
- ESC02: Replace the tight shoulder edge with a broader continuous roll and retain the inward-tapering hood, symmetry and original no-S-bend limits.
- ESC03: Fit the slim continuous light signature and twelve optical modules into the lower front; retain useful wheel clearance and finished surface joins.
- R01: Preserve cabin/rear/wheels, physical dimensions, handling/input/collision, camera, Garage finishes/reflections and unrelated work.
- Q01: Deliver matching prepared geometry/shadows/Garage template/photos, native renderer evidence, actual checks and an isolated Git checkpoint.

## Construction

The final implementation applies one bounded deformation to all prepared front surfaces. The front falls by 0.080 model metres (70.4 mm at the unchanged physical scale), blending smoothly to zero at the cowl. Upper front surfaces also tuck inward by up to 4%, extending the shoulder's horizontal roll and reducing the broad corner block. The hood, front face, optical modules, arch returns and trim share this same mapping instead of being individually repositioned.

Normals follow the inverse-transpose Jacobian of that mapping. Public hood/width/light queries use the transformed surface, while the offline authoring functions remain in their original frame. The night-lens helper supplies original-frame samples so its mesh receives the same deformation exactly once. No per-frame vertex deformation is introduced. Behind the cowl the authored mapping is an exact identity, retaining the cabin/rear form and finish. Denser simple side triangles re-seat 78 derived door-reveal ribbons by at most 3.18 mm, within the original 4.5 mm recess; their authored paths remain. The original panel-depth checks pass. The array audit distinguishes these fitted samples from unchanged authored arrays; its initial all-protected byte-equality assumption reports 78 differences and is retained.

The simple body retains longitudinal side sampling to close its curved front join. The hood's existing inward taper and transverse crown remain. A smooth protected region leaves the original wheel opening and closed tubs on their tyre circle, retaining more than 30 mm model-space opening clearance. Physical wheel positions, tyre size, collision and simulation remain. Final counts, static arch clearance and exact asset comparisons are recorded in report.json.

## Verification and retained attempts

The independent prepared-triangle regression measures both sides at X=0.66/0.72 and Z=-1.88/-1.75, plus the actual outer brow and wheel articulation. The original task-start regression fails 10 of 28 checks, with outer brow 0.94; expanded clearance coverage gives 30 checks / the same 10 failures. The revised model passes all 30. An initial probe incorrectly required UV=1 on collapsed top cells; its nonfinite endpoint result is retained separately before correction. No production geometry is inferred from that fixture failure.

The first lower draft passes the silhouette targets and clean bonnet checks, but fails the unchanged no-S-bend and outer-join tests. Its source, native captures and measurements remain in the evidence. A second independent-profile draft closes its joins but still fails the original curvature/crown checks. Both are rejected. The shared deformation preserves the previously smooth construction across parts. The isolated parameter studies are diagnostic; final acceptance uses actual prepared triangle sections and native views.

Final commands, actual outcomes, source hashes, asset provenance, failures and remaining checks are in [report.json](evidence/electric-sporty-corners-2026-10-27/report.json). Original focused regressions retain their existing bounds. The full visible model stays at 158,270 triangles; simple rises from 70,716 to 78,940 to retain side stations (11.63%), with 7,688 shadow-only triangles / five casters. Both remain below 170,000; no device frame-time improvement is claimed. The rounded-front helper transports its existing paint probes through the lowering: its old fixed Y=0.32 ray now enters the cooling opening. All original eight silhouette/convexity assertions and thresholds remain; the earlier fixed-probe 8/2 failure is retained. The original quality regression caught an unnecessary horizontal shift of the inner wheel wall (60/4); a projected expectation still exposed coarse simple-wall interpolation (60/2). These findings led to protecting both coordinates of the original opening/tubs. The original quality fixture and its thresholds are restored byte-exact, with the failed fixture/results retained.

## Final outcomes

| Verification | Actual result |
|---|---|
| New corner/clearance regression | 30 checks, 0 failures; exact task-start 30/10 retained |
| Smooth nose / fairing / hood / clean bonnet / surface / construction / roundness | 22 / 28 / 28 / 34 / 34 / 54 / 8, all passing |
| Lighting/model | 34 Compatibility and 34 desktop Mobile, all passing |
| Original quality regression | 60 Compatibility and 60 desktop Mobile, all passing; fixture byte-exact |
| Actual App Garage/race | 70 Compatibility and 70 desktop Mobile, all passing; current Garage/canonical mesh arrays agree |
| Electric racing representations | 23 checks, 0 failures; five casters / 7,688 shadow triangles |
| Array preservation | 581 exact arrays; 564 protected authored arrays exact, 78 bounded simple reveal refits |
| Parser / pinned import | 1,330 scripts / 0 failures; final import exit 0 |

All 865 historical v11 files remain byte-exact. V12 has 864 prepared meshes, matching source/assembly hashes. New resource serialization differs from old binary files; array preservation is measured independently. The electric Garage template and all 53 native photos are refreshed. Native captures and geometry counts do not establish device frame-time performance.

## Delivery and limits

Only the affected EV geometry and derived electric representations are updated. Earlier versioned resources remain. The scoped binary patch is checked and applied in an isolated directory and compared byte-for-byte; the main Git index is not staged, committed or reset.

Reload/rebuild is needed in an existing game/editor session. Owner appearance/motion and physical-device cost acceptance remain. No physical-device attachment check/test, APK, real authentication/purchase, owner-save/live mutation, deployment, merge or owner-process restart is performed. Existing original Garage finishes, lighting and both reflections are preserved.
