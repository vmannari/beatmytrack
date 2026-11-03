"""Rules23 must not reopen a folded road join with server-only padding."""
import pytest

from bmt_backend.trajectory_verifier import check
from bmt_backend.verifier import VerificationError


def geometry(rules):
    return {"start": [0, 1.1, 0], "extent": [10, 10],
            "manifest": {"rules_key": rules}, "maximum_speed": {"compact": 120},
            "gates": [[1, 0, -1, 0, 1, 0, -1, 1, 0],
                      [-1, 0, -1, 0, 1, 0, -1, 1, 0]]}


def test_rules23_uses_the_client_gate_span_and_preserves_old_contract():
    proof = {"schema": "bmt-race-path-v1", "samples": [[0, 0, 1.1, 0]] +
             [[index*6, 2 if index % 2 else -2, 1.1, 0] for index in range(1, 11)]}
    assert check(geometry("standing-5-road-gates-v22"), proof, 60, "compact")["lap_ticks"] == [12]*5
    with pytest.raises(VerificationError, match="ordered road gates"):
        check(geometry("standing-5-road-gates-v23"), proof, 60, "compact")
    inside = {"schema": proof["schema"], "samples": [[row[0],row[1],1.0,row[3]] for row in proof["samples"]]}
    exact = geometry("standing-5-road-gates-v23")
    exact["start"][1] = 1.0
    assert check(exact, inside, 60, "compact")["lap_ticks"] == [12]*5
