# Soundtrack packages, custom states and saved-track deletion

2026-09-28. Requirements **MUS03/MUS06/MUS09/MUS10, R01/V03/V05/Q01**.
The owner requests deletion of saved tracks, a persistent Mix Lab sidebar,
configurable state counts and soundtrack packages. They explicitly confirmed
**one compatible subset per package**: select the package first, then draw one
recording from each of its pools, holding those choices throughout a drive.

## Workflow

The running local studio remains <http://127.0.0.1:18765>. Start it with
`powershell -NoProfile -ExecutionPolicy Bypass -File tools/music_generator/launch.ps1`.

1. **Your library → select a saved track → Delete track.** The dialog identifies
   how many packages reference the track. Deletion removes it from the library,
   catalog and every package pool, then places it in **Trash**. Restore retains
   its title/state, but does not silently reinsert removed pool memberships.
   Original audio/manifests are retained; this is recoverable library deletion,
   not disk-space reclamation. Removing a package does not remove its recordings.
2. **Manage states** edits the library's 1–12 named states. Removed trailing
   states become Unassigned on library/trash tracks and pending takes. Existing
   packages retain their own state layouts. New packages start with library
   names and can independently use any count from 1 to 12.
3. **Soundtracks → New soundtrack.** Name it and choose **Layer stack** or
   **Switch tracks**. Set the count, select each state, name it and check the
   saved recordings allowed in its pool. Pools contain alternatives: one track
   is drawn per state. Save incomplete packages as drafts; complete pools are
   required for auditioning. Rename, duplicate and delete packages in this view.
4. **Try in Mix lab → New drive.** Select a specific package or **Random ready
   package**. Selection chooses a package before drawing its tracks. Layer stack
   retains earlier parts as new states add layers; Switch tracks crossfades to
   one arrangement at a time. Collision, state scrubbing and Restart keep the
   chosen recordings. New drive redraws, avoiding an identical consecutive
   draw within the same package when alternatives exist.
5. Package auditions lock track membership, mode, state count and per-track
   entry/variation selectors. **Free mix** explicitly unlocks the experimental
   controls. Clear mix and earlier studies also leave package audition mode.
   Level, mute/solo, timing and loop controls remain audition tools; they do not
   change the saved package. A failed/incomplete package load leaves the current
   audition intact. Returning to a package draws from its current saved pools.

Create, Library, Soundtracks, Manage states and Mix Lab use the shared sidebar,
including the compact navigation and state-management link. Package playback
initializes the state buttons from package names. Free mix supports 1–12 states;
the earlier evolving-tempo score remains its authored six-state experiment.

## Persistent contracts

`build/music/workbench/library.json` migrates atomically from schema 1 to **2**,
with a retained `library-schema-1-backup.json`. It stores:

- `states`: 1–12 unique, nonempty names (up to 40 characters each).
- `tracks` / `trash`: asset-ID-keyed saved metadata. Trash adds `deleted_at`.
- `packages`: UUID-keyed `{id, name, mode, states, updated_at}` objects. Mode is
  `layers` or `arrangement`; each state is `{name, pool: [asset IDs]}`. Each pool
  accepts up to 100 distinct saved, non-deleted tracks. Empty pools are valid
  drafts. Snapshot readiness additionally checks source availability.
- Existing jobs and provenance remain intact. Registry transactions preserve
  active worker references and roll back on failed disk writes.

The checked local POST API adds `/api/states`, `/api/tracks/delete`,
`/api/tracks/restore`, `/api/packages/save` and `/api/packages/delete`. The bounded
JSON request limit is 256 KiB to accommodate pool definitions. Existing local
token/origin checks apply. Source files are never deleted by these endpoints.

Mix setup exports use **bmt-audition-2**, including state names/count. Earlier
`bmt-audition-1` setups retain their original six-state interpretation. The
package registry is the persistent pool definition; a mix setup records one
particular drawn audition. Back up all of `build/music` for registry and audio.

## Actual commands and outcomes

```powershell
python tools/music_generator/test_studio.py
python tools/music_generator/test_packages.py
wsl -d Ubuntu -- bash tools/music_generator/scripts/run_from_windows_repo.sh python tools/music_generator/test_toolkit.py
.tools/review/Scripts/python.exe tools/music_generator/test_packages_browser.py
.tools/review/Scripts/python.exe tools/music_generator/test_studio_browser_errors.py
.tools/review/Scripts/python.exe tools/music_generator/test_browser.py
.tools/review/Scripts/python.exe tools/music_generator/test_iteration_browser.py
.tools/review/Scripts/python.exe tools/music_generator/test_additive_browser.py
.tools/review/Scripts/python.exe tools/music_generator/test_tempo_browser.py
git diff --check
```

- **14 service checks pass** (`test_packages.py` includes 8 existing service
  tests and 6 new package/state/delete tests). Covers migration/backup, counts,
  independent package states, all-pool cleanup, restoration, missing/deleted
  assets, drafts, invalid definitions, atomic rollback, restart and editing
  states during an in-flight synthetic generation.
- **10 toolkit tests pass.** The generator is unchanged in this slice.
- **11 package browser groups pass:** package creation/edit/reload, actual
  nonzero Web Audio output, additive and exclusive targets, stable per-drive
  choices, constrained redraws, package-first random selection, free-mix
  unlock, 1/9-state playback, setup round trip, deletion/restore/pool repair,
  global-state reduction, package deletion, desktop/390px layouts and no JS errors.
  These tests use isolated temporary storage and explicitly synthetic sine
  audio; no owner tracks/packages are modified by them.
- **5 existing simulated browser failure/reconnection checks pass.**
- All existing Mix Lab regressions pass: **19 workbench, 9 R2, 15 additive and
  19 evolving-tempo groups**, using the existing recordings.
- Browser testing found that duplicate number-input change events rebuilt a
  focused field. Repeated same-count changes now leave the DOM intact; the
  complete suite passed after the fix. A test-only random-function override
  also needed an explicit wrapper before the random-package check passed.
- Desktop and compact screenshots were visually inspected. Shared-style
  checkbox sizing and mobile access to Manage states were corrected during
  that review. Final browser suite passes with package isolation controls.

Evidence (test-fixture names/audio, not approved soundtrack assets):
[package editor](evidence/music-packages/package-editor-desktop.png),
[Mix Lab sidebar and package](evidence/music-packages/mix-lab-sidebar.png),
[Trash](evidence/music-packages/library-trash.png),
[compact editor](evidence/music-packages/package-editor-mobile.png),
[compact lab](evidence/music-packages/mix-lab-mobile.png),
[browser results](evidence/music-packages/browser-results.json).
Regression outputs are copied under this round's evidence folder; historical
round captures are preserved.

## Changed files and remaining acceptance

`workbench.py` and `serve.py` implement the registry/API changes. Shared
`ui/shell.js` supplies navigation; `ui/packages.html/js/css` and
`ui/states.html/js` supply authoring. `ui/index.html`, `studio.js`, `lab.html`,
`app.js` and `lab-packages.js` connect deletion, custom states and package-first
auditioning. New tests: `test_packages.py` and `test_packages_browser.py`.
README, music state, development/phase status and this document record scope.

This delivers local package authoring and auditioning, not game-runtime package
selection or an Android soundtrack export. No new music was generated, no
subjective listening approval is claimed, and pool membership does not prove
harmonic/timing compatibility. Owner acceptance remains for workflow and actual
musical combinations. No Godot build, Android export or physical-phone test was
performed; phone attachment was not checked. Narrow captures are desktop Edge.
