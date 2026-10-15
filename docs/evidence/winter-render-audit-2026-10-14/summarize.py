import json
from pathlib import Path
from statistics import mean

root = Path(__file__).resolve().parent
start = root / "start" if (root / "start").is_dir() else root
summary = {"scope": "Desktop attribution; removal bounds are not achievable optimisation percentages", "runs": {}}
for name, directory in [("start", start), ("view1", root / "view1"), ("view1-corrected", root / "view1-corrected")]:
    for renderer in ("gl_compatibility", "mobile"):
        path = directory / renderer / "report.json"
        if not path.exists():
            continue
        report = json.loads(path.read_text(encoding="utf-8"))
        result = {"engine": report["engine"], "device": report["device"], "visual_version": report["visual_version"], "themes": {}}
        for theme, data in report["themes"].items():
            resolutions = {}
            for width in (1920, 3840):
                stages = [s for s in data["stages"] if s["viewport"][0] == width]
                full = [s for s in stages if s["mode"] == "full"]
                if not full:
                    continue
                gpu = mean(s["gpu_ms"]["p50"] for s in full)
                modes = {}
                for stage in stages:
                    modes.setdefault(stage["mode"], []).append(stage)
                resolutions[str(width)] = {
                    "timing_usable": name == "start" or (name == "view1-corrected" and renderer == "gl_compatibility"),
                    "full_gpu_ms": gpu,
                    "full_gpu_samples_ms": [s["gpu_ms"]["p50"] for s in full],
                    "full_gpu_span_percent": (max(s["gpu_ms"]["p50"] for s in full) / min(s["gpu_ms"]["p50"] for s in full) - 1) * 100,
                    "full_draws": [s["draws"] for s in full],
                    "full_primitives": [s["primitives"] for s in full],
                    "modes": {
                        mode: {"gpu_ms": [s["gpu_ms"]["p50"] for s in values],
                               "render_cpu_ms": [s["render_cpu_ms"]["p50"] for s in values],
                               "draws": [s["draws"] for s in values],
                               "primitives": [s["primitives"] for s in values],
                               "difference_percent": (1 - mean(s["gpu_ms"]["p50"] for s in values) / gpu) * 100}
                        for mode, values in modes.items()
                    }
                }
            result["themes"][theme] = {"inventory": data["inventory"], "resolutions": resolutions}
        summary["runs"][name + "/" + renderer] = result
(root / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
for run, data in summary["runs"].items():
    print(run)
    for theme, values in data["themes"].items():
        for width, metrics in values["resolutions"].items():
            print(theme, width, "GPU", round(metrics["full_gpu_ms"], 3), "full drift %", round(metrics["full_gpu_span_percent"], 1))
            if theme == "winter":
                print({mode: [round(mean(value["gpu_ms"]), 3), round(value["difference_percent"], 1)] for mode, value in metrics["modes"].items()})
