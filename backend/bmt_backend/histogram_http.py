"""Private conditional replies and bounded, best-effort refresh interest."""
import gzip
import logging
from collections import OrderedDict
from threading import Lock
from time import monotonic

from fastapi.responses import JSONResponse, Response
from sqlalchemy import case, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from .track_models import HistogramDemand, HistogramSnapshot, digest, now

logger = logging.getLogger("bmt.histograms")
_lock = Lock()


def note_demand(app, key):
    """Runs after the read transaction releases its connection; errors are quiet."""
    try:
        clock = now()
        with app.state.session_factory() as session:
            snapshot = session.execute(select(HistogramSnapshot.generation, HistogramSnapshot.invalidated,
                HistogramSnapshot.next_refresh_at).filter_by(**key)).first()
            if snapshot is None:
                return
            due = 0 if not snapshot.generation or snapshot.invalidated else snapshot.next_refresh_at
            insert = pg_insert if session.get_bind().dialect.name == "postgresql" else sqlite_insert
            statement = insert(HistogramDemand).values(**key, due_at=due, requested_until=clock+600)
            # A request never postpones an already queued refresh.
            statement = statement.on_conflict_do_update(index_elements=list(key), set_={
                "requested_until": clock+600,
                "due_at": case((HistogramDemand.due_at < due, HistogramDemand.due_at), else_=due)})
            session.execute(statement)
            session.commit()
    except Exception:
        logger.exception("histogram_demand_failed")
    finally:
        with _lock:
            app.state.histogram_interest_pending -= 1


def schedule_demand(request, background, version_id, vehicle_id, include_artificial, *, unavailable=False):
    app = request.app
    key = (version_id, vehicle_id, include_artificial)
    clock = monotonic()
    with _lock:
        interests = getattr(app.state, "histogram_interests", None)
        if interests is None:
            interests = app.state.histogram_interests = OrderedDict()
            app.state.histogram_interest_pending = 0
        previous_due, previous_unavailable = interests.get(key, (0, False))
        if ((previous_due > clock and (not unavailable or previous_unavailable))
                or app.state.histogram_interest_pending >= 16):
            return
        interests[key] = (clock + (5 if unavailable else 60), unavailable)
        interests.move_to_end(key)
        while len(interests) > 4096:
            interests.popitem(last=False)
        app.state.histogram_interest_pending += 1
    background.add_task(note_demand, app, dict(zip(("version_id", "vehicle_id", "include_artificial"), key)))


def reply(request, background, identity, build, *, compact=False):
    tag = '"' + digest(["histogram-http-v1", identity]) + '"'
    headers = {"ETag": "W/" + tag if compact else tag,
               "Cache-Control": "private, max-age=0, must-revalidate",
               "Vary": "Authorization, Accept-Encoding" if compact else "Authorization"}
    matches = [token.strip().removeprefix("W/") for token in request.headers.get("if-none-match", "").split(",")]
    if tag in matches or "*" in matches:
        return Response(status_code=304, headers=headers, background=background)
    response = JSONResponse(build(), headers=headers, background=background)
    if compact:
        # Small position-only replies can fall below the global 1-KiB gzip
        # threshold. Compress them too when negotiated and beneficial, so a
        # shorter decoded reply does not cost more wire bytes than full bins.
        for encoding in request.headers.get("accept-encoding", "").lower().split(","):
            parts = [part.strip() for part in encoding.split(";")]
            if parts[0] != "gzip":
                continue
            quality = next((part[2:] for part in parts[1:] if part.startswith("q=")), "1")
            try:
                accepted = 0 < float(quality) <= 1
            except ValueError:
                accepted = False
            if accepted:
                compressed = gzip.compress(response.body, compresslevel=3, mtime=0)
                if len(compressed) < len(response.body):
                    response.body = compressed
                    response.headers["Content-Encoding"] = "gzip"
                    response.headers["Content-Length"] = str(len(compressed))
            break
    return response


def preparing(background):
    return JSONResponse({"detail": "Comparison snapshot is being prepared"}, status_code=503,
                        headers={"Cache-Control": "no-store", "Retry-After": "5"}, background=background)
