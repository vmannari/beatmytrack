# Private Studio restoration, 2026-10-25

Status: the owner supplied the dedicated OAuth client, Google/TOTP identity is configured, and private Studio is deployed. The browser proxy is running at `http://127.0.0.1:8182/admin`. Real owner sign-in and authenticator enrollment remain interactive owner steps. No game API/worker update, database migration, player mutation or owner-process restart was performed. Concurrent workspace changes are preserved. See the deployment continuation below for retained failures and live verification.

## Requirements and behavior

- SR01: restore the web Studio for the active Google Cloud owner account through a separate, IAM-private `bmt-stg-e7a444ab-studio` service. Keep public game API administration routes unavailable.
- SR02: Google Identity Platform manages Google authentication and authenticator-app TOTP in a separate tenant. Verify the Google signature, fixed Secure Token certificate endpoint, exact issuer, project audience, tenant, Google provider, verified email, stable Google subject and fresh authentication. Only a signed TOTP second-factor claim with a factor identifier satisfies MFA. Tokens remain in tab memory, with a one-hour authentication bound. Existing subject-based audit identities and staff disable checks remain.
- SR03: allowlisted first-time staff can enroll an authenticator without gaining Studio access. Enrollment then requires a fresh Google/MFA sign-in. Other accounts cannot enter Studio. Lock, cancellation and a stale pending popup cannot restore access. No third-party QR service receives authenticator secrets; enrollment displays the manual setup key locally.
- SR04: prepare only the Studio image from the exact deployed API image. Preserve the original backend source, migrations, verifier and all other assets. Deploy the separate staff service using its existing staff service account/database secret. Keep API/worker revisions and database schema unchanged.

The owner completed the Google Console step: a dedicated **Web application** OAuth client for **BMT Studio** in project `beat-my-track`, with redirect URI `https://beat-my-track.firebaseapp.com/__/auth/handler`. Its downloaded JSON remains under ignored `.tools/gcp-staging/studio-oauth-client.json`. The helper refuses the game's OAuth client, a different project, missing secrets or a missing redirect URI. Never paste the client secret into chat or commit it.

The browser will open through a loopback Cloud Run proxy at `http://127.0.0.1:8182/admin`. Cloud IAM invocation and application Google/MFA sign-in are separate. The private service URL by itself is not a public browser login page. The proxy preserves application Authorization separately from its Cloud Run invocation token.

## Changed files

Runtime: `backend/bmt_backend/{admin.py,app.py,config.py,studio_access.py,studio_settings.py,studio_identity.py}` and `backend/bmt_backend/admin_ui/{app.js,index.html,signin.js}`.

Operations: `backend/deploy/gcp/{staging.py,studio_recovery.py}` and `scripts/studio.ps1`. Tests: `backend/tests/{test_studio_identity.py,test_studio_recovery.py,test_studio_signin_browser.py}`. Evidence: this document and `docs/evidence/studio-recovery-2026-10-25/`.

## Actual inspection and checks

Read-only Cloud Run inspection found only `bmt-stg-e7a444ab-api`, ready revision `bmt-stg-e7a444ab-api-00099-ret`. Its immutable image is `europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend@sha256:16c22624a9bf5f1995c8315fbf1554d62dc3707826ba6a9217ff0f2d65327c0e`. Identity Platform was not enabled. The separate `-studio-db` secret resource exists; no secret value was retrieved.

Actual commands (repository root unless noted):

```powershell
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/studio_recovery.py
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/studio_recovery.py --build-image build/studio-recovery-2026-10-25/image-final
.tools/backend-venv/Scripts/python.exe -m ruff check backend/bmt_backend/studio_identity.py backend/bmt_backend/studio_access.py backend/bmt_backend/studio_settings.py backend/deploy/gcp/studio_recovery.py backend/tests/test_studio_identity.py backend/tests/test_studio_recovery.py backend/tests/test_studio_signin_browser.py
```

From `backend/`, the final source check was:

```powershell
../.tools/backend-venv/Scripts/python.exe -m pytest tests/test_studio_identity.py tests/test_studio_recovery.py tests/test_studio_signin_browser.py tests/test_studio_platform.py tests/test_admin.py tests/test_security_fixes.py tests/test_gcp_staging.py tests/test_gcp_update.py -m 'not postgres' -q --disable-warnings --maxfail=2
```

