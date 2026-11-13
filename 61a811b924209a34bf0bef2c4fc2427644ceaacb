"""Compare actual retained/current blob paths locally; never contact a service."""
import gc
import importlib.util
import json
import statistics
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "backend"))

from bmt_backend import storage
from bmt_backend.rivalry import standings_data
from bmt_backend.track_models import digest


def compare(before, after, batch_size=8, batches=21):
    assert before() == after()
    values = {"before": [], "after": []}
    enabled = gc.isenabled()
    gc.disable()
    try:
        for batch in range(batches):
            order = (("before", before), ("after", after))
            for name, function in order if batch % 2 == 0 else reversed(order):
                start = time.perf_counter_ns()
                for _ in range(batch_size):
                    function()
                values[name].append((time.perf_counter_ns() - start) / batch_size / 1e6)
    finally:
        if enabled:
            gc.enable()
    before_ms, after_ms = (statistics.median(values[name]) for name in ("before", "after"))
    return {"batches": batches, "batch_size": batch_size, "before_ms": before_ms, "after_ms": after_ms,
            "reduction_percent": 100 * (1 - after_ms / before_ms), "raw_ms": values}


def main():
    spec = importlib.util.spec_from_file_location("bmt_backend._bwr_before_storage",
        EVIDENCE / "before/backend/bmt_backend/storage.py")
    old = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(old)
    proof = json.loads((ROOT / "docs/evidence/race-verification-improvements-2026-10-26/recorded-proof.json").read_text())
    recording = {"schema": "bmt-trajectory-v1", "input_count": 12757,
                 "race_proof": {"schema": "bmt-race-path-v1",
                                "samples": [[r[0], r[1], r[2], r[6]] for r in proof["samples"]]}}
    with tempfile.TemporaryDirectory(prefix="bwr-bench-", dir=ROOT / "build") as folder:
        before = old.PinnedBlobStore(old.LocalBlobStore(folder + "/before"), None)
        after = storage.PinnedBlobStore(storage.LocalBlobStore(folder + "/after"), None)
        before._pin = after._pin = lambda *_args, **_kwargs: None

        def old_path():
            key = digest(recording)
            assert key == before.put_json(recording)
            return key

        def new_path():
            prepared = storage.prepare_json(recording)
            assert prepared.digest == after.put_json(prepared)
            return prepared.digest

        blobs = compare(old_path, new_path)
    from types import SimpleNamespace
    facts = {"players": [{"id":str(i), "name":"Driver "+str(i), "is_test_driver":False, "country_code":"FI"}
                         for i in range(20)],
             "bests": [{"slot":s, "id":str(i), "ticks":10000+i*37+s*900, "run_id":str(i)+"-"+str(s)}
                       for s in range(5) for i in range(20)]}
    group = SimpleNamespace(tracks=[{"tick_rate":120} for _ in range(5)])

    def before_standings():
        return standings_data(None, group, facts), standings_data(None, group, facts)

    def after_standings():
        result = standings_data(None, group, facts)
        return result, result

    report = {"python":sys.version, "storage":{
        "scope":"Actual digest + pinned + local deduplicated publication, pin SQL omitted equally; integrity reads retained",
        "bytes":len(storage.canonical_json(recording)), "samples":len(recording["race_proof"]["samples"]), **blobs},
        "standings":{"scope":"Actual standings computation, 20 drivers, five tracks; SQL excluded",
                     **compare(before_standings, after_standings, batch_size=200)}}
    (EVIDENCE / "benchmark.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({name:{key:value for key,value in row.items() if key != "raw_ms"}
                      for name,row in report.items() if isinstance(row,dict)}, indent=2))


if __name__ == "__main__":
    main()
