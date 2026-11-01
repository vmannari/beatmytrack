"""Offline analysis of read-only renderer-probe JSONL observations.

The analyzer never invokes ADB, launches apps, or touches a device. Surface
edges are counted only when both endpoints occur together in one raw latency
ring read. Host log-marker receipt and device present timestamps are not
assumed to share a clock. Results are diagnostic, not renderer acceptance.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import math
import re
from collections import Counter
from pathlib import Path

MAX_TIMESTAMP = (1 << 63) - 1
CHUNK = re.compile(r"BMT_PERF_CHUNK\s+(\d+)/(\d+)\s+(\S+)")
BEGIN = re.compile(r"BMT_PERF_BEGIN\s+(\S+)")
FINISHED = re.compile(r"BMT_PERF_FINISHED\s+(\d+)")
MONOTONIC_MARKER = re.compile(r"^\s*(\d+)\.(\d{6})\s+(\d+)\s+(\d+)\s+[VDIWEF]\s+.*?\bBMT_PERF_(BEGIN|CASE|GATE_READY|GATE_START|FINISHED)\b")
EXPECTED = {"org.beatmytrack.rendererprobe.gl20261031": "gl_compatibility",
            "org.beatmytrack.rendererprobe.vk20261031": "mobile"}


def percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    return ordered[max(0, min(len(ordered) - 1, math.ceil(len(ordered) * fraction) - 1))]


def parse_latency(raw: str) -> tuple[int | None, list[int | None], int]:
    """Parse Android --latency (refresh period, desired/actual/ready rows)."""
    refresh = None
    presents = []
    ignored = 0
    for line in raw.splitlines():
        fields = line.split()
        if len(fields) == 1 and fields[0].isdigit() and refresh is None:
            value = int(fields[0])
            if 0 < value < MAX_TIMESTAMP:
                refresh = value
        elif len(fields) == 3 and all(item.isdigit() for item in fields):
            actual = int(fields[1])
            if 0 < actual < MAX_TIMESTAMP:
                presents.append(actual)
            else:
                ignored += 1
                # Preserve the hole: do not infer a pair across an invalid row.
                presents.append(None)
    return refresh, presents, ignored


def decode_report(rows: list[dict]) -> tuple[dict | None, list[str], list[str], int | None]:
    parts: dict[int, str] = {}
    counts: set[int] = set()
    errors = []
    phase_begins = []
    finished = None
    for row in rows:
        if row.get("type") != "probe_log":
            continue
        line = str(row.get("line", ""))
        match = BEGIN.search(line)
        if match:
            phase_begins.append(match.group(1))
        match = FINISHED.search(line)
        if match:
            finished = int(match.group(1))
        match = CHUNK.search(line)
        if not match:
            continue
        index, count, data = int(match.group(1)), int(match.group(2)), match.group(3)
        counts.add(count)
        if index in parts and parts[index] != data:
            errors.append(f"Conflicting data for chunk {index}")
        parts[index] = data
    if len(counts) != 1:
        errors.append("Missing or inconsistent report chunk count")
        return None, errors, phase_begins, finished
    count = next(iter(counts))
    if count <= 0 or count > 5000:
        errors.append("Report chunk count is outside the supported bound")
        return None, errors, phase_begins, finished
    if set(parts) != set(range(count)):
        errors.append("Report chunk indices are incomplete or out of range")
        return None, errors, phase_begins, finished
    try:
        value = json.loads(base64.b64decode("".join(parts[i] for i in range(count)), validate=True).decode("utf-8"))
    except (ValueError, UnicodeError) as exc:
        errors.append(f"Could not decode complete report: {exc}")
        return None, errors, phase_begins, finished
    if not isinstance(value, dict):
        errors.append("Decoded report is not an object")
        return None, errors, phase_begins, finished
    return value, errors, phase_begins, finished


def analyze(rows: list[dict]) -> dict:
    report, decode_errors, begins, finished_code = decode_report(rows)
    start = next((row for row in rows if row.get("type") == "start"), {})
    end = next((row for row in reversed(rows) if row.get("type") == "end"), {})
    markers = []
    for row in rows:
        if row.get("type") != "probe_log":
            continue
        line = str(row.get("line", ""))
        match = MONOTONIC_MARKER.search(line)
        if match:
            begin = BEGIN.search(line)
            markers.append({"kind":match.group(5), "timestamp_us":int(match.group(1))*1000000+int(match.group(2)),
                            "pid":int(match.group(3)), "tid":int(match.group(4)),
                            "phase":begin.group(1) if begin else row.get("phase")})
    expected = EXPECTED.get(start.get("package"))
    polls = [row for row in rows if row.get("type") == "surface_poll"]
    # An edge is admitted only when its endpoints appeared consecutively in
    # the same ring dump. Never invent an edge across a missing poll/ring gap.
    global_edges: set[tuple[int, int]] = set()
    groups: dict[str, set[tuple[int, int]]] = {}
    all_timestamps: set[int] = set()
    periods: set[int] = set()
    unsupported = 0
    invalid_rows = 0
    layers: set[str] = set()
    no_overlap = 0
    prev_present: set[int] | None = None
    max_poll_gap_ms = 0.0
    for poll in polls:
        if isinstance(poll.get("gap_ms"), (int, float)):
            max_poll_gap_ms = max(max_poll_gap_ms, float(poll["gap_ms"]))
        if not poll.get("supported"):
            unsupported += 1
            continue
        refresh, timestamps, ignored = parse_latency(str(poll.get("raw", "")))
        invalid_rows += ignored
        if refresh is not None:
            periods.add(refresh)
        if poll.get("layer"):
            layers.add(str(poll["layer"]))
        current = {stamp for stamp in timestamps if stamp is not None}
        if prev_present is not None and current and prev_present and not (current & prev_present):
            no_overlap += 1
        if current:
            prev_present = current
        all_timestamps.update(current)
        edges = {(first,last) for first,last in zip(timestamps,timestamps[1:])
                 if first is not None and last is not None and last > first}
        global_edges.update(edges)
        groups.setdefault(str(poll.get("phase", "unknown")), set()).update(edges)

    def edge_stats(edges: set[tuple[int, int]]) -> dict:
        values = [(last-first)/1_000_000.0 for first, last in edges if last > first]
        return {"observed_edges": len(values), "p50_ms": percentile(values, .5),
                "p95_ms": percentile(values, .95), "p99_ms": percentile(values, .99),
                "max_ms": max(values) if values else None,
                "over_34ms": sum(value > 34.0 for value in values)}

    problems = decode_errors[:]
    try:
        expected_pid = int(start.get("pid"))
    except (TypeError, ValueError):
        expected_pid = None
    mismatched_pid = sum(marker["pid"] != expected_pid for marker in markers) if expected_pid is not None else None
    if mismatched_pid:
        problems.append(f"{mismatched_pid} timestamped markers have a PID different from collector attachment")
    if not start:
        problems.append("Collector did not record successful probe attachment")
    if not end or not end.get("finished"):
        problems.append("Collector did not observe probe completion")
    if not end.get("gate_seen") or not end.get("gate_start_seen"):
        problems.append("Missing gate-ready or gate-start marker")
    if expected is None:
        problems.append("Package is not an approved renderer-probe identity")
    if report is not None:
        if report.get("renderer") != expected:
            problems.append("Actual renderer differs from the package's intended renderer")
        cases = report.get("cases")
        if not isinstance(cases, list) or len(cases) != report.get("expected_cases"):
            problems.append("Decoded case count is incomplete")
        if report.get("errors"):
            problems.append("Probe reported workload or lifecycle errors")
        if not report.get("finished") or finished_code != 0:
            problems.append("Probe completion marker is missing or reports errors")
        if isinstance(cases, list):
            missing = [str(case.get("phase")) for case in cases if isinstance(case, dict) and case.get("phase") not in begins]
            if missing:
                problems.append("Phase-begin markers missing from collector log: " + ", ".join(missing))
            unsampled = [str(case.get("phase")) for case in cases if isinstance(case, dict)
                         and (not isinstance(case.get("frames"), int) or case["frames"] <= 0)]
            if unsampled:
                problems.append("No process-frame samples in cases: " + ", ".join(unsampled))
    if unsupported:
        problems.append(f"{unsupported} SurfaceFlinger polls had no supported layer data")
    if no_overlap:
        problems.append(f"{no_overlap} successive nonempty ring dumps have no common timestamp")
    if any(row.get("type") in {"coverage_gap", "unavailable"} for row in rows):
        problems.append("Collector recorded an explicit coverage or availability gap")
    return {
        "collector_package": start.get("package"), "expected_renderer": expected,
        "actual_renderer": report.get("renderer") if report else None,
        "requested_renderer": report.get("requested_renderer") if report else None,
        "report": report, "phase_begin_markers": begins,
        "timestamped_logcat": {"recognized_markers":markers, "recognized":bool(markers),
                               "display_precision_us":1 if markers else None,
                               "attachment_pid":expected_pid, "markers_with_unexpected_pid":mismatched_pid,
                               "clock_alignment_verified":False, "phase_boundary_latency_verified":False},
        "collector_finished_marker_errors": finished_code, "problems": problems,
        "surface": {"polls":len(polls), "unsupported_polls":unsupported, "invalid_timestamp_rows":invalid_rows,
                    "unique_present_timestamps":len(all_timestamps), "periods_ns":sorted(periods),
                    "layers":sorted(layers), "successive_nonoverlap":no_overlap,
                    "maximum_host_poll_gap_ms":max_poll_gap_ms,
                    "global_observed_edges":edge_stats(global_edges),
                    "by_poll_phase_not_clock_aligned":{phase:edge_stats(edges) for phase,edges in groups.items()}},
        "limitations":["Poll phase is log-receipt scope, not device-clock phase alignment; ring entries can predate the marker.",
                       "Observed edges do not prove boundary coverage, and maximum observed gap is not a certified phase maximum.",
                       "A nonoverlapping ring or missed polls can hide presentations; no gap is fabricated across rings.",
                       "Touch receipt is not physical touch-to-photon latency.",
                       "No built-in screenshot, Android PSS, energy, thermal, GPU or native shader-call attribution is collected.",
                       "App callbacks and Performance monitors are not direct presentation/GPU timing."]
    }


def read_rows(path: Path) -> tuple[list[dict], str]:
    rows = []
    content = path.read_bytes()
    for index, line in enumerate(content.decode("utf-8").splitlines(), 1):
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            raise ValueError(f"{path}:{index}: incomplete or malformed JSONL") from exc
        if not isinstance(row, dict):
            raise ValueError(f"{path}:{index}: observation must be an object")
        rows.append(row)
    return rows, hashlib.sha256(content).hexdigest()


def read_template_probe(path: Path) -> dict:
    text = path.read_text(encoding="utf-8", errors="replace")
    template = re.search(r"(?m)^TEMPLATE_REVISION=([0-9a-f]+)\s*$", text)
    generated = re.search(r"(?m)^GENERATED_COMPACT_REVISION=([0-9a-f]+)\s*$", text)
    stated = re.search(r"(?m)^REVISION_EQUAL=(true|false)\s*$", text)
    exit_code = re.search(r"(?m)^EXIT=(-?\d+)\s*$", text)
    exact = template is not None and generated is not None and stated is not None and exit_code is not None
    observed = template.group(1) == generated.group(1) if exact else None
    consistent = observed == (stated.group(1) == "true") if exact else None
    return {"path":str(path), "scope":"Compact header template revision only, not observed runtime cache hit",
            "exit":int(exit_code.group(1)) if exit_code else None,
            "template_revision":template.group(1) if template else None,
            "generated_revision":generated.group(1) if generated else None,
            "revision_equal":observed, "stated_result_consistent":consistent,
            "probe_valid":bool(exact and int(exit_code.group(1)) == 0 and consistent)}


def compare(first: dict, second: dict, audit: dict | None) -> dict:
    left, right = first.get("report") or {}, second.get("report") or {}
    fields = ("engine", "model", "adapter", "os", "window_size", "viewport_size", "physics", "rules", "screen_hz", "engine_max_fps", "debug_build")
    matching = {name:{"first":left.get(name), "second":right.get(name),
                      "match":left.get(name) == right.get(name) if name in left and name in right else None}
                for name in fields}
    unexpected = audit.get("unexpected") if isinstance(audit, dict) else None
    left_rows = left.get("cases") if isinstance(left.get("cases"), list) else []
    right_rows = right.get("cases") if isinstance(right.get("cases"), list) else []
    left_cases = {case.get("phase"):case for case in left_rows if isinstance(case,dict) and isinstance(case.get("phase"), str)}
    right_cases = {case.get("phase"):case for case in right_rows if isinstance(case,dict) and isinstance(case.get("phase"), str)}
    phase_settings = {}
    for phase in sorted(set(left_cases) | set(right_cases)):
        a, b = left_cases.get(phase, {}), right_cases.get(phase, {})
        phase_settings[phase] = {name:{"first":a.get(name), "second":b.get(name),
                                      "match":a.get(name) == b.get(name) if name in a and name in b else None}
                                 for name in ("vehicle", "viewport", "render_scale", "msaa", "frozen_tick", "countdown")}
    return {"metadata":matching, "apk_unexpected_differences":unexpected,
            "apk_static_content_audit_passed":not unexpected if isinstance(unexpected, list) else None,
            "phase_settings":phase_settings,
            "controlled_comparison_established":False,
            "reason":"Actual runtime cache/template behavior, matched first-use content, screenshot equivalence, memory/thermal state and device-clock phase coverage are not established by these files."}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("observations", type=Path)
    parser.add_argument("--second", type=Path)
    parser.add_argument("--apk-audit", type=Path)
    parser.add_argument("--first-template-check", type=Path)
    parser.add_argument("--second-template-check", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if not args.second and (args.apk_audit or args.second_template_check):
        parser.error("--apk-audit and --second-template-check require --second")
    first_rows, first_digest = read_rows(args.observations)
    first = analyze(first_rows)
    output = {"schema":1, "first_path":str(args.observations), "first_sha256":first_digest, "first":first}
    if args.first_template_check:
        output["first_template_check"] = read_template_probe(args.first_template_check)
    if args.second:
        second_rows, second_digest = read_rows(args.second)
        second = analyze(second_rows)
        audit_bytes = args.apk_audit.read_bytes() if args.apk_audit else None
        audit = json.loads(audit_bytes.decode("utf-8")) if audit_bytes is not None else None
        output.update(second_path=str(args.second), second_sha256=second_digest, second=second, comparison=compare(first,second,audit))
        if audit_bytes is not None:
            output["apk_audit"] = {"path":str(args.apk_audit), "sha256":hashlib.sha256(audit_bytes).hexdigest()}
        if args.second_template_check:
            output["second_template_check"] = read_template_probe(args.second_template_check)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    # Never silently overwrite a previous capture analysis.
    with args.out.open("x", encoding="utf-8") as target:
        json.dump(output, target, indent=2)
    print(json.dumps({"first_problems":first["problems"], "first_surface":first["surface"]["global_observed_edges"],
                      "second_problems":output.get("second", {}).get("problems"), "output":str(args.out)}, indent=2))


if __name__ == "__main__":
    main()
