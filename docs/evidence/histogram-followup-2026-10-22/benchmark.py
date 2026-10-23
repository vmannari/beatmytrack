"""Synthetic storage/CPU comparison; no production-load or phone claim."""
import importlib.util
import json
import statistics
import sys
import time
from pathlib import Path

from bmt_backend.histogram_population import HistogramPopulation

evidence = Path(__file__).parent
spec = importlib.util.spec_from_file_location("histogram_followup_original",
    evidence / "before/backend__bmt_backend__histogram_population.py")
original = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = original
spec.loader.exec_module(original)
frequency = [(tick, 1+(tick % 1000)) for tick in range(1, 216001)]
before = original.HistogramPopulation.from_frequencies(frequency)
after = HistogramPopulation.from_frequencies(frequency)


def encoded(field, redundant):
    value = {"ticks":list(field.ticks), "cumulative":list(field.cumulative),
             "counts":list(field.counts) if redundant else []}
    return len(json.dumps(value, separators=(",", ":")).encode())


def measure(field):
    samples = []
    for _ in range(7):
        start = time.perf_counter()
        for _ in range(1000):
            field.histogram("board", "race", 30, 1, 216001)
        samples.append((time.perf_counter()-start)*1000/1000)
    return statistics.median(samples)


assert before.histogram("board", "race", 30, 1, 216001) == after.histogram("board", "race", 30, 1, 216001)
report = {"synthetic_distinct_ticks":216000, "weighted_population":after.cumulative[-1],
    "old_cache_weight_estimate_bytes":len(before.ticks)*96,
    "new_cache_weight_estimate_bytes":after.cache_weight,
    "packed_numeric_buffer_bytes":after.ticks.nbytes+after.cumulative.nbytes,
    "old_frequency_json_bytes":encoded(before, True), "new_frequency_json_bytes":encoded(after, False),
    "old_30_bin_median_ms":measure(before), "new_30_bin_median_ms":measure(after),
    "limits":"Seven warmed desktop Python runs of 1000 requests each; weighted synthetic counts, no HTTP/database/cloud/concurrency load."}
(evidence / "benchmark.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
