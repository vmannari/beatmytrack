# Challenger shoulder and nose from the owner's reference (2026-11-13)

The owner found the previous Challenger too rounded along its shoulder and incorrectly shaped beside the nose. The supplied red Challenger photograph guides a narrower, deliberate shoulder bend, a fuller upright front flank and a less swept-back front corner. These are authored proportions interpreted from one perspective photograph; they are not photogrammetric measurements.

The native model, fitted variants, prepared Garage/race resources and Super rally pictures have been rebuilt. Reload the game to see the new resources. Owner appearance acceptance and device qualification remain.

## Native comparisons

These are actual Godot workshop captures, using the same camera, paint and current workshop. The before captures substitute the exact task-start native meshes without restoring older shared assets. The final captures use the prepared production model.

| View | Before | Final |
|---|---|---|
| Red reference angle, Vulkan | [Before](evidence/challenger-reference-body-2026-11-13/garage-before/mobile/red-reference.png) | [Final](evidence/challenger-reference-body-2026-11-13/garage-final/mobile/red-reference.png) |
| White side, Compatibility | [Before](evidence/challenger-reference-body-2026-11-13/garage-before/gl_compatibility/white-side.png) | [Final](evidence/challenger-reference-body-2026-11-13/garage-final/gl_compatibility/white-side.png) |
| Red front, Compatibility | [Before](evidence/challenger-reference-body-2026-11-13/garage-before/gl_compatibility/red-front.png) | [Final](evidence/challenger-reference-body-2026-11-13/garage-final/gl_compatibility/red-front.png) |

Both desktop renderers have five matched angles in red and white, before and after: reference, front, rear, rear-flat and side. The original photograph is the owner's chat attachment; no local reference file or reference-file hash is claimed.

## Changes

CRB01: `scripts/challenger_reference_geometry.py` adds a reference-guided shoulder field and crease-aligned topology. Three closely spaced rows follow the character line through the front wing, door and rising rear shoulder. A 1.5 mm analytic fillet gives the two side planes a tight, rounded junction. The former broad roll is removed. Shared positions use a common displacement; a ray-sampled outer skin preserves the thickness of the inner returns, and the measured bonnet boundary is pinned.

CRB02: The front flank below the shoulder is fuller and more upright. A single invertible nose transform moves the front corners, bonnet, bumper, grille and projector assembly together. Its transverse corner advance reduces the old swept-back appearance without separating the bumper from the wing. The leading 14 cm extension remains; the wheel and contact region is fixed. Normal transforms include the shear introduced by the corner advance.

A dark rounded backing closes the optical carrier behind the projector rims, and an intake backing prevents the workshop floor showing through the lower opening. The amber side markers remain compact and fitted to the revised skin. Existing source lighting details and curved grille remain; the abandoned independently moved optics were not shipped.

The same nose map is implemented in `SuperRallyModel._nose_z` for fitted bonnet construction, with a new mesh-cache key. Local triangle allocation was shifted from the broad door/front-wing grids to the crease. Stock assembled geometry is **49,768 triangles reduced / 84,724 full**, below the owner's **50,000 / 85,000** allocations. This is +228 / +789 over the task-start Challenger. No tablet performance or AAA-quality claim is made.

Authored production sources:

- `scripts/challenger_reference_geometry.py` (new).
- `scripts/prepare_challenger.py`.
- `scripts/challenger_detail_geometry.py`.
- `game/vehicle/super_rally_model.gd`.

The preceding panel/join helper was preserved. The original download remains owner-removed; conversion uses the retained measured source panels, component labels and source facts. Original CC-BY attribution remains.

## Validation

All commands and logs are in [the evidence folder](evidence/challenger-reference-body-2026-11-13/). Tests use pinned Godot 4.7.2, private saves and an empty backend URL. Conversion uses pinned Blender 4.5.15 with factory startup and embedded script execution disabled.

| Check | Final result |
|---|---|
| Reference shoulder continuity, bend position, normal change, nose wall and optical carrier | 1,908 checks, 0 failures |
| Identical reference gate on task-start native meshes | 1,884 checks, 120 failures; missing hits reduce subsequent assertion count |
| Original measured bonnet heights at the shared transformed coordinates | 252 checks, 0 failures; maximum error 2.339 mm reduced / 1.561 mm full |
| Rear glazing and trim shading | 784 checks, 0 failures |
| All fitted choices | 316 checks, 0 failures |
| All prepared modules and source/ghost comparison | 1,438 checks, 0 failures |
| Prepared physics/replay and original Rally controls | 3,677 checks, 0 failures; Super rally 198 km/h |
| Washing | 1,655 checks, 0 failures |
| Driving | 72 checks, 0 failures |
| Production parser | 557 scripts, 0 failures |
| Opaque glazing, absolute triangle allocations and native contacts | 30 checks, 0 failures **per desktop renderer** |
| Actual App Garage/race | 13 checks, 0 failures **per desktop renderer** |
| Strict prepared asset preflight | 551 resources, 2,267 checks, 0 failures |
| Native catalogue image provenance | Six images, 161 current source hashes, pass |

