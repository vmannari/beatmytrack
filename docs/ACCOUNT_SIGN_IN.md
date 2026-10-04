# Google and Development sign-in

2026-10-04 PC rivalry logout repair: remembered-session renewal now uses the latest saved credential under a shared process lease. Race upload and result polling retain the authenticated account after another PC client restores that same session. Explicit sign-out and replacement-account fencing remain enforced. See [cause, tests and restart instructions](RIVALRY_SESSION_FIX.md).

Review repair follow-up (2026-10-03): Sign out clears local identity immediately, fences late credential completions and writes a restart fence; server revocation is separate and bounded. Session expiry selects Guest storage immediately while active results remain pinned to their original owner. See [R2/R10 repair and actual acceptance](CODE_REVIEW_REPAIRS_2_3_2026_10_03.md).

Racing names are now unique (case/whitespace/Unicode-normalized), with the UUID remaining the permanent identity. See [unique names](UNIQUE_USERNAMES.md).

Latest ownership update (2026-10-03): development identity `developer` races as **Beat my track**, using the owner's exact requested capitalization. Race discovers backend publications; the retained named circuits have been restored to the PC server. Local player data is account-scoped; creator names come from the account. See [track restoration](TRACK_RESTORATION.md) and [account ownership](ACCOUNT_OWNERSHIP.md).

Startup now shows sign-in unless a saved session can be restored. Open the player-name button in the menu to sign out. See [remembered sign-in](REMEMBERED_SIGN_IN.md) for persistence and verification.

## Provider-first redesign (2026-09-28)

The sign-in screen now follows the owner's scenic reference with a separate focused card. Google requires no name before authentication. Only new Google accounts see a subsequent racing-name step; returning accounts retain their saved name. Development remains the fixed `developer` account, and Play as guest returns to local racing without an account. See [design, evidence and validation](SIGN_IN_REDESIGN.md).

## Google client configured (2026-09-28)

The owner-supplied OAuth Web client ID is now set in both Google settings in the
ignored `.tools/bmt-pc.env`. `scripts/dev.ps1 -Action BackendStart` recreated the
local API/worker and completed successfully; existing development credentials and
data were preserved. A live HTTP check passed readiness, both enabled sign-in
options, browser start/page/prepare, the exact supplied client ID and nonce, and
pending polling. The diagnostic handoff was cancelled without creating an account.
The owner can reopen Sign in and choose Google; new players choose their name afterwards. Real interactive
Google acceptance and the Cloud Console origin registration cannot be verified by
these HTTP checks. No phone test, Android export or production deployment occurred.

## PC fix and current setup (2026-09-28)

The first PC attempt failed because port 8080 belonged to the owner's Crane CMS,
not this game's API, and no `user://backend.cfg` existed. The mock-backed tests
did not exercise this missing workstation setup. The actual PC now has a separate
`bmt-pc-dev` Compose project: PostgreSQL, migrations, API and worker, with a durable
database/object volume and API bound only to `127.0.0.1:18181`. It is left running
for the owner's tests. Existing services on 8080 were not changed.

Start/restart the local setup with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BackendStart
```

This uses Ubuntu WSL Docker and the previously validated `bmt-backend:local` image
(build it with the deployment runbook first on a new workstation). Current backend
Python code is mounted read-only; the image supplies dependencies and the pinned
canonical verifier. The launcher generates private ignored `.tools/bmt-pc.env`
once, reuses its key on later starts, runs migrations and writes the matching URL/key
to `%APPDATA%/Circuit01Lab/backend.cfg`. Normal editor/game launches read that file.
Reopen Sign in or restart the game, then choose Development. No environment-variable
copying is required. `BackendStop` stops only this project and retains its data.
Restart policies resume services when Docker/WSL is running; Windows reboot alone
does not guarantee Docker has started. Use BackendStart if it has not.

The client checks the service identity before sending development credentials,
reloads saved configuration when reopening the account screen, and reports wrong
services separately from connection failures. Default debug port is now 18181.
Google uses an unmodified pre-approved button PNG with preserved aspect ratio,
colors, logo and typography; [asset provenance](../game/assets/auth/PROVENANCE.md).
The screen explicitly says when Google is awaiting configuration.

To obtain a client ID with your existing Google account:

1. Create/select a **Beat my track** project in Google Cloud Console.
2. In **Google Auth Platform → Branding**, set the app name and support email.
3. Set **Audience → External** for personal Gmail testing; add your account as a
   test user when prompted.
4. In **Clients → Create client**, choose **Web application**.
5. Add JavaScript origins `http://localhost`, `http://localhost:18181`, and
   `http://127.0.0.1:18181`. Redirect URIs remain empty for the JavaScript callback flow.
