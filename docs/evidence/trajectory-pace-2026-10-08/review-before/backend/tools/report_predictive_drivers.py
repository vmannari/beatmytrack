"""Independently verify the recorded corpus and export a reproducible report."""
import argparse
import csv
import gzip
import html
import json
import statistics
from pathlib import Path
from types import SimpleNamespace

from bmt_backend.verifier import GodotVerifier


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--project", type=Path, required=True)
    args = parser.parse_args()
    source = json.loads(args.report.read_text(encoding="utf-8"))
    baseline = json.loads((args.evidence / "baseline.json").read_text(encoding="utf-8"))
    old = {row["name"]: row for row in baseline["results"]}
    verifier = GodotVerifier(SimpleNamespace(godot_bin=args.godot, game_project=args.project,
                                            verifier_timeout_seconds=90))
    compared = []
    try:
        for row in source["results"]:
            assert row["finished"] and row["laps"] == 5, row["name"]
            proof = verifier.verify_run(row["document"], row["replay"], "compact")
            assert proof["time_ticks"] == row["ticks"] and len(proof["lap_ticks"]) == 5, row["name"]
            assert proof["manifest"] == row["manifest"] == old[row["name"]]["manifest"], row["name"]
            previous = old[row["name"]]
            compared.append({"name": row["name"], "old_finished": previous["finished"],
                             "old_ticks": previous["ticks"], "new_ticks": row["ticks"],
                             "old_contacts": previous["collisions"], "new_contacts": row["collisions"],
                             "gain_percent": 100*(previous["ticks"]-row["ticks"])/previous["ticks"]
                                             if previous["finished"] else None,
                             "verified_lap_ticks": proof["lap_ticks"], "tracking": row["tracking"]})
            print("VERIFIED", row["name"], row["ticks"], flush=True)
    finally:
        verifier.close()
    summary = {"baseline_finished": sum(r["finished"] for r in baseline["results"]),
               "final_finished": len(compared), "independently_verified": len(compared),
               "median_improvement_percent": statistics.median(r["gain_percent"] for r in compared
                                                               if r["gain_percent"] is not None),
               "old_contacts": sum(r["old_contacts"] for r in compared),
               "new_contacts": sum(r["new_contacts"] for r in compared), "results": compared}
    (args.evidence / "verified-summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    with gzip.open(args.evidence / "verified-recordings.json.gz", "wt", encoding="utf-8") as saved:
        json.dump(source, saved, separators=(",", ":"))
    with (args.evidence / "comparison.csv").open("w", newline="", encoding="utf-8") as saved:
        writer = csv.writer(saved)
        writer.writerow(["track", "old_finished", "old_seconds", "new_seconds", "gain_percent",
                         "old_contacts", "new_contacts", "line_rms_m"])
        for row in compared:
            writer.writerow([row["name"], row["old_finished"], row["old_ticks"]/120,
                             row["new_ticks"]/120, row["gain_percent"], row["old_contacts"],
                             row["new_contacts"], row["tracking"]["rms_m"]])
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="1040" viewBox="0 0 1000 1040">',
           '<rect width="1000" height="1040" fill="#fafafa"/>',
           '<g font-family="Arial,sans-serif" fill="#172238">',
           '<text x="28" y="35" font-size="22">Five-lap artificial-driver benchmark — 27 tracks</text>',
           '<text x="28" y="61" font-size="14">Same canonical manifests; final inputs independently verified. Gray: old, gold: predictive.</text>']
    maximum = max(r["old_ticks"] for r in compared)
    for i, row in enumerate(compared):
        y = 88+i*33
        svg.append(f'<text x="28" y="{y+15}" font-size="14">{html.escape(row["name"])}</text>')
        if row["old_finished"]:
            svg.append(f'<rect x="205" y="{y}" width="{row["old_ticks"]/maximum*590:.2f}" height="10" fill="#86909f"/>')
        else:
            svg.append(f'<text x="205" y="{y+9}" font-size="11">Old driver did not finish</text>')
        svg.append(f'<rect x="205" y="{y+13}" width="{row["new_ticks"]/maximum*590:.2f}" height="10" fill="#dba92b"/>')
        label = f'{row["new_ticks"]/120:.2f}s'
        if row["gain_percent"] is not None:
            label += f' ({abs(row["gain_percent"]):.1f}% {"faster" if row["gain_percent"]>=0 else "slower"})'
        svg.append(f'<text x="805" y="{y+20}" font-size="12">{label}</text>')
    svg.extend([f'<text x="28" y="1015" font-size="14">Median {summary["median_improvement_percent"]:.1f}% faster; recorded contacts {summary["old_contacts"]} → {summary["new_contacts"]}. Desktop only.</text>', '</g></svg>'])
    (args.evidence / "comparison.svg").write_text("\n".join(svg), encoding="utf-8")
    slim = {"results": [{k: v for k, v in row.items() if k not in ("document", "replay")}
                        for row in source["results"]]}
    (args.evidence / "final-telemetry.json").write_text(json.dumps(slim, separators=(",", ":")), encoding="utf-8")
    print(json.dumps({k: v for k, v in summary.items() if k != "results"}))


if __name__ == "__main__":
    main()
