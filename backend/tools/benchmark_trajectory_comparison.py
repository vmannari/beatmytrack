"""Compare a saved checker with the current one on identical prepared paths."""
import argparse
import gc
import hashlib
import importlib.machinery
import importlib.util
import json
import statistics
import sys
import time
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from bmt_backend import trajectory_verifier
from bmt_backend.verifier import GodotVerifier


def summary(rows):
    return {key: statistics.median(row[key] for row in rows) for key in ("cpu_ms", "wall_ms")}


def measure(function, expected, count):
    cpu, wall = time.process_time_ns(), time.perf_counter_ns()
    for _ in range(count):
        result = function()
    elapsed_wall = time.perf_counter_ns()-wall
    elapsed_cpu = time.process_time_ns()-cpu
    # Verification remains real; equality assertions run outside timed batches.
    assert result == expected
    return {"cpu_ms": elapsed_cpu/count/1e6, "wall_ms": elapsed_wall/count/1e6}


def compare(args):
    source = args.baseline.read_bytes()
    loader = importlib.machinery.SourceFileLoader("bmt_backend._comparison_baseline", str(args.baseline))
    baseline = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
    loader.exec_module(baseline)
    original, current = baseline.check, trajectory_verifier.check
    fixture = json.loads(args.fixture.read_text(encoding="utf-8"))
    proof = json.loads(args.proof.read_text(encoding="utf-8"))
    if proof["schema"] == "bmt-race-proof-v1":
        proof = {"schema": "bmt-race-path-v1", "samples": [[r[0],r[1],r[2],r[6]] for r in proof["samples"]]}
    verifier = GodotVerifier(SimpleNamespace(godot_bin=args.godot, game_project=args.project,
        verifier_timeout_seconds=90, persistent_verifier=True))
    try:
        geometry = verifier.race_geometry(fixture["document"])
        engine_calls = 0

        def forbidden(*_args, **_kwargs):
            nonlocal engine_calls
            engine_calls += 1
            raise AssertionError("Measured acceptance invoked the game engine")

        verifier._invoke = forbidden
        long_samples, offset = [], 0
        for index, row in enumerate(proof["samples"]):
            long_samples.append([row[0]+offset, *row[1:]])
            if index < len(proof["samples"])-1:
                for _ in range(15):
                    offset += 6
                    long_samples.append([row[0]+offset, *row[1:]])
        cases = [("recorded", proof, fixture["time_ticks"], 100),
                 ("long_with_stationary_holds", {"schema":proof["schema"], "samples":long_samples},
                  fixture["time_ticks"]+offset, 5)]
        report = {"baseline_sha256":hashlib.sha256(source).hexdigest(),
                  "current_sha256":hashlib.sha256(Path(trajectory_verifier.__file__).read_bytes()).hexdigest(),
                  "python":sys.version, "batches":args.batches, "cases":{}}
        for name, path, ticks, batch_size in cases:
            expected = original(geometry, path, ticks, fixture["vehicle_id"])
            assert current(geometry, path, ticks, fixture["vehicle_id"]) == expected
            replay = {"schema":"bmt-trajectory-v1", "input_count":ticks, "race_proof":path}
            rows = {"before":[], "after":[]}
            for function in (original, current):
                for _ in range(10):
                    assert function(geometry, path, ticks, fixture["vehicle_id"]) == expected
            # Alternate order to reduce effects of CPU frequency and scheduling.
            collected = gc.isenabled()
            gc.disable()
            try:
                for batch in range(args.batches):
                    order = (("before", original), ("after", current))
                    for label, function in (order if batch % 2 == 0 else reversed(order)):
                        rows[label].append(measure(
                            lambda fn=function, p=path, t=ticks: fn(geometry, p, t, fixture["vehicle_id"]),
                            expected, batch_size))
            finally:
                if collected:
                    gc.enable()
            # Check the real adapter too; prepared geometry forbids native work.
            accepted = verifier.verify_run(None, replay, fixture["vehicle_id"], geometry=geometry, capture_ghost=False)
            assert all(accepted[key] == value for key, value in expected.items())
            before, after = summary(rows["before"]), summary(rows["after"])
            report["cases"][name] = {"samples":len(path["samples"]), "ticks":ticks,
                "lap_ticks":expected["lap_ticks"], "batch_size":batch_size, "before":before, "after":after,
                "cpu_ratio":after["cpu_ms"]/before["cpu_ms"], "wall_ratio":after["wall_ms"]/before["wall_ms"],
                "measurements":rows}
        report["engine_calls_during_acceptance"] = engine_calls
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
        return report
    finally:
        verifier.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True, help="Trusted local Python source snapshot")
    parser.add_argument("--godot", required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--proof", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--batches", type=int, default=25)
    args = parser.parse_args()
    if not 5 <= args.batches <= 100:
        parser.error("Use 5 to 100 batches")
    report = compare(args)
    print(json.dumps({"engine_calls_during_acceptance":report["engine_calls_during_acceptance"],
        "cases":{name:{key:value for key,value in case.items() if key != "measurements"}
                 for name,case in report["cases"].items()}}, indent=2))
