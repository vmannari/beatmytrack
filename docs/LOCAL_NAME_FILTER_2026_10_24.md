# Local user-name filtering — 24 October 2026

The backend rejects inappropriate new player and track names before saving or
publishing them. Challenge titles are derived from their creator and selected
tracks, so new challenges and rematches check those names too. The filter runs
locally; it has no provider calls, new runtime dependency or per-check service fee.

## Requirements and coverage

| ID | Implemented behaviour |
| --- | --- |
| LNF01 | Shared policy for every current player naming write: native Google signup, browser signup/handoff, development signup, profile rename, publication/revision envelope name and downloadable document name. |
| LNF02 | Bundled dictionaries, reviewed exceptions and additions, common Unicode/leet/separator/repetition disguises, bounded work, unchanged accepted spelling and document hashes. |
| LNF03 | New challenges/rematches check the creator, all selected track names and their authors, including the fifth custom track. New publication also checks names from older accounts; queued publication rechecks at commit. |
| R01 | Preserve exact acknowledged retries, ownership, ordinary authentication, public-content terms, reports/blocks, verifier authority, publication slots and existing scores. |
| Q01 | Focused and existing backend checks, offline wheel/resource check, original controls for unrelated failures, source fingerprints and a task-only review patch. |

The current API has no editable challenge name or title field; unknown fields are
already rejected. Validating the underlying names covers its generated titles
without inventing a new challenge contract. Saved cosmetic selections use
catalogue identifiers, not user-authored names. Friend-name lookup, catalogue
search, incident reports and private Studio evidence are not naming writes and
remain available for finding/reporting existing abuse.

There is no shipping remote draft-creation or rename endpoint: new and renamed
tracks are uploaded through `/v1/publications`. The shared `TrackContent`
validator also checks both names when used by backend tooling. Retired authoring
routes remain retired; test-only historical routes are not production features.

## Policy and public errors

`backend/bmt_backend/name_moderation.py` reads 26 original language lists from
`name_filter_data/` at startup. `sources.json` pins their source commit and each
file's SHA-256. Full CC-BY-4.0 attribution/license and language/quality limitations
are in that directory's README. The upstream files remain unchanged;
`policy.json` separately contains project exceptions, additions and the smaller
set of terms allowed to match inside compound names.

The policy normalizes only a comparison copy. Ordinary names such as
Scunthorpe, Dickinson, Cockpit, Middlesex, Jasmine and Mäkelä retain their exact
spelling. Neutral identity terms and ambiguous personal/ordinary names are
excluded from word-list matching; an allowed word does not exempt the rest of a
name. Common disguises include `f.u.c.k`, `sh1t`, `V1TTU`, compatibility-width
letters, selected visual confusables, format/combining marks and repeated letters.
Comparison input and expanded-normalization lengths are bounded.

New disallowed names return HTTP 422 with a safe, actionable detail:

```json
{"detail":"NAME_NOT_ALLOWED: Please choose another name."}
```

Request validation additionally includes the existing request ID. Rejected input,
authentication tokens and matched dictionary entries are never included in that
error response. Other validation errors keep `INVALID_INPUT`.

## Durable publication and challenge behaviour

The publication endpoint checks an exact existing operation/body receipt before
applying the current name policy. A policy update therefore cannot strand saved
retries for an acknowledged queued, failed or published request. New keys must
pass current policy before object storage, upload reservation or verifier work.
The authoritative creator replaces the supplied document creator as before.

The publication worker checks the envelope, embedded name, saved creator and
current owner before committing any catalogue/proof/slot changes. A queued
pre-update request that fails policy becomes a durable, nonretryable
`name_not_allowed` failure. Its original evidence is retained. The creator must
choose a different name and submit a new request. Existing published records,
scores, invitations and document hashes are not rewritten.

Challenge creation checks names as part of preparing each selected board, before
new challenge membership/invitation writes. Reads, existing tickets/results and
exact acknowledged challenge receipts retain their earlier contracts.

## Validation and evidence

The focused suite passes **183 checks** (18 PostgreSQL variants explicitly
deselected). It covers offensive/disguised and harmless names, all signup paths,
rename rejection without account changes, old browser handoffs, both track-name
locations, pre-storage rejection, four queued-publication cases, queued/completed
receipt recovery, authoritative creator replacement, fifth-track naming,
challenge recovery, unknown challenge title fields, pathological input and exact
dictionary provenance. Ruff passes. An offline wheel includes all **30** filter
resource files byte-for-byte; the extracted package imports and filters correctly
in an isolated interpreter.

Five initial API probes failed against the task-start code and pass after the
change. The first dictionary trial retained three missing-word failures, corrected
by additions without weakening the assertions. A later ordinary-name probe
identified Japanese Latin abbreviations matching Jasmine/Smith; substring
matching now requires the relevant script. The original package import invocation
and subprocess `PYTHONPATH` correction are recorded rather than hidden.

The first broad regression run recorded 190 passes, five failures, two fixture
errors, five skips and 83 deselections. Two supervision assertions still expect
no discovery process; a challenge downgrade hits the existing migration-0054
creator-event guard. Those three failures reproduce with the task-start modules
in a separate source copy. A real native publication fixture failed in engine
preparation before name admission. The initial archive/subprocess failures lacked
an explicit backend source path; the final runner sets it for child processes.
The regression run passes **193 checks**, with five skips and 87 explicit
deselections (PostgreSQL/native cases and the three reproduced failures). The
archive and disposable API/recovery cases pass with the corrected source path.
The exact commands and retained earlier outcomes are in the evidence report.
Existing assertions and unrelated runtime sources were not changed.

A local Windows benchmark measured a 0.1213 ms median / 0.1474 ms p95 for an
ordinary name (200 calls), and 2.2881 ms / 3.5645 ms for a 512-character repeated
letter case. These are local filter timings, not production load certification.

See [the evidence report](evidence/local-name-filter-2026-10-24/report.json) for
actual command arguments, retained XML/logs, source hashes and the Git-checkable
task-only patch. `app.py`'s control copy was reconstructed by reversing only this
task's exception-handler addition; the other pre-change source copies were
captured before editing. Concurrent work is preserved.

## Rollout and limits

Deliver the updated backend package and restart API/publication-worker processes
through an authorized rollout to activate the policy. No database migration or
client protocol update is required. This task did not deploy, restart owner
processes or mutate an existing player/backend database. No phone/tablet
attachment check, physical-device test or APK build was performed.

The lists vary in language/script coverage and cannot catch every abusive phrase
or disguise. Existing reports, blocking and human moderation remain necessary.
Existing names are not automatically renamed or hidden; new writes and new uses
in publication/challenge creation are checked. Policy and owner acceptance remain
subject to real moderation feedback.
