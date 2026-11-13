"""Pinned multi-car sporting policy. Integer points; ratings never break sporting ties."""
from functools import lru_cache
from math import isqrt
from struct import Struct

from .world_ranking_rules import WEEK, counting

POLICY = "multi-car-circuit-v2"
# Append only; compact archive kinds retain these identities across releases.
CARS = ("compact", "pickup", "classic", "formula", "kart", "forklift", "electric", "hovercraft", "super_rally")
PLAYABLE_CARS = ("compact", "kart", "forklift", "electric", "hovercraft", "super_rally")
CONTRIBUTIONS = (100, 40, 15)
MAX_AWARD = 1500
MAX_CAR_TOTAL = 12 * MAX_AWARD
MAX_TOTAL = MAX_CAR_TOTAL * sum(CONTRIBUTIONS) // 100
NEUTRAL_RATING = 1500


def participation(populations):
    """Eight oldest-to-newest calendar-week counts; missing weeks remain zero.

    A trailing linearly weighted mean, with a half-bonus reference of 1,000
    weekly finishers. Express the mean in /36 units to avoid rounding twice.
    """
    if len(populations) != 8 or any(type(n) is not int or n < 0 for n in populations):
        raise ValueError("Eight nonnegative weekly populations required")
    units = sum(weight * n for weight, n in enumerate(populations, 1))
    return 10000 + 2500 * units // (units + 36000), units


def strength(ratings):
    """Confidence-shrunk car-specific seeds, fixed before this week's outcomes."""
    total, count = ratings
    return max(8000, min(12000, 10000 + 2 * (total // count - NEUTRAL_RATING))) if count else 10000


def evidence(field):
    # Replaces v1's linear small-field factor. A solo entry still earns zero.
    return isqrt(min(max(field - 1, 0), 127) * 100000000 // 127)


def award(place, field, participation_bps=10000, strength_bps=10000):
    if field < 2:
        return 0
    if not 1 <= place <= field or not 10000 <= participation_bps <= 12500 or not 8000 <= strength_bps <= 12000:
        raise ValueError("Invalid multi-car award inputs")
    base = (1000, 850, 775)[place - 1] if place <= 3 else isqrt(56250000 // (place + 96))
    return max(1, base * evidence(field) * participation_bps * strength_bps // 1000000000000)


def car_key(records, limit=12):
    selected = counting(records, limit)
    total = sum(r[1] for r in selected)
    awards = sorted((r[1] for r in selected), reverse=True) + [0] * (limit - len(selected))
    places = sorted(r[2] for r in selected) + [2147483647] * (limit - len(selected))
    key = Struct(">" + "H" * (limit + 1) + "I" * limit).pack(
        limit * MAX_AWARD - total, *(MAX_AWARD - n for n in awards), *places)
    return total, key


def overall(cars):
    """(car, total, sporting_key) -> integer total, deterministic sporting key, breakdown.

    Car names serialize equivalent results only; they cannot decide a rank.
    Round the combined total once. Exact hundredths are its first countback.
    """
    selected = sorted((row for row in cars if row[1] > 0), key=lambda r: (-r[1], r[2], r[0]))[:3]
    numerator = sum(row[1] * weight for row, weight in zip(selected, CONTRIBUTIONS))
    # Fixed-length padding keeps equivalent incomplete records tied.
    keys = [(row[2] + b"\xff" * 128)[:128] for row in selected]
    key = Struct(">I").pack(MAX_TOTAL * 100 - numerator) + b"".join(keys + [b"\xff" * 128] * (3 - len(keys)))
    return numerator // 100, key, [
        {"vehicle_id": row[0], "points": row[1], "weight": weight, "contribution_hundredths": row[1] * weight}
        for row, weight in zip(selected, CONTRIBUTIONS)]


@lru_cache(maxsize=4001)
def expected_probability(difference):
    """Integer probability for a rating estimate, separate from exact point arithmetic."""
    return round(1000000 / (1 + 10 ** (difference / 400)))


def update_rating(prior, weeks, place, tied, field, histogram):
    if field < 2:
        return prior, weeks
    expected = (sum(count * expected_probability(rating - prior) for rating, count in histogram.items()) - 500000) // (field - 1)
    actual = (2 * (field - place) - tied + 1) * 500000 // (field - 1)
    gain = 80 if weeks < 4 else 40
    delta = (gain * (actual - expected) + 500000) // 1000000
    return max(500, min(2500, prior + delta)), min(26, weeks + 1)


def histories_at_risk(records, week):
    live = [r for r in records if week - 25 * WEEK <= r[0] <= week]
    total = car_key(live)[0]
    expired = car_key([r for r in live if r[0] > week - 25 * WEEK])[0]
    return total - expired
