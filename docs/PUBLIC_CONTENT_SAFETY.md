# Public-content safety — 16 October 2026

Public tracks now have working in-game reporting, private player blocking and explicit publication-rules acceptance. This implements the requested application controls against the [Google Play UGC policy](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en), checked on 16 October 2026. The policy also requires effective ongoing moderation; shipping controls alone does not establish that reports are being reviewed.

## Responsible operator

**The Beat my track owner who holds the Backend Studio `owner` credential is the accountable moderation owner.** This is the default operating assignment for this implementation. Analysts can investigate; only the owner can make the existing content-visibility and account-restriction decisions. The Studio case queue and public rules identify this role. No external moderation service, email delivery or individual staff SSO is implied.

The owner must operate this queue whenever public sharing is available:

1. Review Backend Studio → Cases (`/admin/#cases`) every day, including Open, Investigating and Appealed cases. Prioritize child safety, credible threats, personal information and repeated abuse. Arrange another responsible owner operator before being unavailable; do not leave public sharing operating without report coverage.
2. Inspect the **reporter**, **reported player**, exact version ID and evidence separately. A report is an allegation, not an automatic finding. Player names do not establish identity or ownership.
3. Move the case to Investigating. Use the case-linked Quarantine action to hide an offending track across its versions. Quarantine now denies its public metadata/document links and fresh race tickets as well as discovery. Previously issued/idempotent results stay pinned.
4. For serious or repeated player abuse, open **Reported player**, apply the existing audited account restriction, and reference the case in the recorded reason. Account restriction also removes that player's tracks from public discovery and denies their active credentials. Paid publishing slots do not exempt content from these rules.
5. Record the evidence and reason; then resolve the case. A resolved report can be appealed from the game. Recheck Appealed cases and record the follow-up decision. Restoration remains revision-fenced and cannot undo intervening moderation.

Daily review is an operating responsibility, not an automated scheduler or a claimed response-time guarantee. Before public release, the owner must ensure the owner credential is configured and that a real person is covering the queue. Nothing in this task deploys a service or assigns an uncontacted third party to review reports.

## Player flows

- **Report track:** Free Race track detail → Report / block → Report track, or the active public race's pause menu → Report track. Choose a reason and enter 1–2000 characters. A successful response includes the case reference. Categories include harassment, hate, sexual content, child safety, violence, private information, spam/impersonation, illegal content and other track issues.
- **Report / block player:** track creator, a high-score name, a Rivalry hub/podium name, or a challenge creator. Player reports retain the selected track/version as context when available, while the case explicitly separates the reported account from the reporter.
- **Community safety:** Settings → Privacy. Read rules, manage blocked players, retry saved reports/blocks, inspect the latest 50 submitted reports and appeal resolved reports. Guests receive sign-in guidance. Staff notes and other players' reports are never returned through these endpoints.
- **Publish:** fetch the current rules, show the complete scrollable text and an unchecked acceptance box, then record the exact displayed version on the authenticated account. Cancel leaves the draft local. The server rejects missing/outdated acceptance before new publication upload, legacy synchronous/deferred authoring upload, or legacy publish. Existing acknowledged publication receipts remain recoverable. Local drafting and local creator tests retain their original offline behavior.

Rules version `bmt-community-2026-10-16` prohibits objectionable content in track designs, names and other public game features; it describes reporting, blocking, moderation, rights and retained downloaded copies. `/community-rules` provides the public text, linked from the privacy pages. A changed rules version requires fresh acceptance; a reinstall or another device can read the existing account acceptance.

## Blocking and recovery

Blocks are private to an account and backend origin. They filter both discovery systems and random selection, direct authenticated track downloads and fresh race starts. New challenge joins/tickets check blocks in both directions against every participant; blocked hosts/track creators are also unavailable in authenticated invitation views. Blocking preserves historical membership, verified ranks, points and pinned evidence. The game masks blocked names, flags and podium cosmetics and marks blocked creators' Rivalry tracks unavailable. Cached Free Race tracks, favorites, retained metadata and offline launch paths also check the block list.

An offline block hides the player locally immediately and remains pending until synchronized. Unblocking restores content after the server acknowledges it. The account list is capped at 1000 players. Up to 20 pending reports retain their exact UUID command and payload on the device before transmission; uncertain replies and restarts reuse that command, avoiding duplicate cases. The UI distinguishes local recovery from a submitted report. Sign-in, origin changes and late replies are fenced. Settings provides an explicit Retry sync action.

Migration `0036_community_safety` adds `community_acceptances`, `player_blocks` and a nullable reported-player reference on existing cases. Existing cases and events are preserved. Account deletion erases acceptance, blocks and the account's local safety-recovery files using the established deletion flow. Existing report-text erasure and historical moderation skeletons remain in place. Updated privacy copy describes this processing.

Reported-player profiles include these cases and their unresolved counts alongside cases they filed themselves. Quarantined or blocked authors' pinned Rivalry track names and preview points are withdrawn without changing board, membership or score pins. Creators can report a problem with their own public content; self-blocking and standalone self-profile reports are rejected.

## Verification and rollout

The tests use disposable databases, loopback services and fictional accounts; they do not contact a production API. The focused backend suite exercises fresh/repeated/version-changed acceptance, pre-storage rejection including deferred uploads, private blocks, snapshot invalidation, direct links, tickets, group participants, exact report targets/retries, owner-only quarantine and account deletion. Native tests exercise actual HTTP contracts, offline recovery, account fences and the menu sheets.

Results and native captures are retained under `docs/evidence/community-safety-2026-10-16/` and the adjacent `community-safety-*.xml`/logs. The final evidence report records commands, counts, initial failures and limitations. The first native HTTP run caught an overly short text validator for the complete rules; it was corrected. UI tests also caught and corrected sibling-modal stacking and an unattached guest status label. The real publication test exposed an existing journal-to-wire `tick_rate: 120.0` mismatch with the server's strict integer contract; delivery now restores the same integral value to an integer, leaving the pinned contract and replay untouched. Its recovery fixture explicitly advances the fictional backoff clock; production cadence stays unchanged. Legacy publisher fixtures explicitly consent; fresh-account safety tests do not pre-consent.

Final checks include 54 backend passes (two SQLite-only concurrency skips), 13 native HTTP checks, 29 native sheet/recovery checks on each desktop renderer, 28 native publication checks, 31 local-publication checks, 27 account/privacy checks and a 806-script parse. The earlier broader backend pass included publication, erasure and discovery paging: 84 passed, four skipped. The new native dialogs were inspected at 960×540 and 1280×800. Restricted desktop runs print a Windows certificate-store access error; the loopback HTTP and rendering checks do not claim TLS verification. Native credential/privacy and publication integration checks were repeated with normal Windows test access and passed.

Release requires migration plus matching API/worker/game delivery and active owner moderation coverage. Only disposable test databases were migrated; no existing service/player database was changed, no backend was deployed, no APK was built or installed, and no physical-phone acceptance is claimed.
