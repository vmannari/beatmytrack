"""Worker runtime without an HTTP router tree or administrative/auth clients."""
import threading
from collections import OrderedDict
from types import SimpleNamespace

from .config import Settings
from .db import make_engine, make_session_factory
from .observability import configure_logging


def create_worker_app(settings=None, *, engine=None, verifier=None):
    from .database_privileges import verify_runtime
    from .erasure_journal import make_journal
    from .immutable_payloads import ImmutablePayloadCache
    from .run_signals import RunSignals
    from .storage import make_blob_store
    from .verifier import GodotVerifier

    settings = settings or Settings.from_env()
    if settings.workload_role != "worker":
        raise ValueError("Worker runtime requires BMT_WORKLOAD_ROLE=worker")
    configure_logging()
    state = SimpleNamespace(settings=settings)
    state.engine = engine if engine is not None else make_engine(settings.database_url, settings)
    verify_runtime(state.engine, settings)
    state.session_factory = make_session_factory(state.engine)
    state.run_signals = RunSignals(state.engine, capacity=settings.run_wait_capacity)
    state.engine._bmt_run_signals = state.run_signals
    state.blobs = make_blob_store(settings, state.session_factory)
    state.session_factory.configure(info={"cost_archive_blobs": state.blobs, "cost_archive_days": settings.cost_archive_days})
    state.erasure_journal = make_journal(settings)
    state.verifier = verifier if verifier is not None else GodotVerifier(settings)
    state.worker_heartbeat_memory = OrderedDict()
    state.worker_heartbeat_lock = threading.RLock()
    state.discovery_memory = OrderedDict()
    state.discovery_lock = threading.RLock()
    state.immutable_payloads = ImmutablePayloadCache()
    return SimpleNamespace(state=state)
