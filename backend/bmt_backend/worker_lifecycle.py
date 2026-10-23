"""Signal-safe stop requests and cooperative, bounded verifier draining."""
import logging
import signal
import threading
import time

from .operations import heartbeat
from .track_models import new_id

logger = logging.getLogger("bmt.worker")


class WorkerControl:
    def __init__(self):
        self.stop = threading.Event()
        self.abort = threading.Event()
        self.requested_at = None
        self.stop_signal = None

    def request_stop(self, signum=None, _frame=None):
        # No database access, subprocess cleanup or logging in a signal handler.
        if self.requested_at is None:
            self.requested_at = time.monotonic()
            self.stop_signal = signum


def stopping(app):
    control = getattr(app.state, "worker_control", None)
    return bool(control and (control.requested_at is not None or control.stop.is_set()))


def aborting(app):
    control = getattr(app.state, "worker_control", None)
    return bool(control and control.abort.is_set())


def run_worker(app, process_job, *, once=False, control=None, install_signals=True, idle_seconds=1.0):
    if not 0.1 <= idle_seconds <= 60:
        raise ValueError("Invalid bounded worker idle interval")
    control = control or WorkerControl()
    app.state.worker_control = control
    app.state.worker_id = new_id()
    if not once:
        from .driver_work import DriverWork
        app.state.driver_work = DriverWork(app)
    worker_id = app.state.worker_id
    signals = getattr(app.state, "run_signals", None)
    if signals is not None and not once:
        signals.open()
    finished = threading.Event()
    errors = []
    previous = {}
    timer = None

    def abort():
        control.abort.set()
        # The adapter's request_stop only sets an event; its owning thread cleans up.
        if hasattr(app.state.verifier, "request_stop"):
            app.state.verifier.request_stop()

    def work():
        try:
            while not stopping(app):
                if signals is not None:
                    signals.begin_scan()
                try:
                    worked = process_job(app)
                except Exception:
                    logger.exception("worker_iteration_failed", extra={"worker_id": worker_id})
                    if once:
                        raise
                    worked = False
                if once:
                    return
                if signals is not None:
                    signals.set_idle(not worked)
                if not worked:
                    (signals.worker if signals is not None else control.stop).wait(idle_seconds)
        except BaseException as error:  # noqa: BLE001 - transport fatal job-thread errors to the supervisor
            errors.append(error)
        finally:
            finished.set()

    thread = threading.Thread(target=work, name="bmt-worker-jobs")
    try:
        if install_signals:
            for signum in (signal.SIGTERM, signal.SIGINT):
                previous[signum] = signal.getsignal(signum)
                signal.signal(signum, control.request_stop)
        thread.start()
        while not finished.wait(0.05):
            if stopping(app) and timer is None:
                control.stop.set()
                if signals is not None:
                    signals.worker.set()
                started = control.requested_at or time.monotonic()
                remaining = max(0, started + app.state.settings.worker_shutdown_grace_seconds - time.monotonic())
                # Cancellation must not wait for a slow/unavailable heartbeat database.
                timer = threading.Timer(remaining, abort)
                timer.start()
                logger.info("worker_draining", extra={"worker_id": worker_id, "stop_signal": control.stop_signal})
                try:
                    heartbeat(app, worker_id, lifecycle="draining")
                except Exception:
                    logger.exception("worker_drain_heartbeat_failed", extra={"worker_id": worker_id})
    finally:
        control.stop.set()
        if signals is not None:
            signals.worker.set()
        if thread.is_alive():
            abort()
            thread.join()
        if timer is not None:
            timer.cancel()
            timer.join()
        if signals is not None and not once:
            signals.set_idle(False)
            signals.close()
        driver_work = getattr(app.state, "driver_work", None)
        if driver_work is not None:
            try:
                driver_work.close()
            except Exception as error:
                logger.exception("worker_driver_cleanup_failed", extra={"worker_id": worker_id})
                errors.append(error)
        try:
            heartbeat(app, worker_id, lifecycle="stopped")
        except Exception:
            logger.exception("worker_stop_heartbeat_failed", extra={"worker_id": worker_id})
        try:
            if hasattr(app.state.verifier, "close"):
                app.state.verifier.close()
        except Exception:
            logger.exception("worker_verifier_cleanup_failed", extra={"worker_id": worker_id})
        finally:
            try:
                try:
                    if hasattr(app.state, "blobs") and hasattr(app.state.blobs, "close"):
                        app.state.blobs.close()
                finally:
                    try:
                        if hasattr(app.state, "erasure_journal") and hasattr(app.state.erasure_journal, "close"):
                            app.state.erasure_journal.close()
                    finally:
                        app.state.engine.dispose()
            finally:
                for signum, handler in previous.items():
                    signal.signal(signum, handler)
        logger.info("worker_stopped", extra={"worker_id": worker_id,
            "shutdown_seconds": round(time.monotonic() - control.requested_at, 4) if control.requested_at else 0})
    if errors:
        raise errors[0]
