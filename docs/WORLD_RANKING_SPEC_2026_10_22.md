# World Ranking specification

Design for implementation, 22 October 2026. This defines new official results from a declared launch week; it does not change existing race results or deploy a ranking service.

Beat my track World Ranking measures repeated performance in one shared worldwide Weekly Circuit. Every participant races the same five tracks with the same car and pinned competitive rules. Their worldwide weekly position earns one ranking result. The best **12 results from the last 26 completed weeks** determine their world position.

Weekly Rivalry remains the personal competition against a small field of suitable opponents. Its existing track points, local championship and rewards remain separate from worldwide classification. Hidden skill estimates determine opponents; World Ranking points come from worldwide results.

| Decision | Launch rule |
| --- | --- |
| Official competition | Shared Weekly Circuit inside the existing public Compact Weekly Rivalry |
| Car | Compact for the initial ranking version; common performance configuration, personal cosmetics allowed |
| Tracks | Five immutable versions, shared across every official group |
| Race distance | Existing five laps per track |
| Weekly qualification | A verified weekly best on all five tracks |
| Weekly results | At most one award per account and UTC week |
| Scoring | Equal weight for worldwide track placements, followed by a worldwide finishing-place award |
| Maximum weekly award | 1,000 points |
| World total | Best 12 weekly awards from 26 completed weeks; maximum 12,000 |
| Season | 13 consecutive UTC weeks, best six awards; maximum 6,000 |
| Publication | After Monday rollover and settlement of eligible submissions |
| Resumes in the official Circuit | Three free confirmed resumes per attempt, ten-second rewind, no banked credit consumption |

## Competition and eligibility

A Circuit week starts Monday at 00:00 UTC and ends at the next Monday at 00:00 UTC, with an exclusive ending timestamp. Every official group references the same Circuit week, car/configuration, physics/rules contract and ordered five-slot lineup. Prepare future weeks through the existing four-week Studio planner; create and lock the Circuit record before opening, even if nobody has joined, and announce the official lineup to players at the common opening time. Reuse the existing eligibility and variety/repetition preferences when selecting tracks. Use trusted first-party tracks for launch.

The initial version uses Compact. Every player can enter with the common performance configuration. Other selected-car Rivalries continue to work and award their existing local results. Opening the Compact Circuit must make its car explicit and preserve the player's Garage selection on return. Additional worldwide car classes or car rotation require a later policy version and separate balance review; preferred-car results are not merged into this ladder.

An official result requires a production-eligible registered account, the existing username requirements, the public competition scope, and five verified PBs tied to tickets from that Circuit week. Use the server's artificial-player flag and competition scope; authentication provider alone does not classify a player as artificial. Artificial accounts and development competition populations cannot affect public Circuit placement, field size, awards or career statistics.

Each account has one Circuit entry per week and one best run per slot. First and faster verified finishes update that slot; slower/equal retries preserve it. Starts, retries, duplicate receipts and client upgrades cannot create additional entries or awards. Free Race PBs, historical PBs and private/friend challenges do not substitute for a weekly Circuit result.

Incomplete weeks remain visible in Rivalry and track results. Complete all five tracks to enter worldwide weekly classification. Unlimited free racing and retries remain available. Ranking points are not awarded per attempt.

## Worldwide weekly classification

Let **N** be the number of eligible accounts with all five verified Circuit finishes. Construct all five track standings from that same final population. A driver who has not completed the Circuit is absent from these standings; ordinary track leaderboards remain separate.

For each track, lower elapsed canonical ticks finish ahead. Equal ticks share the average of the occupied places. For example, two tied fastest drivers each contribute place 1.5, and the next driver contributes place 3.

Add the five track places; the lowest sum wins the Circuit. Every track has equal weight. A longer track does not receive additional weight merely because its race takes longer, and an exceptional time on one track has a bounded effect on the five-track total.

Resolve a tied sum by comparing each driver's track places sorted from best to worst: compare the best place, then second best, continuing through all five. Lower is better. Equal complete sporting records share the weekly position, using competition ranks such as 1, 1, 3. Accounts, submission timestamps and number of attempts never decide a sporting tie.

