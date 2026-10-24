"""Exact encrypted cold receipts; hot-row removal follows durable publication."""
import base64
import gzip
import hashlib
import os
import re
import uuid
import zlib
from collections import defaultdict

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from fastapi import HTTPException
from sqlalchemy import select, tuple_, update

from .object_models import ArchiveChunk, ArchiveKey, CoinArchiveMetric
from .packed_storage import insert
from .storage import canonical_json
from .track_models import IdempotencyRecord, OperationState, Run, digest, now

MAX_ARCHIVE_BYTES = 6 * 1024 * 1024


def retry_key(player_id, scope, key):
    match = re.fullmatch(r"v2\.([0-9]{10})\.[0-9a-f]{48}", key)
    return match[1] + hashlib.sha256(canonical_json([player_id, scope, key])).hexdigest() if match else ""


def actor_key(session, player_id):
    from .identity_models import Player
    key = session.get(ArchiveKey, player_id)
    if key is not None:
        return key.secret
    # First-key creation shares the account deletion writer's lock. A deleted
    # account cannot acquire a replacement key after cryptographic erasure.
    player = session.scalar(select(Player).where(Player.id == player_id).with_for_update(skip_locked=True))
    if player is None or player.deleted_at is not None or player.disabled:
        return None
    key = session.get(ArchiveKey, player_id)
    if key is None:
        secret = os.urandom(32)
        key = ArchiveKey(player_id=player_id, secret=secret, key_id=hashlib.sha256(secret).hexdigest())
        session.add(key)
        session.flush()
    return key.secret


def encrypt(secret, identity, value):
    nonce = os.urandom(12)
    encoded = AESGCM(secret).encrypt(nonce, gzip.compress(canonical_json(value), compresslevel=3, mtime=0), identity.encode("ascii"))
    return {"key_id": hashlib.sha256(secret).hexdigest(), "nonce": base64.b64encode(nonce).decode("ascii"),
            "data": base64.b64encode(encoded).decode("ascii")}


def decrypt(secret, identity, value):
    import json
    try:
        if value.get("key_id") != hashlib.sha256(secret).hexdigest():
            raise ValueError("Archive key identity differs")
        plain = AESGCM(secret).decrypt(base64.b64decode(value["nonce"], validate=True),
            base64.b64decode(value["data"], validate=True), identity.encode("ascii"))
        decoder = zlib.decompressobj(16+zlib.MAX_WBITS)
        decoded = decoder.decompress(plain, 8*1024*1024+1)
        if len(decoded) > 8*1024*1024 or not decoder.eof or decoder.unused_data:
            raise ValueError("Archived record exceeds bounds")
        result = json.loads(decoded)
        if not isinstance(result, dict):
            raise TypeError("Invalid archived record")
        return result
    except (ValueError, KeyError, TypeError, InvalidTag, zlib.error) as error:
        raise OSError("Private archive failed integrity") from error


def cold_response(session, player_id, scope, key, body):
    identity = retry_key(player_id, scope, key)
    if not identity or int(identity[:10]) > now()-session.info.get("cost_archive_days", 7)*86400:
        return None
    chunks = session.scalars(select(ArchiveChunk).where(ArchiveChunk.kind == "retry",
        ArchiveChunk.lower <= identity, ArchiveChunk.upper >= identity)
        .order_by(ArchiveChunk.created_at.desc(), ArchiveChunk.digest).limit(33)).all()
    if len(chunks) > 32:
        raise HTTPException(503, "RETRY_ARCHIVE_LOOKUP_BUSY")
    if not chunks:
        return None
    blobs = session.info.get("cost_archive_blobs")
    secret = session.get(ArchiveKey, player_id)
    if blobs is None or secret is None:
        raise HTTPException(503, "RETRY_ARCHIVE_UNAVAILABLE")
    for chunk in chunks:
        stored = blobs.get_json_in_session(session, chunk.digest) if hasattr(blobs, "get_json_in_session") else blobs.get_json(chunk.digest)
        record = stored.get("records", {}).get(identity)
        if record is None:
            continue
        record = decrypt(secret.secret, identity, record)
        if record.get("request_hash") != digest(body):
            raise HTTPException(409, "Idempotency-Key already used for different content")
        response = record.get("response")
        if not isinstance(response, dict):
            raise OSError("Invalid archived retry response")
        if response.get("retired"):
            raise HTTPException(410, "Attempt history expired; this request will not be repeated")
        from .resume_models import ResumeRace, ResumeReceipt
        from .track_models import RunTicket
        for name, model in (("run_id", Run), ("ticket_id", RunTicket), ("race_id", ResumeRace), ("receipt_id", ResumeReceipt)):
            if response.get(name) and session.get(model, response[name]) is None:
                raise HTTPException(410, "Attempt history expired; this request will not be repeated")
        return response
    return None


