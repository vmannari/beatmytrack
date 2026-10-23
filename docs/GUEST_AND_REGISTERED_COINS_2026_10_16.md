# Guest and registered-player Coins — 2026-10-16

The owner's follow-up removes all guest earnings and adds the clean-race bonus for registered players. This supersedes the guest-grant and withheld account-clean-bonus behavior in the original earned-coin report. Persistent account wallets and permanent livery/kit purchases remain as implemented there.

Guests have zero available Coins, cannot purchase locked cosmetics and see “Sign in to earn coins.” The app no longer calls or exposes a guest grant function. Completed guest races still save PBs/history normally, including retries, reloads and failed-save rollback. Historical guest balance data is retained without grants, debits or account import; previously available local cosmetics remain usable. The existing priced confirmation opens sign-in for guests.

Registered players receive the fixed **200-Coin Clean race** bonus alongside the other accepted-run rewards. The completed five-lap recording includes a small incident summary from existing collision/off-track telemetry. Its tick duration must match the accepted trajectory, with zero collisions and no off-track events. Missing, dirty, malformed or mismatched summaries earn no clean bonus and do not change otherwise valid score acceptance. The worker grants the fixed server amount in the existing verification/PB transaction; its run receipt prevents duplicate credits through retries or finalization recovery.

The incident summary follows the existing lightweight recorded-evidence policy. It is client-recorded evidence, **not independent server collision resimulation**, and does not make modified-client clean claims tamper-proof. Clients cannot choose the amount. This change does not add full physics replay or alter trajectory timing, gate acceptance, handling or canonical contracts.

Bootstrap advertises `race_incident_rewards_version: 1`. The client sends the optional `bmt-race-incidents-v1` summary only to supporting servers, preserving original samples for older servers. Durable completed-upload payloads retain the incident report inside their existing replay hash. Older stored recordings without the summary retain their ordinary rewards and earn no new clean bonus. This does not retroactively re-credit accepted races.

## Actual checks

| Check | Result |
| --- | --- |
| Account rewards/purchases, SQLite and disposable PostgreSQL | 20 passed, 1 SQLite concurrency fixture skip |
| Coin suite plus lightweight protocol checks, without engine/PG cases | 19 passed, 1 skipped, 10 deselected |
| Client persistence, recovery, account fences, incident capture/transport and actual Garage/Results controls | 56 headless; 65 Compatibility; 65 Mobile — zero failures |
| Actual app results/Continue/retry/PB reload/failed save | 11 passed |
| Whole-project parser after import/class refresh | 818 scripts, zero failures |
| Ruff on changed backend code/tests | Passed |
| Follow-up patch reverse check | Passed |

Native desktop captures show a registered Clean race +200 receipt, permanent livery/kit purchases, insufficient funds, guest sign-in and guest zero rewards. They use the actual native Garage and results controls with isolated account fixtures. Backend API tests use the existing deterministic verifier fixture; a separate test exercises the production trajectory checker with synthetic five-lap gates and incident variants. App sessions are synthetic completed sessions. These are not physical driving or phone tests.

The first PostgreSQL attempts timed out because the documented disposable `bmt-backend-test` container was stopped. It was started for the final passing run and stopped afterward. Initial whole-project scans encountered concurrent News edits and newly introduced Night prop global classes; the current News source and an editor import resolved those dependencies before the final passing scan. The first Ruff check found an import formatting issue in the currency worker hook; it is corrected. Restricted Godot launches retain their certificate-store warning; focused checks completed normally.

All commands, logs, initial failures, captures, hashes and a follow-up patch are in [the evidence report](evidence/guest-no-coins-2026-10-16/report.json). The patch retains concurrent News layout changes. The original report and patch remain historical evidence. Its broader baseline/fixture/engine failures were not rerun or declared resolved by this follow-up.

Account currency still requires the matching client/API/worker release and migration 0037 (plus any other release migrations). No live backend migration/deployment, phone attachment check, physical-phone test, APK build/install, or phone performance claim was made. Price balancing and owner/device acceptance remain.
