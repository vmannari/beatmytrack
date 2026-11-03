"""Derive review tables and verification receipts from completed raw runs."""
import hashlib
import json
from pathlib import Path

folder = Path(__file__).resolve().parent
summary = {"checks": 0, "failures": 0, "race_entries": 0, "retries": 0, "runs": []}
for name in ("compat-three-themes", "mobile", "compat"):
    data = json.loads((folder / (name + ".json")).read_text(encoding="utf-8"))
    receipt = json.loads((folder / (name + "-receipt.json")).read_text(encoding="utf-8"))
    assert receipt["exit_code"] == 0
    changed = [p for p in receipt["before"] if receipt["before"][p] != receipt["after"][p]]
    if name != "compat":
        assert not changed, name + " primary measured sources changed"
    assert data["failures"] == 0 and not data["headless"]
    summary["checks"] += data["checks"]
    summary["failures"] += data["failures"]
    summary["race_entries"] += len(data["samples"])
    rows = []
    for row in data["samples"]:
        marks = {x["name"]: x["us"] for x in row["marks"]}
        durations = {stage: (marks[end] - marks[start]) / 1000 for stage, start, end in [
            ("selected_wait_ms", "selected_wait_begin", "selected_wait_end"),
            ("roads_ms", "roads_begin", "roads_end"),
            ("game_ms", "game_begin", "game_end"),
            ("world_graphics_ms", "graphics_begin", "graphics_end"),
            ("effects_finish_ms", "effects_begin", "effects_end")]}
        row_out = {k: row[k] for k in ("theme", "cycle", "wall_ms", "max_frame_ms", "draw_groups", "effect_counts")}
        row_out.update(durations)
        if "retry_ms" in row:
            row_out["retry_ms"] = row["retry_ms"]
            summary["retries"] += 1
        rows.append(row_out)
    summary["runs"].append({"name": name, "checks": data["checks"], "renderer": data["renderer"], "changed_sources": changed, "rows": rows,
                            "cache_events": data.get("cache_events", [])})
summary["evidence_sha256"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in sorted(folder.iterdir()) if p.suffix in (".json", ".log", ".txt", ".py")
                              and p.name != "summary.json"}
(folder / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: summary[k] for k in ("checks", "failures", "race_entries", "retries")}))
for run in summary["runs"]:
    print(run["name"])
    for row in run["rows"]:
        print(row["theme"], row["cycle"], "total", round(row["wall_ms"]), "roads", round(row["roads_ms"]),
              "game", round(row["game_ms"]), "graphics", round(row["world_graphics_ms"]),
              "effects", round(row["effects_finish_ms"]), "retry", row.get("retry_ms", "unmeasured"))
