# OnePlus phone: offline guest tracks and rendering — 2026-10-11

Requirements R01/T01/V04/V05/Q01. The owner connected the phone after accepting the tablet dust fix, then requested tracks on the phone because it has no internet connection. This authorizes this USB installation/cache transfer. No backend deployment was performed.

## Delivered

The OnePlus DN2103, serial `PRQKU4U4PREQNRWG`, Android 13/API 33, Mali-G77 MC9, has the exact accepted tablet debug APK installed with existing app data preserved. Its SHA-256 is `52fd58bef9bad528552d3d11ed30afcb60ba94a185252194ed02a0964627fd70`, 275,917,226 bytes. No APK rebuild or runtime rendering change was needed for this phone.

**27 existing published tracks** were copied over USB from the PC's public cache for the phone's existing `http://127.0.0.1:18181` origin. Their catalog and immutable document files now populate normal **Play as guest → Race → Free Race**. Every source document matched its published SHA-256 and passed the pinned engine's schema, route and compilation validation. Every transferred file's installed SHA-256 was checked. The catalog was merged by logical track ID and committed after the documents; replaced files have phone-private backups. Phone-only tracks, saved records and account files were preserved. No account/session/credentials, outboxes or artificial-driver data were copied. The old September creator drafts and retired Slicks corpus were not used.

The phone reported **Active default network: none** before and after verification. Normal Guest Free Race showed Dust Cloud and the other transferred cards; Dust Cloud launched an actual five-lap race, and a 2.2-second touch accelerator hold moved the car and created the original dust trail. The screenshot shows 83 km/h, lap 1/5 and a solid car. The ordinary app was left running, PID 24027, with both private mobile diagnostic markers absent.

Evidence: [catalog](evidence/phone-offline-tracks-2026-10-11/guest-catalog.png), [five-lap race start](evidence/phone-offline-tracks-2026-10-11/guest-race-start.png), [touch driving](evidence/phone-offline-tracks-2026-10-11/guest-driving.png), [all names and per-file hashes](evidence/phone-offline-tracks-2026-10-11/transfer-manifest.json), [bundle validation](evidence/phone-offline-tracks-2026-10-11/bundle-validation.log), [network state](evidence/phone-offline-tracks-2026-10-11/connectivity.txt), [installed APK hash](evidence/phone-offline-tracks-2026-10-11/installed-apk-hash.txt).

## Phone rendering result

The Mali renderer remains Compatibility/OpenGL with 2× MSAA (`msaa_actual=1`) and no world FXAA. The Adreno-specific workaround stays restricted to its affected GPU family. Shipping dust presentation remains `desert-dust-21`; original emission, appearance, growth and timing are retained.

The controlled native frozen-cloud comparison found 48 opaque car surfaces, no transparent/depth-disabled/shader-alpha surfaces, 5,989 sampled car-roof depth pixels and 5,521 eroded roof-interior pixels. With visible dust, **zero roof-interior pixels changed**, while 33,577 surrounding pixels changed. The phone samples opaque car depth correctly with MSAA.

The separate actual 30-second unscored driving profile covered 224.163 m: median **16.948 ms (~59 FPS)**, p95 **20.824 ms**, zero paused frames. World rendering covered 1,153,152 pixels at the existing mobile scale, with shadows enabled. This is a short driving sample, not sustained thermal acceptance.

Ground-underpass and upper-deck controlled captures were inspected. The ground car/marks/cloud are hidden by the opaque deck; upper-deck dust and tracks remain present. Both accepted bridge runs have zero paused frames. These fixed-pose diagnostics are visual checks, not driving FPS measurements. The first deck run had 92 paused frames and was rejected; the fresh `deck-retry` completed normally.

Evidence: [native car-depth map](evidence/phone-rendering-2026-10-11/initial-parity/driving-1.png), [same cloud with opaque car](evidence/phone-rendering-2026-10-11/initial-parity/driving-2.png), [parity report](evidence/phone-rendering-2026-10-11/initial-parity/results.json), [actual driving report](evidence/phone-rendering-2026-10-11/driving/results.json), [ground](evidence/phone-rendering-2026-10-11/ground/driving-0.png), [upper deck](evidence/phone-rendering-2026-10-11/deck-retry/driving-0.png).

## Actual commands and outcomes

All commands were run from the repository in PowerShell, with authorized toolchain access.

