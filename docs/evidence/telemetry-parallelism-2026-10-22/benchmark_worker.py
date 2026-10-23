"""One actual Python worker process for the isolated throughput diagnostic."""
import json
import os
import sys
import time

from bmt_backend.db import make_session_factory
from bmt_backend.telemetry_models import ProductEvent
from bmt_backend.telemetry_processing import actor_once, retry_stage, shared_once
from bmt_backend.telemetry_queue import fold_one
from bmt_backend.track_models import now
from sqlalchemy import create_engine, select

engine = create_engine(os.environ["TELEMETRY_TEST_URL"], hide_parameters=True, pool_size=1, max_overflow=0,
    connect_args={"options": os.environ["TELEMETRY_TEST_OPTIONS"]})
factory = make_session_factory(engine)
durations, processed = [], 0
print("READY", flush=True)
assert sys.stdin.readline().strip() == "GO"
try:
    while True:
        started = time.perf_counter()
        amount = retry_stage(actor_once, factory, 500)
        if amount:
            durations.append((time.perf_counter() - started) * 1000)
            processed += amount
        derived = retry_stage(shared_once, factory, 500)
        folded = retry_stage(fold_one, factory, now())
        if not amount and not derived and not folded:
            with factory() as db:
                pending = db.scalar(select(ProductEvent.id).where(ProductEvent.processed_at.is_(None)).limit(1))
            if pending is None:
                break
            time.sleep(.01)
finally:
    engine.dispose()
print(json.dumps({"processed": processed, "durations": durations}), flush=True)
