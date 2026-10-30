# Commands and verification scope

Root: `C:/Codes/Godot/Beat my track`. Engine: `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe`, pinned `4.7.2.stable.official.ed1daf0bf`.

Actual process argument lists, PIDs, copied-test hashes, exit codes and runtime errors are in the `*-execution.json` receipts. Logs are UTF-8. A zero engine exit code with script/resource errors is not counted as a clean result. All runtime logs retain the sandbox root-certificate-store warning.

## Runner

```text
python build/runtime-loading-fixes-2026-10-27/run_check.py LABEL SCRIPT MODE [TEST_ARGS]
```

Modes are `headless`, `gl_compatibility` and `mobile`. The last is desktop Vulkan Mobile, not Android. The runner creates private APPDATA/LOCALAPPDATA, clears BMT environment configuration and explicitly saves an empty backend URL before starting each test. Assertions and thresholds remain; output destinations are redirected. It records the process before waiting and checks native-only fixture prerequisites.

Examples executed:

```text
run_check.py baseline-load game/tests/profile_runtime_correctness.gd gl_compatibility
run_check.py after-load-retry game/tests/profile_runtime_correctness.gd gl_compatibility
run_check.py final-focused-gl game/tests/test_runtime_loading_fixes.gd gl_compatibility --project=build/runtime-loading-fixes-2026-10-27/frozen-after/game
run_check.py final-focused-mobile game/tests/test_runtime_loading_fixes.gd mobile --project=build/runtime-loading-fixes-2026-10-27/frozen-after/game
run_check.py accepted-app-gl game/tests/test_runtime_effect_loading.gd gl_compatibility --first-emission --project=build/runtime-loading-fixes-2026-10-27/frozen-after/game
run_check.py accepted-app-mobile game/tests/test_runtime_effect_loading.gd mobile --first-emission --project=build/runtime-loading-fixes-2026-10-27/frozen-after/game
run_check.py accepted-parser game/tests/test_script_parse.gd headless --project=build/runtime-loading-fixes-2026-10-27/frozen-after/game
run_check.py accepted-load-profile build/runtime-loading-fixes-2026-10-27/final_profile.gd gl_compatibility --project=build/runtime-loading-fixes-2026-10-27/frozen-after/game
```

The final profile preserves the original 60 assertions and additionally records effect counts/reuse. Its run follows the functional GPU batch. Cold disk/driver caches were not cleared and owner processes were left running.

## Controls and retained failures

- `capture_front.gd` records task-start full/simple front signatures and timings before production edits.
- `task_start_contract.gd` loads anonymous copies of the saved original builders: shader sharing, staged preparation and cooperative front entry are all absent. No production source is rolled back.
- `frozen-baseline-dynamic` runs the original full dynamic fixture in the private before-project. It retains 466 checks / 13 failures.
- `dynamic_task_fixture.gd` changes only the obsolete legacy builder input to the exact task-start `SandDust` source. Its component runs preserve the original assertions and pass 139 headless / 462 Compatibility / 472 desktop Mobile. `sand-dust-source-proof.json` verifies that source against the prior audit hash.
- `front_join_builder_fixture.gd` explicitly disables prepared-scene restoration when asserting builder-only dictionaries. All 3,031 original assertions pass; its four-object/one-resource shutdown finding remains recorded.
- Original Mobile night assertions pass. One final run retains four objects/one resource at shutdown, while the task-start control exits cleanly once. No general shutdown fix is claimed.
- The first focused shader-default fixture error, cache accounting/teardown attempts, headless invocation mistakes, transient concurrent class/dialog failures, failed initial profile and headless dummy-texture warning are all retained.

Only command-line-verified processes whose script is in this task's private `checks` directory were stopped. `stop_owned.py` and the stop receipts record that guard. No owner process was stopped or restarted.

## Source isolation and packaging

```text
python build/runtime-loading-fixes-2026-10-27/task_sources.py
python build/runtime-loading-fixes-2026-10-27/task_sources.py --sources-only
python build/runtime-loading-fixes-2026-10-27/package_evidence.py
```

The private before/after projects share public assets/imported data and native runtime libraries read-only. Their code is copied, and the before-project removes only the requested changes. The same concurrently corrected dialog is applied to both private copies. Source-only ZIPs and hashes exclude profiles, player records, SDK settings, assets and native binaries. Frozen projects have outward junctions; the packager traverses only explicit safe directories.

Pinned class-registration import:

```text
Godot_v4.7.2-stable_win64.exe --headless --editor --import --path <root>/game
```

Its zero exit does not erase the locked editor-reload DLL copies, isolated Android SDK settings and certificate warning. No native library or owner process was changed to bypass them. Runtime tests use the actual existing libraries.

The audit-only/runtime task review patch is checked and applied in a separate directory with parent Git discovery disabled, then compared byte-for-byte. No root index, staging, commit, merge, reset, release build, device operation, live provider request or deployment is used.
