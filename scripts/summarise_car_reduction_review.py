"""Reconcile candidate measurements and retain compact source provenance."""
import gzip
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-reduction-review-2026-11-13"
RUNS = {"inventory-generated": "headless", "axial-compat": "gl_compatibility-axial",
        "axial-mobile": "mobile-axial", "lod-compat": "gl_compatibility",
        "lod-mobile": "mobile", "hover-compat": "gl_compatibility-hover"}
checks = 0
results = {}
receipts = {}
for label, directory in RUNS.items():
    receipt = json.loads((OUT / (label + "-receipt.json")).read_text())
    assert receipt["exit_code"] == 0 and not receipt["errors"], label
    assert receipt["changed_inputs"] == [], label
    data = json.loads((OUT / directory / "inventory.json").read_text())
    assert data["failures"] == 0, label
    assert all(r["vehicle"] != "super_rally" for r in data["rows"])
    checks += data["checks"]
    results[label] = data
    receipts[label] = receipt
inventory = results["inventory-generated"]
summary = {"checks": checks, "failures": 0, "cars": [], "receipts": receipts,
           "scope": "Current stock five-car review; Challenger excluded. Candidates stay in memory.",
           "limits": ["Candidate savings overlap and must not be added.",
                      "LOD labels describe engine local-space metrics, not guaranteed maximum error.",
                      "Stored master counts are not selected runtime LOD or FPS measurements.",
                      "Race-distance shots use the showroom camera, not a simulated Game race.",
                      "No physical-device qualification or production model changes."]}
for car in ["compact", "kart", "forklift", "electric", "hovercraft"]:
    normal = next(r for r in inventory["rows"] if r["vehicle"] == car and r["construction"] == "prepared")
    source = next(r for r in inventory["rows"] if r["vehicle"] == car and r["construction"] == "source")
    baseline = normal["baseline"]["triangles"]
    assert source["baseline"]["triangles"] == baseline
    row = {"vehicle": car, "master_triangles": baseline, "prepared_base_hits": normal["base_hits"],
           "source_surfaces": source["baseline"]["surfaces"], "batched_surfaces": normal["baseline"]["surfaces"],
           "candidates": []}
    for c in source["candidates"] + normal["candidates"]:
        triangles = c["inventory"]["triangles"]
        reference = source if c["mode"] == "axial" else normal
        assert c["inventory"]["surfaces"] == reference["baseline"]["surfaces"]
        item = {"mode": c["mode"], "triangles": triangles, "saved_triangles": baseline - triangles,
                "saved_percent": 100 * (baseline - triangles) / baseline, "native": {}}
        for renderer in ["compat", "mobile"]:
            native = results[("axial-" if c["mode"] == "axial" else "lod-") + renderer]
            native_car = next(r for r in native["rows"] if r["vehicle"] == car)
            measured = next(x for x in native_car["candidates"] if x["mode"] == c["mode"])
            assert measured["inventory"]["triangles"] == triangles
            observations = measured["views"]
            assert all(v["repeat"]["significant_pixels"] == 0 and v["restored"]["significant_pixels"] == 0 for v in observations)
            item["native"][renderer] = {"maximum_significant_pixels": max(v["difference"]["significant_pixels"] for v in observations),
                                          "maximum_rgb_mae_255": max(v["difference"]["rgb_mae_255"] for v in observations)}
        row["candidates"].append(item)
    summary["cars"].append(row)
summary["hover_details"] = [{"mode": c["mode"], "triangles": c["inventory"]["triangles"],
                             "views": c["views"]} for c in results["hover-compat"]["rows"][0]["candidates"]]
# Retain each original source pin manifest as compressed bytes. This removes
# only task-owned redundant uncompressed copies after byte-exact verification.
pin_manifest = {}
for path in sorted(OUT.glob("*-source-before.json")):
    content = path.read_bytes()
    target = path.with_suffix(path.suffix + ".gz")
    target.write_bytes(gzip.compress(content, compresslevel=9, mtime=0))
    assert gzip.decompress(target.read_bytes()) == content
    pin_manifest[path.name] = {"compressed": target.name, "logical_sha256": hashlib.sha256(content).hexdigest()}
    path.unlink()
if pin_manifest:
    (OUT / "compressed-source-pins.json").write_text(json.dumps(pin_manifest, indent=2))
(OUT / "summary.json").write_text(json.dumps(summary, indent=2))
print(json.dumps({"checks": checks, "failures": 0, "prepared_base_hits": sum(r["prepared_base_hits"] for r in summary["cars"]),
                  "axial_saved_triangles": sum(r["candidates"][0]["saved_triangles"] for r in summary["cars"])}))
