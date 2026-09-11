# Technical handoff — baseline v2.0

Read the master specification first. This is an implementation contract, not a claim that the game or service already exists. Source IDs refer to `specs/Sources.json`.

## Dependency map

```text
Android / Windows client
  Presentation: scenes, HUD, menus, sound, touch controls, editor
      | commands / state models
  Application: RaceSession, GarageService, EditorSession, SyncOutbox
      | interfaces                         | data-only calls
  Local adapters                       Canonical simulation
  atomic save + replay cache           vehicle / surfaces / gates / rules
      |
  HTTPS provider-neutral API
      |
  Modular backend ------------------------- PostgreSQL
  identity / tracks / runs / economy       ledger + inventory + PBs
  leagues / purchases / moderation         immutable manifests + jobs
      |                         |
  bounded object storage       verification queue
  track bundles / replays       |
                               version-pinned headless verifier
```

Use Godot standard + typed GDScript for the client, with 3D presentation over the canonical planar simulation. Select Compatibility or Mobile through the P0-V device comparison; do not inherit the old 2D-only rendering rationale. Pin the engine/export/plugin matrix. Supabase is the proposed first identity/Postgres/storage provider, not a dependency in every scene. Run a separate verifier process where a game-engine binary is supported; do not assume a database edge function can run Godot. Sources S01–S05, S17.

## Proposed repository layout

```text
client/project.godot
client/presentation/{screens,hud,controls,audio}
client/application/{race,garage,editor,sync}
client/domain/{vehicle,rules,progression,track}
client/adapters/{local,api,android_billing}
client/content/{cars,parts,official_tracks,locales}
sim/                    # canonical core or isolated shared module
server/api/             # versioned service endpoints
server/worker/          # headless replay verification jobs
server/migrations/      # reviewed, reversible database changes
contracts/              # schemas, enums, compatibility manifests
fixtures/replays/       # golden inputs + expected hashes/results
scripts/                # validate, test, Android build/deploy
ops/                    # restore, incident and league runbooks
licenses/               # asset provenance and third-party notices
```

Do not create empty complexity just to reproduce this tree during P0. Introduce modules when their slice is implemented.

## Domain records and authority

| Record | Identity / uniqueness | Authority / mutation |
|---|---|---|
| Player | UUID | Auth identity linked to guest carefully; no silent account merge |
| Car definition | ID + content version | Developer-authored, immutable once used by ranked manifests |
| Garage ownership | Player + car + inventory revision | Server authoritative online; journaled local pending state |
| Part installation | Player + car + part slot | Transaction verifies ownership, XP gate and class rules |
| Track identity | Creator + UUID | Title/description/status mutable with moderation history |
| Track version | Content hash | Geometry/collision/gates immutable; metadata outside geometry hash |
| Challenge | Code/UUID + comparison key | Pins version, rules, car/spec and target run |
| Run | Player + run UUID | Append-only submitted -> verifying -> verified/rejected |
| Replay object | Cryptographic hash | Immutable bounded object; server never trusts a client time field |
| Ledger grant | Player + source run + grant type | Unique index prevents repeated credits or XP |
| PB | Player + comparison key | Best verified result updated atomically; timestamp is not tie priority |
| League entry | Season + cohort + player + event | Best eligible verified time; no points from repetition alone |
| Settlement | Season/cohort + settlement revision | One idempotent transaction and audit record per revision |
| Entitlement | Store + purchase token hash | Server verifies and reconciles refunds; never log raw token publicly |
| Moderation report | UUID + object/version + reporter | Private queue; evidence retention bounded and access controlled |

A single best result per player per comparison key feeds histogram/ranking. Attempts remain separate. Index `(comparison_key, time_ms, player_id)` for ordered reads, and uniquely `(player_id, comparison_key)` for PBs. Histogram aggregation uses the same snapshot/version as the reported population count and rank. Cache with a short explicit TTL; revalidation never grants rewards.

## Comparison-key canonicalization

Serialize only these sorted fields in UTF-8 JSON with no whitespace: track geometry hash, physics version, rules version, direction, lap count, start mode, competition type, car/class/spec rule ID, performance-affecting assist policy. Hash with SHA-256. Use integers or enumerated strings, never locale-dependent floating formatting. Car build snapshots are stored with each run. A class board compares permitted different builds; a spec board pins the exact build and tunable/locked parameters. Do not include cosmetic colour, display name or thumbnail in the competition identity.

Metadata editing must not reset records. Geometry/collision/surface/gate changes do. Keep old physics and track versions available for pinned active challenges; do not execute arbitrary uploaded code to achieve compatibility.

## End-to-end race transaction

