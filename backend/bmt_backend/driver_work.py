"""One owned background drive; foreground verification never cancels its progress."""
import logging
import threading
import time

from .background_work import BackgroundControl
from .worker_lifecycle import stopping

logger = logging.getLogger("bmt.driver_work")


class DriverWork:
    def __init__(self, app):
        self.app = app
        self.cancel = threading.Event()
        self.lock = threading.Lock()
        self.thread = None
        self.worked = False
        self.next_check = 0.0

    def poll(self):
        settings = self.app.state.settings
        if (stopping(self.app) or settings.environment != "development" or not settings.dev_auth_enabled
                or not settings.test_drivers_enabled or not settings.godot_bin):
            self.cancel.set()
            return False
        with self.lock:
            if self.cancel.is_set():
                return False
            if self.thread is not None:
                if self.thread.is_alive():
                    return False
                self.thread.join()
                self.thread = None
                if self.worked:
                    self.worked = False
                    return True
            if time.monotonic() < self.next_check:
                return False
            self.next_check = time.monotonic() + 3
            thread = threading.Thread(target=self._drive, name="bmt-driver-generation")
            thread.start()
            self.thread = thread
            return True

    def _drive(self):
        started = time.monotonic()
        worked = False
        try:
            from .automatic_test_drivers import drive_idle as drive_automatic
            from .test_population_batch import drive_idle as drive_batch
            control = BackgroundControl(self.app, concurrent=True, cancel=self.cancel)
            worked = drive_batch(self.app, generation_control=control)
            if not worked and not self.cancel.is_set() and not stopping(self.app):
                worked = drive_automatic(self.app, generation_control=control)
        except Exception:
            if not self.cancel.is_set() and not stopping(self.app):
                logger.exception("driver_background_attempt_failed")
        finally:
            with self.lock:
                self.worked = worked
            if worked:
                logger.info("driver_background_attempt_complete", extra={
                    "generation_seconds": round(time.monotonic() - started, 3)})

    def close(self):
        # Join before disposing shared HTTP/storage/database resources. The
        # generator polls cancellation and reaps its owned engine on shutdown.
        self.cancel.set()
        with self.lock:
            thread = self.thread
        if thread is not None:
            thread.join()
