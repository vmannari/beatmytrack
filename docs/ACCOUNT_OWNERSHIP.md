# Account ownership and existing circuit access — 2026-09-28

Current override (2026-10-03): Race uses backend publications and disposable
retrieval caches. The 20 retained named local circuits are now published under
**Beat my track**, alongside six existing publications. Matching saved originals
were removed after backup, validated import and verified download; unmatched
recovery copies and unfinished edits remain. This supersedes the shared-local
playable catalog described below. See [track restoration](TRACK_RESTORATION.md).

Requirements B01/B19 (identity), B02–B07 (track/rating/leaderboard ownership), R01
(domain separation), Q01 (validation), and the owner's account-specific data request.

## Audit and changes

The API already keys track ownership, ratings, run tickets, verified personal bests
and leaderboard entries by authenticated player ID. The game previously used one
device-wide LocalRecords and TrackLibrary, allowing different accounts to inherit
each other's local votes, best times, favorites and drafts.

The app now switches both stores using a hash of backend URL and stable player ID.
Display-name changes do not change storage identity. Local records/settings,
favorites, track ratings, vehicle selection, drafts, test witnesses and local
publication records are separate. Switching users clears editor/undo/search and
discovery state. Session configuration remains device-specific. Guest/unassigned
data stays in the original location; no files are deleted or claimed for a player.

The initial separation hid old circuits after login. The owner's follow-up caught
this regression. Play now indexes the original circuit directory as shared,
read-only content and resolves selections from their actual source directory.
Published local tracks from other profiles are also playable; their private WIP
folders are not indexed. My tracks excludes shared entries. The actual PC library
shows all 20 existing circuits after signing in.

New/imported editable creations are stamped with the current racing name on
creation, save, export, test and publication. The arbitrary creator-name dialog is
removed. Creation screens display the account-derived author. Guest drafts use
`Guest`; importing/remixing never grants ownership of the original. Existing shared
files retain their original attribution. Local file contents are not a trusted
identity boundary: backend uploads independently overwrite document creator with
the authenticated player's name before validation/storage, and ownership remains
the stable server player ID.

The development identity remains `development/developer`, with visible racing name
**Beat My Track**. Migration `0004_developer_name` updates its existing profile
without changing player ID, tracks, votes or sessions. Google identities are untouched.
The fixed developer name cannot be changed through profile PATCH.

Changed files: `game/core/app.gd`, `game/persistence/track_library.gd`,
`game/ui/track_catalog.gd`, `track_browser.gd`, `account_panel.gd`; backend auth,
track upload, readiness and new migration; account, PC, domain and end-to-end tests.

## Validation and limitations

- Native HTTP/Godot integration: 62 graphical checks passed, including shared-track resolution and My tracks isolation assertions.
  It tests distinct Google/developer records, drafts, author spoof prevention,
  switching back, session restoration and logout.
- `scripts/dev.ps1 -Action CapturePCAccount`: 10 checks passed, including all
  original circuit IDs visible in the signed-in account's Play catalog.
- `scripts/dev.ps1 -Action TestCatalog`: 18 checks passed.
- `scripts/dev.ps1 -Action TestRecords`: 53 checks passed.
- `scripts/dev.ps1 -Action CheckScript -ScriptPath res://core/app.gd`: passed.
- Broad non-PostgreSQL backend run initially had 112 passes and one obsolete
  document-equality expectation: uploaded documents now contain the authenticated
  author. Updated that assertion to check the new contract while retaining the
  original content and immutable-version checks. Domain tests additionally reject
  author spoofing and another player's version update.
- Final `python -m pytest backend/tests/test_domains.py backend/tests/test_auth_postgres.py backend/tests/test_end_to_end.py -q`: 45 passed, 5 SQLite concurrency cases skipped, including PostgreSQL ownership/session concurrency and both end-to-end replay flows. Test database stopped afterwards. Ruff passed.
- Local PC API/worker stopped and restarted using BackendStart; migration and
  readiness passed. No production deployment or physics changes.

Evidence: [existing PC circuits](evidence/pc-sign-in/pc-existing-tracks.png),
[developer creator identity](evidence/account-ownership/developer-creator.png).

This change scopes local data by account; it does not add cloud synchronization of
local ratings, settings or private drafts. The existing server-owned online data
remains account-specific. Existing unassigned local data is intentionally not
automatically migrated to whichever person signs in first. Real Google interaction
and physical-phone testing were not performed. OS-vault session encryption remains
the previously documented platform limitation.


## Race results follow-up

The owner reported shared tracks visible in Play but absent from race results.
Results rebuilt its catalog without shared entries, and recommendations loaded
saved documents from the private library instead of each entry's source directory.
`app.gd` now shares catalog setup between both screens and includes shared entries
when results rebuilds the index. `TrackCatalog.load_entry_document` supplies the
same source-aware lookup to recommendation validation and race resolution.

Requirements B02/B19/R01/Q01. Changed `game/core/app.gd`,
`game/ui/track_catalog.gd`, `game/ui/race_recommendations.gd` and
`game/tests/test_race_results.gd`. The fixture now uses an empty private library
with circuits in the shared directory; it checks results before Play has populated
the catalog, results after Play, and actually launching a shared recommendation.

`TestResults` initially exposed two overly restrictive new assertions that expected
all recommendations to be shared, although built-in circuits remain valid. Updated
those assertions to permit built-ins while requiring shared entries and a shared
race launch. `scripts/dev.ps1 -Action CaptureResults` then passed all 207 checks,
including a real five-lap AI race and existing results/rating/navigation checks.
[Results screenshot](evidence/shared-results/race-complete-1280x720.png) inspected.
No physics changes, phone test, Android export or deployment.
