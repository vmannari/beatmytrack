# Reproduction commands

Run from the repository root. `.tools/backend-secure-venv` is the existing locked Windows environment. The native engine used is `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe`, version `4.7.2.stable.official.ed1daf0bf`. No package update or cloud command was run.

The executed helper sources are preserved in `tools/`. Copy those three files into `build/security-fixes-20261024/` before rerunning; their working paths are deliberately private/ignored. They never read the existing PC database configuration. `run_tests.py` writes the named log/XML files and passes an explicit private temporary directory to pytest.

Actual final Windows commands:

```powershell
.tools/backend-secure-venv/Scripts/python.exe build/security-fixes-20261024/run_tests.py backend-final backend/tests/test_security_fixes.py backend/tests/test_auth.py backend/tests/test_browser_auth.py backend/tests/test_privacy.py backend/tests/test_resumes.py backend/tests/test_resume_recovery_wire.py backend/tests/test_commerce.py backend/tests/test_admin.py backend/tests/test_admin_support.py backend/tests/test_admin_player_grants.py backend/tests/test_studio.py backend/tests/test_studio_platform.py backend/tests/test_studio_review_fixes.py backend/tests/test_studio_operations.py backend/tests/test_studio_moderation.py backend/tests/test_game_config.py backend/tests/test_readiness.py backend/tests/test_gcp_staging.py backend/tests/test_gcp_update.py backend/tests/test_pc_development.py backend/tests/test_appearance_sync.py backend/tests/test_rivalry_appearance.py -m 'not postgres and not godot' -k 'not postgres and not canonical_three_rewinds and not additive_attempt_migration' -q --tb=short
.tools/backend-secure-venv/Scripts/python.exe build/security-fixes-20261024/run_tests.py deployment-last backend/tests/test_gcp_staging.py backend/tests/test_gcp_update.py backend/tests/test_pc_development.py backend/tests/test_results_deployment.py backend/deploy/test_operations.py -q --tb=short
.tools/backend-secure-venv/Scripts/python.exe build/security-fixes-20261024/run_tests.py authority-complete backend/tests/test_security_fixes.py backend/tests/test_game_config.py -q --tb=short
.tools/backend-secure-venv/Scripts/python.exe build/security-fixes-20261024/run_tests.py circuit-sqlite backend/tests/test_world_ranking.py -k 'shared_circuit_group_independence_and_free_resumes and not postgres' -q --tb=short
.tools/backend-secure-venv/Scripts/python.exe build/security-fixes-20261024/run_tests.py native-http backend/tests/test_appearance_sync_http.py -q --tb=short
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/security-fixes-2026-10-24/slow_body_probe.py --original
.tools/backend-secure-venv/Scripts/python.exe docs/evidence/security-fixes-2026-10-24/slow_body_probe.py
.tools/backend-secure-venv/Scripts/python.exe build/security-fixes-20261024/compose_check.py
```

The real HTTP native test ran outside the sandbox against its own loopback server/profile. Other native checks used workspace APPDATA:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/security-fixes-20261024/native-user'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_security_ownership.gd
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_appearance_sync.gd
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_earned_coins.gd -- --evidence-root=res://../docs/evidence/security-fixes-2026-10-24/native-economy
```

PostgreSQL used an already installed `postgres:17-bookworm` image and a new labelled `bmt-security-fixes-20261024` container. Windows port forwarding timed out; the successful tests used the already installed `bmt-backend:local` image on the fixture's own network, with source mounted read-only and only the two test-output folders writable:

```powershell
.tools/backend-secure-venv/Scripts/python.exe build/security-fixes-20261024/local_pg.py start
wsl.exe -d Ubuntu -- docker run --rm --pull=never --network container:bmt-security-fixes-20261024 --mount 'type=bind,src=/mnt/c/Codes/Godot/Beat my track,dst=/source,readonly' --mount 'type=bind,src=/mnt/c/Codes/Godot/Beat my track/build/security-fixes-20261024,dst=/source/build/security-fixes-20261024' --mount 'type=bind,src=/mnt/c/Codes/Godot/Beat my track/docs/evidence/security-fixes-2026-10-24,dst=/source/docs/evidence/security-fixes-2026-10-24' --workdir /source --entrypoint python bmt-backend:local build/security-fixes-20261024/run_tests.py pg-final backend/tests/test_cloud_setup.py backend/tests/test_service_worker.py -m 'not godot' -q --tb=short -p no:cacheprovider
```

The same container command prefix ran these final selections:

```text
pg-owner-final backend/tests/test_cloud_setup.py -k 'reconfiguration or schema_owner or runtime_sessions' -q --tb=short -p no:cacheprovider
pg-startup-final backend/tests/test_cloud_setup.py -k 'runtime_sessions or schema_owner' -q --tb=short -p no:cacheprovider
pg-startup-last backend/tests/test_cloud_setup.py -k runtime_sessions -q --tb=short -p no:cacheprovider
```

The owned fixture was removed after verification using `local_pg.py stop`, which checks its ownership label before removal. Existing containers were neither stopped nor connected to. Generated fixture passwords were redacted from retained failure traces and were never deployment credentials.

`task-only.patch` compares the captured starting sources with the final task edits. Concurrent README setup changes and discovery-cache settings removal are excluded. Two support-fixture starting copies were reconstructed by reversing only the recorded test edit; their manifest entries say so. The privacy starting copy was likewise reconstructed by reversing its single audit-redaction edit. `git apply --check --reverse --ignore-whitespace` succeeds against the final working sources. This patch is a scoped checkpoint, not a replacement for the existing concurrent working tree.
