"""Review actual wheel-contact dispatch, rendered contact and own-process output."""
from pathlib import Path
import json
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[1]).resolve()
subprocess.run(
    [sys.executable, str(ROOT / "scripts/review_windows_audio_output.py"), str(OUT)],
    check=True,
    capture_output=True,
)
events = json.loads((OUT / "events.json").read_text())
timings = json.loads((OUT / "timing-report.json").read_text())
assert len(events) == len(timings["rows"]) == 6
checks = 1
rows = []
for event, timing in zip(events, timings["rows"]):
    assert event["trial"] == timing["trial"]
    assert event["request_tick"] == event["contact_tick"]
    assert event["unix_us"] >= event["contact_us"] > 0
    assert event["render_contact_us"] > 0
    assert event["kerb_count"] == 1
    expected = "windows_raw" if event["clip"] == "kerb_entry" else "windows_mix"
    assert event["route"] == expected
    checks += 6
    rows.append({
        "trial": event["trial"],
        "clip": event["clip"],
        "speed_mps": event["speed_mps"],
        "route": event["route"],
        "contact_tick": event["contact_tick"],
        "request_tick": event["request_tick"],
        "render_contact_tick": event["render_contact_tick"],
        "contact_to_request_ms": (event["unix_us"] - event["contact_us"]) / 1000,
        "request_to_output_ms": timing["latency_ms"],
        "contact_to_output_ms": (timing["output_unix_us"] - event["contact_us"]) / 1000,
        "render_contact_to_output_ms": (timing["output_unix_us"] - event["render_contact_us"]) / 1000,
    })
by_clip = {}
for clip in ("kerb_entry", "kerb_roll"):
    selected = [row for row in rows if row["clip"] == clip]
    assert sorted(row["speed_mps"] for row in selected) == [5.0, 15.0, 30.0]
    checks += 1
    by_clip[clip] = {
        "trials": len(selected),
        "median_request_to_output_ms": statistics.median(row["request_to_output_ms"] for row in selected),
        "median_render_contact_to_output_ms": statistics.median(row["render_contact_to_output_ms"] for row in selected),
    }
report = {
    "checks": checks,
    "failures": 0,
    "rows": rows,
    "by_clip": by_clip,
    "limits": "Own-process output; rendered contact is the actual wheel-centre projection at frame_post_draw, not tyre-surface contact, monitor scanout or acoustic output. Entry and rolling are isolated diagnostic controls, using the same production contact and playback methods.",
}
(OUT / "kerb-review.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2))
