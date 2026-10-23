# Race interstitial cadence — 2026-10-22

The owner requests an ad after three races or ten minutes, whichever comes first. ADB01–ADB04/R01/Q01 implement that placement locally through the existing AdMob development integration. This explicit placement request supersedes the original blueprint's ads-off/forced-interstitial exclusion for this feature. No production rollout is included.

## Behavior

- **ADB01:** Count completed ordinary races once per attempt through the shared App results path. Free Race, Rivalry and Challenges use this boundary. Abandoned attempts, creator test drives, practice and duplicate completion callbacks do not add finishes. Retrying a completed race starts a new countable attempt.
- **ADB02:** An ad becomes due after three finishes **or** 600,000 milliseconds of active foreground session time. The timer includes ordinary menu use and racing; it excludes background/focus loss, paused races/results, loading, creator/draft work, practice and the ad itself. Time uses the monotonic clock outside the canonical simulation. Counters are session-local and saturate at their thresholds.
- **ADB03:** Present only at the next ordinary race finish, after saving/building its result. Ten minutes never interrupts driving or opens an ad while sitting in a menu. Keep one native preloaded interstitial; loading never opens it. If it is unavailable, return to play immediately and retain the due state for a later finish. Either threshold, or both together, produces one ad. Only an actual show resets both counters, after dismissal. Result actions are shielded during the SDK handoff and the previous keyboard focus is restored afterward.
- **ADB04:** Check authoritative `/me/entitlements` at preparation and at an eligible break. Monthly/permanent ad-free access suppresses the placement. Failed/malformed ownership reads skip it. An account change, leaving/hiding the exact result, backgrounding, and stale/duplicate SDK callbacks cannot open a late ad. Results remain usable during the ownership read.
- **R01:** The existing rewarded-resume path, reward authority, race proofs, PBs, uploads, contracts, race rules and physics are retained. Native rewarded/interstitial displays share one fullscreen request owner. Interstitials grant no reward.

The existing **Settings → Development → Show ads** switch enables the placement on Android debug builds; Off remains Off. Desktop/release builds with no supported bridge remain quiet and issue no placement ownership reads. No preference, saved account or live configuration has been changed. Google's sample app ID and interstitial demo unit `ca-app-pub-3940256099942544/1033173712` are used. Java/source and the existing SDK dependency remain debug-only. The one cached interstitial expires after 55 minutes and its preload has a 45-second timeout; stale loads are discarded. Primary references checked: [Google interstitial integration](https://developers.google.com/admob/android/interstitial) and [test ad units](https://developers.google.com/admob/android/test-ads).

## Files and checks

Runtime changes: `game/core/app.gd`, new `game/platform/race_ad_breaks.gd`, new `game/platform/admob_interstitial.gd` and their UIDs. Native change: `native/admob/src/org/beatmytrack/admob/BmtAdMob.java`; provenance updated in `native/admob/PROVENANCE.md`. Tests: new `game/tests/test_race_ad_breaks.gd` and UID. Status records: `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and this report. Other work in the shared checkout is retained.

All wrapper commands ran from the repository root with `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`. Each Godot run redirected `APPDATA` into a task-owned `.tools/interstitial-cadence-*-user` directory. Windows certificate-store access required execution outside the restricted sandbox; no live account/service or device was used by the fixtures.

| Actual command/check | Outcome |
| --- | --- |
| `TestScript -ScriptPath res://tests/test_race_ad_breaks.gd -CommandTimeoutSeconds 180` | Final **57 checks, 0 failures**. Deterministic thresholds, both-at-once serialization, failure carryover, foreground time, entitlement/account/navigation fences, adapter callback identity, and actual App finish/retry/save/focus paths. |
| Pinned `Godot_v4.7.2-stable_win64_console.exe --audio-driver Dummy --path game --script res://tests/test_race_ad_breaks.gd --log-file <evidence>/graphical-dummy.log -- --capture-ad-breaks=<evidence>` | Final **59 checks, 0 failures**, desktop Compatibility, including two screenshot writes. |
| `TestScript -ScriptPath res://tests/test_admob_development.gd -CommandTimeoutSeconds 180` | **44 checks, 0 failures**; existing rewarded-resume behavior. |
| `TestApp -CommandTimeoutSeconds 240` | **141 checks, 0 failures**. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180` | **930 scripts, 0 failures**. |
| `Import -CommandTimeoutSeconds 180` | Exit 0 on the pinned engine; new script UIDs registered. |
| Existing Gradle wrapper, `compileStandardDebugJavaWithJavac --offline --no-daemon` | **BUILD SUCCESSFUL**, actual Java compilation with cached SDK 25.5.0. No APK target. Existing compileSdk/AGP and manifest warnings retained. JDK 17.0.20.1+1 and the configured Android SDK were used. |
| Scoped `git diff --check` and task-patch reverse check | See `report.json` for the final receipt. |

The first sandbox run could not write the normal user log; a workspace data directory resolved that. Engine startup then failed reading the Windows root certificate store; the isolated run with certificate-store access succeeded. Initial real-App fixture attempts omitted the required published-track marker, then the final lap timestamp; these caused a missing race and three legitimate save-check failures respectively. The fixture was corrected without changing runtime validation. Initial focused passes were 51 checks, then 55 after adding simultaneous-limit/time-first coverage; final focus coverage raises this to 57. The first default graphical run exited with a Windows WASAPI `GetBufferSize` error. A pinned-engine Dummy-audio run passed 55 checks, then the final capture/focus run passed 59. The initial Java command lacked a standard flavor and was ambiguous; the explicit standard-debug compile passed. No failing assertion was removed or weakened.

## Evidence and remaining acceptance

`docs/evidence/interstitial-cadence-2026-10-22/` contains original source snapshots, a task-only source patch, source fingerprints, copied test receipts, Java compilation output and `report.json`. `results-during-injected-ad.png` and `results-after-injected-ad.png` show the real native result page with an injected test adapter; they are **not** screenshots of a Google ad. The focused fixture synthesizes five equal lap times and has no driving telemetry. Its result remains saved and the Retry button regains focus after dismissal. No fake ad screen was added to the product.

Phone attachment was not checked; no physical-device/emulator ad test, APK/export/install, backend deployment, account/race mutation or provider-console change was performed. Actual native ad loading/show/dismissal, touch, owner acceptance of frequency, and release enablement remain. Production requires the owner's AdMob app/interstitial IDs and consent/release configuration. The existing debug-only packaging is intentionally retained until those inputs are supplied. Session restart resets this local cadence; no cross-session persistence was requested.
