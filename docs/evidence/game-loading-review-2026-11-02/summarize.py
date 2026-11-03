"""Derive stage timings from raw runs; reject failed or changing-source runs."""
import json
from pathlib import Path

folder = Path(__file__).resolve().parent
summary = {"startup": [], "races": [], "resources": [], "checks": 0, "failures": 0}
for label in ("startup-stock-v2", "startup-custom-foreground", "startup-custom-cached",
              "race-compat", "race-mobile", "resources-app", "resources-parts"):
    data = json.loads((folder / (label + ".json")).read_text())
    receipt = json.loads((folder / (label + "-receipt.json")).read_text())
    assert receipt["exit_code"] == 0 and not receipt["changed_sources"], label
    assert data.get("failures", 0) == 0, label
    summary["checks"] += data.get("checks", 0)
    if label.startswith("startup"):
        marks = {row["name"]: row["us"] for row in data["marks"]}
        row = {key: value for key, value in data.items() if key != "marks"}
        row.update(label=label, header_ms=(marks["garage_pictures_begin"]-marks["header_begin"])/1000,
                   garage_pictures_ms=(marks["final_screen_begin"]-marks["garage_pictures_begin"])/1000)
        summary["startup"].append(row)
    elif label.startswith("race"):
        rows = []
        for sample in data["samples"]:
            marks = {row["name"]: row["us"] for row in sample["marks"]}
            row = {key: sample[key] for key in ("theme", "cycle", "wall_ms", "max_frame_ms", "retry_ms", "effect_counts", "world_costs")}
            for key, begin, end in (("roads_ms", "roads_begin", "roads_end"),
                                    ("game_ms", "game_begin", "game_end"),
                                    ("graphics_ms", "graphics_begin", "graphics_end"),
                                    ("effects_ms", "effects_begin", "effects_end")):
                row[key] = (marks[end]-marks[begin])/1000
            rows.append(row)
        summary["races"].append({"label": label, "rows": rows, "cache_events": [
            {"case": event["case"], "state": event["state"], "telemetry": event["telemetry"]}
            for event in data["cache_events"]]})
    else:
        assert all(row["ok"] for row in data["rows"]), label
        summary["resources"].append({"label": label, "rows": data["rows"]})
(folder / "summary.json").write_text(json.dumps(summary, indent=2)+"\n")
print("Checks:", summary["checks"], "Failures:", summary["failures"])
for row in summary["startup"]:
    print(row["label"], "load", round(row["shipping_scene_load_ms"]), "ready", round(row["app_ready_ms"]),
          "header", round(row["header_ms"]), "garage", round(row["garage_pictures_ms"]))
for run in summary["races"]:
    for row in run["rows"]:
        print(run["label"], row["theme"], row["cycle"], "total", round(row["wall_ms"]),
              "roads", round(row["roads_ms"]), "game", round(row["game_ms"]),
              "graphics", round(row["graphics_ms"]), "effects", round(row["effects_ms"]))
for run in summary["resources"]:
    print(run["label"], run["rows"])
