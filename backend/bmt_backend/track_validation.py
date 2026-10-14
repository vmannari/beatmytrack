"""Canonical track validation with durable admission, leases and fenced writes."""

from sqlalchemy import func, select

from .queueing import record_claim
from .track_models import QueuePlayer, Track, TrackValidation, TrackVersion, new_id, now
from .verifier import VerificationError, VerifierStopping
from .worker_lifecycle import aborting, stopping


def process_one(app) -> bool:
    if stopping(app) or app.state.settings.local_drafts_only:
        return False
    settings = app.state.settings
    token = new_id()
    with app.state.session_factory() as session:
        job = session.scalar(select(TrackValidation).join(TrackVersion).join(Track)
            .outerjoin(QueuePlayer, QueuePlayer.player_id == Track.owner_id).where(
            TrackValidation.status.in_(("queued", "validating")),
            TrackValidation.lease_until <= now(),
        ).order_by(func.coalesce(QueuePlayer.last_claim_at, 0), TrackValidation.created_at, TrackValidation.version_id)
            .with_for_update(skip_locked=True, of=TrackValidation).limit(1))
        if job is None:
            return False
        if stopping(app):
            return False
        if job.attempts >= settings.max_job_attempts:
            job.status, job.failure_code = "failed", "validator_unavailable"
            job.detail = "Track validation exhausted its retries; your draft is saved. Retry validation to continue."
            job.lease_until, job.lease_token = 0, None
            session.commit()
            return True
        version = session.get(TrackVersion, job.version_id)
        record_claim(session, None, session.get(Track, version.track_id).owner_id)
        job.status, job.lease_token = "validating", token
        job.lease_until = now() + settings.job_lease_seconds
        job.attempts += 1
        version_id, content_hash = version.id, version.content_hash
        if stopping(app):
            session.rollback()
            return False
        session.commit()
    manifest, failure, detail = None, None, None
    try:
        manifest = app.state.verifier.validate_track(app.state.blobs.get_json(content_hash))
        if manifest.get("laps") != 5 or manifest.get("tick_rate") != 120 or not manifest.get("track_content_hash"):
            raise RuntimeError("Unsupported canonical validation manifest")
        from .verifier import GodotVerifier
        if isinstance(app.state.verifier,GodotVerifier):
            from .trajectory_verifier import prepared_geometry
            prepared_geometry(app,content_hash,app.state.blobs.get_json(content_hash))
    except VerifierStopping:
        return True
    except VerificationError as error:
        failure, detail = "invalid_document", str(error)[:500]
    except Exception:  # noqa: BLE001 - persist a bounded retry for any infrastructure failure
        failure, detail = "validator_unavailable", "Track validation is temporarily unavailable; your draft is saved."
    if aborting(app):
        return True
    with app.state.session_factory() as session:
        job = session.scalar(select(TrackValidation).where(TrackValidation.version_id == version_id).with_for_update())
        if job.status != "validating" or job.lease_token != token or job.lease_until <= now():
            return True
        version = session.get(TrackVersion, version_id)
        job.failure_code, job.detail, job.lease_token = failure, detail, None
        if failure == "invalid_document":
            job.status, version.state, job.lease_until = "invalid", "invalid", 0
        elif failure:
            job.status = "failed" if job.attempts >= settings.max_job_attempts else "queued"
            job.lease_until = now() + min(60, 2 ** min(job.attempts, 6))
        else:
            job.status, job.lease_until = "validated", 0
            version.manifest, version.state = manifest, "draft"
        session.commit()
    return True
