"""Reusable canonical engine must isolate state, recover and bound its lifetime."""
import copy
from pathlib import Path
from types import SimpleNamespace

import pytest
from test_resumes import rewind_fixture
from test_verifier import race_fixture as race_fixture_source
from test_verifier import real_verifier as real_verifier_source

race_fixture = race_fixture_source
real_verifier = real_verifier_source

from bmt_backend.loadtest import rss_bytes
from bmt_backend.verifier import GodotVerifier, VerificationError, VerifierUnavailable


@pytest.mark.godot
def test_persistent_engine_isolates_rewinds_rejections_launch_and_recycles(real_verifier, race_fixture):
    verifier = GodotVerifier(SimpleNamespace(godot_bin=real_verifier.binary,
        game_project=real_verifier.project, verifier_timeout_seconds=90,
        persistent_verifier=True, verifier_recycle_jobs=5))
    document, replay = race_fixture["document"], race_fixture["replay"]
    try:
        baseline = verifier.verify_canonical_diagnostic(document, replay, "compact")
        first_pid = verifier._service.pid
        assert verifier.verify_canonical_diagnostic(document, rewind_fixture(replay), "compact") == baseline
        wrong = copy.deepcopy(replay); wrong["frames"] = wrong["frames"][:-1]
        with pytest.raises(VerificationError):
            verifier.verify_canonical_diagnostic(document, wrong, "compact")
        # A different compiled geometry must not pollute the cached original.
        changed = copy.deepcopy(document); changed["points"][77][0] += 0.0005
        assert verifier.validate_track(changed) != verifier.validate_track(document)
        # The job bound recycles the process, never the authoritative score.
        assert verifier.verify_canonical_diagnostic(document, replay, "compact") == baseline
        assert verifier._service.pid != first_pid
        launch = {**replay, "frames": [[0,255,0,0,2]]+[[0,255,0]]*71+replay["frames"]}
        assert verifier.verify_canonical_diagnostic(document, launch, "compact", capture_ghost=False)["time_ticks"] == baseline["time_ticks"]+72
        result = verifier.verify_canonical_diagnostic(document, replay, "compact", capture_ghost=False)
        assert result["ghost"] == {} and result["lap_ticks"] == baseline["lap_ticks"]
        # A corrupt diagnostic stream fails closed and causes a fresh engine.
        verifier._log.write(b"SCRIPT ERROR: injected diagnostic\n"); verifier._log.flush()
        with pytest.raises(VerifierUnavailable, match="engine error"):
            verifier.verify_canonical_diagnostic(document, replay, "compact")
        assert verifier._service is None
        assert verifier.verify_canonical_diagnostic(document, replay, "compact") == baseline
        folder = Path(verifier._directory.name)
    finally:
        verifier.close()
    assert not folder.exists()


@pytest.mark.godot
def test_persistent_track_cache_memory_stays_bounded(real_verifier,race_fixture):
    verifier=GodotVerifier(SimpleNamespace(godot_bin=real_verifier.binary,game_project=real_verifier.project,
        verifier_timeout_seconds=90,persistent_verifier=True,verifier_recycle_jobs=100))
    memory=[]
    try:
        for index in range(12):
            document={**race_fixture["document"],"name":f"Immutable cache fixture {index}"}
            result=verifier.verify_canonical_diagnostic(document,race_fixture["replay"],"compact",capture_ghost=False)
            assert result["time_ticks"]==race_fixture["time_ticks"]
            memory.append(rss_bytes(verifier.engine_pid))
        original=verifier.verify_canonical_diagnostic(race_fixture["document"],race_fixture["replay"],"compact")
        assert original["lap_ticks"]==[2634,2532,2531,2530,2530]
        measured=[value for value in memory if value is not None]
        assert measured,"Engine memory telemetry must be available in the canonical capacity lab"
        assert max(measured)<512*1024*1024
        assert max(measured)-min(measured)<128*1024*1024
    finally:
        verifier.close()
