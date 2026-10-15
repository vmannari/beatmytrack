"""Account removal: erase private data, retain redacted content and historical scores."""
import secrets
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import delete, or_, select, update

from .db import get_session
from .identity_models import BrowserLogin, Identity, Player, SessionFamily, SessionToken
from .middleware import ParsedJSONRoute
from .privacy_models import AccountDeletion, DeletionBlob
from .security import bearer, current_player, digest
from .track_models import Run, Track, TrackVersion, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["privacy"])
REMOVED_NAME = "Removed account"
EMPTY_HASH = "0" * 64
BATCH = 100


class DeleteBody(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    confirmation: str = Field(pattern=r"^DELETE$")
    request_id: str = Field(min_length=36, max_length=36)

    @field_validator("request_id")
    @classmethod
    def operation(cls, value):
        if str(UUID(value, version=4)) != value.lower() or UUID(value).version != 4:
            raise ValueError("Use a version-four UUID")
        return value.lower()


class WebDeleteBody(DeleteBody):
    token: str = Field(min_length=32, max_length=128)


class WebToken(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    token: str = Field(min_length=32, max_length=128)


class Preferences(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    analytics_enabled: bool


def receipt(job):
    return {"status": "complete" if job.completed_at else "requested", "requested_at": job.requested_at,
            "player_id": job.player_id, "tracks_retained": True, "standings_retained": True, "display_name": REMOVED_NAME}


def repeated(session, credential_hash, request_id):
    job = session.scalar(select(AccountDeletion).where(
        AccountDeletion.credential_hash == credential_hash,
        AccountDeletion.operation_hash == digest(request_id),
        AccountDeletion.requested_at > now() - 90 * 86400))
    return receipt(job) if job else None


def ensure_journal(app, player_id):
    """No successful deletion acknowledgement precedes an independent durable record."""
    with app.state.session_factory() as session:
        job = session.get(AccountDeletion, player_id)
        if job is None or job.journal_written_at is not None:
            return
        record = {"schema": "bmt-erasure-record-v1", "player_id": player_id, "requested_at": job.requested_at}
    app.state.erasure_journal.put_json(record)
    with app.state.session_factory() as session:
        session.execute(update(AccountDeletion).where(AccountDeletion.player_id == player_id,
            AccountDeletion.journal_written_at.is_(None)).values(journal_written_at=now()))
        session.commit()


def confirmed_receipt(request, session, value):
    session.info.pop("privacy_actor", None)  # A bound receipt is valid after revocation.
    session.commit()  # Release SQL before separate storage IO.
    ensure_journal(request.app, value["player_id"])
    return value


def remove_account(session, player_id, credential_hash, request_id):
    player = session.scalar(select(Player).where(Player.id == player_id).with_for_update()
                            .execution_options(populate_existing=True))
    job = session.get(AccountDeletion, player_id)
    if player is None or player.deleted_at is not None:
        if job and secrets.compare_digest(job.credential_hash, credential_hash) and secrets.compare_digest(job.operation_hash, digest(request_id)):
            return receipt(job)
        raise HTTPException(401, "INVALID_SESSION")
    # Separate from administrative suspension: retained public rows stay visible.
    # Authentication always rejects deleted_at, even if an admin changes disabled.
    player.deleted_at, player.display_name = now(), REMOVED_NAME
    player.needs_username, player.country_code, player.analytics_enabled = True, "", False
    player.created_at = 0
    subjects = list(session.scalars(select(Identity.subject).where(Identity.player_id == player_id, Identity.provider == "google")))
    session.execute(delete(BrowserLogin).where(BrowserLogin.subject.in_(subjects)))
    session.execute(delete(Identity).where(Identity.player_id == player_id))
    families = select(SessionFamily.id).where(SessionFamily.player_id == player_id)
    session.execute(delete(SessionToken).where(SessionToken.family_id.in_(families)))
    session.execute(delete(SessionFamily).where(SessionFamily.player_id == player_id))
    # Fence already claimed verifiers; score rows that completed before this lock survive.
    session.execute(update(Run).where(Run.player_id == player_id, Run.status.in_(("queued", "verifying"))).values(
        status="rejected", failure_code="account_removed", finished_at=now(), lease_token=None, lease_until=0))
    from .publication_models import PublicationIntent
    session.execute(update(PublicationIntent).where(PublicationIntent.player_id == player_id,
        PublicationIntent.status.in_(("queued", "verifying"))).values(
            status="failed", failure_code="account_removed", detail=None, lease_token=None, lease_until=0, finished_at=now()))
    from .track_models import TrackValidation
    session.execute(update(TrackValidation).where(TrackValidation.version_id.in_(select(TrackVersion.id).join(Track)
        .where(Track.owner_id == player_id)), TrackValidation.status.in_(("queued", "validating"))).values(
            status="failed", failure_code="account_removed", detail=None, lease_token=None, lease_until=0))
    if job is None:
        job = AccountDeletion(player_id=player_id, credential_hash=credential_hash, operation_hash=digest(request_id),
            requested_at=now(), stage=0, cursor="", next_attempt_at=0)
        session.add(job)
    session.commit()
    return receipt(job)


@router.post("/v1/privacy/account-deletion", status_code=202)
def delete_account(body: DeleteBody, request: Request, credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
                   session=Depends(get_session)):
    if credentials is None or credentials.scheme.lower() != "bearer" or not 32 <= len(credentials.credentials) <= 256:
        raise HTTPException(401, "AUTH_REQUIRED")
    credential_hash = digest(credentials.credentials)
    old = repeated(session, credential_hash, body.request_id)
    if old:
        return confirmed_receipt(request, session, old)
    try:
        player = current_player(request, credentials, session)
    except HTTPException as error:
        session.rollback()
        old = repeated(session, credential_hash, body.request_id)
        if error.status_code == 401 and old:
            return confirmed_receipt(request, session, old)
        raise
    # This transaction intentionally changes the write fence into an irreversible tombstone.
    session.info.pop("privacy_actor", None)
    return confirmed_receipt(request, session, remove_account(session, player.id, credential_hash, body.request_id))


@router.post("/v1/privacy/preferences")
def preferences(body: Preferences, player=Depends(current_player), session=Depends(get_session)):
    player.analytics_enabled = body.analytics_enabled
    session.commit()
    return {"analytics_enabled": player.analytics_enabled}


def web_identity(session, token):
    row = session.scalar(select(BrowserLogin).where(BrowserLogin.poll_hash == digest(token),
        BrowserLogin.expires_at > now(), BrowserLogin.consumed.is_(False)).with_for_update())
    if row is None:
        raise HTTPException(401, "LOGIN_EXPIRED")
    if row.subject is None:
        return row, None
    identity = session.scalar(select(Identity).where(Identity.provider == "google", Identity.subject == row.subject))
    if identity is None:
        raise HTTPException(404, "ACCOUNT_NOT_FOUND")
    return row, identity.player_id


@router.post("/v1/privacy/web-session")
def web_session(body: WebToken, session=Depends(get_session)):
    _row, player_id = web_identity(session, body.token)
    if player_id is None:
        return {"status": "pending"}
    player = session.get(Player, player_id)
    return {"status": "ready", "display_name": player.display_name}


@router.post("/v1/privacy/web-delete", status_code=202)
def web_delete(body: WebDeleteBody, request: Request, session=Depends(get_session)):
    credential_hash = digest("web/" + body.token)
    old = repeated(session, credential_hash, body.request_id)
    if old:
        return confirmed_receipt(request, session, old)
    # Find identity before taking the owner lock, following the shared owner-first order.
    _row, player_id = web_identity(session, body.token)
    if player_id is None:
        raise HTTPException(409, "SIGN_IN_PENDING")
    session.rollback()
    player = session.scalar(select(Player).where(Player.id == player_id).with_for_update())
    row, confirmed_player = web_identity(session, body.token)
    if player is None or confirmed_player != player_id:
        raise HTTPException(401, "LOGIN_EXPIRED")
    row.consumed = True
    return confirmed_receipt(request, session, remove_account(session, player_id, credential_hash, body.request_id))


def remember_blob(session, player_id, value):
    if value and value != EMPTY_HASH and session.get(DeletionBlob, (player_id, value)) is None:
        session.add(DeletionBlob(player_id=player_id, digest=value))


def erase_models():
    """Version-one ordering is persistent protocol. Changing it requires a new plan."""
    from .commerce_models import Entitlements, PublicationSlot
    from .publication_models import PublicationIntent, PublicationUpload
    from .race_statistics_models import RaceStatisticsReceipt
    from .resume_models import ResumeGrant, ResumeRace, ResumeReceipt, ResumeWallet
    from .telemetry_models import ProductEvent, ProductPlayerDay, ProductProfile, ProductPublication
    from .test_driver_models import TestDriverProfile
    from .track_models import IdempotencyRecord, QueuePlayer, Rating
    return [PublicationUpload, PublicationIntent, ResumeReceipt, ResumeRace, ResumeGrant, ResumeWallet,
            Entitlements, IdempotencyRecord, QueuePlayer, ProductEvent, ProductPlayerDay, ProductProfile,
            ProductPublication, RaceStatisticsReceipt, TestDriverProfile, PublicationSlot, Rating]


def cleanup_one(app):
    """At most one redaction or 100 private rows per worker iteration; retries survive restart."""
    factory = app.state.session_factory
    with factory() as session:
        job = session.scalar(select(AccountDeletion).where(AccountDeletion.completed_at.is_(None),
            AccountDeletion.next_attempt_at <= now()).order_by(AccountDeletion.requested_at)
            .with_for_update(skip_locked=True).limit(1))
        if job is None:
            return expire_records(app, session)
        if job.plan_version != 1:
            raise RuntimeError("Unsupported erasure plan; preserve the job for a matching worker")
        if job.journal_written_at is None:
            player_id = job.player_id
            job.next_attempt_at = now() + 120
            session.commit()
            ensure_journal(app, player_id)
            with factory() as resumed:
                resumed.execute(update(AccountDeletion).where(AccountDeletion.player_id == player_id).values(next_attempt_at=0))
                resumed.commit()
            return True
        player_id, stage, cursor = job.player_id, job.stage, job.cursor
        if stage == 2 + len(erase_models()):
            version = session.scalar(select(TrackVersion).join(Track).where(Track.owner_id == player_id,
                TrackVersion.id > cursor).order_by(TrackVersion.id).limit(1))
            if version is not None:
                snapshot = (version.id, version.content_hash, dict(version.manifest), version.state)
                # A short durable reservation releases SQL before platform/blob IO.
                job.next_attempt_at = now() + 120
                session.commit()
            else:
                job.stage, job.cursor = stage + 1, ""
                session.commit()
                return True
        elif stage == 0:
            rows = session.scalars(select(Run).where(Run.player_id == player_id, Run.id > cursor)
                .order_by(Run.id).limit(BATCH)).all()
            for row in rows:
                remember_blob(session, player_id, row.replay_hash)
                remember_blob(session, player_id, row.ghost_hash)
                row.replay_hash, row.ghost_hash = EMPTY_HASH, None
            if rows:
                job.cursor = rows[-1].id
            else:
                job.stage, job.cursor = 1, ""
            session.commit()
            return True
        elif stage <= len(erase_models()):
            model = erase_models()[stage - 1]
            from .resume_models import ResumeRace, ResumeReceipt
            from .telemetry_models import ProductEvent, ProductPublication, ProductState
            from .track_models import Rating
            criterion = (model.race_id.in_(select(ResumeRace.id).where(ResumeRace.player_id == player_id))
                         if model is ResumeReceipt else (model.owner_id == player_id if model is ProductPublication else model.player_id == player_id))
            # Serialize erasure with prepared-product projection, which never recreates a deleted profile.
            if model is ProductEvent:
                state = session.scalar(select(ProductState).where(ProductState.id == 1).with_for_update())
            rows = session.scalars(select(model).where(criterion).limit(BATCH)).all()
            for row in rows:
                if model is Rating:
                    version = session.scalar(select(TrackVersion).where(TrackVersion.id == row.version_id).with_for_update())
                    version.rating_count = max(0, version.rating_count - 1)
                    version.rating_sum = max(0, version.rating_sum - row.score)
                if hasattr(row, "replay_hash"):
                    remember_blob(session, player_id, row.replay_hash)
                    remember_blob(session, player_id, row.content_hash)
                if model is ProductEvent and row.processed_at is None:
                    state.pending_events = max(0, state.pending_events - 1)
                    if row.source == "client":
                        state.pending_clients = max(0, state.pending_clients - 1)
                session.delete(row)
            if not rows:
                job.stage += 1
            session.commit()
            return True
        elif stage == 1 + len(erase_models()):
            return finish_cleanup(app, session, job, final=False)
        elif stage < 3 + len(erase_models()) + 3:
            from .challenge_models import ChallengeTicket
            from .rivalry_models import RivalryGroup, RivalryTicket
            model, field = [(RivalryGroup, "tracks"), (RivalryTicket, "outcome"),
                            (ChallengeTicket, "outcome")][stage - 3 - len(erase_models())]
            column = model.id if model is RivalryGroup else model.ticket_id
            rows = session.scalars(select(model).where(column > cursor).order_by(column).limit(BATCH)
                .with_for_update()).all()
            for row in rows:
                original = getattr(row, field)
                redacted = redact_snapshot(original, player_id)
                if original != redacted:
                    setattr(row, field, redacted)
            if rows:
                job.cursor = getattr(rows[-1], column.key)
            else:
                job.stage, job.cursor = stage + 1, ""
            session.commit()
            return True
        else:
            return finish_cleanup(app, session, job)
    version_id, old_hash, _manifest, state = snapshot
    document = app.state.blobs.get_json(old_hash)
    redacted = {**document, "creator": REMOVED_NAME}
    new_manifest = {}
    if state == "published":
        # Compare against the same current compiler, even for older pinned
        # builds. Immutable historical manifests are never rewritten.
        if hasattr(app.state.verifier, "race_geometry"):
            original_geometry = app.state.verifier.race_geometry(document)
            redacted_geometry = app.state.verifier.race_geometry(redacted)
            if ({k: v for k, v in original_geometry.items() if k != "manifest"} !=
                    {k: v for k, v in redacted_geometry.items() if k != "manifest"}):
                raise RuntimeError("Redaction changed prepared race geometry")
            original_manifest, new_manifest = original_geometry["manifest"], redacted_geometry["manifest"]
        else:
            original_manifest = app.state.verifier.validate_track(document)
            new_manifest = app.state.verifier.validate_track(redacted)
        if ({k: v for k, v in new_manifest.items() if k != "track_content_hash"} !=
                {k: v for k, v in original_manifest.items() if k != "track_content_hash"}):
            raise RuntimeError("Redaction must preserve the published track geometry contract")
    new_hash = app.state.blobs.put_json(redacted)
    with factory() as session:
        job = session.scalar(select(AccountDeletion).where(AccountDeletion.player_id == player_id).with_for_update())
        version = session.scalar(select(TrackVersion).where(TrackVersion.id == version_id).with_for_update())
        if job.stage != 2 + len(erase_models()) or job.cursor != cursor:
            return True
        remember_blob(session, player_id, old_hash)
        version.content_hash = new_hash
        version.redacted_track_hash = new_manifest.get("track_content_hash")
        job.cursor, job.next_attempt_at = version_id, 0
        session.commit()
    return True


def finish_cleanup(app, session, job, *, final=True):
    from .admin_models import AdminAudit
    from .commerce_models import Purchase
    from .object_models import ObjectPin
    from .publication_models import PublicationIntent, PublicationUpload
    from .studio_case_models import StudioCase, StudioCaseEvent
    # Support evidence is private; retain only its nonpersonal operation skeleton.
    case_ids = select(StudioCase.id).where(StudioCase.player_id == job.player_id)
    session.execute(update(StudioCaseEvent).where(StudioCaseEvent.case_id.in_(case_ids)).values(detail={}))
    session.execute(update(StudioCase).where(StudioCase.player_id == job.player_id).values(title=REMOVED_NAME))
    session.execute(update(AdminAudit).where(AdminAudit.entity_id == job.player_id).values(
        reason=REMOVED_NAME, before={}, after={}))
    # Keep token digests for bounded purchase replay/fraud prevention, never Google identity.
    session.execute(delete(Purchase).where(Purchase.player_id == job.player_id,
        Purchase.created_at < now() - app.state.settings.privacy_purchase_days * 86400))
    rows = session.scalars(select(DeletionBlob).where(DeletionBlob.player_id == job.player_id).limit(1)).all()
    deferred = False
    for row in rows:
        pin = session.scalar(select(ObjectPin).where(ObjectPin.digest == row.digest).with_for_update())
        if pin and pin.expires_at > now():
            deferred = True
            continue
        referenced = (session.scalar(select(TrackVersion.id).where(TrackVersion.content_hash == row.digest).limit(1))
            or session.scalar(select(Run.id).where(or_(Run.replay_hash == row.digest, Run.ghost_hash == row.digest)).limit(1))
            or session.scalar(select(PublicationIntent.id).where(PublicationIntent.evidence_retired.is_(False),
                or_(PublicationIntent.content_hash == row.digest, PublicationIntent.replay_hash == row.digest)).limit(1))
            or session.scalar(select(PublicationUpload.player_id).where(PublicationUpload.evidence_retired.is_(False),
                or_(PublicationUpload.content_hash == row.digest, PublicationUpload.replay_hash == row.digest)).limit(1)))
        if not referenced:
            # Uses the same pin lock and fresh reference checks as online maintenance.
            app.state.blobs.delete(row.digest)
        session.delete(row)
    if not rows:
        if final:
            job.completed_at = now()
        else:
            job.stage, job.cursor = job.stage + 1, ""
    job.next_attempt_at = now() + 60 if deferred else 0
    session.commit()
    return True


def expire_records(app, session):
    from .commerce_models import Purchase
    rows = session.scalars(select(Purchase).join(Player).where(Player.deleted_at.is_not(None),
        Purchase.created_at < now() - app.state.settings.privacy_purchase_days * 86400).limit(BATCH)).all()
    for row in rows:
        session.delete(row)
    receipts = session.scalars(select(AccountDeletion).where(AccountDeletion.requested_at < now() - 90 * 86400,
        AccountDeletion.credential_hash != "").limit(BATCH)).all()
    for row in receipts:
        row.credential_hash, row.operation_hash = "", ""
    session.commit()
    return bool(rows or receipts)


def redact_snapshot(value, player_id):
    """Only matching public identity labels; preserve times, ranks and other people."""
    if isinstance(value, list):
        return [redact_snapshot(item, player_id) for item in value]
    if not isinstance(value, dict):
        return value
    result = {key: redact_snapshot(item, player_id) for key, item in value.items()}
    if any(value.get(key) == player_id for key in ("id", "player_id")):
        for key in ("display_name", "name"):
            if key in result:
                result[key] = REMOVED_NAME
        if "country_code" in result:
            result["country_code"] = ""
    if any(value.get(key) == player_id for key in ("owner_id", "creator_id")) and "creator" in result:
        result["creator"] = REMOVED_NAME
    return result


def export_ledger(factory, path):
    """Operator-only stream, copied separately from backups; no identity subjects/tokens."""
    import json
    from pathlib import Path
    target = Path(path)
    temporary = target.with_name(target.name + ".tmp")
    with factory() as session, temporary.open("w", encoding="utf-8") as stream:
        stream.write(json.dumps({"schema": "bmt-erasure-ledger-v1"}) + "\n")
        for row in session.execute(select(AccountDeletion.player_id, AccountDeletion.requested_at)
            .order_by(AccountDeletion.player_id).execution_options(yield_per=100)):
            stream.write(json.dumps({"player_id": row.player_id, "requested_at": row.requested_at}) + "\n")
    temporary.replace(target)


def reapply_ledger(app, path):
    """Run on an offline restore BEFORE reopening APIs/workers; never trusts account names."""
    import json
    from pathlib import Path
    count = 0
    with Path(path).open(encoding="utf-8") as stream:
        if json.loads(stream.readline(256)) != {"schema": "bmt-erasure-ledger-v1"}:
            raise ValueError("Invalid erasure ledger")
        for line in stream:
            if len(line) > 256:
                raise ValueError("Invalid erasure record")
            row = json.loads(line)
            if (set(row) != {"player_id", "requested_at"} or not isinstance(row["player_id"], str)
                    or str(UUID(row["player_id"])) != row["player_id"] or type(row["requested_at"]) is not int
                    or not 1 <= row["requested_at"] <= now()):
                raise ValueError("Invalid erasure record")
            with app.state.session_factory() as session:
                player = session.get(Player, row["player_id"])
                if player is None:
                    continue
                if player.deleted_at is None:
                    remove_account(session, player.id, "", str(uuid4_for_restore()))
                job = session.get(AccountDeletion, player.id)
                if job is not None:
                    job.requested_at, job.completed_at, job.stage, job.cursor, job.next_attempt_at = row["requested_at"], None, 0, "", 0
                    job.journal_written_at = None
                    session.commit()
                count += 1
    return count


def uuid4_for_restore():
    from uuid import uuid4
    return uuid4()


def main():
    import argparse

    from .app import create_app
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--export-ledger")
    group.add_argument("--export-journal-ledger")
    group.add_argument("--reapply-ledger")
    group.add_argument("--cleanup-once", action="store_true")
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args()
    if args.reapply_ledger and not args.offline:
        parser.error("Restoration requires --offline and stopped API/worker services")
    app = create_app()
    try:
        if args.export_ledger:
            export_ledger(app.state.session_factory, args.export_ledger)
        elif args.export_journal_ledger:
            from .erasure_journal import export_journal
            print("Independent journal records exported:", export_journal(app.state.erasure_journal, args.export_journal_ledger))
        elif args.reapply_ledger:
            print("Erasure records reapplied:", reapply_ledger(app, args.reapply_ledger))
        else:
            print("Cleanup progressed:", cleanup_one(app))
    finally:
        app.state.erasure_journal.close() if hasattr(app.state.erasure_journal, "close") else None
        app.state.blobs.close() if hasattr(app.state.blobs, "close") else None
        app.state.engine.dispose()


if __name__ == "__main__":
    main()