Use exact integer arithmetic. Store twice each average track place:

```text
track_place2 = 2 * first_occupied_place + number_tied - 1
circuit_sum2 = sum(track_place2 for the five slots)
weekly_sort_key = (circuit_sum2, sorted(track_place2))
```

Worldwide weekly position is one plus the number of strictly better weekly sort keys. PostgreSQL can calculate the five track ranks using window functions over the frozen eligible population, then rank the combined integer keys. An account ID may stabilize page serialization after the sporting key; it must not change the published sporting position.

## Weekly ranking points

The worldwide finishing place determines the award, with a declared reduction for very small global fields. Rivalry group, hidden skill and local division have no multiplier.

For a field of at least 128 complete finishers:

| Worldwide weekly place | Points |
| ---: | ---: |
| 1 | 1,000 |
| 2 | 850 |
| 3 | 775 |
| 4 | 750 |
| 10 | 728 |
| 50 | 620 |
| 100 | 535 |
| 500 | 307 |
| 1,000 | 226 |
| 5,000 | 105 |
| 10,000 | 74 |
| 100,000 | 23 |
| 1,000,000 | 7 |

The complete formula is authoritative; the table illustrates it. Ranking points are sporting scores that cannot be purchased, transferred or spent. Let `r` be the shared worldwide weekly position and `f = min(N - 1, 127)`.

```text
if N < 2:
    points = 0
elif r <= 3:
    points = max(1, ([1000, 850, 775][r - 1] * f) // 127)
else:
    points = max(1, isqrt((56_250_000 * f * f) // ((r + 96) * 127 * 127)))
```

`isqrt` is the floor of the integer square root. All awards are whole points. For places four onward, this is a smooth inverse-square-root curve with an explicit podium premium. The scale approaches full awards as the global field grows to 128; a solo entry earns zero. Exact tied weekly positions receive the same points.

Once the field reaches 128, adding slower finishers behind an existing driver cannot increase that driver's award merely by enlarging the denominator. The full-field schedule also gives the same award for the same worldwide finishing place at different population sizes. A fixed percentile will naturally correspond to a larger absolute place as the world field grows.

Small-field scaling rewards growth below 128. It is not proof that accounts represent distinct humans and is not a substitute for the existing verification, identity and moderation systems.

Competitive results outweigh mere weekly attendance: twelve finishes at worldwide place 100,000 produce 276 points, while one worldwide victory earns 1,000 in a full field. Extra runs within either week cannot add a second award.

## Rolling World Ranking

At publication for completed week **W**, eligible awards belong to weeks **W minus 25 through W**, inclusive. A result from week R leaves the window when publishing week R plus 26. Age follows UTC competition weeks, including void weeks, rather than login time or job execution time.

Select the best 12 awards for each player. Select equal-point results by better worldwide weekly position, then more recent week solely to choose a stable counting set. Add their points. A first positive result establishes a World Ranking; accounts without points display Unranked.

Resolve equal world totals in this order:

1. Compare counting weekly point awards from highest to lowest.
2. Compare counting worldwide weekly positions from best to worst.
3. Share the world position if the complete sporting records remain equal.

A shorter counting list is padded with zeros for point comparisons and missing positions for placing comparisons. Extra noncounting weeks, attempt totals, spending, account age and country have no tie-breaking role. Two drivers with equivalent worldwide winning records can legitimately share World No. 1. This differs from unrelated local champions independently reaching an identical ceiling.

Results keep their earned value until they expire. There is no additional inactivity penalty or skill-based adjustment to earned points. Best 12 provides room for missed and unfinished weeks; it also means a strong existing total can remain unchanged during a break. World Ranking measures results over the published window, while hidden skill and current Rivalry describe present competition.

For the weekly result screen calculate three distinct values:

```text
earned = this week's award
expiry_effect = total_after_expiry_before_new_award - previous_total
new_result_effect = final_total - total_after_expiry_before_new_award
net_change = expiry_effect + new_result_effect
```

A 195-point award replacing a counting 60-point result adds 135 to the total. An expiring 80-point result with a 60-point reserve puts 20 points at risk. Calculate next week's points at risk using reserve results, assuming no new award. World position can fall while total points rise.

