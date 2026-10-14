# Backend communication M1–M6 — 2026-10-13

Review IDs M1–M6; project requirements B01, B05, B07, Q01. Source fixes, regression tests and a scoped review checkpoint. No production deployment or production data writes. Canonical driving, scoring, trajectories, cosmetics and ordinary race access are unchanged.

## Changes

| Item | Result |
| --- | --- |
| M1 | Pin `cryptography==50.0.2` and change the project constraint to `>=50.0.2,<51`. A maintained local backend environment replaces the Windows OpenSSL 1.1.1 test runtime; the dev entry point prefers it and rejects obsolete local TLS. |
| M2 | Logout accepts refresh-token possession, with a compatible bearer fallback. Expired access and consumed tokens can revoke their own family; repeated revocation is idempotent. The client captures refresh/access credentials before immediate local sign-out. |
| M3 | Encrypt the complete saved credential record using user-bound Windows DPAPI or app-owned Android Keystore AES-256-GCM. Bind ciphertext to backend and profile, reject corruption/key loss, migrate legacy records under the existing inter-process rotation lease, and preserve atomic refresh recovery and sign-out fences. Unsupported protection permits memory-only authentication; there is no plaintext fallback. |
| M4 | The first publication 429 pauses the whole account/backend scope. Persist its bounded deadline, respect it across controllers/processes/restarts, preserve interrupted writes, refuse incomplete metadata, and retain every job, permanent operation key and exact creator evidence. Another account has an independent scope. |
| M5 | Reuse provider HTTP Sessions per calling thread, with small connection pools and zero automatic write retries. Close retired-thread pools and all owned pools during API/worker shutdown. Reuse up to four idle Godot HTTPRequest nodes, resetting owner/cancellation state. |
| M6 | Snapshot the browser challenge and roll back its read transaction before Google verification. A fresh conditional update rechecks expiry, consumption and prior completion before accepting the result. Provider IO holds no checked-out DB connection. |

M1's old Windows TLS finding was local; the deployed Linux HTTPS runtime was already OpenSSL 3.0.22. The separate cryptography wheel in the live image was affected. See the [live-image inspection](M1_PRODUCTION_CHECK_2026_10_13.md). The local patched Linux image confirms cryptography 50.0.2 / bundled OpenSSL 4.0.3 with production's Python 3.12.15 / HTTPS OpenSSL 3.0.22. No live image was replaced.

M5's real loopback HTTP test proves that two sequential provider requests use the same TCP connection, while another thread gets its own pool. The client change reduces node creation; Godot HTTPRequest still controls its connection lifecycle, so it does **not** establish fewer client TLS handshakes or a measured latency/FPS improvement.

## Changed files

- Dependencies/tooling: `backend/pyproject.toml`, `backend/requirements.lock`, `backend/README.md`, `scripts/dev.ps1`.
- Server: `backend/bmt_backend/auth.py`, `browser_auth.py`, `http_transport.py`, `gcs_storage.py`, `s3_storage.py`, `app.py`, `worker_lifecycle.py`.
- Client: `game/backend/backend_client.gd`, `session_vault.gd` and UID, `track_lifecycle.gd`.
- Platform: `native/google_sign_in/src/org/beatmytrack/signin/BmtGoogleSignIn.java`, `BmtSecureSession.java`; `native/windows_audio/secure_session.h`, `impact.cpp`; `scripts/build_windows_audio.ps1`; `game/platform/windows/impact.gdextension`, `bmt_windows_audio_v4.dll`.
- Regression coverage: `backend/tests/test_medium_communication.py`, `test_s3_storage.py`; `game/tests/test_medium_communication.gd` and UID, `test_session_rotation.gd`, `test_backend_exception_recovery.gd`; `native/google_sign_in/tests/BmtVaultInstrumentation.java`; `scripts/test_android_session_vault.py`, `test_medium_communication_postgres.py`.
- This report and task entries in `DEVELOPMENT_STATUS.md` / `docs/PHASE_0_PLAN.md`.

The DLL adds a separate credential-protection class through the existing cleared, pinned Godot C++ binding build; existing audio behavior is retained. Android uses platform crypto APIs and the existing plugin bridge, adding no SDK or service dependency. The nonshipping phone instrumentation is compiled into a separate disposable package.