```powershell
# Exact accepted APK installation and native opaque-car/cloud comparison: exit 0.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-tablet.ps1 `
  -DeviceSerial PRQKU4U4PREQNRWG -DocumentPath game/tests/fixtures/dust_cloud.json `
  -Seconds 10 -Features parity_reference,parity_scene_depth,parity_baseline `
  -DustParityReview -CaptureDriving -CaptureDelaySeconds 5 `
  -RequiredRenderer gl_compatibility `
  -Output docs/evidence/phone-rendering-2026-10-11/initial-parity -Install

# Moving sample: exit 0, 224.163 m, zero paused frames.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-tablet.ps1 `
  -DeviceSerial PRQKU4U4PREQNRWG -DocumentPath game/tests/fixtures/dust_cloud.json `
  -Seconds 30 -Features baseline -CaptureDriving -CaptureDelaySeconds 5 `
  -RequiredRenderer gl_compatibility -Output docs/evidence/phone-rendering-2026-10-11/driving

# Ground fixture: exit 0. Deck rerun: exit 0, both visual-only.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-tablet.ps1 `
  -DeviceSerial PRQKU4U4PREQNRWG -DocumentPath game/tests/fixtures/dust_cloud.json `
  -Seconds 10 -Features baseline -BridgeReview -BridgeLayer Ground -CaptureDriving `
  -RequiredRenderer gl_compatibility -Output docs/evidence/phone-rendering-2026-10-11/ground
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-tablet.ps1 `
  -DeviceSerial PRQKU4U4PREQNRWG -DocumentPath game/tests/fixtures/dust_cloud.json `
  -Seconds 10 -Features baseline -BridgeReview -BridgeLayer Deck -CaptureDriving `
  -RequiredRenderer gl_compatibility -Output docs/evidence/phone-rendering-2026-10-11/deck-retry

# Existing 27 public documents: exit 0, all hash/schema/route/compilation checks passed.
$publicCache = "$env:APPDATA/Circuit01Lab/cloud/166f57396bcc750da426bf322777f9361f3815cbbf3c091202d7f10ede7e2573"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 `
  -Action TestScript -ScriptPath res://tests/check_offline_track_bundle.gd -TestArgument $publicCache

# USB cache-only deployment: exit 0, catalog and all 27 documents hash checked.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/sync-phone-offline-tracks.ps1 `
  -DeviceSerial PRQKU4U4PREQNRWG -SourceCachePath $publicCache `
  -Output build/phone-offline-tracks-2026-10-11-final
```

Native commands also used `adb shell dumpsys connectivity`, normal menu taps, `input swipe 2175 760 2175 760 2200`, `screencap`/`pull`, `pm path`/`sha256sum`, `pidof`, and exact `run-as ... test -e` marker checks. Temporary screenshot files were removed by exact path. The transfer script's PowerShell syntax check passed.

Failed attempts are not passing evidence: direct invocation of `dev.ps1` was blocked by Windows execution policy and was rerun with the existing Bypass entry point; an incorrect log-copy path stopped before any transfer; Windows PowerShell initially treated successful ADB progress on stderr as fatal, corrected by checking native exit status explicitly. That transfer stopped before replacing a track and preserved its incomplete snapshot. An invalid `-BridgeLayerDeck` argument was corrected to the existing `-BridgeLayer Deck`; no device change occurred in that rejected invocation.

## Changed files and remaining acceptance

Added `scripts/sync-phone-offline-tracks.ps1` (hash-checked, backed-up cache transfer; no export), `game/tests/check_offline_track_bundle.gd` (opt-in real-document validator; no network), this document, phone evidence and summary, and deployment notes in `docs/ANDROID.md`, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`. No canonical simulation, camera, physics/rules, scoring, authentication or acceptance contract changed.

All 27 documents were validated/compiled, but only Dust Cloud was launched and driven through the phone's normal guest UI. No complete five-lap race, every-track phone drive, long thermal run, other-car acceptance or phone Google sign-in was performed. Guest racing remains local; competitive verified results require authenticated online racing. The tablet was not attached during these phone checks.

A task-only Git-format checkpoint is saved at `build/phone-offline-checkpoint-2026-10-11/checkpoint.patch`, with a frozen review tree and reverse-apply check. Shared existing workspace changes are excluded; the read-only Git index was not staged or committed.
