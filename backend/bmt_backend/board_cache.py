"""Bounded aggregate cache keyed by database-maintained snapshot revision."""
from collections import OrderedDict
from threading import Lock
from weakref import WeakKeyDictionary

_caches = WeakKeyDictionary()
_lock = Lock()
_flights = WeakKeyDictionary()


def cached(session, key, compute, *, namespace="default", max_entries=2048, max_weight=None, weight=None):
    bind = session.get_bind()
    engine = getattr(bind, "engine", bind)
    with _lock:
        cache = _caches.setdefault(engine, {}).setdefault(namespace, OrderedDict())
        if key in cache:
            cache.move_to_end(key)
            return cache[key]
        flights = _flights.setdefault(engine, {}).setdefault(namespace, {})
        flight = flights.setdefault(key, Lock())
    with flight:
        with _lock:
            if key in cache:
                return cache[key]
        try:
            value = compute()
            with _lock:
                cache[key] = value
                cache.move_to_end(key)
                while len(cache) > max_entries or (max_weight is not None and sum(weight(item) for item in cache.values()) > max_weight):
                    cache.popitem(last=False)
            return value
        finally:
            with _lock:
                if flights.get(key) is flight:
                    flights.pop(key, None)
