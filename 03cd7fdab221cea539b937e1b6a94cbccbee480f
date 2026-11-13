# Selected events and scenery retention — 2026-11-04–05

Implemented the requested extension of Free Race preparation to the selected Daily and Rivalry event, and changed ordinary retention to preserve completed scenery before cheaper independent road work. Existing memory limits, graphics settings, geometry, shaders, rules, tickets and results identities remain unchanged.

## Requirements and implementation

**SER01 — prepare one visible selected event.** `race/selected_event.gd` binds the existing `selected_track_preparation.gd` worker to the actual Daily card or Rivalry detail page. It waits 250 ms for selection to settle; an explicit race tap can consume the queued work immediately. There is still one selected CPU worker, with the existing cancellation/discard/reap path. It prepares the validated document, existing road arrays/disk receipt, Winter cover, queries, support and current checkpoint layout. It constructs no speculative Game or 3D world and does not prepare every event/car.

Daily emits a preparation hint from both fresh and restored cards. Rivalry reuses the hash-checked document its existing detail preview already reads/downloads. Neither preview-only nor hidden/stale pages may publish preparation. Repeated presentation deduplicates the same request. Work remains optional: ordinary race loading handles missing, failed or cancelled preparation.

**SER02 — exact handoff and authorization.** Selection validity includes weak page ownership, navigation generation, account/backend scope, car, track identity, version, source hash and canonical/redacted hash pins. Input whose complete source pin differs from the current card/detail event is rejected before work begins. Daily also pins day/end time and checks expiry using the server sample plus monotonic elapsed time. Its normal race-tap revalidation can keep the same worker while refreshing; expiration or a replacement response invalidates it. Rivalry additionally pins group/week/slot, vehicle/circuit mode, snapshot scope/state, availability and completion/status. A changed event is checked after the awaited authorization/download/compile/ghost steps.

Compilation replaces metadata, so the selected pipeline now restores the validated `cloud_entry` pin when hydrating the selected object. Daily and Rivalry then consume that exact object instead of constructing another metadata-only selection. Rivalry still requests a **fresh ticket**; Daily still requests **fresh limits**. No authorization, limits, result, ghost recording or race state is cached by this feature. No simulation tick or countdown advances during preparation.

**SER03 — prefer completed presentation within existing budgets.** Ordinary arbitration first retains the completed world by discarding idle effect proxies, rebuildable road CPU intermediates/final packets and independent road GPU cache entries. Road GPU resources proven to be identical to resources in a retained scene remain counted once; deleting such an alias would not free its buffers. Live scenes retain their own references throughout. CPU/private-road trimming is deferred while a tree-owned preparation worker is running. Verified road artifacts and procedural construction remain the fallback.

Winter's existing 1 MiB static reflection sky is kept with a retained Winter world during ordinary arbitration. Real pressure still clears optional scenes, the sky, idle proxies and the other existing caches. `RETAINED_BUDGET` remains **64 MiB**, road retention **32 MiB**, prepared-world retention **64 MiB / five entries**, and the separate Garage allowance **96 MiB**. These are the existing conservative resource estimates, not RSS/PSS or driver allocation measurements.

