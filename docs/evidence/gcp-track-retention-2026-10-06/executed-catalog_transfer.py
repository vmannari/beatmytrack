"""Operator-only immutable official catalog transfer; never import login identities.

The owner confirms an exported source. This adds catalog rows to an existing
database and preserves its accounts/sessions. It is not a database restore or
a player-facing publication bypass.
"""
from __future__ import annotations

import hashlib
from uuid import UUID, uuid5

from sqlalchemy import select

from bmt_backend.identity_models import Identity, Player
from bmt_backend.storage import canonical_json
from bmt_backend.track_models import Track, TrackVersion
from bmt_backend.usernames import username_key

TRACK_FIELDS = ("id", "owner_id", "authoring_id", "hidden", "archived", "official", "created_at")
VERSION_FIELDS = ("id", "track_id", "number", "name", "content_hash", "revision_key", "manifest",
                  "discovery", "state", "created_at", "published_at")


def validate_catalog(payload, verifier, *, confirm_source):
    if (type(payload) is not dict or payload.get("format") != "bmt-catalog-transfer-v1"
            or payload.get("source_origin") != confirm_source or not confirm_source):
        raise ValueError("Explicit source catalog confirmation is required")
    owners, tracks, versions, objects = (payload.get(k) for k in ("owners", "tracks", "versions", "objects"))
    if (not all(type(v) is list for v in (owners, tracks, versions)) or type(objects) is not dict
            or not tracks or len(tracks) > 100 or len(versions) > 500):
        raise ValueError("Invalid or unbounded official catalog")
    by_owner, by_track, by_version, heads, revision_keys, numbers = {}, {}, {}, {}, set(), set()
    for owner in owners:
        UUID(owner["id"])
        if owner["id"] in by_owner or not 1 <= len(owner["display_name"]) <= 40:
            raise ValueError("Duplicate or invalid catalog attribution")
        by_owner[owner["id"]] = owner
    for track in tracks:
        UUID(track["id"])
        if (track["id"] in by_track or track["owner_id"] not in by_owner
                or track.get("official") is not True or track.get("hidden") is not False):
            raise ValueError("Only explicitly exported visible official tracks may be transferred")
        by_track[track["id"]] = track
    for version in versions:
        UUID(version["id"])
        if (version["id"] in by_version or version["track_id"] not in by_track
                or version["state"] != "published" or type(version["number"]) is not int or version["number"] < 1
                or not 1 <= len(version["name"]) <= 80 or not version.get("published_at")):
            raise ValueError("Invalid published revision")
        position = (version["track_id"], version["number"])
        revision = (version["track_id"], version.get("revision_key"))
        if position in numbers or (revision[1] is not None and revision in revision_keys):
            raise ValueError("Duplicate revision numbering/key")
        numbers.add(position)
        revision_keys.add(revision)
        value = objects.get(version["content_hash"])
        if type(value) is not dict or hashlib.sha256(canonical_json(value)).hexdigest() != version["content_hash"]:
            raise ValueError("Immutable source document hash mismatch")
        by_version[version["id"]] = version
        previous = heads.get(version["track_id"])
        if previous is None or previous["number"] < version["number"]:
            heads[version["track_id"]] = version
    if set(heads) != set(by_track) or set(objects) != {v["content_hash"] for v in versions}:
        raise ValueError("Catalog contains missing heads or unrelated objects")
    # Older share links remain byte-identical with their historical rules.
    # A new deterministically identified revision pins a validated document to
    # the current build; existing immutable manifests are never rewritten.
    for head in heads.values():
        manifest = verifier.validate_track(objects[head["content_hash"]])
        if manifest.get("laps") != 5 or manifest.get("tick_rate") != 120 or not manifest.get("track_content_hash"):
            raise ValueError("Destination canonical build returned an unsupported race contract")
        if canonical_json(manifest) != canonical_json(head["manifest"]):
            timestamp = payload.get("transfer_created_at")
            if type(timestamp) is not int or timestamp < max(head["created_at"], head["published_at"]):
                raise ValueError("A fixed migration timestamp is required for a new canonical revision")
            contract_hash = hashlib.sha256(canonical_json(manifest)).hexdigest()
            revision = {**head, "id": str(uuid5(UUID(head["id"]), "canonical-transfer-v1:" + contract_hash)),
                "number": head["number"] + 1, "manifest": manifest,
                "revision_key": hashlib.sha256(canonical_json({"source_version": head["id"], "manifest": manifest})).hexdigest(),
                "created_at": timestamp, "published_at": timestamp}
            by_version[revision["id"]] = revision
    return by_owner, by_track, by_version


