"""Summarize the native picture-loading audit without changing runtime sources."""
import hashlib
import json
from pathlib import Path
import statistics

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-picture-loading-audit-2026-11-17"
OUT.mkdir(parents=True, exist_ok=True)
report = {"requirements": ["CPI01", "CPI02", "CPI03"], "renderers": {}}
for renderer in ("gl_compatibility", "mobile"):
    folder = ROOT / "docs/evidence/shared-car-pictures-2026-11-15" / f"{renderer}-loading-audit-final-2026-11-17"
    audit = json.loads((folder / "report.json").read_text(encoding="utf-8"))
    assert audit["checks"] == 254 and audit["failures"] == 0
    summary = {"checks": audit["checks"], "failures": audit["failures"],
               "evidence": str(folder.relative_to(ROOT)), "samples": []}
    for fps in (60, 30):
        for mode in ("current", "batch", "batch-coalesced"):
            samples = [s for s in audit["results"] if s["case"] == "six-cached-files"
                       and s["fps_cap"] == fps and s["mode"] == mode]
            assert len(samples) == 3
            last = [max(e["ms"] for e in s["events"] if e["event"] == "publish") for s in samples]
            selected = [next(e["ms"] for e in s["events"] if e["event"] == "publish") for s in samples]
            summary["samples"].append({
                "fps_cap": fps, "mode": mode, "sample_count": len(samples),
                "last_picture_ms_median": statistics.median(last),
                "last_picture_ms_range": [min(last), max(last)],
                "selected_picture_ms_median": statistics.median(selected),
                "warm_dropdown_ms_median": statistics.median(s["warm_popup_average_ms"] for s in samples),
                "extra_notifications_per_open": samples[0]["warm_popup_extra_notifications"] / 20,
                "peak_cache_process_ms": max(s["peak_cache_process_ms"] for s in samples),
            })
    summary["actual_offline_app"] = next(s for s in audit["results"] if s["case"] == "actual-offline-App")
    # Actual App entries have no mode; filter the case before reading mode.
    summary["dropdown_openings"] = [{"fps_cap": s["fps_cap"], "openings": s["popup_openings"]}
                                   for s in audit["results"] if s["case"] == "six-cached-files"
                                   and s["mode"] == "current" and s["popup_openings"]]
    report["renderers"][renderer] = summary
report["production_source_sha256_at_summary"] = {
    path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
    for path in ("game/core/app.gd", "game/ui/header_car_appearance_cache.gd",
                 "game/ui/header_car_icons.gd", "game/ui/header_car_picker.gd",
                 "game/ui/header_car_motion.gd", "game/ui/garage_shared_pictures.gd",
                 "scripts/build_identity.ps1")
}
report["scope"] = "Audit and fixture-only prototypes; no production change, phone test or whole-startup claim."
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
for renderer, values in report["renderers"].items():
    print(renderer, "checks", values["checks"], "failures", values["failures"])
    for s in values["samples"]:
        print(s["fps_cap"], s["mode"], "last", round(s["last_picture_ms_median"], 2),
              "dropdown", round(s["warm_dropdown_ms_median"], 2), "peak", round(s["peak_cache_process_ms"], 2))
