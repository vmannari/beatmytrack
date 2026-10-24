"""Compare the original and corrected footprint observers and real Windows hits."""
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/compact-bridge-impact-2026-10-23"
CAPTURE = ROOT / "build/windows-contact-timing-2026-10-23/bridge-original-fixed-r1/bridge"
before = json.loads((OUT / "baseline/matrix.json").read_text())
after = json.loads((OUT / "fixed/matrix.json").read_text())
assert len(before["rows"]) == len(after["rows"]) == 168
checks = 1
corrected = []
remaining = []
missed_before = 0
for index, (old, new) in enumerate(zip(before["rows"], after["rows"])):
    for key in ("span", "kind", "side", "u", "initial_speed", "physical", "eligible", "full_touch"):
        assert old[key] == new[key], (index, key)
        checks += 1
    assert old["equivalent"] and new["equivalent"]
    assert new["cue_count"] <= 1
    checks += 2
    if new["eligible"] >= 0:
        assert new["cue"] >= 0
        checks += 1
        if old["cue"] < 0:
            missed_before += 1
        else:
            assert new["cue"] <= old["cue"], index
            checks += 1
        if old["cue"] < 0 or old["cue"] > new["cue"]:
            corrected.append({"index": index, "before_tick": old["cue"], "after_tick": new["cue"], "eligible_tick": new["eligible"]})
        if new["cue"] > new["eligible"] + 1:
            remaining.append({"index": index, "ticks_after_dense_reference": new["cue"] - new["eligible"]})
    elif new["physical"] < 0:
        assert new["cue_count"] == old["cue_count"] == 0
        checks += 1
for outline in after["outlines"]:
    assert outline["unique_probes"] <= 128
    checks += 1
subprocess.run(
    [sys.executable, str(ROOT / "scripts/review_windows_audio_output.py"), str(CAPTURE)],
    check=True, capture_output=True,
)
events = json.loads((CAPTURE / "events.json").read_text())
timings = json.loads((CAPTURE / "timing-report.json").read_text())["rows"]
assert len(events) == len(timings) == 6
checks += 1
native = []
for index in range(0, 6, 2):
    old, new = events[index:index + 2]
    old_output, new_output = timings[index:index + 2]
    assert old["original_method"] and not new["original_method"]
    assert old["speed_mps"] == new["speed_mps"]
    assert old["route"] == new["route"] == "windows_raw"
    assert old["cue_count"] == new["cue_count"] == 1
    assert old["physical_tick"] == new["physical_tick"]
    assert old["cue_tick"] == old["physical_tick"]
    assert new["cue_tick"] < new["physical_tick"]
    checks += 7
    old_delay = (old_output["output_unix_us"] - old["render_contact_us"]) / 1000
    new_delay = (new_output["output_unix_us"] - new["render_contact_us"]) / 1000
    assert new_delay < old_delay
    checks += 1
    native.append({
        "speed_mps": old["speed_mps"],
        "original_cue_tick": old["cue_tick"],
        "corrected_cue_tick": new["cue_tick"],
        "physical_tick": old["physical_tick"],
        "original_render_contact_to_output_ms": old_delay,
        "corrected_render_contact_to_output_ms": new_delay,
        "original_request_to_output_ms": old_output["latency_ms"],
        "corrected_request_to_output_ms": new_output["latency_ms"],
    })
report = {
    "checks": checks, "failures": 0,
    "matrix_cases": len(after["rows"]), "eligible_cases": sum(r["eligible"] >= 0 for r in after["rows"]),
    "missed_eligible_before": missed_before, "missed_eligible_after": 0,
    "corrected_cases": corrected, "remaining_dense_reference_gaps": remaining,
    "outlines": after["outlines"], "native_original_corrected_pairs": native,
    "limits": "Current sampled perimeter retains 0.25 m target spacing and the same 128-probe ceiling. Dense 0.05 m reference can lead sampled contact by up to four ticks in two narrow-edge cases. Native output is own-process software capture; rendered-footprint timing excludes monitor scanout and acoustic/Bluetooth latency. No Windows buffer-latency reduction or kerb correction is claimed.",
}
(OUT / "review.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"checks": checks, "failures": 0, "cases_improved": len(corrected), "native_pairs": native}, indent=2))
