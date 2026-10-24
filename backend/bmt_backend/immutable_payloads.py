"""Bounded process-local immutable representations and shared in-flight preparation."""
import threading
from collections import OrderedDict
from concurrent.futures import Future, TimeoutError

from fastapi import HTTPException


class ImmutablePayloadCache:
    def __init__(self, maximum_bytes=32*1024*1024, maximum_entries=256, parallel=4):
        self.maximum_bytes, self.maximum_entries, self.parallel = maximum_bytes, maximum_entries, parallel
        self.lock, self.entries, self.pending = threading.Lock(), OrderedDict(), {}
        self.bytes = 0

    def get(self, key, produce):
        with self.lock:
            if key in self.entries:
                value = self.entries.pop(key)
                self.entries[key] = value
                return value
            owner = key not in self.pending
            if owner:
                if len(self.pending) >= self.parallel:
                    raise HTTPException(503, "CONTENT_PREPARATION_BUSY", headers={"Retry-After": "1"})
                self.pending[key] = Future()
            future = self.pending[key]
        if not owner:
            try:
                return future.result(timeout=1.5)
            except TimeoutError as error:
                raise HTTPException(503, "CONTENT_PREPARATION_BUSY", headers={"Retry-After": "1"}) from error
        try:
            value = produce()
            if not isinstance(value, bytes):
                raise TypeError("Immutable representation must be bytes")
            with self.lock:
                if len(value) <= self.maximum_bytes:
                    self.entries[key] = value
                    self.bytes += len(value)
                    while self.bytes > self.maximum_bytes or len(self.entries) > self.maximum_entries:
                        _, removed = self.entries.popitem(last=False)
                        self.bytes -= len(removed)
                future.set_result(value)
            return value
        except BaseException as error:
            future.set_exception(error)
            raise
        finally:
            with self.lock:
                self.pending.pop(key, None)
