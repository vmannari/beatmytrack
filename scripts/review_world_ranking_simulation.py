"""Reconcile completed offline runs, check evidence, and annotate the HTML report."""
from __future__ import annotations

import argparse
import hashlib
import html
import json
from pathlib import Path

import numpy as np
import plotly.graph_objects as go

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "docs/evidence/world-ranking-simulation-2026-10-22"


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def analyze():
    scenarios = {}
    assertions = []
    probe_events = []
    for label, folder in [("main", DIRECTORY), ("million", DIRECTORY / "million"),
                          ("narrow", DIRECTORY / "narrow"), ("sparse", DIRECTORY / "sparse")]:
        summary = load(folder / "summary.json")
        runs = [load(p) for p in sorted(folder.glob("run-*.json"))]
        scenarios[label] = {"comparison": summary["comparison"], "runs": []}
        for run in runs:
            config = run["config"]
            policies = config["policies"]
            for week in range(1, config["weeks"] + 1):
                rows = [r for r in run["weekly"] if r["week"] == week]
                assert len(rows) == len(policies)
                for key in ["joined", "qualified", "ranked", "groups", "small_fields", "no_award_fields"]:
                    assert len({row[key] for row in rows}) == 1, (label, config["seed"], week, key)
                if "smooth" in policies and "circuit_tiebreak" in policies:
                    values = [r["leader_points"] for r in rows if r["policy"] in ("smooth", "circuit_tiebreak")]
                    assert values[0] == values[1]
            checks = run["checks"]
            assert checks["weeks"] == config["weeks"]
            assert checks["maximum_group_size"] <= 20
            assert checks["maximum_weekly_award"] <= 5000
            assert checks["maximum_rolling_points"] <= 80000
            assert checks["awards_to_incomplete_players"] == 0
            assertions.append({"scenario": label, "population": config["population"],
                "seed": config["seed"], "weeks": config["weeks"], "result": "passed",
                "checks": ["same entrants and races across policies", "complete weekly records",
                    "group cap", "award and rolling bounds", "no incomplete award",
                    "circuit tiebreak preserves smooth leader total"]})
            original_rows = [r for r in run["weekly"] if r["policy"] == "proposed"]
            scenarios[label]["runs"].append({"config": config, "timing": run["timing"],
                "fields_below5_pct": sum(r["no_award_fields"] for r in original_rows)
                    / max(sum(r["groups"] for r in original_rows), 1) * 100,
                "fields_below10_pct": sum(r["small_fields"] for r in original_rows)
                    / max(sum(r["groups"] for r in original_rows), 1) * 100})
            if label == "main":
                for policy in policies:
                    for name in ["new_expert_week_53", "elite_stops_after_39", "strong_13_week_break"]:
                        trace = [r for r in run["traces"] if r["policy"] == policy and r["player"] == name]
                        last = trace[-1]
                        event = {"population": config["population"], "seed": config["seed"],
                            "policy": policy, "player": name, "final_rank": last["rank"],
                            "final_points": last["points"], "final_rank_percentile": last["rank_percentile"]}
                        if name == "new_expert_week_53":
                            event["weeks_until_top1pct"] = next((r["week"] - 52 for r in trace
                                if r["week"] >= 53 and r["rank_percentile"] is not None
                                and r["rank_percentile"] <= 1), None)
                            event["weeks_until_top100"] = next((r["week"] - 52 for r in trace
                                if r["week"] >= 53 and 0 < r["rank"] <= 100), None)
                        if name == "elite_stops_after_39":
                            last_award = max((r["week"] for r in trace if r["earned"] > 0), default=None)
                            first_zero = next((r["week"] for r in trace if r["week"] >= 40
                                               and r["points"] == 0), None)
                            event.update(last_award_week=last_award, first_unranked_week=first_zero)
                            if last_award is not None and first_zero is not None:
                                assert first_zero == last_award + 26
                        probe_events.append(event)
    attendance = []
    main_runs = [load(p) for p in sorted(DIRECTORY.glob("run-*.json"))]
    for size in [10_000, 100_000]:
        for policy in main_runs[0]["config"]["policies"]:
            for cohort in ["regular", "casual", "infrequent"]:
                rows = [row for run in main_runs if run["config"]["population"] == size
                        for row in run["attendance"] if row["policy"] == policy and row["cohort"] == cohort]
                attendance.append({"population": size, "policy": policy, "cohort": cohort,
                    "seeds": len(rows), "players": sum(r["players"] for r in rows),
                    "mean_of_seed_median_points": float(np.mean([r["median_points"] for r in rows])),
                    "mean_of_seed_median_rank_percentile": float(np.mean([r["median_rank_percentile"] for r in rows])),
                    "mean_of_seed_median_skill": float(np.mean([r["median_skill"] for r in rows])),
                    "mean_of_seed_median_completed_weeks": float(np.mean([r["median_awarded_weeks_last26"] for r in rows]))})
    result = {"requirements": {"WRS01": "reproducible 78-week population simulation",
        "WRS02": "rank behavior, newcomers, inactivity, attendance and skill changes",
        "WRS03": "paired scoring variants and population/matching sensitivities",
        "WRS04": "raw artifacts, explicit assumptions, actual local timings",
        "Q01": "behavioral tests, independent evidence checks, offline report and scoped checkpoint"},
        "scenarios": scenarios, "evidence_assertions": assertions, "probe_events": probe_events,
        "attendance_comparison": attendance, "incentives": load(DIRECTORY / "incentives.json"),
        "conclusions": [
            "Best-16/26 expiry is bounded and correctly retires inactive results in this model.",
            "Fixed top-tier winner awards can saturate: identical 16-win records cannot be resolved by result countback alone.",
            "A shared-circuit sporting tiebreak resolves ceiling ties in the tested main runs while preserving the smooth policy's points.",
            "Narrow matching reveals cross-group unfairness: a tiebreak is insufficient when tiers cover substantially different opponent strength.",
            "The exploratory 40% worldwide pace component improves broad skill correlation, but is not uniformly superior at the top and is not a validated final design.",
            "Attendance still matters substantially below 16 completed weeks. All-five-track eligibility makes 65% attendance yield approximately 14.5 complete weeks per 26 in expectation.",
            "One-week routing stresses show possible rewards for easier opposition if admission controls fail; no live exploit or long-run strategy was tested.",
            "Do not ship the proposed payouts unchanged. Next balance experiment should calibrate continuous field strength and/or official worldwide circuit awards.",
        ], "limitations": [
            "Synthetic performance, attendance and tier boundaries are not calibrated to real players.",
            "One shared car and track circuit; multi-car normalization and the existing resume-policy decision are unresolved.",
            "EWMA shared-pace rating proxy, not OpenSkill or the current live PB matcher.",
            "Million-player original-rules run has one seed; alternatives were tested at 10k and 100k, not one million.",
            "Matching and sparse sensitivities each have one seed; these expose risks, not population forecasts.",
            "Local analysis timings include synthetic race generation and metrics, exclude SQL/HTTP/cloud, and some sensitivity/main runs overlapped.",
            "No phone attachment check, device test, gameplay change, backend/account mutation or deployment.",
        ]}
    return result


