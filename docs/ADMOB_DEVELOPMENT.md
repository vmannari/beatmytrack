# AdMob development ads — 2026-10-04

2026-10-04 follow-up: the native x86_64 APK and saved cold-boot Pixel 9 configuration improve track loading; see [EMULATOR_PERFORMANCE.md](EMULATOR_PERFORMANCE.md). One preview retry on that VM still returns SDK code 0 / Unable to obtain a JavascriptEngine. No fullscreen completion or reward was observed; Show ads was restored to Off.

The owner authorized AdMob and a Development section in Settings with a saved Show ads switch. This slice uses Google's real Android SDK and rewarded demo placement in debug builds. Production placements, consent/release configuration, purchases and server-verified banked fulfillment remain separate acceptance work.

## Requirements and behavior

| ID | Implemented contract |
| --- | --- |
| AD01 / V03 | Settings → Development → Show ads, Off by default; Apply settings persists it atomically. Reset development resets only this preference. Sidebar scroll keeps the sixth category accessible on compact displays; category buttons pass drag events to the scroll container. |
| AD02 / RW17 | Off retains the existing immediate temporary resume. On requires a completed Google test ad after banked and daily free resumes are exhausted. Existing server capability controls availability. |
| AD03 / RW05–RW07 | Native rewarded-ad completion is observed honestly. Early close, load/show failure, timeout, account/race changes and cancellation spend nothing. Simulation remains outside the platform adapter. |
| AD04 / RW07 | Resume consumption retains the original race-bound idempotency key. A lost response retries without another ad; completed-ad authorization is bound to the selected race/ordinal/ticks/input offset. Three confirmed resumes per race and the ten-second bound remain. |
| AD05 / V05 | Test rewarded ad opens the actual demo placement without spending or adding resumes. SDK/native code and menu category are debug-only. The bridge makes no rewarded-ad request until explicitly requested. |
| AD06 / Q01 | Exact Godot/source template and SDK versions, asset/dependency provenance, native evidence and a scoped patch are recorded. No production service deployment or credentials. |

Use Settings → Development, turn **Show ads** On, then **Apply settings**. **Test rewarded ad** also applies the staged settings before opening the preview. Off disables preview and restores the temporary free resume path in the development build. Desktop shows the setting but explains that ad previews require Android.

Banked credits are still consumed first, then today's expiring allowance. Debug demo completion gates only the already-authorized `ad_preview` receipt. It does **not** mint a banked credit, submit invented provider proof, or advertise production `ads_available`. For production banked grants, configure real IDs and verify signed, idempotent [AdMob server-side callbacks](https://developers.google.com/admob/android/ssv) before replacing the temporary capability.

## Implementation and build

