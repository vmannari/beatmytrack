# Player card facelift ? 2026-10-24

PCF01?PCF03: Larger player identity, bounded native car showcase, separate gold position/points values, opaque inset panels and a centered track empty state. Existing shared cosmetics, one-shot native rendering, exact creator filtering, paging, retry, blocking/reporting and account fences remain. World Ranking retains its existing behavior with tighter profile-only typography. No new assets, service calls or dependencies.

Runtime change: `game/ui/player_profile.gd`. Reusable fixture capture: `game/tests/capture_player_card_facelift.gd`. Task-only runtime patch and hashes: `evidence/player-card-facelift-2026-10-24/`.

Actual validation through pinned 4.7.2 `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_player_profile.gd`: initial headless 2176/0; final `-Graphical -RenderingMethod gl_compatibility` 2183/0. Capture script passes 6/0 each under Compatibility and desktop Mobile. Native empty/published screenshots are in the corresponding renderer folders. `git diff --check -- game/ui/player_profile.gd game/tests/capture_player_card_facelift.gd` passes.

Isolated userdata: workspace `build/player-card-userdata` and `build/player-card-mobile-userdata`. PowerShell uses process-only ExecutionPolicy Bypass. Initial PATH engine and sandbox certificate failures remain in evidence; successful runs use the pinned engine and approved escalation. Existing test window sizes map to the project's logical viewport; this is not a physical device layout certification.

Owner visual acceptance and client reload remain. No physical-device attachment check or device test was performed. No APK, deployment, live mutation, purchase or owner-process restart. Concurrent work preserved.
