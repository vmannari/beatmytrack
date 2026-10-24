# Legacy cleanup

2026-10-24. The client now uses discovery v3 and trajectory submission directly.
Current controls, liveries and records no longer interpret old versions during
normal use; saved inputs upgrade at one persistence boundary. Existing player
files, accepted results, operation keys, recovery journals and historical physics
controls are preserved.

## Review findings resolved

| Finding | Result |
| --- | --- |
| LCR01 unused helpers | Removed old Desert builders, menu/row helpers and the unused track-poster script from shipping paths. Historical copies remain under excluded fixtures where appropriate. |
| LCR02 test-only APIs | Removed manual route/practice-start and test-population setters. Active tests use Start line projection, worker jobs, immutable publication metadata, acknowledged account reward receipts and complete cooperative loading. The historical histogram algorithm is an excluded diagnostic fixture. |
| LCR03 discovery | One client cursor engine, shared current filters and a strict backend query model. V2 retains small update-required responses. Migration 0062 removes the disposable v2 snapshot/budget tables; their models, worker reads and unused settings are gone. |
| LCR04 upload fallbacks | Normal uploads use trajectory records. Proof normalization no longer calls a full-input codec. Legacy wire arithmetic is excluded from the app. A private ticket-submission lookup recovers an accepted pre-update upload before any new encoding. New outbox records identify their submission schema. |
| LCR05 save compatibility | Input upgrades cover schema-1 seconds, grouped control regions, two-pigment liveries and retired LP metadata. Complete validation and the existing atomic writer retain backup and failed-write recovery. Current data uses a fast path. Session/outbox/publication recovery and historical cosmetic ownership remain purpose-bound. |
| LCR06 Studio credentials | Preserved the concurrent security implementation: shared keys default off and are forbidden in production; named staff/MFA remains the production path. Focused authority and revocation checks pass. No real staff/provider configuration was changed. |
| LCR07 native copies | Archived 12 unused DLL names, 14,199,939 bytes, with exact SHA256 verification. Four descriptor-selected Windows binaries/dependencies remain. Existing game/editor processes were inspected, not stopped. Build scripts apply the same guarded retention policy. |
| LCR08 documentation | README describes current cars, five-lap races, publication/discovery, backend, Android and validation. The superseded guide is archived. |

The offline test-driver generator is also explicitly excluded from Android export.
No migration removes tracks, PBs, player settings or current discovery journals.
Immutable contract upgrades, explicit current-format import rejection, native
platform adapters and the Compatibility renderer remain supported.

## Validation

The broad backend run passed 68 tests; the additional authority/recovery run
passed 9, including named MFA access and revocation. A final recovery/config run
passed 3. These overlap and are reported separately. The populated forward cache
migration is covered on SQLite; PostgreSQL was deselected.

The final parser compiled 1,056 scripts. Native checks passed as follows:

| Suite | Checks passed |
| --- | --- |
| records | 54 |
| control layout | 407 |
| livery patterns | 703 |
| garage records | 64 |
| condition store | 31 |
| discovery windows | 321 |
| startup discovery | 18 |
| free race preload | 120 |
| free race list | 233 |
| carousel histograms | 20 |
| editor workflow | 254 |
| race results | 515 |
| backend scalability | 17 |
| app | 141 |
| biomes | 108 |
| driving | 72 |
| legacy cleanup | 23 |

Rendered Compatibility discovery passed 324 checks, including three native
captures. All 5,000 fixture tracks remain reachable with at most 13 cached pages,
260 cards and 300 cursor coordinates. Native archive filesystem checks passed 7;
a repeat archive found zero candidates. Selected backend Ruff checks pass.

Actual commands, source hashes, per-finding outcomes, failed trial corrections,
logs, XML and native views are recorded in
[the evidence report](evidence/legacy-cleanup-2026-10-24/report.json).
The binary-capable scoped patch uses private comparison trees and preserves
concurrent security and game-configuration edits in both trees.

## Upgrade and acceptance

Apply the matching API/client and explicit `0062_retire_discovery_cache` migration
together with their existing 0060/0061 prerequisites. Pre-update upload recovery
requires `submission_recovery_version: 1`; an older service leaves the original
queued data intact pending its update. Restart the client for the source cleanup.

No phone/tablet attachment check, physical-device test, APK/export/install, live
account/backend mutation or deployment was performed. Desktop renderer and local
database checks do not certify device performance or a production migration.
