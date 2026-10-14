# Nord 2 cloud connection repair, 2026-10-13

Requirements: PD03 restore the connected phone's game-server configuration; PD04 diagnose the remaining sign-in failure; V03/V05/Q01 retain actual device evidence and report limitations. The owner reports Wi-Fi connected but Beat my track cannot log in.

## Findings and repair

Actual OnePlus DN2103 / Android 13 / API 33, serial PRQKU4U4PREQNRWG, remains authorized over USB. Android reports a validated Wi-Fi default network. The game's UID 10264 has no effective Android network-policy block; name resolution and one ICMP request under `run-as org.circuit01.handlinglab` succeed against the established cloud hostname. These checks alone do not prove HTTPS connectivity or every OEM per-app restriction.

The game's private `files/backend.cfg` was absent. `game/backend/account_controller.gd` therefore selects the debug default `http://127.0.0.1:18181`. The existing cloud URL is `https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app`. Read-only PC requests to `/health` and `/v1/bootstrap` returned HTTP 200; bootstrap identifies `beat-my-track`, API `v1`, with Google browser sign-in configured and development authentication enabled.

Installed a private URL-only `backend.cfg` through a unique staging file, verified its SHA-256 against the local source, and renamed it into place. No existing configuration needed replacement. No credentials were copied. The temporary shared file was removed. Restarted the installed game using the project entry point; launch reports `Status: ok`, `COLD`, TotalTime 479 ms / WaitTime 485 ms, then `APP_READY`. No APK rebuild or installation was required.

## Remaining Google sign-in failure

The owner interacted with the restarted game. The inspected capture shows the Google and Development sign-in options and the message `Google sign-in could not complete. Please try again.` This is the native Google failure message, after the service bootstrap/challenge stages, distinct from the earlier unreachable-service error. No successful account sign-in is claimed.

Android reports `Accounts: 0`, with zero Google account records. Google Play services is installed and enabled, version `23.37.17 (190400-570218080)`. Its diagnostic log reports `GetSignInIntentOperation` failing without exposing a precise error category in the collected output. Missing accounts and restricted Google service traffic are relevant next checks; neither is proven to be the sole native failure cause. The initial Settings capture shows Google Services Framework network access disabled. The game uses Android Credential Manager with its Play Services provider. Google's [current guide](https://developer.android.com/identity/sign-in/credential-manager-siwg) says the button flow can add an account even when the device has none; adding one through Android Settings is the available manual next step while this phone's native flow fails.

The earlier owner next-step recommendation was to permit Wi-Fi for Google Play services and Google Services Framework, add a Google account, then retry. That recommendation is superseded by the subsequently reported company-reset notification below. Do not repeat account setup or sign-in while the notification remains unresolved. App-private saved-session and signed-out-fence files were both absent at the check above. No account names or credentials were printed.

## Actual commands and evidence

Used installed SDK `adb.exe`, scoped to the connected serial, for `devices -l`, `getprop`, `dumpsys connectivity`, `dumpsys netpolicy`, `dumpsys network_management`, package metadata, `pidof`, selected `logcat` categories, and account-count checks. Read the missing private configuration with `run-as ... cat files/backend.cfg`. Tested resolution/reachability with:

```powershell
adb -s PRQKU4U4PREQNRWG shell run-as org.circuit01.handlinglab ping -c 1 -W 3 bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app
# Invoke-WebRequest: existing cloud /health and /v1/bootstrap, no authentication.
# adb: force-stop, push URL-only config to a unique /data/local/tmp path,
# run-as copy to unique files/backend.cfg staging path, sha256sum, mv, cleanup.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action LaunchAndroid -DeviceSerial PRQKU4U4PREQNRWG
```

The first sandboxed ADB attempt during the preceding management inspection could not create its user directory; subsequent device reads used the approved tool outside the sandbox. Earlier reads of guessed `game/scripts` paths failed; runtime source is under `game/backend`. No failed probe is recorded as a passing test.

Evidence: [initial Network access screen](evidence/phone-login-2026-10-13/initial-screen.png), [restarted game's sign-in screen](evidence/phone-login-2026-10-13/configured-screen.png), and the public URL-only [configuration](evidence/phone-login-2026-10-13/backend.cfg). No runtime source, device network/management policy, existing records/cosmetics, backend configuration or production deployment was changed. No full engine regression, race, completed authentication or phone performance test was performed for this repair.

## Company-enrollment reset notification: owner correction

The owner subsequently clarified: a notification states the phone is managed by an administrator and will reset soon. This is a pending reset warning, not evidence that Beat my track rebooted the device. The prior recommendation to reconnect Google system services was too broad for an old company-owned phone whose remote enrollment registration was unknown. The owner was advised to disconnect Wi-Fi and not repeat Google account setup, with no assurance that disconnecting cancels a reset already scheduled.

Google's [zero-touch IT guide](https://support.google.com/work/android/answer/7514005?hl=en) documents this behavior: when configured enrollment was skipped because the device could not reach Google during setup, a later connection to Google can trigger a factory reset, with a warning one hour beforehand. It also documents the reset behavior for registered dual-SIM devices with Play services older than 24.07.12. The phone's installed version observed above is 23.37.17. This is a strong match to the reported notification, not direct access to its remote enrollment record. The [user guide](https://support.google.com/work/android/answer/7512589?hl=en) directs the organization's IT administrator to unregister the device; a local factory reset does not remove registration. Request release from Android zero-touch enrollment as well as the company's MDM record. Do not attempt another login, enrollment, service update, reset or policy removal as a diagnostic.

Read-only follow-up: ADB remains authorized; game package, the repaired configuration and local records are still present. At 21:31 Helsinki the device reports uptime 25 days, boot_count 1, setup/provisioning complete, one account and `dpm list-owners` reports no owners. `sys.boot.reason=reboot,factory_reset` is a historical boot reason and does not establish a new reset during this session. Selected logs include `ZeroTouchScheduler` scheduling a periodic run; foreground activity belongs to the game's Credential Manager provider. Neither lack of a local owner nor long uptime rules out the warned future reset.

Copied only the game's local records and their backup, tracks, local ghosts, guest resumes and the URL-only backend configuration through a read-only `adb exec-out run-as ... tar -cf -` stream. No account-session files, credentials or Google/company data were copied. Backup is excluded from Git:

```text
.tools/phone-reset-backup-2026-10-13/4f8ba5c98ef949f08f061854717d2a81/beat-my-track-local-data.tar
2,865,664 bytes
SHA256 EC7C3F86C454F709FA1EE8A40DA700664F2403D320E05685CF084E37DDD8C0F3
```

Python standard-library tar/JSON validation confirms 173 readable files, 119 parseable JSON files, whitelisted archive paths without links, and the exact public URL-only configuration. The adjacent manifest records these checks. No phone writes were performed in this follow-up. The backup retains a point-in-time copy; no restoration, canceled reset, IT release, completed game login or permanent device-management resolution is claimed.
