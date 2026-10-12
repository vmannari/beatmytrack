"""Measure trajectory-check computation and the warm adapter separately from IO."""
import argparse
import json
import statistics
import sys
import time
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from bmt_backend.trajectory_verifier import check
from bmt_backend.verifier import GodotVerifier


def benchmark(binary, project, fixture, proof, iterations):
    verifier = GodotVerifier(SimpleNamespace(godot_bin=binary,game_project=project,
        verifier_timeout_seconds=90,persistent_verifier=True))
    try:
        prep = time.perf_counter_ns()
        geometry = verifier.race_geometry(fixture["document"])
        prepared_ms = (time.perf_counter_ns()-prep)/1e6
        path = {"schema":"bmt-race-path-v1","samples":[[r[0],r[1],r[2],r[6]] for r in proof["samples"]]}
        replay = {"schema":"bmt-trajectory-v1","input_count":fixture["time_ticks"],"race_proof":path}
        # Assert the real engine cannot run during any measured acceptance.
        def forbidden(*_args, **_kwargs):
            raise AssertionError("Trajectory verification attempted engine execution")
        verifier._invoke = forbidden
        compute, adapter = [], []
        for _ in range(iterations):
            start = time.perf_counter_ns()
            result = check(geometry,path,fixture["time_ticks"],fixture["vehicle_id"])
            compute.append((time.perf_counter_ns()-start)/1e6)
            start = time.perf_counter_ns()
            accepted = verifier.verify_run(fixture["document"],replay,fixture["vehicle_id"],geometry=geometry,capture_ghost=False)
            adapter.append((time.perf_counter_ns()-start)/1e6)
            assert result["time_ticks"] == accepted["time_ticks"] == 12757
            assert result["lap_ticks"] == [2634,2532,2531,2530,2530]
        def summary(rows):
            ordered = sorted(rows)
            return {"median_ms":statistics.median(rows),"p95_ms":ordered[int((len(rows)-1)*.95)],
                "max_ms":max(rows),"samples_ms":rows}
        return {"iterations":iterations,"trajectory_samples":len(path["samples"]),
            "static_preparation_ms":prepared_ms,"kernel":summary(compute),"adapter":summary(adapter),
            "engine_calls_during_verification":0,"five_laps":True}
    finally:
        verifier.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",required=True)
    parser.add_argument("--project",type=Path,required=True)
    parser.add_argument("--fixture",type=Path,required=True)
    parser.add_argument("--proof",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--iterations",type=int,default=200)
    args = parser.parse_args()
    if not 10 <= args.iterations <= 10000:
        parser.error("Use 10 to 10000 repetitions")
    result = benchmark(args.godot,args.project,json.loads(args.fixture.read_text(encoding="utf-8")),
        json.loads(args.proof.read_text(encoding="utf-8")),args.iterations)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2),encoding="utf-8")
    print(json.dumps({key:value for key,value in result.items() if key not in ("kernel","adapter")}))
    for key in ("kernel","adapter"):
        print(key,json.dumps({name:value for name,value in result[key].items() if name != "samples_ms"}))
