"""Bounded aggregate cache keyed by database-maintained snapshot revision."""
from collections import OrderedDict
from concurrent.futures import Future
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
        owner = key not in flights
        if owner:
            flights[key] = Future()
        flight = flights[key]
    if not owner:
        return flight.result()
    try:
        value = compute()
        with _lock:
            cache[key] = value
            cache.move_to_end(key)
            while len(cache) > max_entries or (max_weight is not None and sum(weight(item) for item in cache.values()) > max_weight):
                cache.popitem(last=False)
        flight.set_result(value)
        return value
    except BaseException as error:
        flight.set_exception(error)
        raise
    finally:
        with _lock:
            flights.pop(key, None)
