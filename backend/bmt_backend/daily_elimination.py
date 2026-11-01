"""Exact lap percentiles from the same compatible, deduplicated comparison field."""
from bisect import bisect_left

PERCENTILES = (75, 60, 50, 40, 30, 20, 10, 5, 1)
POLICY = "daily-flying-elimination-v1"


def cutoffs(population):
    """Nearest-rank quantiles, fastest first; ties at the boundary qualify."""
    count = population.cumulative[-1]
    if not count:
        return []
    return [
        {"percentile": percent,
         "lap_ticks": population.ticks[bisect_left(population.cumulative, (count*percent+99)//100)-1]}
        for percent in PERCENTILES
    ]
