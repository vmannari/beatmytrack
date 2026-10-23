"""Offline ranking design experiment; never imports the backend or contacts a service.

Uses the analysis Python's existing NumPy and (for the report) Plotly installations.
These are not game/backend dependencies. All identities and performances are synthetic.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import platform
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE_HASH = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
TRACK_POINTS = np.array([30, 26, 23, 20, 18, 16, 14, 12, 10, 8, 6, 4, 2, 1, 1, 1, 1, 1, 1, 1])
CAPS = np.array([50.0, 150.0, 300.0, 500.0])
POLICIES = ("proposed", "smooth", "circuit_tiebreak", "pace_anchor")
NAMES = {
    "proposed": "Proposed tiers + position buckets",
    "smooth": "Same tiers + smooth position curve",
    "circuit_tiebreak": "Smooth curve + circuit-performance tiebreak",
    "pace_anchor": "Exploratory: 60% local + 40% circuit pace",
}


@dataclass(frozen=True)
class Config:
    population: int = 10_000
    weeks: int = 78
    seed: int = 20261022
    attendance: float = 1.0
    track_completion: float = 0.97
    band_width: float = 0.25
    matching: str = "deciles"
    thresholds: tuple[float, float, float] = (-0.67448975, 0.0, 0.67448975)
    policies: tuple[str, ...] = POLICIES


def rank_rows(values: np.ndarray, valid: np.ndarray, *, reverse: bool = False) -> np.ndarray:
    """Competition ranks, including exact ties and missing entries, within each row."""
    sortable = -values.astype(np.float64) if reverse else values.astype(np.float64)
    sortable = np.where(valid, sortable, np.inf)
    order = np.argsort(sortable, axis=1, kind="stable")
    ordered = np.take_along_axis(sortable, order, axis=1)
    change = np.ones(ordered.shape, dtype=bool)
    change[:, 1:] = ordered[:, 1:] != ordered[:, :-1]
    positions = np.broadcast_to(np.arange(1, values.shape[1] + 1), values.shape)
    ranked = np.maximum.accumulate(np.where(change, positions, 0), axis=1)
    result = np.empty(values.shape, dtype=np.int16)
    np.put_along_axis(result, order, ranked, axis=1)
    return np.where(valid, result, 0)


def payout_curve(position: np.ndarray, size: np.ndarray, smooth: bool) -> np.ndarray:
    q = np.clip((position - 1) / np.maximum(size - 1, 1), 0, 1)
    if smooth:
        return np.interp(q, [0, 1 / 15, 3 / 15, 7 / 15, 1], [1, .65, .4, .2, .05])
    reference = np.ceil(q * 15 - 1e-10).astype(int) + 1
    return np.select([reference == 1, reference == 2, reference <= 4,
                      reference <= 8], [1.0, .65, .4, .2], default=.05)


def local_awards(scores: np.ndarray, qualified: np.ndarray, caps: np.ndarray,
                 *, smooth: bool) -> tuple[np.ndarray, np.ndarray]:
    """Tenths of a point; tied finishers share the average occupied payout slots.

    At least five complete five-track finishers are required. 5-9 receive n/10
    of the normal award; 10-20 receive the full award. These are trial rules.
    """
    sizes = qualified.sum(axis=1)
    ranks = rank_rows(scores, qualified, reverse=True)
    slots = np.broadcast_to(np.arange(1, scores.shape[1] + 1), scores.shape)
    schedule = payout_curve(slots, sizes[:, None], smooth)
    cumulative = np.concatenate([np.zeros((len(scores), 1)), np.cumsum(schedule, axis=1)], axis=1)
    tied = ((scores[:, :, None] == scores[:, None, :]) & qualified[:, None, :]).sum(axis=2)
    first = np.maximum(ranks - 1, 0)
    last = np.minimum(first + tied, scores.shape[1])
    means = (np.take_along_axis(cumulative, last, axis=1)
             - np.take_along_axis(cumulative, first, axis=1)) / np.maximum(tied, 1)
    field_factor = np.where(sizes >= 5, np.minimum(sizes / 10, 1), 0)
    awards = np.floor(means * caps[:, None] * field_factor[:, None] * 10 + .5)
    return np.where(qualified, awards, 0).astype(np.uint16), ranks


class Rolling:
    def __init__(self, population: int):
        self.history = np.zeros((population, 26), dtype=np.uint16)
        self.quality = None
        self.counting_quality = None

    def add(self, week: int, awards: np.ndarray, quality: np.ndarray | None = None) -> tuple[np.ndarray, np.ndarray]:
        self.history[:, week % 26] = awards
        if quality is None:
            best = np.sort(self.history, axis=1)[:, -16:]
        else:
            if self.quality is None:
                self.quality = np.zeros(self.history.shape, dtype=np.float64)
            self.quality[:, week % 26] = np.where(awards > 0, quality, 0)
            # Quality only breaks equal award values when choosing counting results.
            selection = np.argsort(self.history.astype(np.float64) + .5 * self.quality, axis=1)[:, -16:]
            best = np.take_along_axis(self.history, selection, axis=1)
            self.counting_quality = np.take_along_axis(self.quality, selection, axis=1).sum(axis=1)
        totals = best.sum(axis=1, dtype=np.int32)
        return totals, best

    def season(self, week: int) -> np.ndarray:
        indexes = np.arange((week // 13) * 13, week + 1) % 26
        return np.sort(self.history[:, indexes], axis=1)[:, -8:].sum(axis=1, dtype=np.int32)


def world_ranks(totals: np.ndarray, best: np.ndarray,
                quality: np.ndarray | None = None) -> tuple[np.ndarray, np.ndarray]:
    """Total, then best-result countback; genuinely identical records share rank.

    Order among exact sporting ties is only a serialization order, never a tiebreak.
    """
    quality_keys = [] if quality is None else [quality]
    order = np.lexsort(tuple(quality_keys + [best[:, i] for i in range(best.shape[1])] + [totals]))[::-1]
    ranked_totals = totals[order]
    change = np.ones(len(totals), dtype=bool)
    change[1:] = ((ranked_totals[1:] != ranked_totals[:-1])
                  | np.any(best[order[1:]] != best[order[:-1]], axis=1))
    if quality is not None:
        change[1:] |= quality[order[1:]] != quality[order[:-1]]
    positions = np.maximum.accumulate(np.where(change, np.arange(1, len(totals) + 1), 0))
    ranks = np.zeros(len(totals), dtype=np.int32)
    ranks[order] = np.where(ranked_totals > 0, positions, 0)
    return ranks, order[ranked_totals > 0]


def ordinal(values: np.ndarray) -> np.ndarray:
    order = np.argsort(values, kind="stable")
    sorted_values = values[order]
    _, start, count = np.unique(sorted_values, return_index=True, return_counts=True)
    result = np.empty(len(values), dtype=np.float64)
    result[order] = np.repeat(start + (count - 1) / 2, count)
    return result


def correlation(a: np.ndarray, b: np.ndarray) -> float | None:
    if len(a) < 3 or np.ptp(a) == 0 or np.ptp(b) == 0:
        return None
    return float(np.corrcoef(ordinal(a), ordinal(b))[0, 1])


def make_groups(ids: np.ndarray, ratings: np.ndarray, rng, width: float, matching: str = "narrow") -> np.ndarray:
    """Random assignment inside fixed pace bands; balanced groups, cap 20."""
    if len(ids) == 0:
        return np.empty((0, 20), dtype=np.int32)
    if matching == "deciles":
        # Existing Rivalry uses ten percentile bands; fixed initial normal deciles
        # preserve that shape without consulting synthetic true skill at matching time.
        cutoffs = [-1.28155157, -.84162123, -.52440051, -.25334710, 0,
                   .25334710, .52440051, .84162123, 1.28155157]
        bands = np.searchsorted(cutoffs, ratings[ids]).astype(np.int16)
    else:
        bands = np.floor(ratings[ids] / width).astype(np.int16)
    order = np.lexsort((rng.random(len(ids)), bands))
    sorted_ids = ids[order]
    _, starts, counts = np.unique(bands[order], return_index=True, return_counts=True)
    group_counts = np.maximum(1, np.floor(counts / 16 + .5).astype(int))
    group_counts = np.maximum(group_counts, (counts + 19) // 20)
    offsets = np.r_[0, np.cumsum(group_counts)]
    matrix = np.full((offsets[-1], 20), -1, dtype=np.int32)
    for start, count, groups, offset in zip(starts, counts, group_counts, offsets):
        local = np.arange(count)
        group = local * groups // count
        group_start = (np.arange(groups) * count + groups - 1) // groups
        slot = local - group_start[group]
        matrix[offset + group, slot] = sorted_ids[start:start + count]
    return matrix


def population(config: Config):
    n = config.population
    rng = np.random.default_rng(config.seed)
    skill = rng.normal(0, 1, n)
    style = rng.choice(3, size=n, p=[.55, .30, .15])
    attendance = np.array([.95, .65, .35])[style]
    cohorts = np.array(["regular", "casual", "infrequent"])[style].astype("U24")
    start = np.zeros(n, dtype=np.int16)
    shuffled = rng.permutation(np.arange(10, n - 1))
    size = n // 20
    start[shuffled[:size]] = 26
    start[shuffled[size:2 * size]] = 52
    cohorts[start > 0] = "newcomer"
    retirement = np.zeros(n, dtype=bool)
    retirement[shuffled[2 * size:3 * size]] = True
    hiatus = np.zeros(n, dtype=bool)
    hiatus[shuffled[3 * size:4 * size]] = True
    improvement = np.zeros(n, dtype=bool)
    improvement[shuffled[4 * size:5 * size]] = True
    cohorts[retirement] = "retired_after_39"
    cohorts[hiatus] = "13_week_break"
    cohorts[improvement] = "improving"
    # Fixed illustrative cases; aggregates, not these single players, drive conclusions.
    probes = {
        0: ("world_class_regular", 3.5, .95),
        1: ("elite_stops_after_39", 3.0, 1.0),
        2: ("strong_regular", 2.5, .95),
        3: ("same_skill_casual", 2.5, .65),
        4: ("improver", -.7, .95),
        5: ("declining", 2.3, .95),
        6: ("strong_13_week_break", 2.5, .95),
        7: ("same_skill_infrequent", 2.5, .35),
        n - 1: ("new_expert_week_53", 3.2, .95),
    }
    for pid, (name, ability, chance) in probes.items():
        skill[pid], attendance[pid], cohorts[pid] = ability, chance, name
        start[pid], retirement[pid], hiatus[pid], improvement[pid] = 0, False, False, False
    retirement[1] = True
    hiatus[6] = True
    start[n - 1] = 52
    estimate = skill + rng.normal(0, .35, n)
    estimate[start > 0] = 0
    return rng, skill, attendance, cohorts, start, retirement, hiatus, improvement, probes, estimate


def simulate(config: Config) -> dict:
    began, cpu_began = time.perf_counter(), time.process_time()
    (rng, base_skill, attendance, cohorts, start, retirement, hiatus,
     improvement, probes, estimate) = population(config)
    n = config.population
    affinity = rng.normal(0, .12, (n, 5))
    observations = np.zeros(n, dtype=np.int16)
    last_qualified = np.full(n, -100, dtype=np.int16)
    counts = np.zeros(n, dtype=np.int16)
    rollings = {policy: Rolling(n) for policy in config.policies}
    previous_ranks = {policy: np.zeros(n, dtype=np.int32) for policy in config.policies}
    previous_top = {policy: set() for policy in config.policies}
    weekly, traces, cohort_rows, attendance_rows, final = [], [], [], [], {}
    timing = {"competition_seconds": 0.0, "ranking_seconds": 0.0}
    checkpoints = {12, 25, 38, 51, 64, config.weeks - 1}
    checks = {"weeks": 0, "maximum_group_size": 0, "maximum_weekly_award": 0,
              "maximum_rolling_points": 0, "awards_to_incomplete_players": 0}
    for week in range(config.weeks):
        stage = time.perf_counter()
        true_skill = base_skill + improvement * min(max(week - 13, 0), 39) * .035
        true_skill[4] = -.7 + min(max(week - 26, 0), 26) / 26 * 3.0
        true_skill[5] = 2.3 - min(max(week - 39, 0), 26) / 26 * 3.0
        present = (start <= week) & (rng.random(n) < attendance * config.attendance)
        present &= ~(retirement & (week >= 39))
        present &= ~(hiatus & (week >= 39) & (week < 52))
        ids = np.flatnonzero(present)
        groups = make_groups(ids, estimate, rng, config.band_width, config.matching)
        real = groups >= 0
        safe = np.maximum(groups, 0)
        group_size = real.sum(axis=1)
        pre_skill = np.where(real, estimate[safe], np.nan)
        group_skill = np.nanmedian(pre_skill, axis=1)
        level = np.searchsorted(config.thresholds, group_skill)
        caps = CAPS[level]
        complete = (rng.random((*groups.shape, 5)) < config.track_completion) & real[:, :, None]
        form = rng.normal(0, .14, n)
        observed = (true_skill[safe, None] + form[safe, None] + affinity[safe]
                    + rng.normal(0, .25, (*groups.shape, 5)))
        # Abstract equal-opportunity weekly PBs; elapsed ticks are quantized for real ties.
        ticks = np.rint(10000 * np.exp(-.06 * observed)).astype(np.int32)
        track_ranks = rank_rows(ticks.transpose(0, 2, 1).reshape(-1, 20),
                                complete.transpose(0, 2, 1).reshape(-1, 20))
        track_ranks = track_ranks.reshape(-1, 5, 20).transpose(0, 2, 1)
        track_scores = np.where(complete, TRACK_POINTS[np.maximum(track_ranks - 1, 0)], 0)
        scores = track_scores.sum(axis=2)
        qualified = complete.all(axis=2)
        field_size = qualified.sum(axis=1)
        any_finish = complete.any(axis=2)
        full_ids = groups[qualified]
        last_qualified[full_ids] = week
        counts[full_ids] += 1
        circuit_score = np.zeros(n, dtype=np.float64)
        circuit_pace = (-np.log(ticks.astype(np.float64) / 10000) / .06).mean(axis=2)
        circuit_score[full_ids] = ordinal(circuit_pace[qualified]) / max(len(full_ids) - 1, 1)
        eligible_award = qualified & (field_size[:, None] >= 5)
        timing["competition_seconds"] += time.perf_counter() - stage
        stage = time.perf_counter()
        for policy in config.policies:
            award_matrix, _ = local_awards(scores, qualified, caps, smooth=policy != "proposed")
            if policy == "pace_anchor":
                factor = np.minimum(field_size / 10, 1)[:, None]
                anchor = 5000 * circuit_score[safe] ** 4 * factor
                award_matrix = np.where(eligible_award,
                    np.floor(.60 * award_matrix + .40 * anchor + .5), 0).astype(np.uint16)
            awards = np.zeros(n, dtype=np.uint16)
            awards[groups[real]] = award_matrix[real]
            quality = circuit_score if policy == "circuit_tiebreak" else None
            totals, best = rollings[policy].add(week, awards, quality)
            ranks, order = world_ranks(totals, best, rollings[policy].counting_quality)
            ranked = totals > 0
            ranked_count = int(ranked.sum())
            active = ranked & (last_qualified >= week - 3)
            top = set(order[:100].tolist())
            # Expected fractional overlap avoids arbitrarily choosing tied Top-100 records.
            top_mask = (ranks > 0) & (ranks <= min(100, ranked_count))
            current_skill_pool = np.flatnonzero((start <= week) & (last_qualified >= week - 3))
            skill_top_count = max(1, math.ceil(len(current_skill_pool) * .01))
            skill_threshold = (np.partition(true_skill[current_skill_pool], -skill_top_count)[-skill_top_count]
                               if len(current_skill_pool) else np.inf)
            moved = ranked & (previous_ranks[policy] > 0)
            moves = np.abs(ranks[moved] - previous_ranks[policy][moved]) / max(ranked_count, 1) * 100
            primary_top_ties = int(np.sum(totals == totals[order[0]])) if len(order) else 0
            row = {
                "population": n, "seed": config.seed, "policy": policy, "week": week + 1,
                "joined": len(ids), "qualified": len(full_ids), "ranked": ranked_count,
                "groups": len(groups), "small_fields": int(np.sum(field_size < 10)),
                "no_award_fields": int(np.sum(field_size < 5)),
                "spearman_active_skill": correlation(true_skill[active], -ranks[active]),
                "top100_skill_top1pct_share": float(np.mean(true_skill[top_mask] >= skill_threshold)) if top_mask.any() else None,
                "top100_inactive_4weeks": int(np.sum(top_mask & (last_qualified < week - 3))),
                "top100_retention": len(top & previous_top[policy]) / 100 if week else None,
                "median_weekly_move_pct": float(np.median(moves)) if len(moves) else None,
                "p95_weekly_move_pct": float(np.percentile(moves, 95)) if len(moves) else None,
                "leader_points": float(totals[order[0]] / 10) if len(order) else 0,
                "joint_world_no1": int(np.sum(ranks == 1)),
                "leader_primary_points_ties": primary_top_ties,
                "point_ceiling_players": int(np.sum(totals >= 80000)),
            }
            weekly.append(row)
            season = rollings[policy].season(week)
            for pid, (name, *_rest) in probes.items():
                traces.append({"population": n, "seed": config.seed, "policy": policy, "week": week + 1,
                    "player": name, "true_skill": float(true_skill[pid]), "skill_estimate": float(estimate[pid]),
                    "points": float(totals[pid] / 10), "earned": float(awards[pid] / 10),
                    "rank": int(ranks[pid]), "rank_percentile": float(ranks[pid] / max(ranked_count, 1) * 100) if ranks[pid] else None,
                    "season_points": float(season[pid] / 10), "complete_weeks": int(counts[pid]),
                    "started": bool(start[pid] <= week)})
            if week in checkpoints:
                for name in np.unique(cohorts):
                    mask = (cohorts == name) & active
                    if not mask.any():
                        continue
                    cohort_rows.append({"population": n, "seed": config.seed, "policy": policy,
                        "week": week + 1, "cohort": str(name), "players": int(mask.sum()),
                        "median_points": float(np.median(totals[mask]) / 10),
                        "median_rank_percentile": float(np.median(ranks[mask]) / max(ranked_count, 1) * 100),
                        "median_skill": float(np.median(true_skill[mask]))})
            if week == config.weeks - 1:
                for cohort in ["regular", "casual", "infrequent"]:
                    mask = ((cohorts == cohort) & (true_skill >= 1.0) & (true_skill < 1.5) & ranked)
                    if mask.any():
                        attendance_rows.append({"population": n, "seed": config.seed, "policy": policy,
                            "cohort": cohort, "skill_range": "1.0 <= true skill < 1.5",
                            "players": int(mask.sum()), "median_skill": float(np.median(true_skill[mask])),
                            "median_points": float(np.median(totals[mask]) / 10),
                            "median_rank_percentile": float(np.median(ranks[mask]) / max(ranked_count, 1) * 100),
                            "median_awarded_weeks_last26": float(np.median(np.count_nonzero(rollings[policy].history[mask], axis=1)))})
                # Save only compact anonymous top records, rather than a full synthetic database.
                final[policy] = [{"synthetic_id": int(pid), "rank": int(ranks[pid]),
                    "points": float(totals[pid] / 10), "true_skill": float(true_skill[pid]),
                    "cohort": str(cohorts[pid]), "counting_results": (best[pid, ::-1] / 10).tolist()}
                    for pid in order[:100]]
            checks["maximum_weekly_award"] = max(checks["maximum_weekly_award"], int(awards.max(initial=0)))
            checks["maximum_rolling_points"] = max(checks["maximum_rolling_points"], int(totals.max(initial=0)))
            checks["awards_to_incomplete_players"] += int(np.sum(award_matrix[~qualified] > 0))
            previous_ranks[policy], previous_top[policy] = ranks, top
        timing["ranking_seconds"] += time.perf_counter() - stage
        # A simple shared-pace EWMA, NOT an implementation or validation of OpenSkill.
        observed_mean = np.sum(np.where(complete, observed, 0), axis=2) / np.maximum(complete.sum(axis=2), 1)
        observed_ids = groups[any_finish]
        gain = np.where(observations[observed_ids] < 3, .70, .25)
        estimate[observed_ids] += gain * (observed_mean[any_finish] - estimate[observed_ids])
        observations[observed_ids] += 1
        checks["maximum_group_size"] = max(checks["maximum_group_size"], int(group_size.max(initial=0)))
        checks["weeks"] += 1
        if (week + 1) % 13 == 0:
            print(json.dumps({"progress": {"population": n, "seed": config.seed, "week": week + 1,
                                         "seconds": round(time.perf_counter() - began, 2)}}), flush=True)
    return {"config": asdict(config), "weekly": weekly, "traces": traces, "cohorts": cohort_rows,
            "attendance": attendance_rows,
            "top100": final, "checks": checks, "timing": {**timing,
                "wall_seconds": time.perf_counter() - began, "cpu_seconds": time.process_time() - cpu_began}}


def incentive_experiment(seed: int = 20261022, samples: int = 12_000) -> dict:
    """Same-skilled focal entrant routed honestly or downward; all complete five tracks.

    This is an admission-control failure stress, not a claim that live matchmaking
    currently permits selecting a tier. Trials are paired by performance noise.
    """
    rng = np.random.default_rng(seed)
    result = []
    for boundary, low_cap, high_cap in zip([-.67448975, 0, .67448975], CAPS[:-1], CAPS[1:]):
        player_skill = boundary + .05
        common = rng.normal(0, .25, (samples, 16, 5))
        form = rng.normal(0, .14, (samples, 16, 1))
        rows = []
        for label, mean, cap in [("honest_stronger", boundary + .125, high_cap),
                                 ("routed_weaker", boundary - .125, low_cap)]:
            skill = rng.normal(mean, .06, (samples, 16, 1))
            skill[:, 0, :] = player_skill
            ticks = np.rint(10000 * np.exp(-.06 * (skill + form + common)))
            ranks = rank_rows(ticks.transpose(0, 2, 1).reshape(-1, 16),
                              np.ones((samples * 5, 16), dtype=bool))
            scores = TRACK_POINTS[ranks.reshape(samples, 5, 16) - 1].sum(axis=1)
            caps = np.full(samples, cap)
            qualified = np.ones(scores.shape, dtype=bool)
            awards, _ = local_awards(scores, qualified, caps, smooth=False)
            rows.append(awards[:, 0] / 10)
        result.append({"boundary": boundary, "lower_cap": low_cap, "higher_cap": high_cap,
            "honest_mean_points": float(np.mean(rows[0])), "weaker_mean_points": float(np.mean(rows[1])),
            "weaker_more_profitable_pct": float(np.mean(rows[1] > rows[0]) * 100),
            "mean_weaker_advantage_points": float(np.mean(rows[1] - rows[0]))})
    # Fixed expected placement exposes the cliff without attributing it to performance.
    cliffs = []
    for rank in [1, 2, 4, 8, 12, 16]:
        multiplier = float(payout_curve(np.array(rank), np.array(16), False))
        cliffs.append({"rank": rank, "club": 50 * multiplier, "challenger": 150 * multiplier,
                       "pro": 300 * multiplier, "elite": 500 * multiplier})
    return {"paired_samples_per_boundary": samples, "routing_trials": result, "tier_cliffs": cliffs,
        "limitation": "One-week routing stress; not a long-run strategic equilibrium or proof of anti-sandbag controls."}


def summarize(runs: list[dict]) -> list[dict]:
    output = []
    for size in sorted({r["config"]["population"] for r in runs}):
        selected = [r for r in runs if r["config"]["population"] == size]
        for policy in POLICIES:
            rows = [r["weekly"][-len(r["config"]["policies"]):] for r in selected
                    if policy in r["config"]["policies"]]
            values = [x for group in rows for x in group if x["policy"] == policy]
            if not values:
                continue
            item = {"population": size, "policy": policy, "seeds": len(values)}
            for key in ["ranked", "spearman_active_skill", "top100_skill_top1pct_share",
                        "top100_retention", "median_weekly_move_pct", "p95_weekly_move_pct",
                        "leader_points", "joint_world_no1", "point_ceiling_players"]:
                numbers = [v[key] for v in values if v[key] is not None]
                item[key] = {"mean": float(np.mean(numbers)), "min": float(np.min(numbers)),
                             "max": float(np.max(numbers))} if numbers else None
            output.append(item)
    return output


def write_csv(path: Path, rows: list[dict]):
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def build_report(directory: Path, runs: list[dict], summary: dict):
    import plotly.graph_objects as go
    from plotly.subplots import make_subplots

    chart = make_subplots(rows=3, cols=2, subplot_titles=(
        "Skill versus world rank (active ranked players)", "Top 100 drawn from most skilled 1%",
        "Same-skilled players: attendance", "New expert enters in week 53",
        "Stopping / a 13-week break", "Improving and declining ability"))
    colors = {"proposed": "#cb6843", "smooth": "#3f83bd", "circuit_tiebreak": "#8056ac", "pace_anchor": "#24967d"}
    largest = max(r["config"]["population"] for r in runs if len(r["config"]["policies"]) > 1)
    seed = min(r["config"]["seed"] for r in runs if r["config"]["population"] == largest)
    chosen = next(r for r in runs if r["config"]["population"] == largest and r["config"]["seed"] == seed)
    for policy in chosen["config"]["policies"]:
        rows = [r for r in chosen["weekly"] if r["policy"] == policy]
        for col, key, scale in [(1, "spearman_active_skill", 1), (2, "top100_skill_top1pct_share", 100)]:
            chart.add_trace(go.Scatter(x=[r["week"] for r in rows],
                y=[r[key] * scale if r[key] is not None else None for r in rows],
                name=NAMES[policy], legendgroup=policy, showlegend=col == 1,
                line={"color": colors[policy]}), row=1, col=col)
    panels = [
        (2, 1, ["strong_regular", "same_skill_casual", "same_skill_infrequent"]),
        (2, 2, ["new_expert_week_53"]),
        (3, 1, ["elite_stops_after_39", "strong_13_week_break"]),
        (3, 2, ["improver", "declining"]),
    ]
    for row, col, players in panels:
        for player in players:
            for policy in chosen["config"]["policies"]:
                values = [r for r in chosen["traces"] if r["player"] == player and r["policy"] == policy]
                chart.add_trace(go.Scatter(x=[r["week"] for r in values],
                    y=[r["rank_percentile"] for r in values],
                    name=f"{player}: {policy}", showlegend=False,
                    line={"color": colors[policy], "dash": ["solid", "dash", "dot"][players.index(player)]},
                    hovertemplate=f"{player} / {policy}<br>Week %{{x}}<br>Rank percentile %{{y:.3f}}<extra></extra>"),
                    row=row, col=col)
        chart.update_yaxes(autorange="reversed", title_text="Rank percentile (lower is better)", row=row, col=col)
    chart.update_layout(height=1300, template="plotly_white", title=f"Synthetic ranking behavior · {largest:,} players · seed {seed}",
                        margin={"t": 120}, legend={"orientation": "h", "y": 1.06})
    chart.update_xaxes(title_text="Simulated week")
    figure_html = chart.to_html(full_html=False, include_plotlyjs=True, config={"displaylogo": False})
    body_rows = []
    for row in summary["comparison"]:
        def value(key, scale=1, row=row):
            item = row[key]
            return f"{item['mean'] * scale:.3f} [{item['min'] * scale:.3f}, {item['max'] * scale:.3f}]" if item else "—"
        body_rows.append(f"<tr><td>{row['population']:,}</td><td>{NAMES[row['policy']]}</td><td>{row['seeds']}</td>"
                         f"<td>{value('spearman_active_skill')}</td><td>{value('top100_skill_top1pct_share', 100)}</td>"
                         f"<td>{value('p95_weekly_move_pct')}</td><td>{value('leader_points')}</td>"
                         f"<td>{value('joint_world_no1')}</td></tr>")
    assumptions = "".join(f"<li>{item}</li>" for item in summary["assumptions"])
    probe_rows = []
    for policy in chosen["config"]["policies"]:
        for player in ["strong_regular", "same_skill_casual", "same_skill_infrequent", "new_expert_week_53",
                       "elite_stops_after_39", "strong_13_week_break", "improver", "declining"]:
            values = [r for r in chosen["traces"] if r["player"] == player and r["policy"] == policy]
            last = values[-1]
            first_one = next((v["week"] for v in values if v["rank_percentile"] is not None
                              and v["rank_percentile"] <= 1), "—")
            probe_rows.append(f"<tr><td>{player}</td><td>{policy}</td><td>{last['rank'] or 'Unranked'}</td>"
                              f"<td>{last['points']:,.1f}</td><td>{first_one}</td></tr>")
    report = f"""<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Beat my track — World Ranking simulation</title><style>body{{font:16px system-ui;margin:32px auto;max-width:1450px;padding:0 20px;color:#172332}}h1{{font-size:30px}}table{{border-collapse:collapse;width:100%;font-size:14px}}td,th{{padding:10px;border-bottom:1px solid #ddd;text-align:left}}aside{{background:#fff1ce;padding:18px}}li{{margin:8px 0}}</style>
<h1>World Ranking simulation · 22 October 2026</h1>
<aside>Synthetic design experiment. Not live players, a backend load test, measured cloud capacity, or an OpenSkill implementation. All reward and eligibility values remain proposals.</aside>
<p>Numbers below are final-week means and seed ranges. The interactive plots show one fixed representative seed; hover for the exact player and policy. Double-click an axis to reset zoom.</p>
<table><thead><tr><th>Players</th><th>Rule</th><th>Seeds</th><th>Skill/rank Spearman</th><th>Top 100 from skill top 1% (%)</th><th>P95 weekly move (% field)</th><th>Leader points</th><th>Joint World No. 1s</th></tr></thead><tbody>{''.join(body_rows)}</tbody></table>
{figure_html}<h2>Assumptions and scope</h2><ul>{assumptions}</ul>
<h2>Illustrative players at the end of the representative run</h2><p>Single seeded examples, not cohort estimates. Rank 0 is displayed as Unranked. The newcomer starts in week 53; other examples start in week 1. Early top-percentile entry during the empty-ladder ramp is not a mature-ladder result.</p>
<table><thead><tr><th>Player</th><th>Rule</th><th>Final rank</th><th>Final points</th><th>First top 1% week</th></tr></thead><tbody>{''.join(probe_rows)}</tbody></table>
<p>The pace-anchor variant is an exploratory design change: 60% smooth local award plus 40% of 500 × worldwide weekly pace percentile⁴, with the same completion and small-field gates. It is not a validated recommendation.</p>
<p>The circuit-tiebreak variant keeps exactly the same points as the smooth curve. Only when total and counting-result countback tie, the sum of shared circuit pace percentiles from those counting weeks decides position. Equal-value weeks select the best pace percentiles. Exact remaining sporting ties still share rank.</p>
<p>Raw evidence: <a href="summary.json">summary.json</a>, <a href="weekly_metrics.csv">weekly metrics</a>, <a href="player_trajectories.csv">player trajectories</a>, <a href="cohort_metrics.csv">cohort metrics</a>, <a href="attendance_comparison.csv">same-skill attendance cohorts</a>, <a href="incentives.json">incentive stress</a>, and per-run JSON files.</p>
<p>Timing includes synthetic race generation, analysis and sorting in a desktop Python process. It excludes SQL, HTTP, verification, network, backup and cloud scheduling. No device or server was tested.</p></html>"""
    (directory / "report.html").write_text(report, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--populations", type=int, nargs="+", default=[10_000, 100_000])
    parser.add_argument("--seeds", type=int, nargs="+", default=[20261022, 20261023, 20261024])
    parser.add_argument("--weeks", type=int, default=78)
    parser.add_argument("--policies", nargs="+", choices=POLICIES, default=list(POLICIES))
    parser.add_argument("--output", type=Path, default=ROOT / "docs/evidence/world-ranking-simulation-2026-10-22")
    parser.add_argument("--no-report", action="store_true")
    parser.add_argument("--attendance", type=float, default=1.0)
    parser.add_argument("--matching", choices=["deciles", "narrow"], default="deciles")
    parser.add_argument("--elite-thresholds", type=float, nargs=3, default=[-.67448975, 0, .67448975])
    args = parser.parse_args()
    if min(args.populations) < 100 or args.weeks < 1 or not 0 < args.attendance <= 1:
        parser.error("Population must be >=100, weeks >=1, and attendance in (0,1].")
    if sorted(args.elite_thresholds) != args.elite_thresholds:
        parser.error("Tier thresholds must be increasing.")
    directory = args.output.resolve()
    workspace = ROOT.resolve()
    if workspace not in directory.parents:
        parser.error("Evidence output must be inside this workspace.")
    directory.mkdir(parents=True, exist_ok=True)
    runs = []
    for size in args.populations:
        for seed in args.seeds:
            config = Config(population=size, weeks=args.weeks, seed=seed, attendance=args.attendance,
                            thresholds=tuple(args.elite_thresholds), policies=tuple(args.policies), matching=args.matching)
            run = simulate(config)
            (directory / f"run-{size}-{seed}.json").write_text(json.dumps(run, indent=2, allow_nan=False), encoding="utf-8")
            runs.append(run)
    assumptions = [
        "78 weeks by default: 90% of accounts start at week 1, 5% at week 27, 5% at week 53.",
        "Skill is a synthetic normal distribution. Initial estimate error SD 0.35; newcomers start at the population prior.",
        "55% regular (95% attendance), 30% casual (65%), 15% infrequent (35%); independent of initial ability.",
        "5% retire after week 39, 5% take a 13-week break, 5% improve; fixed illustrative probes are also recorded.",
        "One shared car / five-track circuit; equal abstract PB opportunities; per-track completion probability 97%.",
        "Actual existing 20-place track-points schedule, quantized elapsed ticks, tied track ranks. Default matching uses ten fixed initial normal-decile skill bands, analogous to the existing ten percentile bands; a narrower 0.25-SD sensitivity is optional.",
        "Default Club/Challenger/Pro/Elite boundaries are fixed skill z-scores -0.6745, 0, 0.6745: approximately population quartiles at initialization, NOT approved live thresholds.",
        "Ranking awards require all five tracks; points placement is among qualified finishers. Fewer than five yields zero; 5-9 scales by n/10.",
        "Tied weekly ranking places share the mean of their occupied payout slots. Awards round to tenths of a point.",
        "Best 16 in the last 26 weeks; shared total/best-result ties share world rank unless the explicitly named circuit-tiebreak variant adds counting-week pace percentiles. Seasons count best 8 in each fixed 13-week block.",
        "Hidden skill uses a global-pace EWMA (first three observations gain 0.70, then 0.25). This assumes a shared pace anchor; it is NOT OpenSkill or the shipping PB matcher.",
        "No retries, resumes, paid advantage, track withdrawal, server delay, cheating trajectory, car normalization or actual human effort adaptation is modeled.",
        "Baseline compares fixed attendance/performance behavior across policies; incentive routing is a separate one-week stress, not an equilibrium simulation.",
        "Exact top-record ties may straddle position 100; quality uses every record with sporting rank <=100. Retention uses the first 100 serialized records and can be affected by exact ties.",
        "Local timings are analysis-process measurements only. Persistent audit and snapshot storage, SQL contention, endpoints and production capacity are not measured.",
    ]
    summary = {"schema": 1, "date": "2026-10-22", "requirements": ["WRS01", "WRS02", "WRS03", "WRS04", "Q01"],
        "source_sha256": SOURCE_HASH,
        "environment": {"python": sys.version, "numpy": np.__version__, "platform": platform.platform()},
        "assumptions": assumptions, "comparison": summarize(runs),
        "runs": [{"config": r["config"], "checks": r["checks"], "timing": r["timing"]} for r in runs]}
    (directory / "summary.json").write_text(json.dumps(summary, indent=2, allow_nan=False), encoding="utf-8")
    write_csv(directory / "weekly_metrics.csv", [row for r in runs for row in r["weekly"]])
    write_csv(directory / "player_trajectories.csv", [row for r in runs for row in r["traces"]])
    write_csv(directory / "cohort_metrics.csv", [row for r in runs for row in r["cohorts"]])
    write_csv(directory / "attendance_comparison.csv", [row for r in runs for row in r["attendance"]])
    (directory / "incentives.json").write_text(json.dumps(incentive_experiment(), indent=2), encoding="utf-8")
    if not args.no_report:
        build_report(directory, runs, summary)
    print(json.dumps({"completed": str(directory), "comparison": summary["comparison"]}), flush=True)


if __name__ == "__main__":
    main()
