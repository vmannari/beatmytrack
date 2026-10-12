"""Shared UTC reporting boundaries; populations include every player."""

from fastapi import HTTPException, Query

from .track_models import now


def time_range(
    since: int | None = Query(None, ge=0), until: int | None = Query(None, ge=1),
) -> tuple[int, int] | None:
    if (since is None) != (until is None):
        raise HTTPException(422, "BOTH_TIME_BOUNDARIES_REQUIRED")
    if since is None:
        return None
    if until <= since or until - since > 90 * 86400:
        raise HTTPException(422, "INVALID_REPORTING_RANGE")
    return since, until


def calendar_range(days: int) -> tuple[int, int]:
    current = now()
    return (current // 86400 - days + 1) * 86400, current + 1


def during(column, window):
    return [] if window is None else [column >= window[0], column < window[1]]
