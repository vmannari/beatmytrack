"""Collect the implementation's actual receipts without conflating bytes and timings."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-loading-improvements-2026-11-13"
IDS = ["compact", "kart", "forklift", "electric", "hovercraft"]


def read(name):
    return json.loads((OUT / name).read_text(encoding="utf-8-sig"))


def gate(label):
    receipt = read(label + "-receipt.json")
    assert receipt["exit_code"] == 0 and not receipt["errors"], label
    return {"label": label, "exit_code": 0, "seconds": receipt["seconds"],
            "concurrent_input_changes": receipt["changed_inputs"]}


def main():
    before, after = read("before-assets.json"), read("after-assets.json")
    assets = []
    for car in IDS:
        a = next(r for r in before if r["id"] == car and r["quality"] == "simple" and r["mode"] == "fixed")
        b = next(r for r in after if r["id"] == car and r["quality"] == "simple" and r["mode"] == "fixed")
        assets.append({"vehicle": car, "before": a, "after": b,
                       "raw_saving_bytes": a["raw_bytes"] - b["raw_bytes"],
                       "dependency_saving_bytes": a["disk_dependency_bytes"] - b["disk_dependency_bytes"]})
    native = {}
    for renderer in ["gl_compatibility", "mobile"]:
        data = read("paired/" + renderer + "/report.json")
        assert data["failures"] == 0 and len(data["rows"]) == 30
        native[renderer] = {"checks": data["checks"], "failures": 0, "pairs": 30,
                            "exact_pairs": sum(r["exact"] for r in data["rows"]),
                            "worst_mean_255": max(r["mean_255"] for r in data["rows"]),
                            "worst_significant_pixels": max(r["significant_pixels"] for r in data["rows"]),
                            "worst_max_delta": max(r["max_delta"] for r in data["rows"])}
    labels = ["native-final-gl_compatibility", "native-mobile-stable",
              "app-clean-gl_compatibility", "app-clean-mobile", "driver-current",
              "dependencies-current", "driving", "kart-contact", "production-final",
              "handoff-prepared", "wash-scoped-final"] + ["modules-final-" + c for c in IDS]
    gates = [gate(label) for label in labels]
    modules = {}
    for car in IDS:
        log = (OUT / ("modules-final-" + car + ".log")).read_text(encoding="utf-8")
        match = re.search(r"MODULAR_CAR_ASSETS: (\d+) checks, (\d+) failures", log)
        assert match and match[2] == "0", car
        modules[car] = int(match[1])
    timings = []
    for file in sorted((OUT / "after").glob("loading-*.json")):
        data = json.loads(file.read_text())
        assert data["failures"] == 0 and len(data["samples"]) == 2
        assert all(s["base_hits"] == 1 for s in data["samples"]), file
        timings.append({"file": file.relative_to(OUT).as_posix(), "vehicle": data["vehicle"],
                        "fitted": data["fitted"], "track": data["track"],
                        "startup_ms": data["startup_ms"],
                        "first_race_ms": data["samples"][0]["race_wall_ms"],
                        "repeat_race_ms": data["samples"][1]["race_wall_ms"],
                        "first_car_ms": data["samples"][0]["game_costs"]["car_us"] / 1000,
                        "repeat_car_ms": data["samples"][1]["game_costs"]["car_us"] / 1000,
                        "driver_cached": data["samples"][0]["driver_cached"]})
    assert {r["vehicle"] for r in timings} == set(IDS)
    result = {"scope": IDS, "challenger_authored": False, "assets": assets,
              "raw_saving_bytes": sum(r["raw_saving_bytes"] for r in assets),
              "dependency_saving_bytes": sum(r["dependency_saving_bytes"] for r in assets),
              "driver_partition": {"before_bytes": 905304, "after_bytes": 583776,
                                   "saving_bytes": 321528, "poses": 10, "triangles": 6456,
                                   "static_triangles": 2761, "additional_draws": 1},
              "native": native, "modules": modules, "module_checks": sum(modules.values()),
              "gates": gates, "timings": timings,
              "limits": ["Desktop RTX 3090; existing OS/import/driver caches; no Android measurements.",
                         "Concurrent world/contact/finish work prevents attributing total timing changes solely to this pass.",
                         "Raw stream bytes and stored dependency bytes are not process RAM or measured VRAM.",
                         "Strict universal pixel identity was not achieved; unchanged existing vehicle appearance bounds pass.",
                         "Challenger publication is excluded; no full-catalogue/device/export qualification is claimed."]}
    (OUT / "summary.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: result[k] for k in ["raw_saving_bytes", "dependency_saving_bytes", "module_checks"]}))


if __name__ == "__main__":
    main()
