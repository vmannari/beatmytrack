"""Audit offline ranking iterations and produce the refined-spec evidence report."""
from __future__ import annotations

import argparse
import hashlib
import html
import json
from dataclasses import fields
from pathlib import Path

import numpy as np
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from simulate_world_circuit import (
    Candidate,
    Scenario,
    award_points,
    make_people,
    structural_experiments,
    weekly_classification,
)

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "docs/evidence/world-ranking-refined-2026-10-22"
PHASES = ("screen", "finalists", "stress", "curve", "podium", "selected", "million", "selected-stress")


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def analyze():
    phases, selected_runs, checks, events, narrow_quality = {}, [], [], [], []
    total_worlds = total_candidates = total_weeks = 0
    people_hash = digest(ROOT / "scripts/simulate_world_ranking.py")
    for phase in PHASES:
        folder = DIRECTORY / phase
        summary = read(folder / "summary.json")
        archive = folder / "simulator.py"
        source = archive if archive.exists() else ROOT / "scripts/simulate_world_circuit.py"
        assert summary["source_sha256"] == digest(source), (phase, "source version")
        assert summary["people_source_sha256"] == people_hash, (phase, "people version")
        runs = [read(path) for path in sorted(folder.glob("run-*.json"))]
        phases[phase] = {"source_sha256": summary["source_sha256"], "comparison": summary["comparison"],
                         "worlds": len(runs), "scope": summary["assumptions"]}
        total_worlds += len(runs)
        for run in runs:
            config = run["config"]
            candidates = [Candidate(**c) for c in config["candidates"]]
            total_candidates += len(candidates)
            total_weeks += config["weeks"] * len(candidates)
            assert len(run["weekly"]) == config["weeks"] * len(candidates)
            for candidate in candidates:
                rows = [r for r in run["weekly"] if r["candidate"] == candidate.key]
                assert [r["week"] for r in rows] == list(range(1, config["weeks"] + 1))
                assert all(0 <= r["leader_points"] <= candidate.count * 1000 for r in rows)
                assert all(0 <= r["field"] <= config["population"] and 0 <= r["ranked"] <= config["population"] for r in rows)
                assert all(r["joint_no1"] >= 1 if r["ranked"] else r["joint_no1"] == 0 for r in rows)
                trace = [t for t in run["traces"] if t["candidate"] == candidate.key
                         and t["player"] == "elite_stops_after_39"]
                last_earned = max((t["week"] for t in trace if t["earned"] > 0), default=None)
                unranked = next((t["week"] for t in trace if last_earned is not None
                                 and t["week"] > last_earned and t["points"] == 0), None)
                if last_earned is not None and unranked is not None:
                    assert unranked == last_earned + 26
                if phase in ("selected", "million", "selected-stress"):
                    events.append({"phase": phase, "scenario": config["name"], "population": config["population"],
                        "seed": config["seed"], "last_retired_award": last_earned, "first_unranked_week": unranked})
            checks.append({"phase": phase, "scenario": config["name"], "population": config["population"],
                           "seed": config["seed"], "candidates": len(candidates), "weeks": config["weeks"], "passed": True})
            if phase in ("selected", "million"):
                selected_runs.append(run)
                scenario_fields = {f.name for f in fields(Scenario)}
                arguments = {k: v for k, v in config.items() if k in scenario_fields and k != "candidates"}
                reconstructed = make_people(Scenario(**arguments))
                _rng, ability, _attend, _cohort, start, retired, _hiatus, improving, _probes, _affinity = reconstructed
                week = config["weeks"] - 1
                ability = ability + improving * min(max(week - 13, 0), 39) * .035
                ability[4] = -.7 + min(max(week - 26, 0), 26) / 26 * 3
                ability[5] = 2.3 - min(max(week - 39, 0), 26) / 26 * 3
                available = (start <= week) & ~(retired & (week >= 39))
                skill_ids = np.flatnonzero(available)
                skill_ids = skill_ids[np.argsort(-ability[skill_ids])]
                leaders = run["leaders"][candidates[0].key]
                leader_ids = {r["synthetic_id"] for r in leaders}
                skill_top25 = set(skill_ids[:25].tolist())
                skill_top100 = set(skill_ids[:100].tolist())
                actual_first = leaders[0]["synthetic_id"]
                narrow_quality.append({"population": config["population"], "seed": config["seed"],
                    "leader_latent_skill_place_among_nonretired": int(np.sum(ability[available] > ability[actual_first]) + 1),
                    "world_top25_overlap_skill_top25": len(leader_ids & skill_top25) / 25,
                    "world_top25_from_skill_top100": len(leader_ids & skill_top100) / 25,
                    "scope": "Modeled current ability among introduced, nonretired accounts; World Ranking also rewards historical results and consistency."})
    structural = structural_experiments()
    trial = np.array([[10, 10, 10, 10, 0], [20, 20, 20, 20, 20], [30, 30, 30, 30, 30]])
    _, initial, _, _ = weekly_classification(trial, "places", 4)
    _, padded, _, _ = weekly_classification(np.vstack([trial, np.full((10, 5), 1000)]), "places", 4)
    structural["four_track_tradeoff"] = {"original_positions": initial.tolist(), "after_ten_slow_finishers": padded[:3].tolist(),
        "meaning": "A missing fifth track has no fixed relative place. Full-five qualification preserves stronger invariance and one clear Circuit completion rule."}
    selected = phases["selected"]["comparison"] + phases["million"]["comparison"]
    return {"schema": 1, "selected_candidate": "places-podium-best12-finish5",
        "requirements": ["WRF01", "WRF02", "WRF03", "WRF04", "WRF05", "WRF06", "WRF07", "WRF08"],
        "counts": {"world_runs": total_worlds, "candidate_world_evaluations": total_candidates,
                   "candidate_weeks": total_weeks}, "phases": phases, "selected_summary": selected,
        "run_checks": checks, "retirement_checks": events, "narrow_quality": narrow_quality,
        "structural": structural,
        "decisions": [
            "Score one common worldwide Compact Circuit independently of local groups.",
            "Combine the five worldwide track placements equally, using exact average occupied places and track-place countback.",
            "Require all five finishes; best 12 results in 26 weeks supplies flexibility between weeks.",
            "Use fixed worldwide-place points, with 1000/850/775 podium awards and a smooth inverse-square-root tail.",
            "Scale fields smaller than 128; keep population context and a 1000-finisher prestige milestone threshold.",
            "Allow genuine equivalent worldwide records to share No. 1. Do not manufacture a winner with an account ID or attempt count.",
            "Use 13-week seasons with best six results; keep world totals continuous.",
            "Propose three free purpose-bound resumes for official attempts so purchases do not change access to assistance.",
        ], "corrections": [
            "Initial lint/import fixes did not weaken numerical tests.",
            "In the early growth screening, the weak-pioneer adjustment also altered a fixed expert probe. Restored the fixed probe ability and reran all selected growth cases. Early growth probe catch-up times are not used as final evidence.",
            "Archived simulator versions accompany each pre-final phase; final normal/million/stress use the final selected source hash.",
        ], "limitations": [
            "Synthetic inputs are not calibrated human behavior; the selected numbers are a coherent launch proposal, not a proved universal optimum.",
            "The million-account selected case has one seed. Smaller main populations and selected stress scenarios have three seeds.",
            "Some stress cases legitimately share No. 1; sparse weekly participation substantially weakens the relation to latent skill.",
            "Unchanged fixed-rank awards after weaker field padding apply only after the global field reaches 128 complete finishers.",
            "Equal car and performance opportunities are modeled; the proposed resume receipt policy and multi-car expansion are not implemented or simulated.",
            "Local runtimes include race generation, repeated truth metrics and competing experiments. No SQL, HTTP, cloud, engine or device capacity was measured.",
            "No game/backend implementation, live account/queue mutation, deployment or phone attachment/device test was performed.",
        ]}, selected_runs