6. Copy the public Client ID ending in `.apps.googleusercontent.com`. No secret is
   needed. Put that ID in both `BMT_GOOGLE_CLIENT_IDS` and `BMT_GOOGLE_WEB_CLIENT_ID`
   in `.tools/bmt-pc.env`, then run BackendStart again. The owner can instead send
   the public ID to the coding agent to configure it.

These steps follow [Google's setup guide](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid).
A personal Google account alone does not configure the game's OAuth client.
Real Google acceptance remains pending that ID and an interactive sign-in.

Actual follow-up verification:

- `scripts/dev.ps1 -Action BackendStart` passed twice against the real PC stack;
  the repeated start preserved configuration and existing services.
- `scripts/dev.ps1 -Action CapturePCAccount`: **8 checks, zero failures**, using
  the saved PC config and real PostgreSQL/API, without injected URL/key or a fake
  Google verifier. Verified developer login, sign-out and durable account reuse.
- `python -m pytest backend/tests/test_account_client.py backend/tests/test_browser_auth.py backend/tests/test_auth.py -q`:
  **43 passed** in 21.37 s.
- Final wrong-service/configuration regressions:
  `python -m pytest backend/tests/test_account_client.py backend/tests/test_pc_development.py -q -s`:
  **4 passed** in 14.12 s; **22 headless Godot checks**, zero failures. This includes
  refusing to send development credentials to a different service.
- Pinned Godot import and Ruff passed. No phone test or Android export performed.
- Current real-PC screenshots: [options](evidence/pc-sign-in/pc-options.png),
  [authenticated developer](evidence/pc-sign-in/pc-developer.png), both inspected.

The earlier implementation record follows; its manual port-8080 setup remains an
option for separately configured API development, not this workstation's default.

2026-09-28 owner follow-up, requirements B01/B19/R01/V03/Q01. The menu now has a
**Sign in** account entry. Its two options are **Continue with Google** and
**Development · developer**. Local driving remains available without signing in.

Google uses a selected player name (1–40 visible characters), not the Google real
name or email. A returning Google identity keeps its saved name and UUID. Names
are display names, not globally unique identifiers. Development always uses the
same backend identity and lowercase name `developer`; it does not use the username
field. The server refuses renaming that account. Google and development identity
namespaces remain separate even when names match.

## Development setup

Start PostgreSQL and configure the API as described in [backend/README.md](../backend/README.md).
Run `scripts/dev.ps1 -Action BackendMigrate` before starting the changed API: schema
`0002_browser_login` adds only expiring browser handoffs and preserves existing data.

Set `BMT_ENVIRONMENT=development`, `BMT_DEV_AUTH_ENABLED=true`, and a privately
generated `BMT_DEV_AUTH_KEY` of at least 32 characters in the API process. In the
debug game process set the **same** `BMT_DEV_AUTH_KEY` and
`BMT_API_URL=http://127.0.0.1:8080`, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Run
```

Use **Sign in → Development · developer**. The API must be running; failed requests
never create a fake local authenticated session. For editor launches, the optional
private `user://backend.cfg` (Windows `%APPDATA%/Circuit01Lab/backend.cfg`) accepts:

```ini
[backend]
url="http://127.0.0.1:8080"
development_key="replace-with-the-same-private-development-key"
```

This file is local to the device, outside the export, and must not be committed or
shared. Environment variables take precedence. Release builds ignore development
keys and hide Development. HTTPS is required except localhost/127.0.0.1 development.
For Android local testing, use an HTTPS service or an ADB reverse mapping to localhost;
Android network permission is now enabled. No phone test is claimed.

## Google setup

Create/configure a Google OAuth **Web application** client. Set its public client ID
in both `BMT_GOOGLE_WEB_CLIENT_ID` and the allowlist `BMT_GOOGLE_CLIENT_IDS` (comma
separated). Set `BMT_PUBLIC_BASE_URL` to the externally reachable HTTPS API origin
and use that same origin for the game's `BMT_API_URL`. Add that origin to Google's
**Authorized JavaScript origins**. For local development use the same exact
localhost origin in Google, the API and the game. No client secret is needed by
this Google Identity Services callback flow. See Google's
[setup guide](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid)
and [nonce/callback API](https://developers.google.com/identity/gsi/web/reference/js-reference).

Choose a player name and press Google. The system browser opens the backend's
sign-in page, which renders Google's own account button. After Google completes,
return to the game; it checks completion every five seconds. Cancel and five-minute
expiry both leave the player signed out. Existing accounts keep their stored name.
The menu then displays the authenticated name and offers **Sign out**.

Only the signed Google subject establishes Google identity. Separate random browser
and game-poll secrets are hashed in PostgreSQL; the browser secret travels in a URL
fragment removed before Google loads. The browser never receives game access or
refresh tokens. Google signature/audience/issuer/expiry/nonce validation remains
mandatory. Completion and token collection are single-use across API replicas.
The browser page uses CSP and disallows framing. Expired handoffs are removed by
the existing maintenance command. Tokens remain in memory; signing in again is
required after restarting the game. Secure persisted sessions are a later slice.

## Removing Development later

Set `BMT_DEV_AUTH_ENABLED=false` and restart all API replicas. Bootstrap hides the
option on the next account-screen refresh; development login returns 404 and both
existing access and refresh credentials are rejected. Remove the private client
key as well. Existing development-owned tracks/records are retained, avoiding
silent data deletion or reassignment; deleting that data is a separate explicit
operation. Production already forbids enabling the bypass. Google login is unaffected.

## Implementation and evidence

- `game/backend/account_controller.gd`, `backend_client.gd`: session, browser polling,
  cancellation, server capabilities and debug-only configuration.
- `game/ui/account_panel.gd`, `game/core/app.gd`: account menu, username and sign-out.
- `backend/bmt_backend/browser_auth.py`, `auth.py`, `security.py`: handoff, fixed
  developer identity, Google name preservation and development-session retirement.
- Identity model/migration, maintenance, settings and Compose support the new flow.
- Real menu screenshots: [sign-in](evidence/account-sign-in/sign-in-960.png),
  [developer](evidence/account-sign-in/developer-960.png),
  [Google test player](evidence/account-sign-in/google-player-960.png),
  [Google-only configuration](evidence/account-sign-in/google-only-960.png).

Google UI handoff tests inject a **test-only** Google identity verifier and browser opener. They are
not evidence of acceptance against a real configured Google OAuth project. No NAS
deployment, Android export or physical-device acceptance is included.

| Executed command | Actual result |
|---|---|
| `.tools/backend-venv/Scripts/python -m pytest backend/tests -q -k 'not postgres'` | 106 passed, 31 deselected, 53.84 s. Before the final non-ASCII nonce regression and account-refresh assertion. |
| `.tools/backend-venv/Scripts/python -m pytest backend/tests/test_auth_postgres.py -q` | 4 passed, 56.93 s, including concurrent one-time browser collection, Google creation, refresh reuse and migrations. |
| `BMT_CAPTURE_ACCOUNT=<absolute docs/evidence/account-sign-in>` with `python -m pytest backend/tests/test_account_client.py backend/tests/test_browser_auth.py -q` | Final focused run: 9 passed, 17.24 s. Real Godot UI/HTTP development login, fixed identity, logout, fixture-Google handoff, chosen name, cancellation, hidden retired option, malformed nonce, expiry and provider separation. Screenshots at 1280×720 and 960×540 inspected. |
| `scripts/dev.ps1 -Action TestMenus` | 26 checks, zero failures. |
| `BMT_CAPTURE_ACCOUNT=<evidence directory>` with `python -m pytest backend/tests/test_account_client.py -q -s` | Final UI rerun after lazy account-controller initialization: 25 checks, zero failures; 1 pytest case passed in 16.42 s. |
| `scripts/dev.ps1 -Action CheckScript -ScriptPath res://core/app.gd` and `-Action Import` | Passed on exact pinned Godot. Import retains the existing Android build-tools fallback notice. |
| `python -m ruff check --config backend/pyproject.toml backend/bmt_backend backend/tests backend/deploy` | All checks passed. |
| `scripts/dev.ps1 -Action TestApp` | Failed/stalled: old fixture searches for `Tracks`/creator navigation although the existing menu has uppercase `PLAY`/`CREATE`; null access at test lines 112 and 59. Same failure was already present in the pre-change 2026-09-24 app-test log. Stopped only this stalled test process. Test was not weakened or reported as passed. |

Pytest emits the existing Starlette/httpx deprecation warning. The disposable WSL
PostgreSQL test fixture was started for tests and stopped afterward. No production
database or server was configured or deployed by these tests.
