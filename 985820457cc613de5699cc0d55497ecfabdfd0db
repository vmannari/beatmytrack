"""Reanalyse the retained native race trace; no game or owner data is used."""

import hashlib
import json
import re
from pathlib import Path

here = Path(__file__).resolve().parent
trace = here.parent / "native-shader-preparation-2026-10-28" / "race-trace"
inputs = [trace / "frames.json", trace / "output.log"]
frames = json.loads(inputs[0].read_text(encoding="utf-8"))
calls = []
for line in inputs[1].read_text(encoding="utf-8", errors="replace").splitlines():
    match = re.search(r"NATIVE_CALL api=(\w+) us=(\d+) utc_end_us=(\d+)", line)
    if match and match[1] == "glLinkProgram":
        calls.append((int(match[2]), int(match[3])))

rows = []
for frame in sorted(frames, key=lambda value: value["us"], reverse=True)[:12]:
    end = frame["utc_end_us"]
    begin = end - frame["us"]
    # Hook and frame timestamps share the original probe's calibrated clock.
    overlaps = [duration for duration, call_end in calls
                if min(end, call_end) > max(begin, call_end - duration)]
    rows.append({
        "stage": frame["stage"],
        "status": frame["status"],
        "frame_us": frame["us"],
        "link_calls_overlapping": len(overlaps),
        "longest_full_link_call_us": max(overlaps, default=0),
    })

result = {
    "description": "Additional analysis of an archived 2026-10-28 desktop race trace, not a new run",
    "inputs_sha256": {str(path.relative_to(here.parent)): hashlib.sha256(path.read_bytes()).hexdigest() for path in inputs},
    "link_call_count": len(calls),
    "largest_frames": rows,
}
output = here / "link-frames.json"
output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, indent=2))