def write_report(findings, selected_runs):
    normal100k = next(r for r in selected_runs if r["config"]["population"] == 100000
                     and r["config"]["seed"] == 20261022)
    final_key = findings["selected_candidate"]
    finalists = findings["phases"]["finalists"]["comparison"]
    five = [r for r in finalists if r["candidate"].endswith("finish5")]
    figure = make_subplots(rows=2, cols=2, subplot_titles=(
        "Attendance flexibility at 100,000 accounts (baseline fixed-place curve)", "Selected worldwide weekly point schedule",
        "Strong newcomer in the selected 100,000-account run", "Retiring player in the selected run"))
    ratios = [100 * r["casual_median_points"] / r["regular_median_points"] for r in five]
    figure.add_trace(go.Bar(x=[r["candidate"].split("best")[1].split("-")[0] for r in five], y=ratios,
        name="Casual / regular points", marker_color="#cda339", text=[f"{r:.1f}%" for r in ratios],
        textposition="outside", cliponaxis=False), row=1, col=1)
    positions = np.array([1, 2, 3, 4, 10, 50, 100, 500, 1000, 5000, 10000, 100000, 1000000])
    figure.add_trace(go.Scatter(x=positions, y=award_points(positions, 1000000, "podium"), mode="lines+markers",
                               name="Weekly points", line_color="#305d88"), row=1, col=2)
    for col, player in [(1, "new_expert_week_53"), (2, "elite_stops_after_39")]:
        trace = [r for r in normal100k["traces"] if r["candidate"] == final_key and r["player"] == player]
        figure.add_trace(go.Scatter(x=[r["week"] for r in trace],
            y=[r["rank_percentile"] if col == 1 else r["points"] for r in trace],
            name=player, line_color="#368a70"), row=2, col=col)
    figure.update_xaxes(type="log", row=1, col=2)
    figure.update_xaxes(title_text="Counting weeks in 26", row=1, col=1)
    figure.update_yaxes(title_text="Percent of regular cohort points", range=[0, 100], row=1, col=1)
    figure.update_yaxes(title_text="Rank percentile (lower is better)", autorange="reversed", row=2, col=1)
    figure.update_yaxes(title_text="World points", row=2, col=2)
    figure.update_xaxes(title_text="Week", row=2)
    figure.update_layout(height=1000, template="plotly_white", showlegend=False, margin={"t": 80})
    table = []
    for row in findings["selected_summary"]:
        table.append(f"<tr><td>{row['population']:,}</td><td>{row['seeds']}</td>"
            f"<td>{row['spearman_active']['mean']:.3f}</td><td>{row['joint_no1']['min']:.0f}–{row['joint_no1']['max']:.0f}</td>"
            f"<td>{100 * row['casual_median_points'] / row['regular_median_points']:.1f}%</td>"
            f"<td>{row['new_expert_weeks_to_top1pct']}</td></tr>")
    stress = []
    for row in findings["phases"]["selected-stress"]["comparison"]:
        stress.append(f"<tr><td>{row['scenario']}</td><td>{row['seeds']}</td>"
            f"<td>{row['spearman_active']['mean']:.3f} [{row['spearman_active']['min']:.3f}, {row['spearman_active']['max']:.3f}]</td>"
            f"<td>{row['joint_no1']['min']:.0f}–{row['joint_no1']['max']:.0f}</td></tr>")
    decisions = "".join(f"<li>{html.escape(x)}</li>" for x in findings["decisions"])
    quality = findings["narrow_quality"]
    strongest = [r["leader_latent_skill_place_among_nonretired"] for r in quality]
    overlap = [r["world_top25_overlap_skill_top25"] for r in quality]
    limits = "".join(f"<li>{html.escape(x)}</li>" for x in findings["limitations"])
    sources = " · ".join(f'<a href="{phase}/report.html">{phase}</a>' if (DIRECTORY / phase / "report.html").exists()
                         else f'<a href="{phase}/summary.json">{phase} data</a>' for phase in PHASES)
    structure = findings["structural"]["methods"]
    method_rows = "".join(f"<tr><td>{r['method']}</td><td>{r['rank_changes_after_multiplying_one_track_duration_by4']:,}</td>"
                          f"<td>{r['median_driver_before_rank']:,} → {r['after_one_half_time_rank']:,}</td></tr>" for r in structure)
    body = f"""<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Refined Beat my track World Ranking</title><style>body{{font:16px system-ui;max-width:1420px;margin:30px auto;padding:0 24px;color:#192733}}h1{{font-size:30px}}table{{border-collapse:collapse;width:100%;font-size:14px}}td,th{{padding:10px;border-bottom:1px solid #ddd;text-align:left}}aside{{background:#fff0c9;padding:18px}}li{{margin:8px 0}}code{{background:#eef1f4;padding:2px}}</style>
<h1>Refined World Ranking specification and simulation</h1><aside>Selected proposal: one shared worldwide Compact Circuit, five completed tracks, fixed finishing-place points and best 12 results over 26 weeks. Synthetic behavior, not live player or server-capacity evidence.</aside>
<p><a href="../../WORLD_RANKING_SPEC_2026_10_22.md">Read the complete specification</a> · <a href="findings.json">Machine-readable findings</a> · <a href="commands.json">Actual commands and validation</a></p>
<p>{findings['counts']['world_runs']} scenario-and-seed runs of 78 weeks, with {findings['counts']['candidate_world_evaluations']} candidate/world evaluations and {findings['counts']['candidate_weeks']:,} candidate weeks across the iterations. Candidates inside a world share identical race/attendance observations. Seeds are reused between scenarios for controlled comparison; these are not 55 independent statistical samples.</p>
<ul>{decisions}</ul><h2>Selected rules in normal population runs</h2>
<p>Population is synthetic accounts, not simultaneous users. Weekly complete fields are smaller. Figures are final-week seed means; a range is a seed range, not a confidence interval. Similar-skill cohort comparison uses true ability 1.0–1.5; casual attends 65% of weeks and regular 95%, before track completion.</p>
<table><thead><tr><th>Accounts</th><th>Seeds</th><th>Skill and rank correlation</th><th>No. 1s</th><th>Casual/regular points</th><th>New expert weeks to top 1%</th></tr></thead><tbody>{''.join(table)}</tbody></table>
<p>A stricter top-end check reconstructs the initial latent abilities: final leaders were among the strongest {min(strongest)}–{max(strongest)} introduced, nonretired modeled drivers. The world Top 25 overlapped the corresponding latent-skill Top 25 by {min(overlap)*100:.0f}–{max(overlap)*100:.0f}%. World Ranking also rewards earned historical performance and consistency, so exact overlap with current modeled skill is not the objective.</p>
{figure.to_html(full_html=False, include_plotlyjs=True, config={'displaylogo':False})}
<h2>Why these choices</h2><p>Track-place aggregation preserves equal track weight and bounds the contribution of one extreme time. A raw elapsed-time sum changes 9,969 of 10,000 positions when one track is made four times longer; place scoring changes none. Relative-time aggregation also preserves duration invariance, but is more sensitive to a single anomalously fast input.</p>
<table><thead><tr><th>Method</th><th>Changed positions after duration scaling</th><th>Median driver before and after one half-time input</th></tr></thead><tbody>{method_rows}</tbody></table>
<p>The half-time input is a statistical stress, not a claimed verification bypass. Pure percentile awards inflate with slower population padding: the same 1,000th place moves from 729 to 970 points when the field grows from 10,000 to 100,000. The selected full-field schedule keeps the award for an unchanged finishing place fixed.</p>
<p>The initial fixed-place curve gave second place 995 points. The selected podium premium gives 850 while retaining the same smooth tail shape for broad field differentiation. The sharper fourth-root alternative improved some top-end measures but reduced whole-field skill correlation; a single correlation was not treated as the design objective.</p>
<p>Four-track qualification slightly improved completion-driven metrics, but a missing fifth time has a moving last-place penalty as the population changes. Requiring all five finishes keeps one complete Circuit and stronger invariance; the reduced 12-result counting requirement provides flexibility between weeks.</p>
<h2>Selected rules under changed assumptions</h2><table><thead><tr><th>Scenario</th><th>Seeds</th><th>Skill and rank correlation</th><th>Final joint leaders</th></tr></thead><tbody>{''.join(stress)}</tbody></table>
<p>The low-participation stress reduces weekly attendance to 1.5% of its normal rate. Few repeated results cannot establish a strong long-term skill ordering. The specification therefore retains population context and gates prestige milestones; it does not claim a formula can manufacture a mature competitive field.</p>
<p>Two stress seeds produce legitimate joint No. 1s with equivalent worldwide winning records. The separate alternating-champions fixture also produces two No. 1s deliberately. This is permitted by the sporting tie rule.</p>
<h2>Evidence and limits</h2><ul>{limits}</ul><p>All {len(findings['run_checks'])} saved world runs pass independent sequence, bounds, source-fingerprint and applicable expiry checks. Numerical unit tests and strict patch checks are recorded separately in commands.json; no backend, device or cloud tests are implied.</p>
<p>Iteration evidence: {sources}.</p><p>Earlier local-group experiments are retained separately and are not paired race-for-race with this revised generator. Do not interpret differences between those generations as a controlled measured uplift.</p></html>"""
    (DIRECTORY / "report.html").write_text(body, encoding="utf-8")


