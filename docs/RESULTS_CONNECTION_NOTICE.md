# Results connection notice — 2026-10-03

Requirements: R01/V03/Q01; owner asks to remove routine server/upload footer text and indicate connection failure only.

Changed `game/core/app.gd`: CloudRunStatus is hidden for ordinary progress, successful verification, offline races and practice. Queued races show “Could not connect to the server. We'll retry automatically.” only on upload/poll network errors or server 5xx responses. `game/backend/cloud_tracks.gd` records connection failure separately from technical status, retaining it during retry backoff and clearing it after successful contact. Upload persistence/retry and verification rules are unchanged.

`game/tests/test_race_results.gd`: isolated local race fixture uses a temporary cloud revision marker and explicit offline start to satisfy backend-only race admission, then restores local rating behavior.

Actual commands through pinned `scripts/dev.ps1`: TestResults initially failed on null game from outdated fixture admission. CaptureResults first repeated admission failure, then exposed missing local rating setup; final capture produced inspected results screenshots before failing at existing local-recommendation assumptions (no recommendations, then button index out of bounds at line 313). Full results suite is not passed. CheckScript with explicit res://core/app.gd and res://backend/cloud_tracks.gd both exit 0. An earlier CheckScript without ScriptPath started an unintended app process; that process was stopped.

Desktop evidence: `docs/evidence/results-connection-2026-10-03/track-default-1280x720.png` inspected; no routine footer. No Android export or physical-device test performed; device attachment was not checked. Real network interruption/recovery and owner visual acceptance remain. No service or player-data changes. Existing mixed working tree prevents a clean whole-tree commit; this document records the scoped checkpoint.
