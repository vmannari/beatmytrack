"""Bounded aggregate cache keyed by database-maintained snapshot revision."""
from collections import OrderedDict
from threading import Lock
from weakref import WeakKeyDictionary

_caches = WeakKeyDictionary()
_lock = Lock()


def cached(session, key, compute):
    bind = session.get_bind()
    engine = getattr(bind, "engine", bind)
    with _lock:
        cache = _caches.setdefault(engine, OrderedDict())
        if key in cache:
            cache.move_to_end(key)
            return cache[key]
    value = compute()
    with _lock:
        cache[key] = value
        cache.move_to_end(key)
        while len(cache) > 128: cache.popitem(last=False)
    return value