def checkpoint():
    paths = [ROOT / "scripts/simulate_world_circuit.py", ROOT / "scripts/test_world_circuit_simulation.py",
             Path(__file__), ROOT / "docs/WORLD_RANKING_SPEC_2026_10_22.md"]
    patch = []
    for path in paths:
        relative = path.relative_to(ROOT).as_posix()
        lines = path.read_text(encoding="utf-8").splitlines()
        patch.extend([f"diff --git a/{relative} b/{relative}", "new file mode 100644", "--- /dev/null",
                      f"+++ b/{relative}", f"@@ -0,0 +1,{len(lines)} @@"])
        patch.extend("+" + line for line in lines)
    (DIRECTORY / "task-only.patch").write_bytes(("\n".join(patch) + "\n").encode("utf-8"))
    manifest = {"requirements": ["WRF01", "WRF02", "WRF03", "WRF04", "WRF05", "WRF06", "WRF07", "WRF08"],
        "source_files": {str(p.relative_to(ROOT)): digest(p) for p in paths},
        "unchanged_dependency": {"scripts/simulate_world_ranking.py": digest(ROOT / "scripts/simulate_world_ranking.py")},
        "evidence": {str(p.relative_to(DIRECTORY)): digest(p) for p in DIRECTORY.rglob("*")
                     if p.is_file() and p.name != "checkpoint.json"},
        "scope": "Simulation and refined specification only; existing workspace work preserved."}
    (DIRECTORY / "checkpoint.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint-only", action="store_true")
    args = parser.parse_args()
    if not args.checkpoint_only:
        findings, runs = analyze()
        (DIRECTORY / "findings.json").write_text(json.dumps(findings, indent=2, allow_nan=False), encoding="utf-8")
        write_report(findings, runs)
        print(json.dumps({"counts": findings["counts"], "checks": len(findings["run_checks"]),
                          "narrow_quality": findings["narrow_quality"]}))
    checkpoint()


if __name__ == "__main__":
    main()
