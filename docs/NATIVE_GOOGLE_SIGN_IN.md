# Android Google sign-in without a browser (2026-10-09)

Owner request: phone login must not require opening a browser. Requirements B01/B07 (verified authentication/session boundaries), R01 (existing racing), V03 (account presentation), Q01 (verification). This supersedes browser sign-in on Android only.

Android now calls Google Credential Manager's explicit Google button flow. It passes the existing backend's single-use challenge nonce and configured OAuth Web client ID to the native account picker, then sends Google's ID token to `/v1/auth/google`. Signature/audience/issuer/expiry/nonce validation remains server-side. Desktop retains its browser flow. Android errors/cancellation/missing configuration never launch a browser. Existing saved sessions, separate Development accounts and guest racing remain available.

New Google accounts omit the racing name and enter the existing username/country onboarding; returning identities retain their saved name. The direct Google endpoint now supports the same optional-name semantics as browser sign-in. Explicit names remain validated. No schema migration is needed. The owner-authorized development deployment is complete; see the rollout evidence below.

Changed files:

- `game/backend/account_controller.gd`, `backend_client.gd`: native Android branch, cancellation/sign-out and optional-name payload.
- `native/google_sign_in/android.gradle`, `src/org/beatmytrack/signin/BmtGoogleSignIn.java`, `PROVENANCE.md`: pinned native dependencies, in-memory result bridge and provenance.
- `game/addons/bmt_google_sign_in/plugin.cfg`, `export_plugin.gd`, `game/project.godot`, `scripts/dev.ps1`: Android plugin registration and build hook, debug and release.
- `backend/bmt_backend/auth.py`: public Web client ID in challenge response and optional racing-name onboarding.
- `backend/tests/test_auth.py`, `game/tests/test_native_google_sign_in.gd`: direct native endpoint onboarding/returning identity, controller success/cancellation/error/missing-plugin coverage.
- `game/tests/test_account.gd`: two stale Tracks expectations aligned with the existing approved Rivalry startup/guest entry; screenshot restoration uses the same entry.
- This document, `ACCOUNT_SIGN_IN.md`, `DEVELOPMENT_STATUS.md`: current behavior and acceptance.

Actual verification:

