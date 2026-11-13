"""VRI01-VRI03: uniform speed allowance and actual recorded start crossings."""
import copy

import pytest

from bmt_backend.trajectory_verifier import check
from bmt_backend.verifier import VerificationError


def course():
    # Two opposing gates let these tests isolate continuity from track shape.
    return {"start": [-0.1, 0, 0], "creator_start": [-0.1, 0, 0], "extent": [10, 10],
            "manifest": {"rules_key": "standing-5-road-gates-v23"},
            "maximum_speed": {"compact": 12},
            "gates": [[1, 0, 0, 0, 1, 0, -1, 1, 0], [-1, 0, 0, 0, 1, 0, -1, 1, 0]]}


def path(samples, legacy):
    if legacy:
        return {"schema": "bmt-race-proof-v1",
                "samples": [[tick, x, y, 0, 0, 0, layer, 0] for tick, x, y, layer in samples]}
    return {"schema": "bmt-race-path-v1", "samples": samples}


@pytest.mark.parametrize("legacy", [False, True])
@pytest.mark.parametrize("creator", [False, True])
def test_first_recorded_position_cannot_invent_a_gate_crossing(legacy, creator):
    # The nominal start is behind the gate. The first recorded sample is
    # within its 15 cm tolerance but already ahead; moving farther ahead does
    # not cross the gate. Previously that movement incorrectly earned a gate.
    samples = [[0, 0.04, 0, 0]] + [
        [tick*6, 0.1 if tick % 2 else -0.1, 0, 0] for tick in range(1, 3 if creator else 11)]
    with pytest.raises(VerificationError, match="ordered road gates"):
        check(course(), path(samples, legacy), samples[-1][0], "compact", creator_test=creator)


@pytest.mark.parametrize("legacy", [False, True])
@pytest.mark.parametrize("creator", [False, True])
def test_tolerated_start_offset_still_accepts_real_crossings(legacy, creator):
    samples = [[0, -0.04, 0, 0]] + [
        [tick*6, 0.1 if tick % 2 else -0.1, 0, 0] for tick in range(1, 3 if creator else 11)]
    result = check(course(), path(samples, legacy), samples[-1][0], "compact", creator_test=creator)
    assert result["lap_ticks"] == [12] * (1 if creator else 5)


@pytest.mark.parametrize("stride", range(1, 6))
@pytest.mark.parametrize("legacy", [False, True])
def test_dense_samples_cannot_multiply_the_speed_tolerance(stride, legacy):
    geometry = course()
    geometry["start"] = [-0.0595*stride, 0, 0]
    # 0.119 metres/tick is over the ordinary six-tick allowance of
    # 12 m/s * 1.1 / 120 + 0.05 / 6 = 0.118333... metres/tick.
    # It was allowed at every shorter spacing by the old flat 5 cm grant.
    samples = [[0, -0.0595*stride, 0, 0]] + [
        [tick*stride, (0.0595 if tick % 2 else -0.0595)*stride, 0, 0] for tick in range(1, 11)]
    with pytest.raises(VerificationError, match="speed limit"):
        check(geometry, path(samples, legacy), 10*stride, "compact")


@pytest.mark.parametrize("stride", range(1, 7))
@pytest.mark.parametrize("legacy", [False, True])
def test_uniform_speed_allowance_accepts_every_sample_spacing(stride, legacy):
    geometry = course()
    geometry["start"] = [-0.055*stride, 0, 0]
    samples = [[0, -0.055*stride, 0, 0]] + [
        [tick*stride, (0.055 if tick % 2 else -0.055)*stride, 0, 0] for tick in range(1, 11)]
    assert check(geometry, path(samples, legacy), 10*stride, "compact")["lap_ticks"] == [2*stride]*5


def test_six_tick_speed_limit_keeps_the_original_allowance():
    geometry = course()
    distance = 12*1.1/120*6 + 0.05
    geometry["start"] = [-distance/2, 0, 0]
    samples = [[tick*6, (-1 if tick % 2 == 0 else 1)*distance/2, 0, 0] for tick in range(11)]
    proof = path(samples, False)
    assert check(geometry, proof, 60, "compact")["time_ticks"] == 60
    excessive = copy.deepcopy(proof)
    excessive["samples"][1][1] += 0.000001
    with pytest.raises(VerificationError, match="speed limit"):
        check(geometry, excessive, 60, "compact")
