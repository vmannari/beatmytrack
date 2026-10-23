# Challenge Club — 2026-10-16

The owner requests better presentation, easier challenge discovery without entering codes, stronger motivation and rewards. This local rework makes Discover the entry view and keeps concrete reward goals beside Join & race.

## Delivered experience

- Discover shows actual public, active challenges with room to join and compatible pinned contracts. Search by track/driver, filter by car/type, and sort by ending soon or newest. Friends uses accepted mutual friends' public challenges. Joined and Created retain personal competitions/history.
- Scenic cards show actual outlines, times, creators, deadlines and available Coins. Detail includes a larger route/time preview, driver count, personal best/gap and scrollable standings. Reward goals, rules and race action stay visible together. Controls retain 52 logical pixel touch targets.
- Join & race uses existing membership and ticket authority directly. Guests can browse and try; earning/spending Coins requires a registered account. Manual code entry has no menu action. Invitation links/native sharing remain.
- Creation places Public / Private immediately after the track and repeats it in the preview. Public lists in Discover and requires existing public-sharing consent. Private uses an invitation link. Existing challenges stay private. Public creation returns to the challenge; private creation retains sharing.
- Preserve exact completed-result sources, best-only scoring, optional tries, pinned track/car/setup, actual ghosts, normal race results first and explicit rematches. Challenge results also show reward progress.

## Coin rules

The economy already contained 50/100 challenge milestones. This rework exposes them and tightens their meaning:

| Goal | Coins | Grant |
| --- | ---: | --- |
| Finish five laps | 50 | First verified, counted challenge race |
| Beat the target | 100 | Strictly faster than the pinned duel target |
| Outrun a rival and lead | 100 | Strictly faster than every other timed group driver, with at least one actual verified rival time |

Finish and competitive bonuses each pay once per challenge. Empty groups and ties do not mint the competitive bonus. Creating a duel does not promise its creator an opponent's rewards.

Up to three previously unrewarded challenge finishes can start paying challenge bonuses per account per UTC submission day. Normal race rewards and scores still count afterward. An already rewarded challenge can pay its outstanding competitive bonus later without consuming another daily slot. An unrewarded challenge can be raced on a later day for its first reward. This is a limit on new reward challenges, not an unconditional 450-Coin daily ceiling.

Verification credits the existing wallet and durable receipt atomically under the account lock. Replayed work cannot credit twice. No manual claim, guest balance import, new currency or unverified local grant. Amounts and the three-challenge limit remain balance choices for owner review.

## Contracts and bounds

Migration `0041_challenge_discovery` adds only `Challenge.visibility` and a discovery index. Its default is `private`, including existing rows. It follows concurrently added `0040_studio_platform`; no live migration/deployment ran.

`challenge_discovery_version: 1` advertises support. Older services retain Joined/Created and opened invitations, with an actionable discovery message; creation omits unsupported metadata.

Discovery filters published availability, hidden/archived tracks, disabled/artificial creators, mutual blocks, blocked participants, membership, capacity, deadline and pinned build/handling fields before paging. Friends never reveals private challenges. Keyset cursors bind identity, folder and every filter. Guests use a separate public read route.

Public pages contain at most 20 challenges; personal pages retain 50. The client retains at most 100 rows, deduplicates pagination and draws card outlines with at most 96 points, preserving both endpoints. Existing detail/source contracts remain. Browsing downloads no tracks, creates no rendering worlds/worker jobs and adds no polling beyond the existing visible-page refresh.

## Actual validation

[Evidence report, commands, source hashes and scoped patch](evidence/challenge-rework-2026-10-16/report.json).

| Check | Actual result |
| --- | --- |
| SQLite/PostgreSQL discovery, original challenge and Coin contracts | 92 passed, 3 existing fixture skips |
| Final discovery including archive/participant-block guards and UTC reset | 14 passed |
| Focused UTC reset follow-up | 2 passed |
| Real native HTTP flows with actual canonical/trajectory verification | 2 passed; 49 and 50 client checks |
| Final challenge UI at 1280×720, 960×540, 1600×720 | 68 headless, 80 Compatibility, 80 Mobile; zero failures |
| Original Challenge tab / adapter and app | 60 / 165 checks passed |
| Retained menu/folder behavior / source request priority | 47 / 27 checks passed |
| Frozen project parser | 831 scripts, zero failures |
| Changed Python lint and schema JSON | Passed |

Native HTTP covers browsing without a code, two isolated identities, source racing, joining, five-lap racing, the creator ghost, earned rewards, result order, retry, rematch and groups. Native UI captures include discovery, pinned rewards, verified progress and creation.

Final UI validation uses `build/challenge-rework/frozen-game`: an isolated source copy/cache with the existing asset directory and recorded hashes. Challenge source files match the working project. Concurrent class changes and a temporarily missing News helper invalidated earlier root-project attempts; logs retain them. Final frozen runs have no script errors. Thread teardown warnings remain in native fixture logs; no measured phone lifecycle/performance claim is made.

Retained initial corrections: authenticated list handling plus a separate guest route; unjoined fixtures corrected to leave a seat; asynchronous assertions await their request; test consent includes authentication; concurrent migration head reconciled; unavailable discovery preserves opened invitations; creation-summary encoding fixed after native inspection. An initial PATH invocation used Godot 4.6.2; final runs use pinned 4.7.2, workspace test data and normal certificate-store access. A zero-exit script-error attempt was rejected by inspecting logs and repeated successfully.

## Acceptance and rollout

Owner visual/balance and physical-phone touch/performance acceptance remain. Public discovery begins with future deliberately public challenges; existing invitations were not published and no live population was fabricated. Matching API/worker/schema rollout and a new phone build remain. No phone attachment/input automation, APK export/install, backend deployment, notifications, FPS measurement or production data mutation was performed.