**SER04 — preserve Winter material preparation and appearance.** Retaining Winter exposed a road-patch difference when its run-owned wind materials were recreated. Meshes, transforms, buffers and uniform values matched; changing construction order or copying transforms individually did not fix it, and both experiments were reverted. The pinned Compatibility renderer includes material identifiers in its opaque sort key. Reusing the material identity is consistent with preserving the ordering of coincident surfaces. [Godot 4.7.2 renderer source](https://github.com/godotengine/godot/blob/ed1daf0bf/drivers/gles3/rasterizer_scene_gles3.cpp#L297).

The existing world cache now optionally retains Winter surface material instances under **exclusive weak-owner leases**. Another live owner receives a private copy. Return restores the original scene material bindings, clears run-specific samplers/presentation parameters and releases the lease. Idle entries hold no run-specific lookup texture. Each retained material reserves 8 KiB for material/parameter/UBO state; a world's largest float lookup footprint reserves 32 bytes per pixel, conservatively even when the independent source cache also owns it. No identity history accumulates on lookup regeneration. If a reservation cannot fit the unchanged cache limit, the optional scene entry is dropped. Pressure can release the cache while an active wind owner keeps its own references.

The native controlled prototype removes the original 564-channel road-patch difference. Geometry, shaders, cameras, antialiasing, reflections, wind coverage and particle counts are unchanged. No visual threshold or production invariant was relaxed.

## Controlled desktop measurements

Godot 4.7.2, NVIDIA RTX 3090, Compatibility, 960×540. Actual offline App/Game; Pine once, then Winter three times, destroying/recreating Game each time. Each theme's exact selected NativeTrack is compiled once outside entry timing, matching normal selected-event re-entry and the earlier loading review. Both arms use current App/Game/art; the control substitutes the archived task-start memory arbitration only. Private records/backend configuration and road directories are used. These are two warm samples per arm, not cold-driver statistics or a phone measurement.

| Winter entry | Old retention | New retention |
| --- | ---: | ---: |
| First re-entry | 2.011 s | 1.395 s |
| Second re-entry | 1.973 s | 0.654 s |
| Median of those two | 1.992 s | 1.024 s |

The observed warm median falls **48.6%**. The old policy admits Winter then evicts it on every entry; the new policy keeps it. New estimated retained resources after arbitration are 44,699,956 bytes on first Winter and 56,914,972 bytes on re-entry, both below 67,108,864 bytes. Pressure still releases the optional scenes and sky. Initial Winter entries are 25.929 s control / 23.413 s new; no cold-loading improvement is inferred from that unmatched observation.

`final-scenery-control.json` and `final-scenery-compat.json` contain the complete rows, costs, before/after telemetry and cache state. The new run passes all 28 assertions, including exact full native re-entry pixels and exact active-view pixels before/after ordinary memory arbitration. The longer old-policy control retains one strict image failure: its final recreated view differs by 104 channels, maximum 8/255. That raw result remains; the control is not presented as a clean visual pass.

Earlier experiments recreated NativeTrack on every re-entry, which also repeated several seconds of checkpoint/query preparation. Those observations are retained but excluded from the selected-event timing table. Earlier 1280×720 runs after the material fix show one antialiased car-edge pixel changing by up to 7/255 on one re-entry, with the following re-entry exact. There is no universal independent-instance pixel-equivalence claim. The 960×540 accepted run retains the strict equality check; raw larger captures and all failed experiments remain available.

The selected-event fixture separately observes real CPU work finishing before the race tap and verifies object reuse. One diagnostic run records Daily 8.930 s and Rivalry 5.309 s of worker preparation; these are work shifted earlier, not claimed reductions in total work or backend latency. Cold graphics preparation remains a separate cost.

The nine focused accepted runs total **257 assertions, zero failures**. The event checks use the final event runtime; scenery checks match the final five scenery/retention runtime hashes. Additional retained fixtures and their failures/warnings are reported separately below.

## Validation, controls and commands

Evidence is in `docs/evidence/selected-events-retention-2026-11-04/`. Every process receipt records the command, private APPDATA, exit status and before/after text-source hashes. The runner pins the engine, selects Dummy audio and writes an empty backend URL in its private profile. No real authentication or service mutation is used; authorization/limits tests use explicit fixture adapters. `summary.json` retains every attempt, including failures and warnings.

| Check | Actual outcome |
| --- | --- |
| Selected events, headless/native | 58/0 each; cancellation, deduplication, expiry, late download, exact object, full input pins, fresh Rivalry ticket, changed-week rejection |
| Actual early-prepared Daily install | 7/0; exact prepared object, fresh limits, ten laps, tick 0/countdown 360 |
| Retained Daily metadata/catalogue | 6/0; retains an existing one-instance teardown warning |
| New selective budget / surface leases | 12/0 each; shared/private accounting, unchanged caps, sky/scene pressure release, exclusive owners, reset, identity reuse and lookup reservation |
| Retained memory/selected CPU preparation | 20/0 |
| Compatibility scenery | 28/0, exact native images at 960×540 |
| Desktop Mobile scenery | 28/0 after 20 native settle draws; strict re-entry and active before/after images exact. The earlier four-draw attempt retains one image failure |
| Retained race reuse | 794/0 assertions; retains a background Garage coroutine teardown error, not a clean engine log |
| Retained Free Race selection | 59 checks / one `.res`-versus-`.arrays` artifact assertion; cancellation/handoff checks continue; background Garage teardown errors retained |
| Archived selection/memory Free Race control | Same 59 checks / one artifact assertion and the same background Garage transform errors |
| Retained prepared-world/physics fixture | 85 checks / one missing-document assertion; the source's bundled fallback can supply the exact deleted local document. The failure occurs before scenery construction; cloud code is unchanged |
| Legacy Winter-sky fixture | 13 checks / three failures: it creates native resources outside App without activating the newer lazy policy boundary |
| Same sky fixture with explicit policy activation | 13/0; every original assertion retained; native texture/audio shutdown findings remain |
| Retained opaque Winter wind appearance | 34/0; every original assertion retained and output redirected into this task's evidence |

The `.res` artifact assertion and the externally constructed sky fixture are checked with task-start controls/adapters, rather than changing their assertions. Windows engine logs also retain the certificate-store error. Native long-run teardown can retain the previously observed MP3 resource/instance warnings. Exact error/warning lines, source changes and control limits are in the per-run summary. An unrelated review script changed during the primary Compatibility run; the owned runtime sources did not change in that run. Final event-pin hardening followed the settled Mobile scenery run; its five scenery/retention sources match the final code, and final event checks were rerun afterward. Component hashes are explicit in the summary. Concurrent startup, prepared-asset and other loading work is preserved.

Entry timing ends before capture/readback/PNG work. Diagnostic captures can emit hitch warnings while canonical tick/countdown remain frozen; there is no hitch-free driving claim here.

Actual command examples (use a fresh label for additional runs to preserve these receipts):

```powershell
python docs/evidence/selected-events-retention-2026-11-04/run_check.py final-events-native res://tests/test_selected_events.gd
python docs/evidence/selected-events-retention-2026-11-04/run_check.py final-scenery-compat res://tests/test_selected_scenery_retention.gd --timeout 240 --viewport=960x540
python docs/evidence/selected-events-retention-2026-11-04/run_check.py final-scenery-control res://tests/test_selected_scenery_retention.gd --timeout 240 --control --viewport=960x540
python docs/evidence/selected-events-retention-2026-11-04/run_retained_checks.py
python docs/evidence/selected-events-retention-2026-11-04/run_final_controls.py
python docs/evidence/selected-events-retention-2026-11-04/summarize.py
python docs/evidence/selected-events-retention-2026-11-04/checkpoint.py
```

The task-only checkpoint includes changed runtime sources, tests, archived control sources, report and evidence helpers. It is checked forward/reverse with exact normalized content in an owned build directory, without writing the main index. Reload/owner appearance and actual device acceptance remain. No device query/test, APK/AAB, owner-save/process change, live/backend request, deployment or main-index write was performed. Official engine-source browsing was read-only.