def annotate_report(result):
    comparisons = result["scenarios"]["main"]["comparison"]
    ceiling_rows = []
    for size in [10_000, 100_000]:
        for policy in ["proposed", "smooth", "circuit_tiebreak"]:
            row = next(r for r in comparisons if r["population"] == size and r["policy"] == policy)
            ceiling_rows.append(f"<tr><td>{size:,}</td><td>{policy}</td><td>{row['seeds']}</td>"
                f"<td>{row['joint_world_no1']['min']:.0f}–{row['joint_world_no1']['max']:.0f}</td></tr>")
    million = result["scenarios"]["million"]["comparison"][0]
    ceiling_rows.append(f"<tr><td>1,000,000</td><td>proposed</td><td>1</td>"
                       f"<td>{million['joint_world_no1']['mean']:,.0f}</td></tr>")
    conclusions = "".join(f"<li>{html.escape(c)}</li>" for c in result["conclusions"])
    overview = f"""<!-- analysis-start --><h2>Result: keep the rolling window; rebalance the awards</h2>
<p>The experiment covers six main 78-week runs (three seeds each at 10,000 and 100,000 accounts), one 78-week million-account baseline, and separate narrow-matching and sparse-population stresses. Counts are registered synthetic accounts; weekly participation is lower.</p>
<table><thead><tr><th>Accounts</th><th>Rules</th><th>Seeds</th><th>Players sharing World No. 1 at week 78</th></tr></thead><tbody>{''.join(ceiling_rows)}</tbody></table>
<ul>{conclusions}</ul><p><a href="findings.json">Complete findings and checks</a> · <a href="million/summary.json">Million-player evidence</a> · <a href="narrow/summary.json">Narrow-group sensitivity</a> · <a href="sparse/summary.json">Sparse-field sensitivity</a></p><!-- analysis-end -->"""
    path = DIRECTORY / "report.html"
    report = path.read_text(encoding="utf-8")
    if "<!-- analysis-start -->" in report:
        before, rest = report.split("<!-- analysis-start -->", 1)
        _, after = rest.split("<!-- analysis-end -->", 1)
        report = before + after
    if "<!-- sensitivity-start -->" in report:
        before, rest = report.split("<!-- sensitivity-start -->", 1)
        _, after = rest.split("<!-- sensitivity-end -->", 1)
        report = before + after
    marker = "</aside>"
    report = report.replace(marker, marker + overview, 1)
    figure = go.Figure()
    for scenario, name in [("main", "Ten broad matching bands"), ("narrow", "Narrow matching bands")]:
        values = [r for r in result["scenarios"][scenario]["comparison"] if r["population"] == 100_000]
        figure.add_trace(go.Bar(name=name, x=[r["policy"] for r in values],
            y=[r["top100_skill_top1pct_share"]["mean"] * 100 for r in values]))
    figure.update_layout(template="plotly_white", height=440, barmode="group",
                         title="Sensitivity: how much of the Top 100 comes from the most skilled 1%?",
                         yaxis_title="Percent of Top 100", xaxis_title="Scoring policy")
    sensitivity = ("<!-- sensitivity-start -->"
                   + figure.to_html(full_html=False, include_plotlyjs=False, config={"displaylogo": False})
                   + "<!-- sensitivity-end -->")
    report = report.replace("<h2>Assumptions and scope</h2>", sensitivity + "<h2>Assumptions and scope</h2>", 1)
    path.write_text(report, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint-only", action="store_true", help="Refresh hashes/patch without regenerating the checked report.")
    args = parser.parse_args()
    if args.checkpoint_only:
        result = load(DIRECTORY / "findings.json")
    else:
        result = analyze()
        (DIRECTORY / "findings.json").write_text(json.dumps(result, indent=2, allow_nan=False), encoding="utf-8")
        annotate_report(result)
    files = [ROOT / "scripts/simulate_world_ranking.py", ROOT / "scripts/test_world_ranking_simulation.py",
             Path(__file__)]
    patch = []
    for path in files:
        name = path.relative_to(ROOT).as_posix()
        lines = path.read_text(encoding="utf-8").splitlines()
        patch.extend([f"diff --git a/{name} b/{name}", "new file mode 100644",
                      "--- /dev/null", f"+++ b/{name}", f"@@ -0,0 +1,{len(lines)} @@"])
        patch.extend("+" + line for line in lines)
    (DIRECTORY / "task-only.patch").write_bytes(("\n".join(patch) + "\n").encode("utf-8"))
    manifest = {"requirements": result["requirements"], "source_files": {
        str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
        "evidence_files": {str(p.relative_to(DIRECTORY)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(DIRECTORY.rglob("*")) if p.is_file() and p.name != "checkpoint.json"},
        "scope": "Offline simulation and evidence only; all existing workspace modifications preserved."}
    (DIRECTORY / "checkpoint.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps({"evidence_runs_checked": len(result["evidence_assertions"]),
                      "findings": str(DIRECTORY / "findings.json"), "report": str(DIRECTORY / "report.html")}))


if __name__ == "__main__":
    main()
