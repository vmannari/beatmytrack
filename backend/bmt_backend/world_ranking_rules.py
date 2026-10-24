"""Exact sporting arithmetic, independent of storage and wall clocks."""
from math import isqrt
from struct import Struct

WEEK = 604800
POLICY = "compact-circuit-v1"
CAR = "compact"
RESULT = Struct(">Q6IH2s")  # key, five ticks, weekly place, points, country
WORLD = Struct(">QIH2s")  # key, world position, total, historical country
MISSING_PLACE = 2147483647


def points(place: int, field: int) -> int:
    if field < 2:
        return 0
    if not 1 <= place <= field:
        raise ValueError("Invalid Circuit position")
    scale = min(field - 1, 127)
    if place <= 3:
        return max(1, (1000, 850, 775)[place - 1] * scale // 127)
    return max(1, isqrt(56250000 * scale * scale // ((place + 96) * 127 * 127)))


def counting(results, limit=12):
    """Input triples: (week_start, points, weekly_place). Reserves remain stored."""
    return sorted((r for r in results if r[1] > 0), key=lambda r: (-r[1], r[2], -r[0]))[:limit]


def sporting_key(results, limit=12):
    selected = counting(results, limit)
    total = sum(r[1] for r in selected)
    # Lexicographic unsigned bytes have identical ordering in PostgreSQL/SQLite.
    # Store only transient work keys. IDs and recency do not break sporting ties.
    values = [12000 - total]
    point_key = sorted((r[1] for r in selected), reverse=True) + [0] * (limit-len(selected))
    place_key = sorted(r[2] for r in selected) + [MISSING_PLACE] * (limit-len(selected))
    return (total, Struct(">" + "H" * (1+limit) + "I" * limit).pack(
        *values, *(1000-v for v in point_key), *place_key))


def season_start(week: int, launch: int) -> int:
    return launch + ((week-launch) // (13*WEEK)) * 13*WEEK


def breakdown(results, week):
    eligible = [tuple(r) for r in results if week-25*WEEK <= r[0] <= week]
    selected = counting(eligible)
    total = sum(r[1] for r in selected)
    reserve_after_expiry = counting([r for r in eligible if r[0] > week-25*WEEK])
    return {"total": total, "points_at_risk": total-sum(r[1] for r in reserve_after_expiry),
            "results": [{"week_start": r[0], "points": r[1], "weekly_place": r[2],
                         "counting": r in selected} for r in sorted(eligible, reverse=True)]}
