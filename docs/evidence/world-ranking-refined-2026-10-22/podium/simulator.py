"""Second offline ranking experiment: shared worldwide five-track competition.

No backend imports, network, account writes, or installed dependencies. Uses the
existing analysis Python's NumPy/Plotly and the first experiment's synthetic people.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import platform
import time
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np
from simulate_world_ranking import Config as PeopleConfig
from simulate_world_ranking import correlation, population

ROOT = Path(__file__).resolve().parents[1]
SOURCE_HASH = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()


@dataclass(frozen=True)
class Candidate:
    method: str = "places"
    curve: str = "absolute"
    count: int = 14
    minimum_tracks: int = 5

    @property
    def key(self):
        return f"{self.method}-{self.curve}-best{self.count}-finish{self.minimum_tracks}"


@dataclass(frozen=True)
class Scenario:
    name: str = "normal"
    population: int = 10_000
    weeks: int = 78
    seed: int = 20261022
    noise: float = .25
    completion: float = .97
    affinity: float = .30
    candidates: tuple[Candidate, ...] = (Candidate(),)


def midranks2(values: np.ndarray) -> np.ndarray:
    """Twice the one-based midrank, in ascending value order; exact integer ties."""
    order = np.argsort(values, kind="stable")
    _, starts, counts = np.unique(values[order], return_index=True, return_counts=True)
    ranks = np.empty(len(values), dtype=np.int32)
    ranks[order] = np.repeat(2 * starts + counts + 1, counts)
    return ranks


def ordering(keys: list[np.ndarray]) -> tuple[np.ndarray, np.ndarray]:
    """Lowest key wins; all keys equal means a shared competition rank."""
    if not keys or len(keys[0]) == 0:
        return np.array([], dtype=np.int32), np.array([], dtype=np.int32)
    order = np.lexsort(tuple(keys[::-1]))
    change = np.ones(len(order), dtype=bool)
    change[1:] = np.logical_or.reduce([key[order[1:]] != key[order[:-1]] for key in keys])
    ordered_ranks = np.maximum.accumulate(np.where(change, np.arange(1, len(order) + 1), 0))
    ranks = np.empty(len(order), dtype=np.int32)
    ranks[order] = ordered_ranks
    return ranks, order


def weekly_classification(ticks: np.ndarray, method: str, minimum_tracks: int = 5):
    """Zero denotes a missing track; four-track trial gives a missing track last place."""
    eligible = np.flatnonzero((ticks > 0).sum(axis=1) >= minimum_tracks)
    values = ticks[eligible]
    n = len(eligible)
    track_places = np.zeros((n, 5), dtype=np.int32)
    for track in range(5):
        valid = values[:, track] > 0
        track_places[valid, track] = midranks2(values[valid, track])
        track_places[~valid, track] = 2 * (n + 1)
    countback = np.sort(track_places, axis=1)
    if method == "places":
        keys = [track_places.sum(axis=1, dtype=np.int64)]
    elif method == "relative_time":
        # Approximate geometric product for this experiment only. A shipping
        # implementation must compare exact integer tick products for ties.
        keys = [np.log(np.maximum(values, 1)).mean(axis=1)]
    elif method == "total_time":
        keys = [values.sum(axis=1, dtype=np.int64)]
    else:
        raise ValueError(method)
    keys.extend(countback[:, track] for track in range(5))
    # Exact lexicographic input times are deliberately NOT a sporting tiebreak.
    ranks, order = ordering(keys)
    return eligible, ranks, order, track_places


def award_points(ranks: np.ndarray, field_size: int, curve: str) -> np.ndarray:
    """Integer world points, 1..1000 for a competitive complete result.

    Full awards at 128 global finishers. Smaller fields scale linearly from zero
    at one entrant. Lower-ranked participants cannot change absolute-curve awards
    once this small-field factor is full.
    """
    if field_size < 2:
        return np.zeros(len(ranks), dtype=np.uint16)
    q = np.clip((field_size - ranks) / max(field_size - 1, 1), 0, 1)
    absolute = np.sqrt(100 / (99 + ranks.astype(np.float64)))
    if curve == "absolute":
        multiplier = absolute
    elif curve == "fourth_root":
        multiplier = np.power(ranks.astype(np.float64), -.25)
    elif curve == "podium":
        multiplier = np.where(ranks == 1, 1.0, np.where(ranks == 2, .85,
            np.where(ranks == 3, .775, np.sqrt(56.25 / (96 + ranks.astype(np.float64))))))
    elif curve == "percentile":
        multiplier = q ** 3
    elif curve == "hybrid":
        multiplier = .5 * absolute + .5 * q ** 3
    else:
        raise ValueError(curve)
    factor = min(1, (field_size - 1) / 127)
    return np.maximum(1, np.floor(1000 * factor * multiplier + 1e-10)).astype(np.uint16)


def rank_world(totals: np.ndarray, best: np.ndarray, places: np.ndarray):
    """Points, best-result countback, then best counting-week worldwide place.

    places stores chronological official placements. Use the best placements
    only to break otherwise identical counting point sets; all exact ties remain.
    """
    keys = [-totals]
    keys.extend(-best[:, i].astype(np.int32) for i in range(best.shape[1] - 1, -1, -1))
    keys.extend(places[:, i] for i in range(places.shape[1]))
    ranks, order = ordering(keys)
    ranks[totals == 0] = 0
    return ranks, order[totals[order] > 0]


def counting_records(points: np.ndarray, places: np.ndarray, count: int):
    # A 1e-9 position fraction cannot cross a one-point gap for <=1e6 entrants.
    score = points.astype(np.float64) - places * 1e-9
    indices = np.argsort(score, axis=1)[:, -count:]
    best = np.take_along_axis(points, indices, axis=1)
    picked_places = np.take_along_axis(places, indices, axis=1)
    picked_places = np.where(best > 0, picked_places, np.iinfo(np.int32).max)
    return best.sum(axis=1, dtype=np.int32), best, np.sort(picked_places, axis=1)


def make_people(config: Scenario):
    args = population(PeopleConfig(population=config.population, seed=config.seed))
    rng, skill, attendance, cohorts, start, retire, hiatus, improving, probes, _estimate = args
    if config.name == "growth":
        start[:] = np.select([rng.random(config.population) < .10], [0], default=26)
        # Deliberately weak pioneer field to expose historical field-size advantage.
        skill[start == 0] -= .8
        start[:8] = 0
        start[config.population - 1] = 52
        for pid, (_name, original_skill, _chance) in probes.items():
            skill[pid] = original_skill
    if config.name == "sparse":
        attendance *= .015
    if config.name == "specialists":
        affinity = rng.normal(0, .85, (config.population, 5))
    else:
        affinity = rng.normal(0, config.affinity, (config.population, 5))
    affinity -= affinity.mean(axis=1, keepdims=True)
    return rng, skill, attendance, cohorts, start, retire, hiatus, improving, probes, affinity


def simulate(config: Scenario):
    began, cpu_began = time.perf_counter(), time.process_time()
    rng, base, attendance, cohorts, start, retired, hiatus, improving, probes, affinity = make_people(config)
    n = config.population
    histories = {c.key: np.zeros((n, 26), dtype=np.uint16) for c in config.candidates}
    place_histories = {c.key: np.full((n, 26), np.iinfo(np.int32).max, dtype=np.int32) for c in config.candidates}
    previous_top = {c.key: set() for c in config.candidates}
    previous_ranks = {c.key: np.zeros(n, dtype=np.int32) for c in config.candidates}
    rows, traces, cohort_rows = [], [], []
    last_active = {minimum: np.full(n, -100, dtype=np.int16)
                   for minimum in {c.minimum_tracks for c in config.candidates}}
    final_examples = {}
    for week in range(config.weeks):
        ability = base + improving * min(max(week - 13, 0), 39) * .035
        ability[4] = -.7 + min(max(week - 26, 0), 26) / 26 * 3
        ability[5] = 2.3 - min(max(week - 39, 0), 26) / 26 * 3
        present = (start <= week) & (rng.random(n) < attendance)
        present &= ~(retired & (week >= 39))
        present &= ~(hiatus & (week >= 39) & (week < 52))
        ids = np.flatnonzero(present)
        noise = rng.normal(0, config.noise, (len(ids), 5))
        if config.name == "heavy_tail":
            noise = rng.standard_t(3, size=(len(ids), 5)) * config.noise / math.sqrt(3)
        form = rng.normal(0, .14, (len(ids), 1))
        pace = ability[ids, None] + affinity[ids] + form + noise
        # Unequal circuit durations expose an unnormalized elapsed-time sum.
        lengths = np.array([7000, 10000, 14000, 18000, 24000])
        ticks = np.rint(lengths * np.exp(-.06 * np.clip(pace, -12, 12))).astype(np.int32)
        if config.name == "correlated_completion":
            completed = np.repeat(rng.random((len(ids), 1)) < config.completion, 5, axis=1)
        else:
            completed = rng.random((len(ids), 5)) < config.completion
        ticks[~completed] = 0
        if config.name == "one_fast_track":
            # Statistical bad-input stress, not a claim these would pass verification.
            disturbed = rng.random(len(ids)) < .01
            ticks[disturbed, 0] //= 2
            ticks[(ticks == 0) & completed] = 1
        classifications = {}
        for candidate in config.candidates:
            lookup = (candidate.method, candidate.minimum_tracks)
            if lookup not in classifications:
                classifications[lookup] = weekly_classification(ticks, *lookup)
        for candidate in config.candidates:
            key = candidate.key
            eligible, placements, _weekly_order, _track_places = classifications[(candidate.method, candidate.minimum_tracks)]
            entered = ids[eligible]
            awards = award_points(placements, len(eligible), candidate.curve)
            history, place_history = histories[key], place_histories[key]
            history[:, week % 26] = 0
            place_history[:, week % 26] = np.iinfo(np.int32).max
            history[entered, week % 26] = awards
            place_history[entered, week % 26] = placements
            activity = last_active[candidate.minimum_tracks]
            activity[entered] = week
            totals, best, counting_places = counting_records(history, place_history, candidate.count)
            ranks, order = rank_world(totals, best, counting_places)
            ranked_count = len(order)
            recent = (ranks > 0) & (activity >= week - 3)
            top = set(order[:100].tolist())
            true_order = np.argsort(-ability)
            best_onepct = set(true_order[:max(1, math.ceil(n * .01))].tolist())
            moves = (ranks > 0) & (previous_ranks[key] > 0)
            movement = np.abs(ranks[moves] - previous_ranks[key][moves]) / max(ranked_count, 1) * 100
            row = {"scenario": config.name, "population": n, "seed": config.seed, "candidate": key,
                "week": week + 1, "field": len(entered), "ranked": ranked_count,
                "leader_points": int(totals[order[0]]) if len(order) else 0,
                "joint_no1": int(np.sum(ranks == 1)),
                "top100_from_skill_top1pct": len(top & best_onepct) / max(len(top), 1),
                "top100_retention": len(top & previous_top[key]) / max(len(top), 1) if week else None,
                "median_movement_percentile": float(np.median(movement)) if len(movement) else None,
                "p95_movement_percentile": float(np.percentile(movement, 95)) if len(movement) else None,
                "spearman_active": correlation(ability[recent], -ranks[recent])
                    if week % 13 == 12 or week == config.weeks - 1 else None,
            }
            rows.append(row)
            for pid, (name, *_rest) in probes.items():
                traces.append({"candidate": key, "week": week + 1, "player": name,
                    "rank": int(ranks[pid]), "rank_percentile": float(ranks[pid] / max(ranked_count, 1) * 100) if ranks[pid] else None,
                    "points": int(totals[pid]), "earned": int(history[pid, week % 26]),
                    "ability": float(ability[pid])})
            if week == config.weeks - 1:
                for style in ["regular", "casual", "infrequent"]:
                    mask = (cohorts == style) & (ability >= 1) & (ability < 1.5) & (ranks > 0)
                    if mask.any():
                        cohort_rows.append({"candidate": key, "cohort": style, "players": int(mask.sum()),
                            "median_ability": float(np.median(ability[mask])),
                            "median_points": float(np.median(totals[mask])),
                            "median_rank_percentile": float(np.median(ranks[mask]) / max(ranked_count, 1) * 100),
                            "median_awarded_weeks": float(np.median(np.count_nonzero(history[mask], axis=1)))})
                final_examples[key] = [{"synthetic_id": int(pid), "rank": int(ranks[pid]),
                    "points": int(totals[pid]), "ability": float(ability[pid]), "style": str(cohorts[pid])}
                    for pid in order[:25]]
            previous_top[key], previous_ranks[key] = top, ranks
        if (week + 1) % 13 == 0:
            print(json.dumps({"scenario": config.name, "population": n, "seed": config.seed,
                              "week": week + 1, "seconds": round(time.perf_counter() - began, 2)}), flush=True)
    return {"config": asdict(config), "weekly": rows, "traces": traces, "attendance": cohort_rows,
        "leaders": final_examples, "timing": {"wall_seconds": time.perf_counter() - began,
                                               "cpu_seconds": time.process_time() - cpu_began}}


def summarize(runs):
    summaries = []
    groups = sorted({(r["config"]["name"], r["config"]["population"], c["method"], c["curve"], c["count"],
                     c["minimum_tracks"]) for r in runs for c in r["config"]["candidates"]})
    for scenario, size, method, curve, count, minimum in groups:
        key = Candidate(method, curve, count, minimum).key
        selected = [r for r in runs if r["config"]["name"] == scenario and r["config"]["population"] == size
                    and any(row["candidate"] == key for row in r["weekly"])]
        finals = [next(row for row in reversed(r["weekly"]) if row["candidate"] == key) for r in selected]
        item = {"scenario": scenario, "population": size, "candidate": key, "seeds": len(selected)}
        for metric in ["spearman_active", "top100_from_skill_top1pct", "joint_no1", "top100_retention",
                       "p95_movement_percentile", "leader_points", "field"]:
            vals = [r[metric] for r in finals if r[metric] is not None]
            item[metric] = {"mean": float(np.mean(vals)), "min": float(np.min(vals)),
                            "max": float(np.max(vals))} if vals else None
        for style in ["regular", "casual", "infrequent"]:
            vals = [a["median_points"] for r in selected for a in r["attendance"]
                    if a["candidate"] == key and a["cohort"] == style]
            item[style + "_median_points"] = float(np.mean(vals)) if vals else None
        catchup = []
        for run in selected:
            event = next((t["week"] - 52 for t in run["traces"] if t["candidate"] == key
                and t["player"] == "new_expert_week_53" and t["week"] >= 53
                and t["rank_percentile"] is not None and t["rank_percentile"] <= 1), None)
            catchup.append(event)
        item["new_expert_weeks_to_top1pct"] = catchup
        summaries.append(item)
    return summaries


def structural_experiments(seed=20261022, size=10_000):
    rng = np.random.default_rng(seed)
    ability = rng.normal(0, 1, size)
    affinity = rng.normal(0, .4, (size, 5))
    affinity -= affinity.mean(axis=1, keepdims=True)
    ticks = np.rint(np.array([7000, 10000, 14000, 18000, 24000])
                    * np.exp(-.06 * (ability[:, None] + affinity + rng.normal(0, .2, (size, 5))))).astype(np.int32)
    methods = []
    for method in ["places", "relative_time", "total_time"]:
        _, before, order, _ = weekly_classification(ticks, method)
        disturbed = ticks.copy()
        victim = int(np.argsort(np.abs(ability))[0])
        disturbed[victim, 0] //= 2
        _, after, _, _ = weekly_classification(disturbed, method)
        scaled = ticks.copy()
        scaled[:, 0] *= 4
        _, scale_rank, _, _ = weekly_classification(scaled, method)
        methods.append({"method": method, "median_driver_before_rank": int(before[victim]),
            "after_one_half_time_rank": int(after[victim]),
            "rank_changes_after_multiplying_one_track_duration_by4": int(np.sum(before != scale_rank)),
            "leader_true_ability": float(ability[order[0]])})
    curves = []
    positions = np.array([1, 2, 3, 10, 50, 100, 500, 1000, 5000, 10000])
    for curve in ["absolute", "fourth_root", "podium", "percentile", "hybrid"]:
        first = award_points(positions, 10_000, curve)
        padded = award_points(positions, 100_000, curve)
        curves.append({"curve": curve, "ranks": positions.tolist(), "points_at_10000": first.tolist(),
                       "points_after_90000_slower_entrants": padded.tolist()})
    return {"methods": methods, "curves": curves, "scope": "Bad-input statistical sensitivity, not a live verification bypass."}


def report(directory, runs, summary):
    import plotly.graph_objects as go
    from plotly.subplots import make_subplots

    normal = [r for r in runs if r["config"]["name"] == "normal"]
    chosen = max(normal, key=lambda r: r["config"]["population"]) if normal else runs[0]
    figure = make_subplots(rows=2, cols=2, subplot_titles=("Skill and world rank", "Same-skilled attendance cohorts",
                                                        "New expert enters week 53", "Inactive former elite"))
    candidates = [Candidate(**c).key for c in chosen["config"]["candidates"]]
    for candidate in candidates:
        rows = [r for r in chosen["weekly"] if r["candidate"] == candidate and r["spearman_active"] is not None]
        figure.add_trace(go.Scatter(x=[r["week"] for r in rows], y=[r["spearman_active"] for r in rows],
                                   name=candidate, legendgroup=candidate), row=1, col=1)
        values = [r for r in chosen["attendance"] if r["candidate"] == candidate]
        figure.add_trace(go.Bar(x=[r["cohort"] for r in values], y=[r["median_points"] for r in values],
                               name=candidate, legendgroup=candidate, showlegend=False), row=1, col=2)
        for col, player in [(1, "new_expert_week_53"), (2, "elite_stops_after_39")]:
            values = [r for r in chosen["traces"] if r["candidate"] == candidate and r["player"] == player]
            figure.add_trace(go.Scatter(x=[r["week"] for r in values], y=[r["rank_percentile"] for r in values],
                                       name=candidate, legendgroup=candidate, showlegend=False), row=2, col=col)
    figure.update_layout(template="plotly_white", height=1050, margin={"t": 150},
                         legend={"orientation": "h", "y": 1.13}, barmode="group")
    figure.update_yaxes(autorange="reversed", title_text="Rank percentile", row=2)
    figure.update_xaxes(title_text="Week", row=2)
    rows = []
    for item in summary["comparison"]:
        def fmt(key, item=item):
            return f"{item[key]['mean']:.3f}" if item[key] else "—"
        rows.append(f"<tr><td>{item['scenario']}</td><td>{item['population']:,}</td><td>{item['candidate']}</td>"
                    f"<td>{item['seeds']}</td><td>{fmt('spearman_active')}</td><td>{fmt('top100_from_skill_top1pct')}</td>"
                    f"<td>{item['regular_median_points']}</td><td>{item['casual_median_points']}</td>"
                    f"<td>{item['new_expert_weeks_to_top1pct']}</td></tr>")
    body = f"""<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>World Ranking worldwide circuit experiment</title><style>body{{font:15px system-ui;max-width:1500px;margin:30px auto;padding:0 20px}}table{{border-collapse:collapse;font-size:12px}}td,th{{padding:7px;border-bottom:1px solid #ddd}}aside{{padding:15px;background:#fff1ce}}</style>
<h1>World Ranking worldwide circuit experiment</h1><aside>Synthetic offline experiments. No live players, backend capacity or shipped implementation. Seed ranges and assumptions are in summary.json.</aside>
<p>Each worldwide circuit shares five pinned tracks and one car. Comparison candidates use identical attendance and race observations. The first panel samples correlation every 13 weeks; other panels show a representative seed, not an average.</p>
{figure.to_html(full_html=False, include_plotlyjs=True, config={'displaylogo':False})}
<table><thead><tr><th>Scenario</th><th>Players</th><th>Candidate</th><th>Seeds</th><th>Skill correlation</th><th>Top100 skill-top1% share</th><th>Regular median points</th><th>Casual median points</th><th>New expert weeks to top1%</th></tr></thead><tbody>{''.join(rows)}</tbody></table>
<p>Machine-readable evidence: <a href="summary.json">summary</a> and <a href="structural.json">structural experiments</a>, plus individual run JSON files.</p></html>"""
    (directory / "report.html").write_text(body, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--populations", nargs="+", type=int, default=[10000])
    parser.add_argument("--seeds", nargs="+", type=int, default=[20261022, 20261023, 20261024])
    parser.add_argument("--weeks", type=int, default=78)
    parser.add_argument("--methods", nargs="+", choices=["places", "relative_time", "total_time"], default=["places"])
    parser.add_argument("--curves", nargs="+", choices=["absolute", "fourth_root", "podium", "percentile", "hybrid"], default=["absolute"])
    parser.add_argument("--counts", nargs="+", type=int, default=[12, 14, 16])
    parser.add_argument("--minimum-tracks", nargs="+", type=int, choices=[4, 5], default=[5])
    parser.add_argument("--scenarios", nargs="+", choices=["normal", "growth", "heavy_tail", "specialists", "sparse", "one_fast_track", "correlated_completion"], default=["normal"])
    parser.add_argument("--completion", type=float, default=.97)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--no-report", action="store_true")
    args = parser.parse_args()
    if (min(args.populations) < 100 or args.weeks < 1 or any(not 1 <= count <= 26 for count in args.counts)
            or not 0 < args.completion <= 1):
        parser.error("Population >=100, weeks >=1 and result counts in 1..26 required.")
    directory = args.output.resolve()
    if ROOT.resolve() not in directory.parents:
        parser.error("Output must remain inside this workspace.")
    directory.mkdir(parents=True, exist_ok=True)
    candidates = tuple(Candidate(m, c, k, t) for m in args.methods for c in args.curves for k in args.counts
                       for t in args.minimum_tracks if t == 5 or m == "places")
    runs = []
    for scenario in args.scenarios:
        for size in args.populations:
            for seed in args.seeds:
                config = Scenario(scenario, size, args.weeks, seed, completion=args.completion, candidates=candidates)
                run = simulate(config)
                (directory / f"run-{scenario}-{size}-{seed}.json").write_text(json.dumps(run, allow_nan=False), encoding="utf-8")
                runs.append(run)
    result = {"source_sha256": SOURCE_HASH,
        "people_source_sha256": hashlib.sha256((ROOT / "scripts/simulate_world_ranking.py").read_bytes()).hexdigest(),
        "environment": {"python": platform.python_version(), "numpy": np.__version__},
        "comparison": summarize(runs), "timings": [{"config": r["config"], "timing": r["timing"]} for r in runs],
        "assumptions": ["One worldwide car/circuit; five equally weighted track places or an explicitly named timing comparison.",
            "Existing synthetic attendance/retirement/improvement/newcomer cohorts, independent of world points.",
            "No matchmaker or rating affects worldwide scoring. No OpenSkill implementation.",
            "Normal log-time generation favors relative-time aggregation by construction; structural tests and specialist/outlier sensitivities also inform the choice.",
            "Absolute curve = floor(1000*sqrt(100/(99+place))); fourth_root = floor(1000/place^0.25); percentile = floor(1000*q^3); hybrid blends absolute/percentile 50/50 before flooring.",
            "Podium curve: 1000/850/775 for first three, then floor(750*sqrt(100/(96+place))); all apply the same small-field scale before flooring.",
            "Fields below 128 scale by (N-1)/127; one entrant earns zero. Two or more earn at least one point.",
            "Whole-point awards, best K of 26; world ties compare best counting awards then counting worldwide places.",
            "Four-track alternative assigns a missing fifth track worse than every eligible entrant.",
            "Relative-time sorting uses floating log products in the experiment; exact arithmetic is required for a final shipping contract.",
            "Latent skill measures, simulation duration and quality thresholds are model inputs, not production observations."]}
    (directory / "summary.json").write_text(json.dumps(result, indent=2, allow_nan=False), encoding="utf-8")
    (directory / "structural.json").write_text(json.dumps(structural_experiments(), indent=2), encoding="utf-8")
    if not args.no_report:
        report(directory, runs, result)
    print(json.dumps({"completed": str(directory), "runs": len(runs), "candidates": len(candidates)}), flush=True)


if __name__ == "__main__":
    main()
