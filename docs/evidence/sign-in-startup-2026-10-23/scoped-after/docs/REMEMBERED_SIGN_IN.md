# Startup and remembered sign-in

## Tablet persistence and direct menu entry, 2026-10-23

ASI01-ASI03/B01/B19/R01/G01/Q01: Android's `JNISingleton` exposes plugin
operations through `has_java_method`; checking only `Object.has_method` made
the working Keystore adapter appear unavailable and prevented remembered
sign-in. The vault now checks that Java registry on Android and retains the
ordinary native method check on desktop. Encrypted storage, backend/profile
binding, refresh rotation, explicit logout and account-change fences remain.
See the [Godot JNI method documentation](https://docs.godotengine.org/en/4.6/classes/class_jnisingleton.html).

Successful sign-in and first name/country saving now enter the Race menu
directly. A restored account asks for a country only when its server profile
has no valid country. A saved country bypasses both country setup and the
former signed-in confirmation. Profile → Manage account remains available
for country changes, sign-out and deletion, with the heading Your account.

Actual validation: focused capability/profile checks 16/0; real HTTP account
integration 75/0 headless and 88/0 native Compatibility, including restart
before country selection, restart after saving, returning Google identity,
name conflicts, cancellation and explicit account management; shared session
rotation 17/0; full App 141/0. The captured original vault reproduces two
Android-registry failures. The broader communication fixture retains four
publication-cooldown failures, identical with the original vault; its secure
storage assertions pass. The initial account harness timeout came from
reading controls during the existing asynchronous profile rebuild; the final
harness waits for that screen transition without changing assertions.

[Missing-country startup](evidence/sign-in-startup-2026-10-23/native/missing-country-startup.png)
and [returning-player menu](evidence/sign-in-startup-2026-10-23/native/returning-google-menu.png)
were captured and inspected in the native game. The fixture's Rivalry service
is deliberately unavailable; those screenshots demonstrate routing, not live
Rivalry availability. Commands, source hashes, logs and the scoped checkpoint
are in [the evidence report](evidence/sign-in-startup-2026-10-23/report.json).

No successful tablet attachment check or device test was performed: ADB could
not initialize its user directory in the sandbox, and no local ADB server was
running. No APK, install, live backend/account mutation or deployment occurred.
An updated tablet build and owner cold-restart acceptance remain. If the old
build never saved a session, sign in once after updating. The historical
plaintext/future-vault notes below describe the original implementation;
current storage uses the existing platform-protected vault.

2026-10-04 renewal repair: clients sharing the private session file coordinate refresh and the following authenticated retry. Saves add noncredential `login_id` and `player_id` metadata; old saves gain these on successful renewal. A different explicit login is preserved rather than silently adopted. See [PC rivalry logout repair](RIVALRY_SESSION_FIX.md).

2026-09-28 owner request; requirements B01/B19 authentication, R01 isolation, Q01 verification.

Normal startup opens the sign-in screen. If a saved session exists, the game verifies
the backend identity, exchanges its refresh token, and enters Home with the returned
player profile. Incomplete Google name selection stays on the account screen.
Guest play remains available and does not create a remembered account. Explicit
diagnostic capture and direct-track launches retain their existing entry points.

From the menu, select the player-name button and then **Sign out**. This removes
the saved login before contacting the server; the next startup shows sign-in.
Invalid/revoked tokens are discarded. A bootstrap connection failure retains the
saved token for retry; an ambiguous refresh failure requires signing in again
because refresh rotation is single-use.

`game/backend/backend_client.gd` stores only backend URL and rotating refresh token
in `user://account_session.cfg`, using a temporary file and rename. Access tokens,
Google tokens and development keys are not stored there. No token is trusted as a
cached identity: restoration always calls the backend. Storage is in the application
data directory, separate from records/track exports. This first implementation is
not OS-vault encrypted; another process with access to that OS user's files can read
it. Native Keystore/Credential Manager integration remains future platform work.

`game/backend/account_controller.gd` handles restore/status/retry;
`game/core/app.gd` controls startup routing. `game/ui/account_panel.gd` retains the
menu logout action. Tests isolate persistence beside their temporary records and
do not write the owner's session file.

Actual commands and results:

- `python -m pytest backend/tests/test_account_client.py -q -s` with graphical
  `BMT_CAPTURE_ACCOUNT=docs/evidence/remembered-sign-in`: passed, 46 native checks.
  Covers initial sign-in screen, fresh App instance restoring to Home, rotating
  token, no saved access token/development key, menu logout, and restart after logout.
- Final headless run: passed, including invalid-token rejection/removal in the same integration test.
- `scripts/dev.ps1 -Action CapturePCAccount`: 8 checks passed with actual PC API,
  PostgreSQL and installed device configuration, using pinned Godot 4.7.2.
- `git diff --check`: passed.

[Desktop startup screen](evidence/remembered-sign-in/sign-in-1280.png) inspected;
compact and account-state captures are in the same folder. No art changes.
Real Google interaction, physical Android testing and release secure-storage
integration were not performed. No production deployment or physics change.


## No login flash during restoration

Owner follow-up, B01/B19/V03/Q01: `game/core/app.gd` now chooses a neutral
branded loading screen when a saved session exists. It does not construct the
account panel during restoration. Valid completed profiles go directly to Home;
failed restoration or unfinished name selection opens the account screen only
after the result is known. First-time users still start at sign-in.

`game/tests/test_account.gd` checks every restoration frame for the absence of
login controls and verifies the final Home route. The headless HTTP/Godot run
passed 56 checks. Graphical validation passed 65 checks using the same test with
`BMT_CAPTURE_ACCOUNT=docs/evidence/startup-no-flash`; the neutral loading layout
is explicitly held for its screenshot after the live startup assertions.
[Loading screen](evidence/startup-no-flash/remembered-startup.png) inspected.
No phone test, Android export, backend or physics change.
