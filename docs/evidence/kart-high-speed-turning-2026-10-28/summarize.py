"""Collect measured receipts and audit the narrow resource/fixture change."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
turning = json.loads((OUT / "turning.json").read_text())
canonical = json.loads((OUT / "canonical-verification.json").read_text())
original = json.loads((OUT / "original/turning.json").read_text())
retained = []
for row in json.loads((OUT / "before/retained-hashes.json").read_text(encoding="utf-8-sig")):
    path = Path(row["Path"])
    if path == ROOT / "game/resources/cars/kart.tres":
        continue
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    retained.append({"file": path.relative_to(ROOT).as_posix(),
                     "before_sha256": row["Hash"].lower(), "current_sha256": actual,
                     "exact": actual == row["Hash"].lower()})

def summary(log, pattern):
    text = (OUT / "logs" / log).read_text(encoding="utf-16")
    match = re.search(pattern, text)
    assert match, (log, text[-1000:])
    return {"checks": int(match[1]), "failures": int(match[2])}

before = json.loads((OUT / "before/backend/tests/fixtures/verified_oval.json").read_text())
after = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())
before["expected_manifest"]["vehicles"]["kart"] = after["expected_manifest"]["vehicles"]["kart"]
assert before == after, "Unexpected concurrent fixture differences need separate attribution"
assert (ROOT / "game/tests/fixtures/kart_high_speed_turning_before.tres").read_text() == (
    OUT / "before/game/resources/cars/kart.tres").read_text()

receipt = {
    "date": "2026-10-28", "requirements": ["KHT01", "KHT02", "R01", "Q01"],
    "focused": {"checks": turning["checks"], "failures": turning["failures"]},
    "task_start_control": {"checks": original["checks"], "failures": original["failures"]},
    "kart": summary("test_kart.log", r"KART_TESTS: (\d+) checks, (\d+) failures"),
    "cars_kart_laps": summary("test_cars.log", r"CAR_TESTS: (\d+) checks, (\d+) failures"),
    "handling": summary("test_handling.log", r"HANDLING_TESTS: (\d+) checks, (\d+) failures"),
    "rewind": summary("test_rewind.log", r"Rewind: (\d+) checks, (\d+) failures"),
    "canonical": canonical,
    "turns": turning["turns"], "handling_version": turning["handling_version"],
    "config_hash": turning["config_hash"], "physics_version": turning["physics_version"],
    "retained_sources": retained,
    "only_kart_entry_changed_in_local_backend_fixture": True,
    "baseline_test_fixture_exact": True,
    "broader_checks": {
        "backend": {"passed": 1, "failed": 1,
                    "failure": "test_real_engine_manifest_pins_every_competitive_config expects retired classic/formula IDs retained in Appearance"},
        "global_parse": {"passed": False, "failure": "tests/fixtures/parking_hall_before/garage_page.gd:67 calls missing _build_wash_requirement()"}},
    "preferred_kart_dependency_parse": {"passed": True, "log": "logs/preferred-parse.log"},
    "initial_findings": [
        "Sandboxed native engine cannot read Windows certificate store; task-profile offline native runs used automatic escalation.",
        "Initial verification helper assumed every active car existed in the older fixture; Hovercraft is absent. Record missing coverage while retaining every present contract assertion."],
    "limits": ["No device attachment query or physical-device test", "No APK/export or deployment",
               "No owner save or owner process change", "No main-index staging, commit or merge",
               "Reload/rebuild, matching backend contract rollout and owner/device feel acceptance remain"],
}
(OUT / "report.json").write_text(json.dumps(receipt, indent=2)+"\n")
print(json.dumps({key: receipt[key] for key in ["focused", "task_start_control", "kart", "cars_kart_laps", "handling", "rewind", "canonical"]}))
print("Retained source mismatches:", [row["file"] for row in retained if not row["exact"]])