def _preflight(session, owners, tracks, versions):
    for source in owners.values():
        existing = session.get(Player, source["id"])
        if existing is not None:
            if (existing.display_name != source["display_name"] or existing.disabled or existing.is_test_driver
                    or session.scalar(select(Identity.id).where(Identity.player_id == existing.id).limit(1))):
                raise RuntimeError("Catalog attribution conflicts with an existing authenticated account")
        other = session.scalar(select(Player.id).where(Player.username_key == username_key(source["display_name"]), Player.id != source["id"]))
        if other is not None:
            raise RuntimeError("Catalog name already belongs to another account")
    for source in tracks.values():
        existing = session.get(Track, source["id"])
        if existing is not None and any(getattr(existing, key) != source[key] for key in TRACK_FIELDS):
            raise RuntimeError("Destination logical track conflicts with source")
        other = session.scalar(select(Track.id).where(Track.owner_id == source["owner_id"], Track.authoring_id == source["authoring_id"], Track.id != source["id"]))
        if source["authoring_id"] is not None and other is not None:
            raise RuntimeError("Destination authoring identity conflicts with source")
    for source in versions.values():
        existing = session.get(TrackVersion, source["id"])
        if existing is not None and any(getattr(existing, key) != source[key] for key in VERSION_FIELDS):
            raise RuntimeError("Destination immutable revision conflicts with source")
        other = session.scalar(select(TrackVersion.id).where(TrackVersion.track_id == source["track_id"], TrackVersion.number == source["number"], TrackVersion.id != source["id"]))
        if other is not None:
            raise RuntimeError("Destination revision number conflicts with source")


def import_catalog(payload, factory, blobs, verifier, *, confirm_source, apply=False):
    owners, tracks, versions = validate_catalog(payload, verifier, confirm_source=confirm_source)
    with factory() as session:
        _preflight(session, owners, tracks, versions)
    result = {"status": "validated", "tracks": len(tracks), "versions": len(versions),
              "objects": len(payload["objects"]), "current_heads_validated": len(tracks),
              "compatible_revisions": len(versions) - len(payload["versions"]),
              "login_identities_imported": 0, "scores_imported": 0, "ratings_imported": 0}
    if not apply:
        return result
    # Immutable IO and canonical validation never hold database locks.
    for digest, document in payload["objects"].items():
        if blobs.put_json(document) != digest or blobs.get_json(digest) != document:
            raise RuntimeError("Destination object integrity check failed")
    with factory() as session:
        _preflight(session, owners, tracks, versions)
        inserted_tracks = inserted_versions = 0
        for source in owners.values():
            if session.get(Player, source["id"]) is None:
                # Catalog attribution has no login provider, credentials,
                # memberships, times or rewards. Google accounts stay separate.
                session.add(Player(id=source["id"], display_name=source["display_name"], created_at=source["created_at"],
                                   disabled=False, is_test_driver=False, needs_username=False))
        session.flush()
        for source in tracks.values():
            if session.get(Track, source["id"]) is None:
                session.add(Track(**{key: source[key] for key in TRACK_FIELDS}))
                inserted_tracks += 1
        session.flush()
        for source in versions.values():
            if session.get(TrackVersion, source["id"]) is None:
                session.add(TrackVersion(**{key: source[key] for key in VERSION_FIELDS},
                    creator_test_run_id=None, rating_sum=0, rating_count=0, verified_finishers=0))
                inserted_versions += 1
        session.commit()
    return {**result, "status": "imported", "inserted_tracks": inserted_tracks,
            "inserted_versions": inserted_versions}