## Seasons and career records

The first season begins with the declared launch Monday. Each season lasts 13 complete UTC competition weeks. Count each player's best six official awards from that season, with the same result and world-position countback rules. The worldwide winner at the final published season snapshot is season champion; equal sporting records produce joint champions.

A new season clears the season race and preserves the rolling World Ranking. Season points and trophies have no additional world-point value. Additional tournaments, World Cups and finals do not add awards to this first version.

Keep permanent legitimate career records for highest world position, qualifying weeks in the Top 100 and at World No. 1, Circuit victories and season titles. Preserve the participant count and date beside a highest-position record so early community results retain their context. The original local Rivalry win/podium statistics remain separate and are not awarded twice.

Prestige milestone badges and Top 100/No. 1 week counters begin on published weeks with at least **1,000 complete Circuit finishers**. Public positions and points remain available in smaller fields. Award a global season title only if at least six weeks in that season meet that threshold; otherwise retain the season standings without a global-champion trophy. These launch thresholds are explicit product balance choices, not estimates of human activity from the simulations.

Ordinary rank loss, expiry and inactivity never remove a legitimately earned career record. An audited disqualification or invalid-result correction can rebuild the affected record; permanent does not mean retaining an award whose sporting source was invalid.

## Fair competitive access and matchmaking

Official Circuit attempts use the same car/performance configuration and **three free confirmed resumes per race**, with the existing ten-second rewind window. Every new legitimate attempt has that allowance. Official attempts do not consume banked/purchased resumes or daily free balances and do not offer ad or purchase gates for additional resumes. Personal cosmetics remain permitted.

This is an explicit proposed change from the existing policy that lets purchased resumes contribute to verified competitive results. Implement it as a purpose-bound server receipt policy for Circuit tickets; retain the existing purchase and resume promises in other racing. Do not invalidate historical races or silently apply the new policy to an already-open week.

Keep the existing skill-based Rivalry matching for launch. Worldwide scoring is invariant to which eligible group contains a player, so deliberately seeking a weaker group cannot improve world points for an unchanged set of Circuit times. A future rating algorithm can improve local matching independently; an OpenSkill dependency is unnecessary for the ranking launch.

Repeated practice can improve actual times. More starts or replay submissions never directly mint additional ranking results. The scoring design does not claim to eliminate the benefit of practice or strengthen the currently approved trajectory verifier.

## Weekly settlement and corrections

Use existing server acceptance and ticket-expiry boundaries. A new submission must be accepted by the server before the week's exclusive deadline; a valid accepted receipt can be retried idempotently after the deadline. Verification may complete later. Client clocks, an offline save and a pending unaccepted upload do not establish timely admission.

The durable weekly state machine is `open -> settling -> finalized -> published`. After closure, wait for all eligible accepted submissions to become terminal through the existing bounded worker lease/retry rules. New-week racing proceeds while the prior week settles. Show the previous published ranking and its date until the complete replacement is ready; normal race/Rivalry results do not wait for worldwide publication.

Freeze the eligible PB inputs, compute weekly placings/awards, build all world/country/season entries and career deltas in a new generation, then atomically switch the published pointer. Career deltas and awards stay behind that same publication boundary. Batch work is restartable, fenced and idempotent. A failed worker must neither duplicate an award nor publish a partial ladder. Alert on an overdue generation; do not discard accepted results simply to meet a display deadline.

Pin the Circuit contract for the complete week. Schedule incompatible physics/rules changes between weeks and retain the matching verification contract for accepted old jobs. Ordinary content updates may not replace an opened Circuit slot. A critical contract failure or unavailable official track that prevents a fair five-track event requires an owner-audited whole-week void, with no Circuit awards. Existing local results and player files remain; world expiry still advances by calendar week.

Corrections create a new revision with the original inputs, changed eligibility/results, reason, actor/command and superseded generation recorded. Recompute that Circuit's placings and awards, then rebuild affected world/season snapshots and source-based career facts. An ordinary account rename or deletion is handled by the established identity/privacy policy and does not automatically disqualify an otherwise valid sporting result. Preserve only the historical facts permitted by that policy; redact identifiers consistently.