1. The API issues an authenticated run ticket binding player, run ID, pinned manifest, inventory revision, expiry and event deadline. The client obtains required cached content before starting.
2. Input is sampled/quantized at fixed logical ticks. Rendering is interpolated separately. Record pause/background/reset events and all data required by the canonical core.
3. Finish locally. Display a local result and pending progression promptly. Persist the outbox atomically before upload; retry must not wait for the network.
4. Upload a bounded replay object through a scoped URL. Submit its hash and ticket using the run ID as the idempotency key.
5. Verifier loads only approved content versions, executes the canonical simulation, computes checkpoints, time and eligible active-driving duration, and checks legality.
6. One database transaction records the verdict, grants earned rewards once, updates a PB when faster and emits a durable result event. API retries return the same outcome.
7. Client reconciles the authoritative ledger/inventory revision. Pending upgrades become confirmed only when their dependencies are verified. Invalid local results remain explained practice history, not unexplained disappearing balances.

A replay validates physical consistency, not that a human generated the inputs or that a real second of wall time was spent per simulated second. Bind ranked tickets to server time; add rate/automation abuse detection, appeal/review and economic grant-rate checks. Play Integrity may contribute signals but is not proof of a legitimate race (S16). Do not market the system as cheat-proof.

## Offline support and failure states

Cached circuits, local editor, local progression and personal ghosts work offline. New online league eligibility needs the event manifest and authorized build. A supported pre-issued ticket can finish during a connection loss; an old event cannot be entered retroactively offline. Local pending earned claims are checked before influencing the cloud garage or ranked eligibility. A fixed-spec loaner remains available when a developed build is pending.

Cloud failures cannot destroy drafts or block practice. Use a persistent outbox, exponential backoff with jitter and stable operation UUIDs. Writes carry expected inventory revisions. Conflicts return an explicit retry/reconcile state, not last-write-wins currency. Files use temporary-write, flush and atomic-replace plus a previous-known-good backup. Migration fixtures cover all shipped save versions.

## Simulation and verifier gate

Prototype feel first. Before P4, run the same input corpus on Windows, representative Android devices and the verifier, at multiple render rates. Official finish time/checkpoint sequence and state hashes must satisfy an explicitly approved equivalence contract. Fixed timestep alone does not establish bitwise determinism (S05).

Prefer exact equivalence for a custom integer/fixed-point core with documented overflow/rounding, canonical collision iteration and stable lookup tables. A small C++ GDExtension is a fallback if GDScript precision/performance cannot meet the gate. Do not introduce a broad tolerance that accepts impossible shortcuts. If exact replay is not achieved, revise the simulation/verification design before making public global records authoritative.

## Capacity model to benchmark, not a hosting quote

Let A = DAU, R = completed/eligible run claims per active player/day, V = verifier CPU-seconds per replay, B = average retained replay bytes, D = retention days. Then jobs/day = A×R; average CPU cores = A×R×V/86,400; raw replay storage = A×R×B×D. Multiply peak arrival rate by measured burst headroom and include retries, uploads, backups and database writes. Store PB/selected ghosts longer than rejected or superseded attempts under an explicit policy.

Illustration only: 10,000 DAU × 30 runs × 0.10 CPU-seconds = 30,000 CPU-seconds/day (~0.35 continuously busy core), but a ten-times slower verifier needs ~3.5 cores before burst capacity. At 40 KiB/run and 30-day retention the raw replay volume is about 343 GiB. These inputs are unmeasured examples, not promises that a cheap plan is sufficient. Verify reward-bearing attempts too, not just PB candidates.

Required benchmark output: median/p95 replay CPU time; upload bytes; memory per job; failure/retry rate; peak queue age; Postgres writes/run; index size; storage/egress; backfill cost; moderation reports per 1,000 players. Add a service-budget alert and circuit breaker before public traffic.

## Architecture decisions to record

ADR-001: local-first modular client, not a cloud-dependent race loop.
ADR-002: asynchronous non-colliding ghosts for ranked competition; no live multiplayer v1.
ADR-003: track/rules/physics versions are part of record identity.
ADR-004: server-verifiable earned economy with idempotent ledger.
ADR-005: purchase only creator capacity/cosmetics; no paid power or XP.
ADR-006: moderation, deletion and bounded hosted-retention commitments precede public UGC commerce.
ADR-007: exact simulation strategy selected at the cross-device replay gate.

These are proposed decisions requiring owner acceptance, except where they enforce confirmed requirements.


## Visual architecture revision
The normative camera/presentation handoff is `Rendering_and_camera.md`. Use a high-oblique overhead following Camera3D, selective cel shading and 1.15x scene framing relative to the selected screenshot. HUD zoom is independent. Menu-board chase views are not gameplay references. The canonical backend, verification, economy and API boundaries above are retained.