## Actual commands and outcomes

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build_windows_audio.ps1
.tools/backend-secure-venv/Scripts/python.exe -m pip check
.tools/backend-secure-venv/Scripts/python.exe scripts/test_medium_communication_postgres.py
.tools/backend-secure-venv/Scripts/python.exe -m pip wheel --no-deps --wheel-dir build/communication-m1-m6-2026-10-13/project-wheel ./backend --cert .tools/gcp-staging/windows-trust.pem
.tools/backend-secure-venv/Scripts/python.exe build/communication-m1-m6-2026-10-13/test_linux_image.py
# Each native regression uses the exact pinned Godot through this entry point:
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_medium_communication.gd
```

Windows DLL compilation and `pip check` pass. The isolated maintained Windows environment reports Python 3.14.7 / HTTPS OpenSSL 3.5.7 / cryptography 50.0.2 / bundled OpenSSL 4.0.3. Public OSV querybatch checked all 45 pinned packages and returned no matching advisories; this is a dependency-database check, not a proof of comprehensive security.

The owned PostgreSQL 17 matrix reports **198 passed, nine expected skips**. It covers real logout/refresh races, family isolation, invalid/repeated revocation, browser completion connection lifetime and changed challenges, RSA Google-token signature/audience/issuer/expiry validation, ECDSA provider proofs, storage integrity/bounds, actual TCP reuse, worker shutdown, adjacent H1–H4 boundaries, and publication idempotency. The fixture verifies its generated container label before stopping/removing it. [Actual output](evidence/communication-m1-m6-2026-10-13/backend-regression.log).

The local-only patched image over the exact deployed image index reports **83 passed, three expected skips** on Linux/Python 3.12. Its dependency check passes. Builds and test containers have no network access or production credentials; the image is a diagnostic artifact, not an authorized rollout candidate. [Linux output](evidence/communication-m1-m6-2026-10-13/linux-runtime.log).

Final native matrix:

| Pinned Godot regression | Checks / failures |
| --- | --- |
| `test_medium_communication.gd` | 31 / 0 |
| `test_local_draft_publication.gd` | 31 / 0 |
| `test_session_rotation.gd` | 17 / 0 |
| `test_backend_exception_recovery.gd` | 28 / 0 |
| `test_shared_resume_recovery.gd` | 21 / 0 |
| `test_refreshed_ticket_priority.gd` | 26 / 0 |
| `test_http_retry.gd` | 14 / 0 |
| `test_mission_outbox.gd` | 11 / 0 |
| `test_resume_recovery_budget.gd` | 260 / 0 |

Total **439 native checks**, with fictional network outcomes and isolated files. DPAPI checks use the actual compiled platform adapter. Coverage includes exact ciphertext context binding, tampering, legacy migration, no-protection behavior, shared refresh recovery, immediate sign-out, independent active request nodes, bounded idle reuse, whole-batch pauses, controller restart, interrupted/corrupt cooldown writes, unchanged proof bytes and exact upload retries. Overlapping Windows/Linux/backend counts are not presented as distinct tests.

Android `javac` compilation and offline `compileStandardDebugJavaWithJavac` both pass using the installed SDK and existing Gradle dependencies. Existing AGP/compileSdk and manifest warnings remain. On the attached DN2103 physical phone, `scripts/test_android_session_vault.py --serial <attached serial>` passes **13 checks**: ciphertext round-trip, randomized IV, authenticated context/tamper rejection, a non-exportable key, bounds, process-restart recovery and refusal after key loss. The generated package was uninstalled and its throwaway signing key removed; the game's installation and data were untouched. Actual receipt and both instrumentation logs are retained under `build/communication-m1-m6-2026-10-13/android-vault-*` and copied into this report's evidence directory.

Ruff and scoped `git diff --check` pass. No presentation layout changed; screenshots are not applicable.

## Verification corrections and limitations

The first S3 transport test still mocked the old top-level Requests function; it failed, and was updated to intercept the actual pooled Session while retaining all original bounds/redirect assertions. Early native runs found one remaining plaintext ConfigFile load in the post-refresh fence; it now uses the vault. A proof fixture comparison initially compared JSON floats with in-memory ints; the corrected assertion verifies exact on-disk bytes. An actual ciphertext context test was corrected to retain the existing file instead of deleting it through configuration sign-out.

The initial sandboxed native run could not access its disposable user files and stalled. Only its two verified test PIDs were stopped, then the same regression passed with normal profile access. A later concurrent soundtrack class-cache update interrupted the retry test; importing refreshed the class registration, although the import itself reported a locked extension DLL. The retry and outbox/recovery tests then passed without changing the soundtrack or stopping an owner editor. Full Import is therefore not claimed as passed.

An initial wheel command used `backend` as a package name and fetched/built an unrelated PyPI wheel without installing it. The corrected `./backend` command built the local project wheel used in Linux verification. The network-disabled Linux overlay initially lacked a build backend, then exposed the parent image's stale source-tree egg-info constraint. Using the built local wheel and replacing that stale generated metadata made the genuine dependency check pass. A future overlay rollout must update package metadata as well as the library; a fresh Dockerfile build already generates metadata from the new project constraint.

The first upgrade attempt in the old Windows venv encountered a DLL loaded by an existing process during cleanup. Subsequent verification uses the isolated maintained environment. The installed Cloud SDK interpreter had vendored libraries ahead of venv packages; its stdlib was isolated in the task environment without editing SDK files, and actual imported versions plus `pip check` were verified. Use a standard maintained Python distribution for fresh setups, as the README specifies.

## Remaining rollout acceptance

Restart all same-profile desktop game/editor instances together so each reads the protected save format. Ship a new Android build with the updated native plugin; the physical fixture validates the platform implementation, while actual game sign-in/restore through Godot JNI remains a release/device acceptance check. Credential protection reduces offline-file exposure and does not protect credentials from a compromised running process or malicious code executing as the same OS user/app.

Deploy matching API/worker code and dependencies only with explicit owner authorization. Production still runs the previously inspected image. Check Google sign-in, persistent restart/rotation, expiry logout, provider IO/shutdown, and publication 429 recovery in the rollout environment. No game Android APK export/install, full Validate, full physics/replay regression or live account/purchase request was performed for this slice. The attached phone was used only for the separate Keystore fixture. Scoped checkpoint/evidence: `docs/evidence/communication-m1-m6-2026-10-13/`; concurrent changes are preserved and excluded from the task-only patch.
