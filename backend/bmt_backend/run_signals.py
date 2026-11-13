"""Bounded, lossy wake-up hints over the durable run queue and result receipts.

PostgreSQL notifications use one connection from the existing bounded pool only
while listening or publishing. No NOTIFY is part of a race's write transaction.
The worker and HTTP wait both retain periodic authoritative database checks.
"""
import asyncio
import hashlib
import json
import logging
import threading
import time
from dataclasses import dataclass

from sqlalchemy import event, inspect
from sqlalchemy.orm import Session

from .publication_models import PublicationIntent
from .track_models import Run

logger = logging.getLogger("bmt.run_signals")
TERMINAL = ("verified", "skipped", "rejected", "failed")
MAX_PENDING = 64


@dataclass(eq=False)
class Watch:
    run_id: str
    player_id: str
    loop: asyncio.AbstractEventLoop
    event: asyncio.Event

    def wake(self):
        try:
            self.loop.call_soon_threadsafe(self.event.set)
        except RuntimeError:
            pass  # Its disconnected HTTP loop may already have closed.


class RunSignals:
    def __init__(self, engine, *, capacity=4):
        self.engine = engine
        self.capacity = capacity
        self.worker = threading.Event()
        self.condition = threading.Condition()
        self.watches = set()
        self.pending = set()
        self.pending_work = False
        self.work_hint = False
        self.work_generation = 0
        self.idle_worker = False
        self.users = 0
        self.thread = None
        self.stopped = False
        self.connection = None
        self.listening = False

    def open(self):
        with self.condition:
            self.users += 1
            self.stopped = False

    def close(self):
        with self.condition:
            self.users = max(0, self.users - 1)
            if self.users:
                return
            self.stopped = True
            self.pending.clear()
            self.pending_work = False
            self.worker.set()
            watches = tuple(self.watches)
            self.watches.clear()
            self.condition.notify_all()
            thread = self.thread
        for watch in watches:
            watch.wake()
        if thread is not None:
            thread.join(timeout=4)
            if thread.is_alive():
                connection = self.connection
                if connection is not None:
                    try:
                        connection.close()
                    except Exception as error:  # noqa: BLE001 - finish the remaining shutdown cleanup
                        logger.warning("run_notification_close_failed", extra={"exception_type": type(error).__name__})
                thread.join(timeout=1)

    def subscribe(self, run_id, player_id):
        with self.condition:
            if self.stopped or len(self.watches) >= self.capacity or any(w.player_id == player_id for w in self.watches):
                return None
            watch = Watch(run_id, player_id, asyncio.get_running_loop(), asyncio.Event())
            self.watches.add(watch)
            self._start()
            self.condition.notify_all()
            return watch

    def unsubscribe(self, watch):
        with self.condition:
            self.watches.discard(watch)
            self.condition.notify_all()

    def set_idle(self, value):
        with self.condition:
            self.idle_worker = value
            if value:
                self._start()
            self.condition.notify_all()

    def begin_scan(self):
        with self.condition:
            self.worker.clear()
            if self.work_hint:
                # Give a hinted foreground claim the full pool again. A plain
                # LISTEN-ready wake keeps the listener for its one catch-up scan.
                self.work_hint = False
                self.idle_worker = False
                self.condition.notify_all()

    def publish(self, work=False, run_ids=()):
        self._deliver(work, run_ids)
        with self.condition:
            if self.stopped or not self.users or self.engine.dialect.name != "postgresql":
                return
            self.pending_work |= work
            for run_id in run_ids:
                if len(self.pending) < MAX_PENDING:
                    self.pending.add(run_id)
            self._start()
            self.condition.notify_all()

    def _deliver(self, work, run_ids):
        with self.condition:
            if work:
                self.work_generation += 1
                self.work_hint = True
                self.worker.set()
            watches = tuple(w for w in self.watches if w.run_id in run_ids)
        for watch in watches:
            watch.wake()

    def _start(self):
        # Called while owning condition. Small custom pools retain ordinary DB
        # access and use the same local hints plus periodic cross-process reads.
        if (self.engine.dialect.name != "postgresql" or not self.users or self.stopped
                or getattr(self.engine.pool, "size", lambda: 0)() < 2):
            return
        if self.thread is None or not self.thread.is_alive():
            self.thread = threading.Thread(target=self._transport, name="bmt-run-signals", daemon=True)
            try:
                self.thread.start()
            except RuntimeError:
                self.thread = None
                logger.warning("run_notification_thread_unavailable")

    def _receive(self, notification):
        try:
            packet = json.loads(notification.payload)
            work, ids = packet.get("work") is True, packet.get("done", [])
            if not isinstance(ids, list) or len(ids) > MAX_PENDING or any(type(key) is not str or len(key) > 36 for key in ids):
                return
            self._deliver(work, ids)
        except (ValueError, AttributeError, TypeError):
            return  # Hints never carry an authoritative result or credentials.

    def _transport(self):
        retry = 0.25
        while True:
            with self.condition:
                while not self.stopped and not (self.idle_worker or self.watches or self.pending or self.pending_work):
                    self.condition.wait()
                if self.stopped:
                    return
            try:
                with self.engine.connect().execution_options(isolation_level="AUTOCOMMIT") as connection:
                    try:
                        self._exchange(connection.connection.driver_connection)
                    except Exception:  # Discard a failed notification-only connection.
                        connection.invalidate()
                        raise
                retry = 0.25
            except Exception as error:  # noqa: BLE001 - a hint cannot fail an already committed race
                self.connection = None
                self.listening = False
                with self.condition:
                    if self.stopped:
                        return
                    logger.warning("run_notification_unavailable", extra={"exception_type": type(error).__name__})
                    deadline = time.monotonic() + retry
                    while not self.stopped and time.monotonic() < deadline:
                        self.condition.wait(timeout=max(0, deadline-time.monotonic()))
                retry = min(5, retry * 2)

    def _exchange(self, raw):
        self.connection = raw
        previous_timeout = raw.execute("SHOW statement_timeout").fetchone()[0]
        raw.execute("SET statement_timeout = '500ms'")
        schema = raw.execute("SELECT current_schema()").fetchone()[0]
        channel = "bmt_runs_" + hashlib.sha256(schema.encode()).hexdigest()[:20]
        try:
            listening = False
            while True:
                with self.condition:
                    if self.stopped:
                        break
                    need_listen = bool(self.idle_worker or self.watches)
                    work, done = self.pending_work, list(self.pending)
                    self.pending_work = False
                    self.pending.clear()
                if need_listen and not listening:
                    raw.execute("LISTEN " + channel)
                    listening = self.listening = True
                    # LISTEN commits before the next authoritative read, closing
                    # startup/reconnect gaps. Notifications carry no result data.
                    self.worker.set()
                    with self.condition:
                        for watch in self.watches:
                            watch.wake()
                if work or done:
                    raw.execute("SELECT pg_notify(%s, %s)", (channel, json.dumps({"work": work, "done": done})))
                if not need_listen:
                    break
                for notification in raw.notifies(timeout=0.05, stop_after=64):
                    self._receive(notification)
        finally:
            self.listening = False
            self.connection = None
            if not raw.closed:
                raw.execute("UNLISTEN *")
                raw.execute("SELECT set_config('statement_timeout', %s, false)", (previous_timeout,))


