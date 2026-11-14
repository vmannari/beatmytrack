# Challenger corner correction verified and finalised (2026-11-14)

The requested rounded, slightly downturned nose corners were already present in the native model. The remaining work was to bring the prepared game assets and catalogue photograph up to date. That work is now complete for Challenger.

The seven conversion/source inputs and all native Challenger files match the previously qualified corner correction. No further geometry or handling change was necessary. The preceding sharp shoulder, continuous plan taper, 14 cm nose extension and 198 km/h tune remain. Current assembled counts are **49,968 reduced / 84,924 full triangles**, including the separately authored bonnet contours, within the 50k/85k allocations.

The earlier [corner report](CHALLENGER_CORNER_ROLL_2026_11_13.md) retains the native section, downturn, plan-shape and baseline-rejection measurements. Its stale prepared-assets conclusion is superseded by the scoped results below.

## Current prepared results

| Check | Result |
|---|---|
| Strict Challenger prepared assets | **84 resources / 349 checks / 0 failures** |
| Challenger catalogue photograph | **1 exact native image / 168 current source hashes** |
| Prepared opacity, contours, contacts and allocations, Compatibility | **30 checks / 0 failures** |
| Same prepared checks, Vulkan Mobile | **30 checks / 0 failures** |
| Actual App Garage/race, Compatibility | **13 checks / 0 failures** |
| Actual App Garage/race, Vulkan Mobile | **13 checks / 0 failures** |
| Prepared showroom views | Eight captures per renderer, red and white finishes |
| Final bake source fence and live source audit | **446 inputs unchanged** |

The final full catalogue validator also passes: **six exact native images / 168 current source hashes**. This photograph check does not qualify the other vehicles' complete prepared-asset sets.

Current native game captures: [white front-quarter](evidence/challenger-corner-finalise-2026-11-13/garage-final/gl_compatibility/white-opposite.png), [red reference angle](evidence/challenger-corner-finalise-2026-11-13/garage-final/gl_compatibility/red-reference.png), and [Vulkan front-quarter](evidence/challenger-corner-finalise-2026-11-13/garage-final/mobile/white-opposite.png).

The Vulkan App fixture retains two ObjectDB leaked-instance warnings and one resource-in-use teardown diagnostic after its 13 passing assertions. The logs are retained; this is not a clean-teardown claim. All runs use pinned Godot 4.7.2, private test profiles and an empty backend URL.

## Refresh and concurrent work

Regenerating build identity first exposed stale prepared keys. The refresh rebuilt Challenger's bases, kits, Garage scene, dependent header, artwork and photograph. A concurrent producer update rejected the first full source fence; its logs remain under `producer-update-attempt`. The next scoped presentation refresh passed both strict validators with stable sources and model revisions.

A later concurrent prepared-scene rewrite invalidated the photograph's exact scene digest without changing the qualified native geometry or source fence. A further photograph refresh restored that exact scene binding. The final audit invokes the live photograph validator as well as checking the saved command receipts, so a past passing log alone is insufficient for completion.

All 65 model, native-resource, configuration and handling controls remain byte-exact against this verification task's start. The shared Git index changed concurrently and is preserved; this task did not stage or write it. All 24 unrelated PNG controls are exact in the final audit. Five other catalogue photographs changed temporarily during concurrent refreshes; their final bytes again match task start. This task's photograph command explicitly excludes those vehicles. No older binary or source was restored over concurrent work.

The accepted command receipts, rejected attempts, source hashes and current image hashes are in [the evidence folder](evidence/challenger-corner-finalise-2026-11-13/), especially [completion.json](evidence/challenger-corner-finalise-2026-11-13/completion.json) and [the final live photograph check](evidence/challenger-corner-finalise-2026-11-13/live-preview-check.log). This qualification covers Challenger's prepared model and desktop Garage/race. Whole-project cache/export readiness and physical-device acceptance are separate.

## Retention and reproduction

Required retention cleanup completed successfully. Its own console receipt reports **23.72 to 23.72 GiB, zero eligible entries**; recent, protected or locked output remains above the 20 GiB target. This task's build output is unpinned and disposable. See [cleanup output](evidence/challenger-corner-finalise-2026-11-13/build-cleanup.log).

```powershell
python docs/evidence/challenger-corner-finalise-2026-11-13/guarded_assets.py --pictures-only
python docs/evidence/challenger-corner-finalise-2026-11-13/prepared_checks.py
python docs/evidence/challenger-corner-finalise-2026-11-13/final_audit.py
python scripts/check_garage_previews.py --vehicles=super_rally
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Reload and owner appearance acceptance remain. No device query/test, APK/export, owner-save/process change, backend request or deployment was performed.
