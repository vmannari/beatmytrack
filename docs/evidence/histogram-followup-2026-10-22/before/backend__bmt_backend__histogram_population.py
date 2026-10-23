"""Shared immutable driver frequencies, with cheap per-result overlays."""
from bisect import bisect_left
from collections import Counter
from dataclasses import dataclass
from itertools import pairwise
from types import MappingProxyType

SNAPSHOT_OWN_LIMIT = 4096


@dataclass(frozen=True)
class HistogramPopulation:
    own: object
    ticks: tuple
    counts: tuple
    cumulative: tuple
    stored_grid: object = None

    @classmethod
    def from_rows(cls, rows, stored_grid=None):
        own = dict(rows)
        frequencies = sorted(Counter(own.values()).items())
        return cls.from_frequencies(frequencies, own, stored_grid)

    @classmethod
    def from_frequencies(cls, frequencies, own=None, stored_grid=None):
        """Sorted exact tick counts; memory depends on distinct times, not drivers.

        None means personal markers are read separately by indexed player ID.
        Small fields retain their frozen per-player snapshot values.
        """
        frequencies = tuple(frequencies)
        cumulative = [0]
        for _, count in frequencies:
            cumulative.append(cumulative[-1] + count)
        return cls(MappingProxyType(dict(own)) if own is not None else None, tuple(t for t, _ in frequencies),
                   tuple(c for _, c in frequencies), tuple(cumulative), stored_grid)

    def frame(self, candidate, start, end):
        if not self.ticks:
            return None, None
        return (min(self.ticks[0], candidate or self.ticks[0], start or self.ticks[0]),
                max(self.ticks[-1] + 1, candidate + 1 if candidate else 0, end or 0))

    def histogram(self, board_id, metric, bins, start, end):
        result = {"board_id": board_id, "metric": metric,
                  "population": self.cumulative[-1],
                  "minimum_ticks": self.ticks[0] if self.ticks else None,
                  "maximum_ticks": self.ticks[-1] if self.ticks else None, "bins": []}
        if not self.ticks:
            return result
        width = max(1, (end - start + bins - 1) // bins)
        # Shared bin boundaries need one search each, rather than two per bin.
        indices = [bisect_left(self.ticks, start+i*width)
                   for i in range((end-start-1)//width+2)]
        counts = [self.cumulative[right] - self.cumulative[left]
                  for left, right in pairwise(indices)]
        result["bins"] = [{"from_ticks": start + i * width,
                           "to_ticks_exclusive": start + (i + 1) * width, "count": count}
                          for i, count in enumerate(counts)]
        return result

    def position(self, ticks, own_ticks):
        if ticks is None:
            return None
        opponents = self.cumulative[-1] - int(own_ticks is not None)
        if opponents <= 0:
            return None
        faster = self.cumulative[bisect_left(self.ticks, ticks)] - int(own_ticks is not None and own_ticks < ticks)
        # A compact large-field snapshot may precede the current personal PB.
        # Its self-correction can differ by one place; keep endpoint ranks valid.
        faster = max(0, min(opponents, faster))
        position, population = faster + 1, opponents + 1
        return {"position": position, "population": population,
                "top_percent": max(1, (position * 100 + population - 1) // population),
                "candidate_ticks": ticks}