def _lease(session, kind, stamp):
    identity = "cost-archive:" + kind
    session.execute(insert(session)(OperationState).values(id=identity, updated_at=stamp, details={})
        .on_conflict_do_nothing(index_elements=[OperationState.id]))
    state = session.scalar(select(OperationState).where(OperationState.id == identity).with_for_update(skip_locked=True))
    if state is None or state.details.get("until", 0) > stamp:
        return None
    token = str(uuid.uuid4())
    state.details = {**state.details, "token": token, "until": stamp+60}
    return state, token


def archive_once(factory, blobs, *, kind="retry", days=7, limit=500, at=None):
    from .economy_models import CoinReward
    from .studio_platform_models import StudioCoinEntry
    if kind not in ("retry", "reward") or not 7 <= days <= 90 or not 1 <= limit <= 1000:
        raise ValueError("Invalid archive work budget")
    stamp = now() if at is None else at
    cutoff = stamp-days*86400
    records, snapshots, size = {}, [], 128
    with factory() as session:
        owned = _lease(session, kind, stamp)
        if owned is None:
            return False
        state, token = owned
        cursor = state.details.get("cursor", "")
        if kind == "retry":
            statement = select(IdempotencyRecord).where(IdempotencyRecord.archive_key > cursor,
                IdempotencyRecord.archive_key != "", IdempotencyRecord.archive_key < str(cutoff), IdempotencyRecord.created_at < cutoff)
            statement = statement.order_by(IdempotencyRecord.archive_key).limit(limit)
        else:
            statement = select(CoinReward).where(CoinReward.created_at < cutoff).order_by(CoinReward.created_at, CoinReward.run_id).limit(limit)
        finance_by_owner = {}
        if kind == "reward":
            reward_rows = session.scalars(statement).all()
            references = ["run/"+row.run_id for row in reward_rows]
            finance_rows = session.scalars(select(StudioCoinEntry).where(StudioCoinEntry.kind == "earned",
                StudioCoinEntry.reference.in_(references))).all() if references else []
            finance_by_owner = {(row.player_id, row.reference): {"id": row.id, "reference": row.reference,
                "kind": row.kind, "amount": row.amount, "created_at": row.created_at, "detail": row.detail} for row in finance_rows}
            source_rows = reward_rows
        else:
            source_rows = session.scalars(statement.execution_options(yield_per=1))
        last = cursor
        secrets = {}
        for row in source_rows:
            identity = row.archive_key if kind == "retry" else row.run_id
            last = identity
            if row.player_id not in secrets:
                secrets[row.player_id] = actor_key(session, row.player_id)
            secret = secrets[row.player_id]
            if secret is None:
                continue
            plain = {"player_id": row.player_id, "scope": row.scope, "key": row.key, "created_at": row.created_at,
                "request_hash": row.request_hash, "response": row.response} if kind == "retry" else {
                "player_id": row.player_id, "amount": row.amount, "rows": row.rows, "created_at": row.created_at,
                "finance": finance_by_owner.get((row.player_id, "run/"+row.run_id))}
            encoded = encrypt(secret, identity, plain)
            length = len(canonical_json(encoded)) + len(identity) + 8
            if size + length > MAX_ARCHIVE_BYTES:
                break
            size += length
            records[identity] = encoded
            snapshots.append((row.player_id, row.scope, row.key, row.request_hash, digest(row.response))) if kind == "retry" else snapshots.append((row.run_id, row.amount, digest(row.rows)))
        if not records:
            state.details = {"until": 0, "cursor": "" if last == cursor else last}
            session.commit()
            return False
        session.commit()  # Release account/lease locks before durable object publication.
    stored_hash = blobs.put_json({"schema": "bmt-private-cost-archive-v1", "kind": kind, "records": records})
    with factory() as session:
        state = session.scalar(select(OperationState).where(OperationState.id == "cost-archive:"+kind).with_for_update())
        if state.details.get("token") != token or state.details.get("until", 0) <= now():
            return False
        if kind == "retry":
            keys = [(player, scope, key) for player, scope, key, _, _ in snapshots]
            rows = session.scalars(select(IdempotencyRecord).where(tuple_(IdempotencyRecord.player_id,
                IdempotencyRecord.scope, IdempotencyRecord.key).in_(keys)).with_for_update(skip_locked=True)).all()
            actual = {(r.player_id, r.scope, r.key): r for r in rows}
            unchanged = len(rows) == len(snapshots) and all(actual[(p, s, k)].request_hash == h
                and digest(actual[(p, s, k)].response) == response_hash for p, s, k, h, response_hash in snapshots)
        else:
            ids = [key for key, _, _ in snapshots]
            rows = session.scalars(select(CoinReward).where(CoinReward.run_id.in_(ids)).with_for_update(skip_locked=True)).all()
            actual = {r.run_id: r for r in rows}
            unchanged = len(rows) == len(snapshots) and all(actual[key].amount == amount and digest(actual[key].rows) == rows_hash
                for key, amount, rows_hash in snapshots)
        if not unchanged:
            state.details = {"until": 0, "cursor": cursor}
            session.commit()
            return False  # Erasure/retention won; never publish stale retry answers.
        session.add(ArchiveChunk(digest=stored_hash, kind=kind, lower=min(records), upper=max(records), records=len(records), created_at=stamp))
        if kind == "reward":
            session.execute(update(Run).where(Run.id.in_(ids)).values(reward_archive_hash=stored_hash))
            finance = session.scalars(select(StudioCoinEntry).where(StudioCoinEntry.reference.in_(["run/"+key for key in ids]),
                StudioCoinEntry.kind == "earned").with_for_update()).all()
            totals = defaultdict(lambda: [0, 0])
            for entry in finance:
                totals[entry.created_at, entry.kind][0] += entry.amount
                totals[entry.created_at, entry.kind][1] += 1
                session.delete(entry)
            for (at_second, entry_kind), (amount, count) in totals.items():
                statement = insert(session)(CoinArchiveMetric).values(at=at_second, kind=entry_kind, amount=amount, count=count)
                session.execute(statement.on_conflict_do_update(index_elements=[CoinArchiveMetric.at, CoinArchiveMetric.kind],
                    set_={"amount": CoinArchiveMetric.amount+amount, "count": CoinArchiveMetric.count+count}))
        for row in rows:
            session.delete(row)
        state.details = {"until": 0, "cursor": last if kind == "retry" else ""}
        state.updated_at = stamp
        session.commit()
    return True


def backfill_retry_keys(factory, limit=500):
    """Bounded upgrade for pre-cutover v2 rows; legacy keys remain permanent."""
    with factory() as session:
        rows = session.scalars(select(IdempotencyRecord).where(IdempotencyRecord.archive_key == "",
            IdempotencyRecord.key.startswith("v2.")).order_by(IdempotencyRecord.created_at)
            .limit(limit).with_for_update(skip_locked=True)).all()
        for row in rows:
            value = retry_key(row.player_id, row.scope, row.key)
            # Malformed historical keys cannot be admitted by the current API.
            row.archive_key = value or "invalid"
        session.commit()
        return bool(rows)