Original native bridge: `native/admob/src/org/beatmytrack/admob/BmtAdMob.java`. It serializes main-thread SDK requests, waits for fullscreen dismissal before returning success, cancels abandoned requests and times out loading after 45 seconds. GDScript adapter: `game/platform/admob_test_ads.gd`; stale/duplicate callbacks are ignored. Only the public [Google demo application and rewarded unit](https://developers.google.com/admob/android/test-ads) are used. SDK `com.google.android.gms:play-services-ads:25.5.0` is pinned with `debugImplementation`; source is attached only to `android.sourceSets.debug`. Minimum Android SDK is 24, per [Google's setup guide](https://developers.google.com/admob/android/quick-start). Provenance: `native/admob/PROVENANCE.md`.

Godot export hook `game/addons/bmt_admob/export_plugin.gd` adds the native plugin and sample app metadata to debug only. The game preset now uses Gradle. `scripts/dev.ps1 ExportAndroid` installs the exact official source template into ignored `game/android/build`, writes `game/android/.build_version`, attaches the original Gradle hook and disables the persistent Gradle daemon so the Windows console process can finish. An existing incomplete/mismatched template is preserved and rejected.

Godot remains `4.7.2.stable.official.ed1daf0bf`. Source `android_source.zip` SHA-256 is `A15416B528EFB0A19A7D187E4D9F4E5336D0689144B111329FB4BD12C4447AD3`. It is read from the matching global template directory or ignored `.tools/admob/android_source.zip`; obtained from the official `Godot_v4.7.2-stable_export_templates.tpz`. Native template versions: Gradle 8.11.1, AGP 8.6.1, Kotlin 2.1.21, compile SDK 36, build tools 36.1.0, NDK 29. SDK/platform tools were installed using already accepted Android licenses. JDK 17 and SDK paths come from the pinned editor settings.

Windows export temporarily uses Java's `Windows-ROOT` trust store unless the caller explicitly selects a custom trust store, and restores `JAVA_TOOL_OPTIONS` afterward. This preserves TLS verification and uses the computer's existing trusted roots; it does not install a certificate or disable HTTPS checks. [Oracle's provider documentation](https://docs.oracle.com/en/java/javase/17/security/oracle-providers.html) describes Windows-ROOT.

### Approved local Avast diagnostic configuration

The first real emulator request failed with AdMob code 0. Android WebView reported `Trust anchor for certification path not found` / `net_error -202`. A verified host TLS probe identified Avast's HTTPS scanning root as the issuer. Windows already trusts this root; the emulator did not. The owner explicitly approved trusting that same public root for local debug ad testing.

Optional `BMT_ADMOB_DEBUG_CA_DIR` attaches an explicitly selected local debug manifest/resource directory through `native/admob/android.gradle`. No certificate or generated trust XML is committed. On this machine `.tools/admob/local-trust` contains the public DER certificate (no private key), manifest and domain-limited configuration for Google's ad/resource domains. Normal system roots remain trusted, other domains retain system trust, TLS remains verified, and release source sets never include it. The generated files can be reviewed locally before using the option. This is separate from the Java build-download trust setting.

```powershell
# Normal debug build, with standard Android trust:
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ExportAndroid -QuickValidation -CommandTimeoutSeconds 600
# Only for this owner's approved local Avast diagnostic configuration:
$env:BMT_ADMOB_DEBUG_CA_DIR = (Resolve-Path '.tools/admob/local-trust').Path
try {
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ExportAndroid -QuickValidation -CommandTimeoutSeconds 600
} finally { Remove-Item Env:\BMT_ADMOB_DEBUG_CA_DIR -ErrorAction SilentlyContinue }
```

Changing antivirus settings or installing a system-wide Android CA was unnecessary. Builds without the environment option do not include this local trust configuration. Android's [network-security configuration documentation](https://developer.android.com/privacy-and-security/security-config) explains domain-specific trust anchors; the build variant supplies the debug-only boundary here.

## Changed files and actual validation

Runtime/UI: `game/ui/settings_page.gd`, `game/persistence/local_records.gd`, `game/platform/resume_credits.gd`, `game/core/game.gd`, new ad adapter and UID. Packaging: new `game/addons/bmt_admob/` export hook/config/UID, new `native/admob/` source/Gradle/provenance, `game/project.godot`, `game/export_presets.cfg`, `scripts/dev.ps1`, `.gitignore`. Tests: new `game/tests/test_admob_development.gd` and UID, `game/tests/capture_settings.gd`, `game/tests/test_script_parse.gd`. Documentation: this file, `docs/ANDROID.md`, `docs/REWIND.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, `AGENTS.md`.

Commands from repository root, using `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Action | Actual outcome |
| --- | --- |
| `Import` | Passed on the pinned engine; registered new scripts and export hook. |
| `TestScript -ScriptPath res://tests/test_admob_development.gd` | **44 checks, 0 failures**, wrapper exit 0. Fake SDK/client objects exist only inside this export-excluded harness. Tests cover priority, early close, completion, retry/idempotency, account/race fencing, capability/transport rejection, persistent type validation and stale callbacks. |
| `CaptureSettings` | **263 checks, 0 failures**, at 1280×720, 960×540 and 1600×720. Persistence, staged drafts, scoped reset, save-failure rollback and category/content geometry checked. |
| `TestRecords` | **54 checks, 0 failures**. |
| `TestRewind` | **57 checks, 0 failures**. |
| `TestApp` | **96 checks, 0 failures**. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | **284 scripts, 0 failures**. Traversal now follows `.gdignore`, excluding the generated native template's vendor instrumented-test assets exactly as Godot does. |
| `ExportAndroid -QuickValidation -CommandTimeoutSeconds 600` | Passed: import/`APP_READY`, driving **72**, catalog **21**, menus **48**, native Gradle compile and fresh APK export. Full Validate not run. |
| `InstallAndroid -DeviceSerial emulator-5554`, `LaunchAndroid -DeviceSerial emulator-5554` | Original AdMob debug APK installed, `Success`; explicit force-stop and cold launch passed. Native plugin initialized and `APP_READY` logged. |
| `game/android/build/gradlew.bat dependencies --configuration standardReleaseRuntimeClasspath --console=plain` | Passed with configured JDK 17/Windows-ROOT; **zero Mobile Ads dependency matches**. Log: `build/admob-release-dependencies.log`. Initial direct invocation lacked JAVA_HOME and was corrected. This resolves dependencies, not a signed release build. |

Normal-trust debug APK snapshot: `build/android/circuit01-admob-debug.apk`, SHA-256 `06D5A8B1A7B2649ECD227F7605B99A040663A3A5FDD48D7F23B1E37DAF34EDBA`. Zip inspection confirmed both the original native bridge and the rewarded SDK class. This dedicated artifact avoids another task overwriting the shared `circuit01-debug.apk`.

Initial failures and corrections: sandboxed Godot could not open its user-data log; permitted toolchain execution resolved that. A no-argument `CheckScript` accidentally launched the app and hit its timeout; this is not a passing parse test. Standalone indirect `DriveFrame` loading initially retained a script on shutdown; loading the app's actual dependency graph fixed the targeted test's resource errors. Java's bundled CA store initially rejected Maven HTTPS; Windows-ROOT fixed verified downloads. A successful native build's persistent Gradle daemon held the console pipe; disabling that daemon fixed exporter completion. The first all-script scan found a vendor `BaseTest` dependency under ignored Gradle assets; honoring `.gdignore` fixed the scan without excluding project scripts. The first local-certificate manifest replaced Godot's generated metadata and caused a missing-AdMob-app-ID startup crash. The combined manifest now preserves Godot's complete metadata and lives outside Gradle's clean output directory; an intermediate build-directory version was erased by Godot's clean task and rejected by APK inspection before installation. Final APK manifest inspection requires debug/plugin/app-ID/trust entries before install. Existing driving shutdown ObjectDB warnings appeared in focused runs; no canonical code or failing physics invariant was changed.

## Device evidence and remaining acceptance

Pixel_9 / `emulator-5554` is Android 17/API 37, Google Play, x86_64 with ARM64 translation and 16 KB pages. Existing package data was retained. `adb -s emulator-5554 reverse tcp:18181 tcp:18181` routes the debug game to the already-running local PC backend. No API/worker rebuild, migration, deployment or real-player balance grant was performed by this task. DN2103 is attached, but **no physical-phone install or ad/device test was performed for this slice**.

Inspected evidence: `docs/evidence/admob-development-2026-10-04/android-development-off.png` (default Off/disabled preview), `android-rewarded-ad.png` (saved On and honest initial TLS failure), `android-development-on-reloaded.png` (On retained after reinstall/cold launch), `android-test-ad-diagnostics.png` (load failure), `android-sdk-probe.png` and `android-sdk-probe-25.4.png` (independent SDK failure); desktop Development captures in `build/settings/settings-development-{1280x720,960x540,1600x720}.png`.

### Independent SDK diagnosis

The approved CA configuration removed the game's sampled WebView trust-anchor errors. The SDK recognizes the sample app ID and the emulator as a test device; its core web page loads and logs `jsLoaded`, but its rewarded request returns **code 0 / “Unable to obtain a JavascriptEngine.”**, with no response ID or adapter response. The bridge now logs full SDK load/show diagnostic objects under `BMTAdMobTest`.

An original minimal Android Activity was built under ignored `.tools/admob/sdk-probe`, using the same Google sample IDs and local CA configuration, without Godot or game code. Actual command: `game/android/build/gradlew.bat -p .tools/admob/sdk-probe assembleDebug --console=plain` with configured JDK 17/Windows-ROOT. **25.5.0 build passed in 1m18s; 25.4.0 comparison passed in 47s**. Both were installed/launched specifically on `emulator-5554` under temporary package `org.beatmytrack.admobprobe`, and **both reproduce the same initialization error**. The game remains pinned to 25.5.0; 25.4.0 is only a diagnostic comparison, consistent with [Google's release history](https://developers.google.com/admob/android/rel-notes).

Temporary ADB WebView inspection on port 9223 confirmed the SDK core page's ready state was `complete` and its sample public configuration request completed. The matching host GET returned HTTP 200. This narrows the failure to the SDK/emulator/network combination; it does not identify one exact component or prove that another API image/network will fix it. No invented ad, reward or passing fullscreen check is reported. The probe and temporary forwarding are removed before handoff.

The 25.4.0 probe reproduced the same error after an actual emulator reboot (`sys.boot_completed=1`); evidence is `android-sdk-probe-after-reboot.png`. The temporary probe package was then uninstalled successfully. The original game cold-launched again successfully; emulator port 18181 was restored. SDK logs (`build/admob-sdk-diagnostics.log`) and both probe build logs remain under ignored `build/`.

Final development APK: `build/android/circuit01-admob-local-debug.apk`, SHA-256 `60CA102B404C657795085F9B00ECC1AFCF037AC2868E89E10163236FD3D1DA93`. Its manifest was inspected for the native plugin, sample app ID, debug flag and optional trust reference; DEX inspection confirmed bridge/SDK/detailed error logging. Install and repeated cold launches succeeded. **Actual fullscreen playback, completion/early-dismissal return and in-race native ad/audio/pause behavior remain unverified because SDK loading fails on this emulator.** Native load failure is verified and spends nothing; automated completion/cancellation/consumption tests passed using export-excluded fakes, not a simulated shipping ad. Final native sidebar content swipe reaches Development without selecting the dragged-over category; Off survives a fresh page and cold launch, and disables preview. Show ads is left Off for usable temporary resumes. Evidence: `android-final-sidebar.png`, `android-development-final-off.png`.

Remaining acceptance: diagnose the SDK/WebView/network failure or retry on another supported development device/network; this task does not prove a specific workaround. Then verify fullscreen completion, early dismissal, background/audio restoration and two in-race resumes (daily first, then ad), without adding banked credits. Owner finger feel, physical-device testing, real consent/account configuration, signed production SSV grants, a built release exclusion audit and performance/thermal acceptance remain. Full Validate and hosted deployment were not performed. The scoped source checkpoint is `build/checkpoints/admob-development-2026-10-04/admob-development.patch`; the shared dirty tree is preserved without a mixed commit.