Result: **132 passed, 1 deselected, 291 warnings, 77.07s**. Ruff passes. PowerShell's language parser accepts the new launcher. Scoped `git diff --check` passes (line-ending notices only).

The deployed-image source snapshot, with only the authentication patch applied, was separately checked:

```powershell
$env:PYTHONPATH = 'C:\Codes\Godot\Beat my track\build\studio-recovery-2026-10-25\image-final\baseline'
../.tools/backend-venv/Scripts/python.exe -m pytest tests/test_studio_identity.py tests/test_studio_signin_browser.py tests/test_admin.py -m 'not postgres' -q --disable-warnings --maxfail=2
```

Result: **31 passed, 1 deselected, 66 warnings, 21.40s**. Tests include actual RSA signature/expiry rejection with isolated test certificates, role/account/tenant/MFA fences, enrollment granting no administrative access and operator disable checks. A real headless Edge browser exercised the UI with a simulated identity provider; it made no Google sign-in or live write. Its desktop/mobile screenshots are [sign-in](evidence/studio-recovery-2026-10-25/signin-desktop.png), [verification](evidence/studio-recovery-2026-10-25/verify-desktop.png), and [mobile](evidence/studio-recovery-2026-10-25/signin-mobile.png).

The initial authentication image was `europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/studio:signin-52c67cff130ec9baed62`, manifest-list SHA256 `40b9d909d904477b86102433d3b212677bf262c3bb83b12fd49f5cb50f6d963c`. The ignored build receipt `build/studio-recovery-2026-10-25/image-final/image.json` records its nine source hashes. This initial image was superseded during the live continuation described below.

## Retained failures and corrections

- Initial outbound shell requests were sandbox-blocked. Initial gcloud invocation encountered PowerShell execution policy, then the sandbox's credential-file boundary, then the local TLS issuer error. Read-only checks succeeded through `gcloud.cmd` with the existing trusted CA bundle and approved execution. Certificate verification was never disabled.
- The first archive extraction used a Python-version-incompatible `filter` argument. The corrected Python 3.10 path explicitly rejects traversal and all non-file/directory members before extraction.
- The first image patch check failed because the deployed middleware predates a local optimization. A narrow two-line context applies only the same authentication changes without copying that unrelated optimization. The failed build directories remain. Final image construction succeeds.
- The first snapshot check encountered one PostgreSQL setup timeout at the configured local `localhost:55439` (29 passes, one setup error). PostgreSQL was not available. The explicit non-PostgreSQL checks above retain the database test as a deselection; no assertion was weakened.
- Ruff initially identified two formatting issues; corrected. Initial visual inspection found an empty error banner; it now stays hidden until an error exists. A nested PowerShell validation invocation had a quoting error; direct language-parser validation succeeds.

## Deployment continuation after owner supplied OAuth client

Identity Platform and Secure Token APIs were enabled, and the `BMT-Studio-feydr` tenant now has only Google sign-in and TOTP MFA (one adjacent interval). Existing authorized domains were retained; loopback and the project's Firebase auth domain were added. A browser key is restricted to the two authentication APIs and the loopback/Firebase origins. The Google owner email and stable subject were verified through Google's authenticated user-info endpoint; only that subject is configured with the owner role. The private identity configuration remains under `.tools/gcp-staging/studio-identity.private.json`; neither it nor the OAuth secret is copied into evidence.

The missing `bmt-stg-e7a444ab-staff` service account was created with `roles/cloudsql.client`, access to only the existing `-studio-db` secret, and the documented object creator/viewer roles on the owned bucket. Existing conditional grants remain. Studio has no anonymous IAM principal; the owner has service-specific invocation access. Its production settings forbid legacy keys and require MFA.

The first revision failed because the retained image predates `bmt_backend.http_server`. The corrected image includes that existing repository module, retaining the bounded server rather than falling back to an older launch command. The resulting deployed-image snapshot passed **41 checks, one PostgreSQL deselection**, including the real HTTP-server tests. Updated recovery-helper checks pass **9/9**. After the popup policy correction below, the focused identity, helper and simulated-provider browser checks pass **31/31**. Ruff passes.