def wake_after_commit(session):
    """Share the existing lossy worker hint without IO inside the transaction."""
    if getattr(session.get_bind(), "_bmt_run_signals", None) is not None:
        session.info.setdefault("run_signals", {"work": False, "done": set()})["work"] = True


@event.listens_for(Session, "after_flush")
def collect_run_signals(session, _context):
    if getattr(session.get_bind(), "_bmt_run_signals", None) is None:
        return
    signals = session.info.setdefault("run_signals", {"work": False, "done": set()})
    for run in session.new.union(session.dirty):
        if isinstance(run, PublicationIntent):
            if (run in session.new or inspect(run).attrs.status.history.has_changes()) and run.status == "queued":
                signals["work"] = True
            continue
        if not isinstance(run, Run):
            continue
        changed = run in session.new or inspect(run).attrs.status.history.has_changes()
        if changed and run.status == "queued":
            signals["work"] = True
        elif changed and run.status in TERMINAL and len(signals["done"]) < MAX_PENDING:
            signals["done"].add(run.id)


@event.listens_for(Session, "after_commit")
def committed_run_signals(session):
    if session.in_nested_transaction():
        return
    packet = session.info.pop("run_signals", None)
    signals = getattr(session.get_bind(), "_bmt_run_signals", None)
    if packet and (packet["work"] or packet["done"]) and signals is not None:
        try:
            signals.publish(packet["work"], packet["done"])
        except Exception as error:  # noqa: BLE001 - SQL is already committed; retry identity must survive
            logger.warning("run_notification_unavailable", extra={"exception_type": type(error).__name__})


@event.listens_for(Session, "after_rollback")
def discard_run_signals(session):
    session.info.pop("run_signals", None)
