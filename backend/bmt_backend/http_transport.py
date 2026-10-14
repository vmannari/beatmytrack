"""Reuse bounded HTTP connection pools without sharing mutable Sessions across threads."""
import threading

import requests
from requests.adapters import HTTPAdapter


class PooledTransport:
    def __init__(self):
        self.lock = threading.Lock()
        self.sessions = {}
        self.closed = False

    def __call__(self, *args, **kwargs):
        with self.lock:
            if self.closed:
                raise OSError("Object transport closed")
            # Worker executors may retire threads between batches. Don't retain
            # their connection pools until process shutdown.
            for owner in list(self.sessions):
                if not owner.is_alive():
                    self.sessions.pop(owner).close()
            owner = threading.current_thread()
            session = self.sessions.get(owner)
            if session is None:
                session = requests.Session()
                # Preserve application-level retry/idempotency decisions; never
                # silently replay a write after an ambiguous network failure.
                for scheme in ("http://", "https://"):
                    session.mount(scheme, HTTPAdapter(pool_connections=2, pool_maxsize=2, max_retries=0))
                self.sessions[owner] = session
        return session.request(*args, **kwargs)

    def close(self):
        with self.lock:
            self.closed = True
            sessions, self.sessions = self.sessions, {}
        for session in sessions.values():
            session.close()
