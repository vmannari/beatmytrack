# Audit commands and reproducibility

Working directory: `C:/Codes/Godot/Beat my track`. Engine: pinned `4.7.2.stable.official.ed1daf0bf`, actual executable `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe`. Python for backend tests: `.tools/backend-secure-venv/Scripts/python.exe`. No owner process was restarted. No physical-device query, APK/AAB, deployment or real provider interaction was run.

The commands below preserve the relevant arguments; absolute checkout paths and ordinary shell output redirection are normalized for readability. The Python runner sources retain exact process argument lists/profile setup. Raw logs are retained. These are an execution record, **not a single green release command**.

## Owned offline client runs

```powershell
python build/re-audit-2026-10-27/run_client_checks.py
python build/re-audit-2026-10-27/run_native_checks.py
python build/re-audit-2026-10-27/run_soak.py
```

Each runner launches only its own process, isolates APPDATA/LOCALAPPDATA under `build/re-audit-2026-10-27/profiles`, clears inherited BMT configuration and explicitly writes an empty backend URL. Client copies retain assertions/fixture reads and redirect known evidence outputs. `client-results.json`, `native-results.json` and `soak50-execution.json` retain results, durations and copied-test hashes.

Soak's exact engine argument tail:

```text
--audio-driver Dummy --rendering-method gl_compatibility --path <root>/game
--script tests/soak_runtime_correctness.gd -- --cycles=50
--report-dir=res://../build/re-audit-2026-10-27/soak50-native
```

Actual App load profile:

```text
--audio-driver Dummy --rendering-method gl_compatibility --path <root>/game
--script <root>/build/re-audit-2026-10-27/profile_current.gd
```

The profile copy changes only explicit offline setup/output roots. It loads Star and five Storm tracks twice and checks pause/camera/held-input state. Evidence includes individual load records and native images.

Additional isolated headless scripts run with `--headless --audio-driver Dummy --path <root>/game --script <script>`:

- `game/tests/test_handling.gd`: 88 checks.
- `game/tests/test_checkpoint_rules.gd`: 266 checks.
- `game/tests/test_creator.gd`: 113 checks.
- `game/tests/test_script_parse.gd`: final 1,330 scripts, zero parse failures.
- `checks/test_electric_slide_access.gd`: 518 checks, only final report output redirected; original baseline read retained.
- `checks/test_free_race_restart.gd` where retained by the run: 17 checks; see `free-race-restart.log` and original test entrypoint.

Late Garage preload runs use the same offline copied script, once headless and once native:

```text
--headless --audio-driver Dummy --path <root>/game
--script <root>/build/re-audit-2026-10-27/checks/test_garage_preload.gd
-- --output=res://../build/re-audit-2026-10-27/preloader

--audio-driver Dummy --rendering-method gl_compatibility --path <root>/game
--script <root>/build/re-audit-2026-10-27/checks/test_garage_preload.gd
-- --output=res://../build/re-audit-2026-10-27/preloader-native
```

Their execution JSON records exact commands/PIDs/hashes. Results: 381 headless / 382 native assertions, zero failures. Native metrics, including a 2,659 ms maximum warm draw interval, are in `preloader-native/report.json`.

`pause_settled.gd` is a separate native `--verbose` cleanup control. Only end-of-test free/null/settling changes; all 17 assertions remain. Four Ogg audio objects / one resource still remain at exit. The initial graphical pause test was incorrectly attempted headless; that owned process was stopped and its failure retained. No pass is attributed to that invocation.

## Backend selection

Executed from `backend`, with isolated basetemp/cache paths under the audit build folder:

```text
<venv-python> -m pytest -q
  tests/test_trajectory_integrity.py tests/test_lightweight_verifier.py
  tests/test_security_fixes.py tests/test_auth.py tests/test_commerce.py
  tests/test_privacy.py tests/test_resume_recovery_wire.py
  tests/test_statistics_request_reuse.py
  -k "not postgres" --basetemp=<audit>/pytest -o cache_dir=<audit>/pytest-cache
```

Result: 160 passed, two failed, five fixture errors, two skipped, 30 deselected. Strict native verifier fails closed on the sandbox certificate error; the recovery-wire development wrapper also encounters access denial. The initial wrong-import-root invocation is retained separately. The original native-wire fixture regenerated build identity metadata incidentally.

The same eight modules, adding `-m "not godot"` and separate `pytest-unit` / `pytest-unit-cache` output roots: **160 passed, two skipped, 37 deselected**.

Direct-engine wire control from repository root, with `PYTHONPATH=backend;backend/tests`:

```text
<venv-python> -m pytest -q
  build/re-audit-2026-10-27/test_resume_recovery_wire_direct.py
  -k "not postgres" --basetemp=<audit>/wire-pytest
  -o cache_dir=<audit>/wire-pytest-cache
```

Result: **five passed, five deselected**. The copied test changes only its blocked development-wrapper process launch to direct pinned Godot execution of the unchanged wire-budget fixture. All HTTP/backend assertions remain.

No PostgreSQL parameterized fixture was selected. No live/player database was accessed by these tests.

## Static and trust checks

```powershell
python scripts/localization.py check
.tools/backend-secure-venv/Scripts/python.exe -m ruff check backend/bmt_backend backend/tests --output-format json
```

Translation result: current 2,659-message template, 176 completeness failures (16 per non-English language). Ruff: 18 findings, five production. The complete structured results are retained.

`verification_probe.py` first attempted the strict native verifier and failed on Godot's certificate error (`trajectory-probe.log`). The unchanged `game/backend/runner.gd` was then invoked directly with the local `geometry-request.json` / `geometry-response.json`; its fresh geometry and manifest were supplied to the actual Python acceptance function. `trajectory-probe-raw.log` and `synthetic-trajectory-result.json` retain the successful local trust reproduction. No score/reward was submitted to a service. No strict verifier error policy was relaxed.

The inventory/location scan uses `rg --files` and local hashing; three private-key/live-payment/GitHub-token patterns yielded zero locations. Private credential/environment roots were excluded. No comprehensive secret/advisory audit is claimed.

## Packaging and limits

```powershell
python build/re-audit-2026-10-27/package_evidence.py
```

This copies only audit-generated logs/harnesses/results/captures, never profiles, credential configuration, pytest databases or player saves. UTF-16 raw logs are retained alongside UTF-8 readable copies. SHA256 manifests cover the packaged evidence. Start/end inventory comparisons include initial paths even if ignore rules change; absence from a later `rg` listing is not treated as a deletion.

The complete 27 October backend rollout receipt is inspected as **retained evidence**, and its manifest is compared mechanically with fresh local geometry. It was not deployed or independently live-tested by this audit. Device, final artifact, provider and full-suite acceptance remain as described in the main report.
