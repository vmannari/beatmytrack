"""Idempotently seed owner-approved local tracks into the official catalog.

This is an operations command, not an HTTP endpoint.  Official tracks are still
validated by the pinned canonical verifier, but they do not acquire an invented
creator race or leaderboard time.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections.abc import Iterable

from sqlalchemy import select

from .config import Settings
from .db import make_engine, make_session_factory
from .identity_models import Identity, Player
from .storage import LocalBlobStore
from .track_models import Track, TrackVersion, digest, now
from .tracks import discovery_projection
from .usernames import DEVELOPER_NAME, DEVELOPER_NAME_KEY, username_key
from .verifier import GodotVerifier, VerificationError, VerifierUnavailable

OFFICIAL_NAME = DEVELOPER_NAME


def prepare_document(verifier, source: dict) -> tuple[dict, dict]:
    if type(source) is not dict:
        raise ValueError("Every seeded track must be a JSON object")
    document, manifest = verifier.prepare_track({**source, "creator": OFFICIAL_NAME})
    document["creator"] = OFFICIAL_NAME
    name = document.get("name")
    if type(name) is not str or not name.strip() or len(name.strip()) > 80:
        raise ValueError("Seeded track name must contain 1..80 characters")
    if (
        manifest.get("laps") != 5
        or manifest.get("tick_rate") != 120
        or not manifest.get("track_content_hash")
    ):
        raise RuntimeError("Canonical verifier returned an unsupported manifest")
    return document, manifest


def seed_documents(session_factory, blobs, verifier, documents: Iterable[dict]) -> list[dict]:
    """Validate and publish documents under the fixed development identity."""
    with session_factory() as session:
        owner = session.scalar(
            select(Player)
            .join(Identity, Identity.player_id == Player.id)
            .where(Identity.provider == "development", Identity.subject == "developer")
        )
        if owner is None or username_key(owner.display_name) != DEVELOPER_NAME_KEY or owner.disabled:
            raise RuntimeError(f"Active {OFFICIAL_NAME} development account not found")
        session.scalar(select(Player).where(Player.id == owner.id).with_for_update())
        owner.display_name = OFFICIAL_NAME

        results = []
        for source in documents:
            document, manifest = prepare_document(verifier, source)
            name = document["name"].strip()
            content_hash = blobs.put_json(document)
            existing = session.scalar(
                select(TrackVersion)
                .join(Track)
                .where(Track.owner_id == owner.id, TrackVersion.content_hash == content_hash)
            )
            if existing is not None:
                existing_track = session.get(Track, existing.track_id)
                if existing_track.authoring_id is None:
                    existing_track.authoring_id = document.get("id")
                existing.discovery = discovery_projection(document)
                if existing.state != "published":
                    existing.state = "published"
                    existing.published_at = existing.published_at or now()
                results.append({"name": existing.name, "version_id": existing.id, "status": "existing"})
                continue
            track = session.scalar(select(Track).where(Track.owner_id == owner.id, Track.authoring_id == document.get("id")))
            if track is None:
                # Recover legacy identity from immutable content, without renaming it.
                for candidate, previous in session.execute(select(Track, TrackVersion).join(TrackVersion).where(Track.owner_id == owner.id, Track.authoring_id.is_(None))):
                    if blobs.get_json(previous.content_hash).get("id") == document.get("id"):
                        track = candidate
                        track.authoring_id = document.get("id")
                        break
            if track is None:
                track = Track(owner_id=owner.id, authoring_id=document.get("id"))
                session.add(track)
                session.flush()
            head = session.scalar(select(TrackVersion).where(TrackVersion.track_id == track.id).order_by(TrackVersion.number.desc()).limit(1))
            version = TrackVersion(
                track_id=track.id,
                number=head.number + 1 if head else 1,
                name=name,
                content_hash=content_hash,
                manifest=manifest,
                revision_key=digest({"name": name, "hash": content_hash}),
                discovery=discovery_projection(document),
                state="published",
                published_at=now(),
            )
            session.add(version)
            session.flush()
            results.append({"name": name, "version_id": version.id, "status": "published"})
        session.commit()
        return results


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--confirm-owner",
        required=True,
        help=f'Required safety confirmation; must be exactly "{OFFICIAL_NAME}"',
    )
    parser.add_argument("--validate-only", action="store_true", help="Validate every source without writing")
    args = parser.parse_args()
    if args.confirm_owner != OFFICIAL_NAME:
        parser.error(f'--confirm-owner must be exactly "{OFFICIAL_NAME}"')
    # Windows PowerShell 5 writes a UTF-8 BOM when piping text to a native
    # process. Accept it at this operations boundary without weakening JSON.
    payload = json.loads(sys.stdin.buffer.read().decode("utf-8-sig"))
    documents = payload if type(payload) is list else [payload]
    settings = Settings.from_env()
    verifier = GodotVerifier(settings)
    if args.validate_only:
        results = []
        rejected = []
        for source in documents:
            try:
                document, manifest = prepare_document(verifier, source)
            except (ValueError, RuntimeError, VerificationError, VerifierUnavailable) as error:
                rejected.append({"name": source.get("name") if type(source) is dict else None, "error": str(error)})
                continue
            results.append({"name": document["name"], "authoring_id": document["id"], "manifest": manifest})
        json.dump({"validated": len(results), "tracks": results, "rejected": rejected}, sys.stdout, ensure_ascii=False)
        sys.stdout.write("\n")
        if rejected:
            sys.exit(1)
        return
    engine = make_engine(settings.database_url)
    try:
        results = seed_documents(
            make_session_factory(engine),
            LocalBlobStore(settings.object_dir),
            verifier,
            documents,
        )
    finally:
        engine.dispose()
    json.dump({"tracks": results}, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
