"""Reconcile the review's inventories and native comparisons; write summary."""
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
stock = {}
checks = 0
for mode in ["headless", "gl_compatibility", "mobile"]:
    report = json.loads((OUT / (mode + ".json")).read_text())
    assert report["failures"] == 0, mode
    checks += report["checks"]
    for row in report["rows"]:
        if row["case"] != 0:
            continue
        if mode == "headless":
            stock[row["id"]] = row
        else:
            for field in ["triangles", "surfaces", "buffer_bytes", "candidate_bytes", "blend_bytes"]:
                assert row[field] == stock[row["id"]][field], (mode, row["id"], field)
            for view in row["native"]["views"]:
                assert view["packing_pixel_exact"] and view["restoration_pixel_exact"]
components = json.loads((OUT / "driver-components.json").read_text())
static_morph_bytes = sum(row["blend_bytes"] for row in components
                        if row["static_vertex_normal_tangent_arrays"])
assert static_morph_bytes == 495720
receipts = {}
for mode in ["headless", "gl_compatibility", "mobile", "headless-components",
             "gl_compatibility-showroom", "mobile-showroom"]:
    receipt = json.loads((OUT / (mode + "-receipt.json")).read_text())
    assert receipt["exit_code"] == 0, mode
    assert ".git/index" not in receipt["changed_inputs"]
    receipts[mode] = receipt
summary = {"checks": checks, "failures": 0,
           "static_helmet_morph_bytes": static_morph_bytes,
           "stock": [{"id": key, "triangles": row["triangles"], "surfaces": row["surfaces"],
                      "buffer_bytes": row["buffer_bytes"],
                      "packing_saving_bytes": row["buffer_bytes"]-row["candidate_bytes"],
                      "packing_saving_percent": 100*(1-row["candidate_bytes"]/row["buffer_bytes"]),
                      "unused_bytes": row["unused_bytes"], "lod_surfaces": row["lod_surfaces"]}
                     for key, row in stock.items()], "receipts": receipts,
           "qualification": "Review observations only; concurrent input changes are recorded per run. No unified release or device qualification."}
(OUT / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
print(json.dumps({"checks": checks, "failures": 0, "cars": len(stock),
                  "static_helmet_morph_bytes": static_morph_bytes}))
manifest = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(OUT.iterdir()) if path.is_file()
            and path.name not in ["artifact-hashes.json", "review-source.patch"]}
(OUT / "artifact-hashes.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
