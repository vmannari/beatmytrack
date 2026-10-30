"""Assemble this task's measured results and isolated review patch."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import xml.etree.ElementTree as ET

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
BASE = EVIDENCE / "task-start"


def read_log(path):
    raw = path.read_bytes()
    return raw.decode("utf-16" if raw.startswith(b"\xff\xfe") else "utf-8-sig", errors="replace")


def xml_result(name):
    node = ET.parse(EVIDENCE / name).getroot()
    if node.tag == "testsuites":
        node = node.find("testsuite")
    return {key: int(node.get(key, 0)) for key in ("tests", "failures", "errors", "skipped")}


def validate(instance, schema, schema_file):
    # The repository schemas here use only this vocabulary. No dependency
    # installation or network resolution is needed to check the real fixture.
    if "$ref" in schema:
        file_part, _, fragment = schema["$ref"].partition("#")
        target = schema_file.parent / file_part if file_part else schema_file
        resolved = json.loads(target.read_text())
        for token in fragment.lstrip("/").split("/") if fragment else []:
            resolved = resolved[token.replace("~1", "/").replace("~0", "~")]
        validate(instance, resolved, target)
        return
    if "type" in schema:
        types = schema["type"] if isinstance(schema["type"], list) else [schema["type"]]
        actual = ("null" if instance is None else "boolean" if isinstance(instance, bool) else
                  "integer" if isinstance(instance, int) else "number" if isinstance(instance, float) else
                  "string" if isinstance(instance, str) else "array" if isinstance(instance, list) else "object")
        assert actual in types or actual == "integer" and "number" in types, (actual, types)
    if "const" in schema:
        assert instance == schema["const"]
    if "enum" in schema:
        assert instance in schema["enum"]
    if isinstance(instance, dict):
        assert set(schema.get("required", ())) <= set(instance)
        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            assert set(instance) <= set(properties), set(instance) - set(properties)
        for key, value in instance.items():
            if key in properties:
                validate(value, properties[key], schema_file)
    elif isinstance(instance, list):
        assert len(instance) <= schema.get("maxItems", len(instance))
        if "items" in schema:
            for value in instance:
                validate(value, schema["items"], schema_file)
    elif isinstance(instance, str):
        assert len(instance) >= schema.get("minLength", 0)
        if "pattern" in schema:
            assert re.search(schema["pattern"], instance)
    elif isinstance(instance, (int, float)) and not isinstance(instance, bool):
        assert instance >= schema.get("minimum", instance)
        assert instance <= schema.get("maximum", instance)


def main():
    native = {}
    scripts = ["test_statistics_request_reuse", "test_instant_comparisons", "test_personal_comparison",
               "test_carousel_histograms", "test_startup_histogram", "test_results_histograms",
               "test_cost_downloads", "test_app", "test_script_parse"]
    for name in scripts:
        path = EVIDENCE / f"verified-{name}.log"
        text = read_log(path)
        assert "SCRIPT ERROR:" not in text and "Command failed" not in text, name
        if name == "test_statistics_request_reuse":
            result = json.loads(re.findall(r"STATISTICS_REUSE (\{.*\})", text)[-1])
        else:
            counts = re.findall(r"(?:checks=|: )(\d+)(?: checks| scripts)?(?:, | )(?:(?:failures=)(\d+)|(\d+) failures)", text)
            assert counts, name
            count, f1, f2 = counts[-1]
            result = {"checks": int(count), "failures": int(f1 or f2)}
        assert result["failures"] == 0, name
        native[name] = {**result, "log": path.name,
                        "build_ids": re.findall(r"Client build: ([^\r\n]+)", text)}
    for renderer in ("gl_compatibility", "mobile"):
        path = EVIDENCE / f"verified-{renderer}.log"
        text = read_log(path)
        assert "SCRIPT ERROR:" not in text and "Command failed" not in text
        result = json.loads(re.findall(r"STATISTICS_REUSE (\{.*\})", text)[-1])
        assert result["failures"] == 0
        native[renderer] = {**result, "log": path.name, "physical_device": False,
                            "build_ids": re.findall(r"Client build: ([^\r\n]+)", text)}

    backend = {name: xml_result(name) for name in ("backend-verified.xml", "backend-protocol.xml",
               "backend-native-verifier.xml", "backend.xml", "backend-baseline-control.xml")}
    for name in ("backend-verified.xml", "backend-protocol.xml", "backend-native-verifier.xml"):
        assert backend[name]["errors"] == backend[name]["failures"] == 0
    fixture = json.loads((EVIDENCE / "protocol-fixture.json").read_text())
    for field, filename in (("full", "results-comparison-v1.schema.json"),
                            ("overlay", "results-comparison-overlay-v1.schema.json")):
        path = ROOT / "docs/schemas" / filename
        validate(fixture[field], json.loads(path.read_text()), path)

    summary = (
        "<!-- STATISTICS-REQUEST-REUSE-20261026 -->\n"
        "## Histogram and track-detail request reuse (2026-10-26)\n"
        f"SRR01-SRR04/R01/Q01: Fresh matching race/lap PBs reuse private histograms until the server snapshot's absolute population-dependent expiry. "
        "Slower results retain exact bins and fetch their own position through a keyed, compressed omission response; changes in PB, frame, generation or identity refresh safely. "
        "Three-row leaderboard previews, independent refreshed-board reuse and queued-speculation cancellation reduce unused reads. Actual account binding includes persisted caches and early identity changes. "
        f"Focused{native['test_statistics_request_reuse']['checks']}headless/{native['gl_compatibility']['checks']}Compatibility/{native['mobile']['checks']}desktopMobile, "
        f"instant25/personal17/carousel20/startup22/results37/download122/App141/parser{native['test_script_parse']['checks']} and backend33 plus protocol3/local verifier1 pass. "
        "Two-driver fixture compressed comparison bodies600to373bytes; no player-day/bill forecast. Original six-target carousel20/1 reproduces with task-start two-target code; only superseded count changes. "
        "Existing0054 downgrade failure reproduces with task-start modules in isolated memory. Initial adapter/lifetime, sandbox-verifier and concurrent transient parser findings remain recorded. "
        "650ms track preparation, two-viewport discovery reserve, geometry, physics, scoring and rewards remain. Matching API/client reload and owner/device acceptance remain; no device attachment check/test, APK, live mutation, deployment, owner-process restart, staging or commit. "
        "Concurrent App/profile and other work preserved and excluded. Sources, commands, captures, hashes and scoped patch: docs/STATISTICS_REQUEST_REUSE_2026_10_26.md and docs/evidence/statistics-request-reuse-2026-10-26/report.json.\n"
        "<!-- /STATISTICS-REQUEST-REUSE-20261026 -->\n\n"
    )
    for filename in ("AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"):
        path = ROOT / filename
        current = path.read_bytes()
        if b"<!-- STATISTICS-REQUEST-REUSE-20261026 -->" not in current:
            prefix = summary.replace("\n", "\r\n") if b"\r\n" in current[:2000] else summary
            path.write_bytes(prefix.encode("utf-8") + current)

    changed = ["game/backend/comparison_preloader.gd", "game/ui/track_browser.gd", "game/ui/race_complete.gd",
               "game/core/app.gd", "backend/bmt_backend/runs.py", "backend/bmt_backend/histogram_snapshots.py",
               "backend/bmt_backend/histogram_http.py", "game/tests/test_carousel_histograms.gd",
               "docs/schemas/results-comparison-v1.schema.json", "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
    added = ["game/backend/comparison_reuse.gd", "game/tests/test_statistics_request_reuse.gd",
             "backend/tests/test_statistics_request_reuse.py", "docs/schemas/results-comparison-overlay-v1.schema.json",
             "docs/STATISTICS_REQUEST_REUSE_2026_10_26.md"]
    for filename in list(added):
        if filename.endswith(".gd") and (ROOT / (filename + ".uid")).exists():
            added.append(filename + ".uid")
    patch, excluded = [], []
    for filename in changed:
        old = (BASE / filename).read_text(encoding="utf-8-sig")
        current = (ROOT / filename).read_text(encoding="utf-8-sig")
        if filename in ("AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"):
            current = summary + old
        lines = list(difflib.unified_diff(old.splitlines(True), current.splitlines(True),
                                       fromfile="a/"+filename, tofile="b/"+filename))
        if filename == "game/core/app.gd" and lines:
            kept = lines[:2]
            starts = [i for i, line in enumerate(lines) if line.startswith("@@")]
            for begin, end in zip(starts, starts[1:]+[len(lines)]):
                hunk = lines[begin:end]
                if any(marker in "".join(hunk) for marker in ("comparisons.cancel_speculation", "_configure_result_comparisons", "page.comparison_cache")):
                    kept.extend(hunk)
                else:
                    excluded.append({"file": filename, "hunk": hunk[0].strip()})
            lines = kept
        patch.extend(lines)
    for filename in added:
        content = (ROOT / filename).read_text(encoding="utf-8-sig")
        patch.extend(difflib.unified_diff([], content.splitlines(True), fromfile="/dev/null", tofile="b/"+filename))
    (EVIDENCE / "task-only.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
    report = {
        "date": "2026-10-26", "requirements": ["SRR01", "SRR02", "SRR03", "SRR04", "R01", "Q01"],
        "status": "Implemented and locally verified; matching API/client rollout remains",
        "native": native, "backend": backend,
        "protocol_fixture_schema_checks": {"full": True, "overlay": True, "checker": "Local stdlib checker of the schemas' used vocabulary; no external resolver/dependency"},
        "wire_body_bytes": fixture["wire_body_bytes"], "decoded_bytes": fixture["decoded_bytes"],
        "wire_body_reduction_percent": 100*(1-fixture["wire_body_bytes"]["overlay"]/fixture["wire_body_bytes"]["full"]),
        "wire_sample_scope": fixture["scope"],
        "runtime_files": [filename for filename in changed+added if filename.startswith(("game/", "backend/bmt_backend/")) and "/tests/" not in filename],
        "source_sha256": {filename: hashlib.sha256((ROOT/filename).read_bytes()).hexdigest() for filename in changed+added},
        "excluded_concurrent_App_hunks": excluded,
        "controls": {"carousel": "Original20checks/1failure reproduces with exact task-start preloader; only old six-target count changed to the retained two-target cap", "migration": "Existing0054 downgrade guard fails identically with exact task-start runs/snapshot modules executed only in memory"},
        "initial_findings": ["Unconfigured test adapter corrected before cache use", "Freed-service callback guarded", "Sandboxed native verifier initialization failed; isolated permitted rerun passed", "Concurrent Rivalry/challenge polling callbacks briefly lacked their declarations; those files were preserved and fixed concurrently"],
        "limitations": ["No physical-device attachment check or test", "No production traffic, aggregate bandwidth or phone-loading measurement", "Configured PostgreSQL fixture unavailable; SQLite checks and local native verifier are recorded", "Existing migration downgrade failure remains", "Legacy private cache envelopes miss once under the stronger actual-actor namespace"],
        "preserved": ["650-ms selected-track preparation", "Two-viewport discovery reserve", "Track/ghost document caching", "Race/physics/rules/scoring/rewards", "Concurrent source work"],
        "not_performed": ["APK/AAB", "real authentication/purchase", "live backend/account mutation", "deployment", "owner-process restart", "Git staging/commit"],
        "commands": ["Pinned scripts/dev.ps1 TestScript commands in verified-*.log; isolated APPDATA/cache", "Backend pytest selections in docs/STATISTICS_REQUEST_REUSE_2026_10_26.md and XML results", "backend_baseline_control.py executes task-start code only in isolated process memory", "finish_evidence.py checks protocol fixtures, preserves concurrent docs and creates the scoped patch"],
        "patch_sha256": hashlib.sha256((EVIDENCE/"task-only.patch").read_bytes()).hexdigest(),
    }
    (EVIDENCE / "report.json").write_text(json.dumps(report, indent=2)+"\n")
    print(json.dumps({"native": {key:value["checks"] for key,value in native.items()}, "backend": backend,
                      "excluded_concurrent_App_hunks": len(excluded), "wire_body_reduction_percent": report["wire_body_reduction_percent"]}, indent=2))


if __name__ == "__main__":
    main()
