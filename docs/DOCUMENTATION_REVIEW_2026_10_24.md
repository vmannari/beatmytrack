# Documentation reconciliation — 2026-10-24

Requirements R01/Q01: reconcile the repository's current setup, behavior and format
guidance with the workspace implementation. This is a documentation change. The
review follows the main entry points and affected guides; it is not a line-by-line
certification of all 756 top-level documentation files or their historical evidence.

## Corrected findings

| Previous guidance | Current implementation and correction |
|---|---|
| Root title CIRCUIT / 01, Play startup, seven Slicks circuits | Beat My Track; session restore/account entry and Race; only Starter Circuit in the packaged native catalogue. Retired Slicks fixtures remain diagnostic. |
| Three-lap menu races and timed creator test drives | Five-lap standing races; untimed editor practice and Garage hall. |
| Space brakes; three tuning presets; F5 cycles seven imports | Space is handbrake; S/Down brakes. Six diagnostic presets, gated out of production-mode races. F5 follows the current catalogue and yard. |
| No backend, no network permission, missing Android tooling/no APK | Connected API/client, configured network permissions and Gradle ARM64/x86_64 exports. Recorded device deployments are linked without claiming all source changes are installed. |
| Creator format called v2/v3 current; 16 KiB documents | Current creator-track-v5/native surface-grid-v2, 1 MiB documents, 4,096 objects and independently 4,096 expanded tyre stacks, provisional 128 MiB prop estimate. |
| Pine/Coast/Desert are appearance-only palettes and all props passable | Grass/Desert/Night/Winter/Storm; Coast retired. Compacted sand/ice semantics, solid scenery and hazards are documented. |
| Protocol2 exact-total/offset discovery with a legacy fallback | Protocol3 cursor windows, 13 × 20-preview cache, actual loaded cards and 20–60-card reserve. Old routes return HTTP426. |
| Challenge entry/invitations, compact creation sheet and illustrated car selector | Format → tracks → actual Garage cars, separate browsing, quiet PB lookup and exact post-race ticket. 3×3 requires the matching schema58 rollout. |
| Disconnected backend diagram, future GCS and repeated old local-only statuses | Current architecture and release status precede the historical first-server report. Schema57 is the latest recorded release; later source migrations and prospective ranking launch are distinguished. |
| Older “current slice”/authorization blocks appear authoritative | Index and status/plan pointers explain checkpoint dates. Historical test results, failures, screenshots and scope decisions are retained. |

## Changed files and source evidence

The [root README](../README.md) and [documentation index](README.md) now lead to the
current guide sections. Updated guides: [menus/creator](MENUS_AND_CREATOR.md),
[creator format](CREATOR_FORMAT.md), [driving diagnostics](DRIVING_PLAYGROUND.md),
[themes](TRACK_THEMES.md), [discovery](DISCOVERY_PAGING.md),
[challenges](CHALLENGES.md), [challenge UI](CHALLENGE_PAGE.md),
[accounts](ACCOUNT_SIGN_IN.md), [Android](ANDROID.md),
[architecture](BACKEND_V1.md) and [backend setup](../backend/README.md).
[Development status](../DEVELOPMENT_STATUS.md) and [Phase 0 history](PHASE_0_PLAN.md)
link to these entry points. The backend dependency-check example now uses the
maintained `backend-secure-venv` already selected by the documented setup.

Facts were checked against project/input/export settings, App startup, Game input
dispatch, race rules, vehicle/theme/built-in catalogues, TrackDocument/CreatorLimits,
TrackCompiler/TrackLibrary, the parking hall, discovery windows/routes/bootstrap,
challenge creation/series, session restoration, API composition, worker supervision
and migration headers. The index links these sources directly. Deployment statements
come from existing receipts, especially the
[schema57 release](LATEST_BACKEND_DEPLOY_2026_10_23.md), rather than live inspection.

## Verification and limits

Verification results are recorded in the
[review evidence](evidence/documentation-review-2026-10-24/report.json).
The local checks pass: 35 source-fact comparisons, 177 current-section local link
destinations and 18 command examples checked against the wrapper's declared actions
and parameters. PowerShell parsing reports zero errors. Local destinations in the
retained bodies were also checked; the missing historical `app.log` link was replaced
with an explicit evidence-gap note. Historical test outcomes remain unchanged.
No documented build/test/deploy command was executed as part of these static checks.

The first source-fact probe incorrectly expected `physical_keycode=32`; project
Object fields use `"physical_keycode":32`. Correcting that probe resolves its one
failure without a source or control-mapping change. Task-scoped whitespace checks
pass. Historical gameplay/backend suites were not rerun by this task.

A concurrent challenge-art revision added its v3 checkpoint while this review was
running. Its source/guide changes are preserved, and its in-progress report reference
is recorded separately in the evidence. The task-only patch uses a separate base for
that shared guide so the concurrent section is not attributed to this review.
An initial PowerShell-to-Python pipe also replaced Unicode punctuation in new guide
prefixes; UTF-8 patches restored it before the final checks.

No runtime behavior, canonical schema, asset, migration or deployment configuration
was changed. No new screenshots are needed for these prose changes. Existing owner
game/editor processes and unrelated working-tree changes were preserved. No device
attachment check, physical-device test, APK/export/install, backend launch/migration,
account mutation, purchase or deployment was performed. A current installed build,
live service state, external-link availability and owner/device acceptance remain
outside this review. No full gameplay/backend regression pass is claimed.

The review used `rg --files`/`rg -n`, UTF-8 source reads, `git status --short` and
`git diff --numstat` to inspect scope. Before-edit bytes for the 14 existing documents
are retained under ignored `build/documentation-review-2026-10-24/before/`.
The evidence records the final local-check commands and source hashes. A task-only
patch against those before-edit bytes is retained in the same ignored build directory
so pre-existing changes are not attributed to this review.