Independent seven-station shoulder probes find a 25.74–70.74 degree plane change over a 5–6 mm transition. The nose map matches runtime/offline output at 55 stations within 4.89e-15 m. Its surveyed minimum longitudinal Jacobian is 0.29252, with maximum inverse error 2.89e-12 m; it does not fold over. See `after-reference.json` and `nose-contract.json`.

The inherited design test has **27 checks / 1 failure**, retained in `geometry-final.log` and `geometry-acceptance.json`. The sole failure is its relative `Challenger <= reduced Rally + 10,000` cost test: the current reduced Rally is 33,928 triangles, giving a 43,928 threshold. The exact task-start Challenger is already 49,540 triangles and fails that threshold as well (`legacy-budget-control.json`). The test was not weakened. The separately enforced owner absolute 50k/85k allocations pass in both native renderers. The other 26 inherited design assertions pass. Consequently, the aggregate `final_checks.py` exits nonzero; this is not described as a wholly green test run.

The old panel/nose probes encoded the previous linear nose extension. This pass retains them but qualifies bonnet source heights with the shared new coordinate map and qualifies the explicitly requested crease with independent reference stations. It does not claim the old soft-shoulder/nose expectation remains appropriate.

## Preparation, provenance and controls

`run_preparation.py` pins the retained source, component labels and all conversion helpers and verifies fresh output for both tiers. `guarded_assets.py` performs ten commands: identity, Super rally bases, kits, Garage, shared header template, Super rally art, Super rally catalogue image, identity again, strict resource preflight and image provenance. All **439** fenced inputs remain exact throughout the bake and final audit. The conversion output itself is disposable; its hashes and command receipts remain.

Eight car configurations and the two canonical handling sources are byte-exact against task start. Of 24 immediate unrelated PNG controls, 22 are exact; concurrent `compact.png` and `electric.png` updates are preserved. This task's catalogue command excludes every other vehicle, as recorded in `assets/pictures-command.json` and its log. The live six-image provenance gate passes with those current images.

The main Git index byte hash changed during this long task; it was observed and preserved, not restored. No main-index staging or write was issued by this task, and the final read-only cached diff is empty. No byte-identity claim is made for the index. See `final-audit.json` for exact control and native hashes.

The four-source [checkpoint](evidence/challenger-reference-body-2026-11-13/source-only.patch) applies and reverses byte-exactly in a private scratch repository, with whitespace checks that accept native CRLF endings. The first scratch attempt inherited global automatic line-ending conversion and failed byte equality; the corrected scratch repository explicitly disables that conversion. No production file was changed for this fixture correction. The checkpoint excludes generated binaries, documentation and all concurrent source work.

## Retained drafts and limits

Rejected local side lofts produced an overly square nose or floating front strips when separately projecting joined surfaces. A subsequent draft collapsed inner returns onto the outer skin. The final version preserves layer thickness and uses one monotone global deformation. An initially stronger corner advance looked too boxy and was moderated before final preparation. Rejected captures, source and logs remain. Duplicate draft images also remain because automatic approval review rejected their direct removal, stating “blocked by policy.”

The baseline screenshot helper was corrected to enumerate the manifest explicitly and bypass resource cache reuse. This made the task-start mesh count 49,540 rather than accidentally showing the current 49,768. The original misleading baseline receipt was superseded by the corrected receipt. Final and baseline captures now use the intended meshes.

The final App checks contain no script errors or teardown warnings. Historical draft failures and the legacy relative-budget finding remain in the logs. Screenshots qualify desktop appearance only. Owner review, a fresh launch and physical-device performance/appearance acceptance remain. No device query/test, APK/export, owner-save/process change, backend request or deployment was performed.

Task-specific private profiles, debug mesh arrays and conversion copies are disposable. Their concise receipts have been copied into evidence. Automatic approval review rejected direct task-folder removal and the separate removal of its `.keep` marker, stating “blocked by policy.” No alternative deletion mechanism was attempted. The task build folder and pin therefore remain and need removal when permitted. The owner-requested `clean_build.ps1 -Apply` completed: 23.78 GiB before/after, zero eligible entries removed, with recent/protected output exceeding the 20 GiB target. See `build-cleanup.json` and `retention-limits.json`; cleanup is not claimed complete.

## Reproduction entry points

From the repository root:

```powershell
python docs/evidence/challenger-reference-body-2026-11-13/run_preparation.py
# Convert with game/tests/bake_challenger_hellcat.gd, then refresh prepared resources:
python docs/evidence/challenger-reference-body-2026-11-13/guarded_assets.py
python docs/evidence/challenger-reference-body-2026-11-13/final_checks.py
python docs/evidence/challenger-reference-body-2026-11-13/prepared_checks.py
python docs/evidence/challenger-reference-body-2026-11-13/verify_nose.py
python docs/evidence/challenger-reference-body-2026-11-13/checkpoint.py
python docs/evidence/challenger-reference-body-2026-11-13/audit.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Use the exact native conversion command in `native-final-command.json` between preparation and refresh. `prototype.py`, `prototype.gd` and `rejected-side-loft.py` are retained draft evidence and are not final conversion entry points. `final_checks.py` includes the documented inherited relative-budget failure; its nonzero result must remain visible.
