"""Record the task-only working-tree delta without changing Git's index or refs."""
import difflib
import hashlib
import json
import subprocess
from pathlib import Path

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
FILES = [
    "game/core/app.gd", "game/backend/challenges_client.gd",
    "game/ui/race_results.gd", "game/ui/challenge_result_view.gd",
    "game/tests/test_challenge_race_flows.gd", "game/tests/test_challenge_multi_http.gd",
    "game/tests/test_challenge_result_action.gd", "game/tests/test_challenges_http.gd",
    "backend/tests/test_challenge_multi_http.py", "backend/tests/test_challenges_http.py",
    "docs/CHALLENGES.md", "docs/CHALLENGE_RACE_FLOWS_2026_10_24.md",
    "AGENTS.md", "DEVELOPMENT_STATUS.md",
    "docs/evidence/challenge-result-action-2026-10-24/CAPTURE_PROVENANCE_2026_10_24.md",
]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    patch = []
    sources = []
    for relative in FILES:
        before = EVIDENCE / "before" / relative
        current = ROOT / relative
        original = before.read_bytes() if before.is_file() else b""
        final = current.read_bytes()
        destination = EVIDENCE / "final" / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(final)
        sources.append({"path": relative, "before_sha256": digest(original) if before.is_file() else None,
                        "sha256": digest(final), "bytes": len(final)})
        patch.extend(difflib.unified_diff(
            original.decode("utf-8-sig").splitlines(keepends=True),
            final.decode("utf-8-sig").splitlines(keepends=True),
            fromfile="a/" + relative if before.is_file() else "/dev/null",
            tofile="b/" + relative,
        ))
    patch_path = EVIDENCE / "task.patch"
    patch_path.write_text("".join(patch), encoding="utf-8", newline="\n")
    checked = subprocess.run(["git", "apply", "--reverse", "--check", str(patch_path)],
                             cwd=ROOT, text=True, capture_output=True, check=False)
    (EVIDENCE / "patch-check.log").write_text(
        f"git apply --reverse --check task.patch\nexit={checked.returncode}\n" + checked.stdout + checked.stderr,
        encoding="utf-8",
    )
    if checked.returncode:
        raise RuntimeError(checked.stdout + checked.stderr)
    report = {
        "date": "2026-10-24", "timezone": "Europe/Helsinki", "requirements": ["CRF01", "CRF02", "CRF03", "CRF04", "R01", "Q01"],
        "outcome": "Reproduced and fixed 3x3 selected-track/retained-Game mismatch; removed extra Continue challenge action; audited start/retry/feedback/recovery flows.",
        "engine": "4.7.2.stable.official.ed1daf0bf",
        "environment": "Windows, isolated workspace APPDATA and disposable loopback SQLite accounts/services; RTX 3090 desktop Compatibility and Mobile rendering; no external game service.",
        "baseline": {"checks": 5, "failures": 4, "log": "baseline.log"},
        "native_command": "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/NAME.gd -CommandTimeoutSeconds 180; graphical variants add -Graphical -RenderingMethod gl_compatibility or mobile",
        "native": [
            {"test": "test_challenge_race_flows", "checks": [34, 36, 36], "modes": ["headless", "gl_compatibility", "mobile"], "failures": 0, "logs": ["flows-headless-final.log", "flows-gl_compatibility-final.log", "flows-mobile-final.log"]},
            {"test": "test_challenge_result_action", "checks": [23, 29], "modes": ["headless", "gl_compatibility"], "failures": 0},
            {"test": "test_challenge_series", "checks": 30, "failures": 0},
            {"test": "test_custom_challenge_tracks", "checks": 55, "failures": 0},
            {"test": "test_app", "checks": 141, "failures": 0},
            {"test": "test_rivalry_ghost_retry", "checks": 17, "failures": 0},
            {"test": "test_race_results", "checks": 515, "failures": 0},
            {"test": "test_challenges", "checks": 216, "failures": 0},
            {"test": "test_challenge_result_view", "checks": 293, "failures": 0},
            {"test": "test_script_parse", "scripts": 1093, "failures": 0},
        ],
        "backend": {
            "command": ".tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_challenge_series.py backend/tests/test_custom_challenge_tracks.py backend/tests/test_challenges.py -q -k 'sqlite and not migration' --basetemp build/challenge-flow-pytest",
            "passed": 36, "skipped": 2, "deselected": 46,
            "limit": "SQLite only; migration and PostgreSQL variants explicitly excluded.",
        },
        "http": [
            {"command": ".tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_challenge_multi_http.py -q -s --basetemp build/challenge-flow-http-clean", "passed": 1, "native_checks": 26, "native_failures": 0, "script_errors": 0, "log": "multi-http-final.log", "facts": "Four actual five-lap native runs; trajectory-v1 verification; per-track attempts 2/1/1; all three stage results produce a combined verified score."},
            {"command": ".tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_challenge_multi_http.py backend/tests/test_challenges_http.py -q -s --basetemp build/challenge-flow-http-final", "ordinary_flow_native_checks": 53, "source_flow_native_checks": 52, "ordinary_and_source_passed": 2, "initial_multi_failed": 1, "log": "http-final.log", "note": "Multi-track assertions passed but strict script-error check exposed freed standings controls. Fixed and rerun separately above."},
        ],
        "lint": {"command": ".tools/backend-venv/Scripts/python.exe -m ruff check backend/tests/test_challenges_http.py backend/tests/test_challenge_multi_http.py", "passed": True},
        "retained_corrections": [
            "PowerShell script execution policy required the normal -ExecutionPolicy Bypass entry point.",
            "Restricted native execution could not read Windows certificates. Successful runs used pinned-engine host access with workspace-only saves; no TLS check was disabled.",
            "Task-start reproduction retained the exact blank retry warning and four failed checks.",
            "Old ordinary HTTP fixture timed out after calling private retry with a released Game. Updated it to the real feedback Race handler and updated only expectations for the explicitly removed button.",
            "Current daily catalogue publication was added to the disposable HTTP fixture preparation.",
            "New multi-track HTTP fixture initially raced before initial refresh completed; it now awaits challenge busy state.",
            "Real HTTP caught freed deferred standings controls despite all 26 assertions passing. Kept the strict assertion and fixed callback lifetime.",
            "Ruff initially found one test import-order issue; corrected, final lint passes.",
            "Existing screenshot test ignored --evidence and overwrote six historical Compatibility PNGs. Original bytes were unavailable; original recorded hashes/Mobile captures retained, provenance note added, new images copied into this task and test output destination corrected.",
        ],
        "limitations": [
            "No physical-device or phone/tablet attachment check, APK/export/install, owner-process restart, purchase, live mutation or deployment.",
            "Desktop Mobile renderer is not physical-device validation. Owner device workflow/feel acceptance remains.",
            "Reload or rebuild the client to use the fix. No new migration is required; existing challenge capabilities still require a matching service.",
            "An already accepted server ticket remains a reserved try when navigation or network failure abandons that start, per existing challenge rules.",
            "Optional comparison 503 and empty-ghost 404 responses occurred in disposable HTTP checks without preventing race verification.",
        ],
        "sources": sources,
        "checkpoint": {"path": "task.patch", "sha256": digest(patch_path.read_bytes()), "reverse_check_exit": checked.returncode,
                       "scope": "Only the task source delta against captured pre-task files; Git index/branch/refs, concurrent runtime sources and owner processes are untouched. Historical screenshot overwrite is explicitly documented."},
        "screenshots": [{"path": str(path.relative_to(EVIDENCE)).replace("\\", "/"), "sha256": digest(path.read_bytes())}
                        for path in sorted((EVIDENCE / "ui").rglob("*.png"))],
    }
    (EVIDENCE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"files": len(sources), "patch_reverse_check": checked.returncode,
                      "screenshots": len(report["screenshots"])}))


if __name__ == "__main__":
    main()
