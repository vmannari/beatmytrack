"""Exercise bytes produced by the pinned native client's saved-journal path."""
import json
import os
import subprocess
import uuid
from pathlib import Path

import pytest
from test_domains import domain as domain_fixture
from test_domains import headers
from test_exception_recovery import resume_operation

domain = domain_fixture


@pytest.fixture(scope="module")
def native_recovery_wire():
    if os.name != "nt":
        pytest.skip("Native saved-journal wire integration uses the Windows dev entry point")
    repo = Path(__file__).resolve().parents[2]
    work = repo / "build" / ("recovery-wire-" + uuid.uuid4().hex)
    work.mkdir(parents=True)
    wire = work / "wire.json"
    environment = {**os.environ, "APPDATA": str(work / "profile"), "BMT_RECOVERY_WIRE_PATH": str(wire)}
    run = subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(repo / "scripts/dev.ps1"),
         "-Action", "TestScript", "-ScriptPath", "res://tests/test_resume_recovery_budget.gd"],
        cwd=repo, env=environment, capture_output=True, text=True, timeout=90, check=False,
    )
    assert run.returncode == 0, run.stdout + run.stderr
    body = json.loads(wire.read_text())
    for field in ("ordinal", "input_offset", "from_tick", "to_tick"):
        assert type(body["selection"][field]) is int, (field, wire.read_text())
    return body


@pytest.mark.godot
@pytest.mark.parametrize("bank", [0, 2])
@pytest.mark.parametrize("action", ["confirm", "abandon"])
def test_saved_native_wire_recovers_once_without_replaying_a_charge(domain, native_recovery_wire, bank, action):
    _, consumed, recovery = resume_operation(domain, bank=bank, selection=native_recovery_wire["selection"])
    body = {**native_recovery_wire, **recovery, "action": action}
    replies = [domain.client.post("/v1/resume-recovery", json=body, headers=headers(domain, "Alice"))
               for _ in range(2)]
    assert [reply.status_code for reply in replies] == [200, 200], [reply.text for reply in replies]
    assert replies[0].json() == replies[1].json()
    assert replies[0].json()["state"] == ("consumed" if action == "confirm" else "abandoned")
    expected = consumed["wallet"]["balance"] if action == "confirm" else bank
    assert replies[0].json()["wallet"]["balance"] == expected


@pytest.mark.godot
def test_backend_still_rejects_fractional_or_float_evidence(domain, native_recovery_wire):
    _, _, recovery = resume_operation(domain, selection=native_recovery_wire["selection"])
    for value in (1.0, 1.5, "1"):
        body = {**recovery, "action": "confirm",
                "selection": {**recovery["selection"], "ordinal": value}}
        response = domain.client.post("/v1/resume-recovery", json=body, headers=headers(domain, "Alice"))
        assert response.status_code == 422
    assert domain.client.post("/v1/resume-recovery", json={**recovery, "action": "confirm"},
                              headers=headers(domain, "Alice")).status_code == 200