## Player experience

Provide World, Country and Friends views of the same published world-point system. Show the player's position, movement, counting total and the snapshot date. Country membership is captured for the weekly snapshot; country changes appear in the next ranking publication. Friends uses the existing accepted, bounded, unblocked roster plus the player, evaluated against the same snapshot. Relationship changes affect the friend view rather than earned world points.

Offer a bounded breakdown of all results still inside the 26-week window, marking counting results, reserves, dates, worldwide places and earned awards. Show actual expiry risk. Preserve account/navigation/visibility fences for every asynchronous response.

Inside Compact Weekly Rivalry, show five-track completion toward Circuit qualification. Retain the existing immediate provisional track-time feedback, live local standings, local ghosts and normal race summary first. In the first version, worldwide weekly positions and awards publish after settlement; do not recalculate a worldwide ladder on every PB or show a fabricated projected award.

The completed-week ceremony shows local Rivalry finish, worldwide Circuit finish, points earned, effect on the counting total, new World Ranking and movement. If the local group is settled while worldwide publication is pending, show the local result with World Ranking updating; Share/Continue and next-week enrollment retain their existing behavior.

Profiles add the published world position, contextual highest position, eligible career counters and season titles. Reuse the achievement system for legitimate milestones. World rank search/pages and profile reads must respect current redaction/blocking rules without changing sporting positions as a side effect of a player's private block list.

## Server data and computation

Extend the existing API/database/worker architecture. The following are logical records; allocate migration identifiers at implementation time against the then-current migration graph.

| Record | Required facts and constraints |
| --- | --- |
| CircuitWeek | Unique UTC week; car/contract/policy versions; ordered track IDs and lineup hash; state; input cutoff; revision |
| CircuitBest | Unique `(circuit_week, player, slot)`; verified run/ticket identity; canonical ticks; best-only idempotent update |
| CircuitResult | Unique active `(circuit_week, player)` revision; five ticks/source references; five `track_place2` values; sum/countback; weekly place; frozen field size; integer award; eligibility/correction provenance |
| RankingSnapshot | Week/revision/policy set, prior generation, counts, state, publication time and immutable identity |
| RankingEntry | Unique `(snapshot, player)`; total, world/country rank, prior world rank, counting result IDs and countback keys |
| RankingCareer | Compact aggregate facts with unique source week/milestone identities; rebuildable after corrections |
| SeasonResult | Fixed season interval; best-six total/countback; final snapshot and qualifying-week count |

Extract only official weekly PBs and accepted receipts. No extra physics simulation or trajectory verification is needed to compute ranks. Store scalar result evidence and references; follow existing recording/blob retention rather than retaining every replay indefinitely.

Index Circuit bests by week/player/slot and week/slot/ticks, awards by player/week, entries by snapshot/world rank/player and snapshot/country/country rank/player, and due jobs by state/due time. Read a player's window in one bounded query; use exact tuple ordering to select counting results. Do not reproduce the experiment's floating selection shortcut in shipping code.

The weekly work consists of five worldwide track sorts, one Circuit sort, bounded 26-result selections, and world/country/season sorts. It requires no all-player pairwise skill comparisons. Use bounded database batches and a fair worker budget so ranking progresses under traffic while foreground race/publication verification retains service capacity. Never keep one transaction open across the entire population or perform this job inside a player HTTP request.

Serve stored published positions. Default leaderboard pages contain 50 rows; an around-player response contains at most nine. Cursor and ETag values bind to an immutable generation. Friends ranking is calculated over the existing bounded roster, avoiding per-friend stored ladders. A breakdown returns at most 26 weekly results. The client does no authoritative scoring or global sorting.

Keep current/previous hot generations and the recent rank history required by the UI. Compact career facts preserve lifetime milestones; archive older weekly facts under the existing account/privacy retention policy. Permanent weekly evidence continues to grow: a steady N participants produces approximately `52 * N` award records per year, independently of the 26-week scoring window. Plan indexes, archive/restore and corrections accordingly.

Representative PostgreSQL tests must measure weekly completion, API read latency, database/temporary-sort memory, row/index growth, concurrent PB writes and worker interruption. The desktop numerical experiment is not a server capacity or cost benchmark. A dedicated ranking service is not part of the initial architecture; change capacity only after those measurements.