The first live browser check loaded the actual SDK and displayed the Google button at desktop/mobile sizes. An additional real provider-handoff check then caught `auth/internal-error`: CSP rejected `https://apis.google.com/js/api.js`. A browser-only policy probe confirmed the precise fix reaches `accounts.google.com` without entering credentials. The final image adds that specific Google script origin to the managed-sign-in page; legacy pages retain their policy. Initial failing checks and the diagnostic screenshot remain in the evidence directory.

The final image is `europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/studio@sha256:c04c62ed30f18bc526200dc0751efc9fd66406e178fe71729d181feba1046ee1`. Its source receipt overlays ten files on the exact retained API image; all other source, migrations, verifier and assets remain from that base. The API revision remains `bmt-stg-e7a444ab-api-00099-ret`.

Live continuation commands:

```powershell
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/studio_recovery.py --prepare-identity --oauth-client .tools/gcp-staging/studio-oauth-client.json --owner-email <owner-email> --identity-config .tools/gcp-staging/studio-identity.private.json
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/studio_recovery.py --build-image build/studio-recovery-2026-10-25/image-live-final
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/studio_recovery.py --deploy-image build/studio-recovery-2026-10-25/image-live-final/image.json --identity-config .tools/gcp-staging/studio-identity.private.json
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/studio_recovery.py --verify --identity-config .tools/gcp-staging/studio-identity.private.json
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/studio.ps1 -NoBrowser
.tools/backend-venv/Scripts/python.exe scripts/check_studio_live.py
```

The official Cloud Run Proxy component `0.5.1` was installed because it was absent. The new account-authenticated proxy runs on IPv4 loopback only, preserves the application bearer separately, and does not replace any existing listener. Temporary Docker registry credentials were removed after each push. No TLS verification was disabled.

Final live verification passes all nine checks: health, readiness, Studio HTML, sign-in asset and identity configuration return 200 through Cloud IAM; missing/invalid application credentials return 401; game authentication is absent from Studio (404); direct anonymous service invocation returns 403. The exact results are [live-checks.json](evidence/studio-recovery-2026-10-25/live-checks.json). A fresh real Edge browser loads the deployed SDK and final CSP, displays the Google button, and reaches Google's account sign-in page without entering credentials, JavaScript errors or failed requests. Desktop/mobile screenshots and [live-browser.json](evidence/studio-recovery-2026-10-25/live-browser.json) record this final check with `csp_probe_override: false`. Public deployment metadata and source hashes are retained in [deployment.json](evidence/studio-recovery-2026-10-25/deployment.json) and [image.json](evidence/studio-recovery-2026-10-25/image.json).

Additional retained provisioning failures/corrections: user-info requests reject the Cloud quota-project header (now omitted for that endpoint); initial API activation needed propagation; repeated `initializeAuth` is not idempotent (now read-before-initialize); tenant display names cannot contain spaces (corrected to `BMT-Studio`); adding a bucket grant alongside existing conditions requires explicit `--condition=None`. The proxy's first start lacked its SDK component; installation with an external Python interpreter resolved the SDK's noninteractive bundled-Python restriction.

## Remaining owner acceptance

Confirm real Google sign-in, authenticator enrollment, fresh TOTP challenge, owner access, lock/relogin and core Studio reads with the owner. Automated live checks deliberately do not enter credentials or complete MFA. Authenticated dashboards therefore remain owner acceptance, not a claimed live pass. No phone attachment check or physical-device test was performed. Reopen the private proxy/browser with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/studio.ps1` when needed.

Google references: [TOTP enrollment and verification](https://firebase.google.com/docs/auth/web/totp-mfa), [tenant MFA configuration](https://docs.cloud.google.com/identity-platform/docs/admin/enabling-totp-mfa), [Google provider setup](https://docs.cloud.google.com/identity-platform/docs/web/google), and [Cloud Run proxy header behavior](https://github.com/GoogleCloudPlatform/cloud-run-proxy/blob/main/main.go).
