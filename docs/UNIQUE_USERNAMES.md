# Unique racing names — 2026-09-29

Owner request, B01/B19/R01/Q01: racing names must be unique while the UUID remains
the master identifier and names may change later.

`players.id` is unchanged. `players.username_key` is a backend-maintained lookup
key with a database UNIQUE constraint, not an ownership identifier. Its comparison
uses Unicode NFKC normalization, collapsed whitespace and case folding. `Ville`,
`VILLE` and equivalent full-width spelling cannot be claimed by different players.
The chosen display spelling remains visible. This does not attempt to identify
every visually similar character across different writing systems.

New identity creation and `/me` renames enforce uniqueness, including concurrent
requests. Conflicts return HTTP 409 `USERNAME_TAKEN`; the game displays an actionable
message and keeps name selection available. The developer name `Beat My Track`
is reserved for the existing fixed development identity. UUID-based ownership,
sessions and local profile directories remain stable across renames. A rename can
release the previous name for another player; names are never used to resolve ownership.

Unfinished Google accounts do not claim the placeholder `Racer`: their key is NULL
until name selection completes. Such accounts cannot upload tracks before choosing
a name. A CHECK constraint prevents completed profiles from having no claimed key.
Emails remain outside identity linking and are not stored.

Migration `0005_unique_username` backfills existing completed profiles and preserves
their UUIDs and display names. It checks for duplicates before altering the table
and aborts rather than silently renaming accounts. Read-only PC preflight found two
completed profiles and no duplicates. After migration, the same two profiles have
two claimed keys; the API/worker passed readiness and remain running.

Changed files: backend `usernames.py`, identity model, auth routes, upload guard,
readiness, migration and deployment instructions; game `account_controller.gd` for
feedback; native account and backend auth/concurrency/end-to-end fixtures.

Actual validation:

- `python -m pytest backend/tests/test_auth.py backend/tests/test_browser_auth.py -q`: 44 passed.
- `python -m pytest backend/tests -q -k 'not postgres'`: 120 passed, 33 deselected.
- `python -m pytest backend/tests/test_usernames.py -q`: final 8 passed, covering
  equivalent names, reserved name, rename/UUID/track/session preservation,
  database constraint, pending names, duplicate signup and migration preservation/refusal.
- `python -m pytest backend/tests/test_auth_postgres.py -q`: 5 passed, including
  two concurrent players claiming one name (one success, one 409) and concurrent
  creation of the same Google identity retaining one UUID. Test database stopped.
- Graphical `test_account_client.py` with `BMT_CAPTURE_ACCOUNT`: 67 native checks
  passed, including duplicate-name feedback and completing onboarding afterwards.
- Ruff and staged diff checks passed. PC API/worker stopped, then
  `scripts/dev.ps1 -Action BackendStart` applied migration and passed readiness.

[Duplicate-name feedback](evidence/unique-username/name-taken.png) inspected.
No physical-phone test, Android export, production deployment or new rename UI.
The existing profile API supports future renaming; no physics changes.