## Implementation and acceptance

| Requirement | Acceptance before launch |
| --- | --- |
| WRF01 | All official groups use one pinned Circuit; exactly one account/week entry and award; other cars/Free Race/test populations cannot enter it |
| WRF02 | Golden fixtures cover exact ticks, average occupied track places, five-track sums, countback, shared sporting ties and row-order invariance |
| WRF03 | Exact integer award fixtures cover every podium transition, 1/2/127/128-person fields and million-place tails; slower-field padding leaves full-field awards unchanged |
| WRF04 | Best 12/26, reserves, expiry, skipped weeks, first entry, best 6/13 seasons, legitimate ties and net-change arithmetic match the contract |
| WRF05 | Circuit tickets grant only the identical free three-resume policy; existing non-Circuit credits and promises remain intact |
| WRF06 | PostgreSQL concurrency/restart/correction tests prove single awards and atomic snapshots; delayed verification and navigation/account changes remain safe |
| WRF07 | Country/friends/redaction, performance reads, source-based career records, ceremony/Continue and mobile layouts retain their established behavior |
| WRF08 | Shadow publication and real-population calibration confirm the distribution and operational budgets before public points are enabled |

Implement in reviewable slices: the authoritative Circuit/award ledger and settlement first; ranking snapshots and reads second; the client/achievements third; then shadow operation and an explicitly authorized rollout. Keep published history empty until the declared launch. Historical Rivalries are not backfilled because they did not share these eligibility and resume conditions.

The remaining validation concerns are real participation/track specialization, multi-car expansion, actual database/network/worker capacity, and owner/device acceptance. The spec proposes the new official resume policy for review; no live competitive or purchased-resource policy has been changed.

## Simulation evidence

The [refinement report](evidence/world-ranking-refined-2026-10-22/report.html) records the candidate screening, subsequent iterations, selected-rule runs, assumptions, raw results and actual commands. The [first simulation](evidence/world-ranking-simulation-2026-10-22/report.html) establishes why local-tier awards required redesign.

The experiment uses synthetic skill, attendance and track preferences rather than calibrated player data. Relative-time generation naturally favors a geometric-time method in a latent-skill comparison, so the decision also considers duration invariance, bounded single-track influence, population padding, podium incentives and implementation clarity. Correlation is an evaluation aid, not the definition of sporting merit. Exact equivalent worldwide winning records are allowed to tie.

Across the iterations, 55 scenario-and-seed runs of 78 weeks evaluated 217 candidate/world combinations. Seeds are reused between scenarios for controlled comparison; this is not a set of 55 independent statistical samples. In the controlled 100,000-account baseline-curve comparison, similar-skill casual players retained 94.4% of regular players' median points with best 12, versus 86.5% with best 16. The final podium curve retained 94.4%. The cohorts attended 65% and 95% of weeks respectively, before individual track completion; these percentages are synthetic model inputs.

| Final selected normal case | Seeds | Final skill and rank correlation | Final joint leaders | Expert newcomer to top 1 percent |
| --- | ---: | ---: | ---: | --- |
| 10,000 accounts | 3 | 0.916 mean | 1 in each seed | 13–14 weeks |
| 100,000 accounts | 3 | 0.921 mean | 1 in each seed | 8–12 weeks |
| 1,000,000 accounts | 1 | 0.924 | 1 | 6 weeks |

These are final-week model observations, not population forecasts. The top-one-percent target corresponds to different absolute positions as populations grow. Final leaders were among the four strongest introduced, nonretired modeled drivers; world Top 25 overlap with latent-skill Top 25 was 76–84%. Some heavy-tail/correlated-completion stress seeds legitimately shared No. 1. The sparse-participation stress had weak skill correlation, illustrating the limits of a ranking with few repeated competitive results.

The chosen five-track rule and best-12 window balance a complete circuit with flexibility between weeks. Four-track qualification was tested; missing a discipline is retained as an unfinished week in the launch contract. No game/backend code, live account/queue data, deployment or phone/device state is changed by this design task.
