"""Reconcile CTR observations and create native comparison sheets."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-triangle-review-2026-11-14"
NAMES = {"compact": "Rally", "kart": "Kart", "forklift": "Forklift", "electric": "Volt",
         "hovercraft": "Hover", "super_rally": "Challenger"}


def difference(a: Path, b: Path) -> dict:
    metrics = json.loads((OUT / "pixel-metrics.json").read_text(encoding="utf-8-sig"))
    return metrics[f"{b.parent.name}/{b.name}"]


def main() -> None:
    inventory = json.loads((OUT / "inventory-final.json").read_text())
    result = {"inventory_cases": len(inventory["rows"]), "inventory_failures": inventory["failures"],
              "renderers": {}, "notes": [
                  "Candidate metrics are engine local-space error keys, not certified displacement bounds.",
                  "Master comparisons disable car LODs; production/bias comparisons keep automatic LODs.",
                  "Viewport primitives include the studio. Differences change only car LOD bias.",
                  "No frame time, FPS, device memory or owner appearance acceptance is established."]}
    for renderer in ("gl_compatibility", "mobile"):
        path = OUT / renderer / "native.json"
        if not path.exists():
            continue
        data = json.loads(path.read_text())
        directory = path.parent
        rows = []
        for row in data["rows"]:
            samples = []
            for view in row["views"]:
                baseline = directory / view["master"]["image"]
                production = directory / view["production"]["image"]
                samples.append({"view": view["view"],
                                "restoration": difference(baseline, directory / view["restored"]["image"]),
                                "master_primitives": view["master"]["primitives"],
                                "production_primitives": view["production"]["primitives"],
                                "bias_levels": [{**level, "saved_primitives": view["production"]["primitives"]-level["primitives"],
                                                 "difference": difference(production, directory / level["image"])}
                                                for level in view["lod_levels"]]})
            candidates = []
            for variant in row["candidates"]:
                candidates.append({"level": variant["level"], "metric": variant["metric"],
                                   "triangles": variant["triangles"], "surfaces": variant["surfaces"],
                                   "saving_percent": round(100*(1-variant["triangles"]/row["baseline"]["triangles"]), 3),
                                   "views": [{"view": view["view"],
                                              "difference": difference(directory / view["master"]["image"], directory / capture["image"])}
                                             for view, capture in zip(row["views"], variant["captures"])]})
            rows.append({"vehicle": row["vehicle"], "name": NAMES[row["vehicle"]],
                         "triangles": row["baseline"]["triangles"], "surfaces": row["baseline"]["surfaces"],
                         "mesh_bytes": row["baseline"]["buffer_bytes"], "base_hits": row["base_hits"],
                         "candidates": candidates, "native_views": samples})
        result["renderers"][renderer] = {"checks": data["checks"], "failures": data["failures"], "cars": rows}
    (OUT / "summary.json").write_text(json.dumps(result, indent=2)+"\n")
    for renderer, content in result["renderers"].items():
        print(renderer, "checks", content["checks"], "failures", content["failures"])
        for row in content["cars"]:
            print(row["name"], "master", row["triangles"],
                  "candidates", [(v["triangles"], v["saving_percent"], max(x["difference"]["pixels_over_8"] for x in v["views"])) for v in row["candidates"]],
                  "restoration_peak", max(v["restoration"]["max_delta_255"] for v in row["native_views"]))


if __name__ == "__main__":
    main()