| Command | Outcome |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://backend/account_controller.gd` | Passed with pinned Godot 4.7.2; initial restricted run could not write normal user logs. |
| Same entry point, `-Action TestScript -ScriptPath res://tests/test_native_google_sign_in.gd` | Final 11 checks, zero failures, clean shutdown. First run leaked replaced test client nodes; fixture cleanup fixed. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_auth.py backend/tests/test_browser_auth.py -q` | Final 45 passed; initial 44 passed before adding direct onboarding regression. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_account_client.py -q` | Final 1 passed, actual Godot/HTTP menu 67 checks. Initial two stale navigation assertions failed; no production navigation was changed. Output `build/native-google-account-http-final.log`. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ExportAndroid -QuickValidation` | Final APK export passed; import/startup, driving72, catalog21, menus48 checks passed. Existing driving shutdown ObjectDB warning retained. Logs `build/logs/ExportAndroid-44384`. Full Validate not run. |
| Installed SDK `adb.exe devices -l` | Authorized OPD2403 tablet `f0ba474a` attached; no phone listed. Initial sandbox could not access ADB home; normal-local-access check succeeded. |

Initial prepared APK: `build/android/circuit01-debug.apk`, SHA256 `78D044DB2B0F886716F88144413A28E1F3FE874AB904BA1530862B517F770FF1`. The later authorized rollout rebuilt and installed the current APK, as recorded below. No real Google identity interaction/device login or native-picker screenshot/video was performed; mock controller and fixture verifier tests do not prove Google acceptance. Existing sign-in artwork/layout was unchanged. No full physics regression or production action.

Remaining acceptance:

1. Complete: owner explicitly authorized deployment and installation; the development backend now returns the native client ID and supports optional-name onboarding.
2. Owner reports registration complete in the existing Google project for package `org.circuit01.handlinglab` and the actual APK signing certificate SHA-1. Register each separately signed variant; Play-distributed builds need the Play app-signing certificate. Credential Manager requests the existing Web client ID, which must remain in the server audience allowlist. No client secret belongs in the app.
3. APK installed and launched on the attached tablet. Unlock it and perform actual account selection, new/returning username checks, cancellation, sign-out/account switch, restart restoration and offline failure on the target device; capture native-picker evidence without account details. Review phone and tablet provider availability. Current physical-device login acceptance remains outstanding.

Primary reference: [Google's native sign-in implementation](https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation).


## Authorized development rollout and tablet installation

The owner created the Android OAuth client using the extracted certificate fingerprint, then explicitly authorized deploying the development update and installing the tablet APK. Fresh successful Cloud SQL backup **1791575842574** preceded publication. The exact-parent one-module overlay updates **auth.py only** from live parent `da0ab3da07ceb28bd6a2ae63294ef6faeff99dad3e09d0219e34347c4c114c63`; all **112 packaged canonical-game files are byte-identical**. API/worker and associated migrate/smoke/catalog job images now use immutable digest **190ef67329da6b8eac4d1141187c84b23251e7913d533192274b78495a9c1b52**. No migration, reseed, new driver generation, real account creation or production deployment was performed. [Exact backend patch](evidence/native-google-sign-in-2026-10-09/backend-image.patch), [game proof](evidence/native-google-sign-in-2026-10-09/packaged-game-proof.json), [deployment receipt](evidence/native-google-sign-in-2026-10-09/deployment.json).

Actual private helper commands under `.tools/native-google-sign-in-20261009`: `prepare.py`, local cached-parent Docker build (`--pull=false --network=none --platform=linux/amd64`), `extract.py`, `deploy.py backup`, `publish`, `deploy`, `smoke`, then `verify.py`. Exact extracted-package authentication/browser regressions: **45 passed**, actual imports confirmed under the isolated packaged directory; output `build/native-google-packaged-auth-tests.log`.

API and worker **Ready** on the intended image. Live readiness200/challenge201/configured Web client/optional-name schema/invalid-Google-token401 checks pass. The negative probe writes one expiring anonymous challenge, no player or identity. Nonce/token material is not retained in public evidence. Actual smoke logs report **12,757 canonical ticks**, schema **0020_challenges**, results-comparison contract present, two temporary storage diagnostics and **zero player writes**. [Final readiness and actual smoke](evidence/native-google-sign-in-2026-10-09/final-readiness.json). This smoke remains an explicit diagnostic; competitive verification behavior was unchanged by the login overlay.

The final `scripts/dev.ps1 ExportAndroid -QuickValidation` passes import/startup, driving72, catalog21 and menus48; logs `build/logs/ExportAndroid-43084`. Initial startup check emitted an unrelated saved-session TLS error; retry directed the test process to localhost rather than changing runtime trust or player configuration. Initial automatic-review timeouts were retried once and resolved. First registry-login attempt failed before remote rollout; private diagnostic capture/retry succeeded. No credential was printed or committed. Full Validate was not run.

Current APK **246,691,565 bytes**, SHA256 **7356EF3E653AA8309034FB91067B018149DCC93C3E9699C6D15FF9993044377B**, preserved at `build/native-google-sign-in-2026-10-09/circuit01-debug.apk`. Native plugin manifest registration and DEX class verified; apksigner verifies the same owner-registered SHA-1 **74:25:07:A1:26:65:E6:BC:2B:05:A8:4C:33:E7:70:F5:81:FE:83:39**. `scripts/dev.ps1 InstallAndroid -DeviceSerial f0ba474a`: **Success**, existing app data retained. `LaunchAndroid`: **Status ok / COLD**, activity `org.circuit01.handlinglab/com.godot.game.GodotApp`. Logs `build/logs/InstallAndroid-12888`, `LaunchAndroid-26032`. [Device receipt](evidence/native-google-sign-in-2026-10-09/android-update.json).

The authorized OPD2403 tablet is attached; no phone is listed. Read-only window/power checks show Awake with **secure keyguard showing**. No lock bypass, actual Google account choice, Google consent/account write or native-picker screenshot/video was performed. Remaining acceptance is owner unlock ? Google account selection, successful new/returning onboarding, cancellation, account switching and restored session on restart. Other phone/device/provider coverage remains outstanding. [Initial task-only source checkpoint](evidence/native-google-sign-in-2026-10-09/task-only.patch), [rollout-only documentation checkpoint](evidence/native-google-sign-in-2026-10-09/rollout-only.patch).


## Owner-reported failed native login: Android client configuration corrected

On 2026-10-09 the owner reports that sign-in cannot complete. Attached-tablet Credential Manager logs show native account selection and final provider response on two attempts at approximately 23:36 Helsinki. Sanitized backend request logs show challenge201 followed by Google-login401 at 20:36:21/20:36:26 UTC. No token, subject, email or nonce was printed or retained. The initial private screenshot was already a practice-loading screen and is not evidence of the login error.

Read-only `client_config.py inspect` confirms both live API and worker on the newer owner-authorized trajectory image `61b0accbcfaa3e9e9bdf444273c655bbde853b28a7a5901748854dfebfd7a9f6`, with the existing Web OAuth client as the only allowed client. Google documents that Android/Web hybrid tokens can carry the Android client as `azp`, separate from the Web `aud`. The current verifier explicitly rejects an unconfigured `azp`. This missing configuration is a supported explanation for the failure; actual token claims have not been inspected and a successful real-Google retry remains necessary to confirm the complete fix.

Added `backend/tests/test_google_crypto.py::test_android_presenter_requires_explicit_client_configuration`: actual RSA-signed Web-audience/Android-presenter token is rejected before explicit allowlisting and accepted afterwards; an unrelated Android presenter remains rejected. `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_google_crypto.py -q`: **11 passed**, existing signature/issuer/audience/time validation retained. No runtime verification rule was removed or changed.

The Android OAuth Client ID has been requested from the owner. Private helper `.tools/native-google-sign-in-20261009/client_config.py` prepares a guarded configuration-only update to the existing API/worker/jobs, retaining the current image, Web client, data and other environment fields. It checks Google project prefix and concurrent image/configuration changes. No configuration write/deployment/install/account creation was performed during this diagnosis. Remaining acceptance: owner supplies Android Client ID; apply the already-authorized login correction, then retry real Google login. Phone not listed; OPD2403 tablet attached. No new device login or native-picker screenshot is claimed.

Reference: https://developers.google.com/identity/openid-connect/openid-connect (`azp` for hybrid Android/Web clients).


## Supplied Android client configured (2026-10-10)

The owner supplied Android OAuth Client ID `833380148973-68nhqr1sd8e08m6evropjfsm5edhdr08.apps.googleusercontent.com`. Under the existing explicit login deployment authorization, `client_config.py apply --android-client-id <supplied ID>` added that exact client to the allowed Google clients on the development API, worker, migrate/smoke/catalog jobs. The Web client remains `833380148973-4p82mhm57eulrlv22ndv9aelern3829s.apps.googleusercontent.com`; all images remain `61b0accbcfaa3e9e9bdf444273c655bbde853b28a7a5901748854dfebfd7a9f6`. The guarded operation retained other environment fields, schema and player data and updated the private deployment configuration/rendered environment files for future deployments. No image upload, migration, reseed, new APK, Android installation or player account write was performed for this configuration change.

Actual commands under `.tools/native-google-sign-in-20261009`: `client_config.py apply --android-client-id ...`, `client_config.py audit --android-client-id ...`, `client_http.py`. Apply and audit check the exact configured clients and unchanged images across all five resources. [Configuration receipt](evidence/native-google-sign-in-2026-10-09/android-client-config.json). Live API readiness200, native challenge201, preserved Web client and invalid-token401 checks pass. [HTTP receipt](evidence/native-google-sign-in-2026-10-09/android-client-http.json). Prior actual RSA-signature regression is 11 passed; no authentication invariant was removed to accept an unknown presenter.

The configuration correction is complete. At the first post-change HTTP check no new real Google login was recorded; native end-to-end success is **not yet confirmed**. The owner has been asked to retry Continue with Google and report success/error. No new phone attachment check, device login/screenshot/video or full regression was performed on 2026-10-10. Remaining acceptance: actual signed Google login, onboarding for a new account, returning name/session preservation, cancellation/account switching and restart restoration. [Configuration-only documentation checkpoint](evidence/native-google-sign-in-2026-10-09/android-client-only.patch).
