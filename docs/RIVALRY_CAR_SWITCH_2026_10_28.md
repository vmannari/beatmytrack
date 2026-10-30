# Rivalry standings during car changes (2026-10-28)

Changing the header car could display four successive standings sets: the old car, a saved snapshot for the selected car, an intermediate automatic-enrollment response, and the final enrolled board. The isolated actual-App regression reproduced that exact sequence: `compact-final/80`, `pickup-saved/40`, `pickup-intermediate/60`, `pickup-final/100`.

| Requirement | Result |
| --- | --- |
| RCS01 | Scope changes notify the visible page before appearance synchronization can yield. The existing Rivalry loading view replaces the previous board immediately. |
| RCS02 | A changed scope bypasses saved standings during its fetch and retries. Automatic enrollment completes before its response is applied or cached. Only the final selected board is published. |
| RCS03 | Existing generation/scope fences reject late responses, including an earlier request for the same car. Same-car background refreshes retain their table and controls. Connection failure keeps Refresh usable; a new adapter still restores the initial scoped cache. |

The runtime change is confined to `game/backend/weekly_rivalry_client.gd`. The new `game/tests/test_rivalry_car_switch.gd` and generated UID exercise the actual App and header selector with independently delayed appearance, current-membership, and enrollment replies. Existing regressions are unchanged. The service is synthetic and all player files are under disposable workspace profiles. There is no API, persistence-schema, simulation, scoring, car, or artwork change in the task patch.

Actual commands, source hashes, raw attempts, and captures are indexed in [report.json](evidence/rivalry-car-switch-2026-10-28/report.json). Every engine run uses pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`.

| Verification | Outcome |
| --- | --- |
| Starting runtime, new car-switch regression | 36 checks, **23 failures**; records the four-board publication sequence. |
| Fixed car-switch regression, headless | 36 checks, zero failures. |
| Fixed car-switch regression, Compatibility, 1280×720 | 42 checks, zero failures; six native screenshots. |
| Fixed car-switch regression, desktop Mobile, 960×540 | 42 checks, zero failures; six native screenshots. |
| Existing automatic enrollment | 14 checks, zero failures. |
| Existing menu loading/cache restoration | 27 checks, zero failures; retained track-browser anchor warning. |
| Existing Rivalry entry | 66 checks, zero failures. |
| Existing enrollment failure/retry | 38 checks, zero failures. |
| Existing week completion | 38 checks, zero failures. |
| Existing App | 141 checks, zero failures. |
| Full script parser | 1,377 scripts, zero failures. |

Native views show [loading during appearance synchronization](evidence/rivalry-car-switch-2026-10-28/compatibility/pickup-appearance-loading.png), [the same loading state during enrollment](evidence/rivalry-car-switch-2026-10-28/compatibility/pickup-enrollment-loading.png), [the final selected standings](evidence/rivalry-car-switch-2026-10-28/compatibility/pickup-final.png), [connection failure with Refresh](evidence/rivalry-car-switch-2026-10-28/compatibility/kart-failed.png), and [recovered standings at 960×540](evidence/rivalry-car-switch-2026-10-28/mobile/kart-recovered.png). These use explicit fixture scores, not live player results.

The initial sandbox run stopped on Windows certificate-store access; approved local execution used isolated offline profiles. An initial fixture path guard needed normalization. Concurrent Hovercraft work initially had no header PNG and subsequently needed resource import; those original failures remain in the logs. A temporary test-only exclusion allowed the first reproduction while that unrelated asset was incomplete. It was removed; both final native runs use the actual imported catalogue artwork. No production fallback or concurrent source was changed. Generated build metadata and imported resources are excluded from the task-only checkpoint; concurrent changes and advanced build identity are preserved.

The [source-only checkpoint](evidence/rivalry-car-switch-2026-10-28/task.patch) contains one runtime file, the regression, and its UID. Network latency still determines how long the loading view remains. Reload/rebuild and owner acceptance on the original device remain. No physical-device attachment query or device test, APK, live account/save mutation, backend deployment, owner-process restart, or main-index staging/commit/merge was performed.
