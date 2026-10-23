"""Synthetic snapshot representation benchmark, not server/deployment capacity.

The preserved original class builds a per-driver map. The compact class builds
the same exact distribution from grouped frequencies. SQL grouping, network IO,
verification and worker scheduling are deliberately outside this experiment.
"""
import gc
import importlib.util
import json
import sys
import time
import tracemalloc
from pathlib import Path

from bmt_backend.histogram_population import SNAPSHOT_OWN_LIMIT, HistogramPopulation

folder = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("owned_histogram_before", folder / "before/backend__bmt_backend__histogram_population.py")
before = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = before
spec.loader.exec_module(before)


def sample(drivers, compact):
    distinct = min(drivers, 1000)
    gc.collect()
    tracemalloc.start()
    started = time.perf_counter()
    if compact:
        frequencies = [(1000 + i, drivers // distinct + int(i < drivers % distinct)) for i in range(distinct)]
        own = ({f"{i:036x}": 1000 + i % distinct for i in range(drivers)}
               if drivers <= SNAPSHOT_OWN_LIMIT else None)
        field = HistogramPopulation.from_frequencies(frequencies, own)
    else:
        field = before.HistogramPopulation.from_rows((f"{i:036x}", 1000 + i % distinct) for i in range(drivers))
    build_ms = (time.perf_counter() - started) * 1000
    _current, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    start, end = field.frame(None, None, None)
    started = time.perf_counter()
    for _ in range(2000):
        grid = field.histogram("owned-board", "race", 30, start, end)
    histogram_us = (time.perf_counter() - started) * 1000000 / 2000
    assert sum(row["count"] for row in grid["bins"]) == drivers
    payload = {"own": dict(field.own) if field.own is not None else {}, "ticks": field.ticks,
               "counts": field.counts, "cumulative": field.cumulative, "histogram": grid}
    if compact:
        payload["own_mode"] = "snapshot" if field.own is not None else "indexed"
    encoded = json.dumps({"race": payload, "best_lap": payload, **({"format": 2} if compact else {})},
                         separators=(",", ":")).encode()
    return {"drivers": drivers, "mode": "compact" if compact else "original",
            "distinct_ticks": len(field.ticks), "two_metric_json_bytes": len(encoded),
            "estimated_two_metric_cache_weight": 2 * ((len(field.own) * 180 if field.own is not None else 0) + len(field.ticks) * 96),
            "build_ms": round(build_ms, 3), "build_python_tracemalloc_peak_bytes": peak,
            "histogram_us": round(histogram_us, 3)}


rows = []
for drivers in (1000, 100000, 400000):
    rows.extend([sample(drivers, False), sample(drivers, True)])
rows.append(sample(10000000, True))
result = {"scope": __doc__, "samples": rows,
          "qualifications": ["One synthetic distribution per size; 1000 distinct tick values at most.",
            "Build memory is Python tracemalloc, not process RSS or database memory.",
            "Two-metric cache weight is the implementation's estimate, not measured RSS.",
            "The ten-million sample uses weighted counts, not ten million database/player rows.",
            "No live database, HTTP service or object store was contacted."]}
(folder / "benchmark.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(rows, indent=2))
