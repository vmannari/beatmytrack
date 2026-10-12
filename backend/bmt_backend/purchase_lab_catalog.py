"""Approved public tracks for the isolated purchase lab, without racing/player data."""
import json
from pathlib import Path

from sqlalchemy import select

from .contracts import build_contract
from .identity_models import Identity, Player
from .official_tracks import OFFICIAL_NAME, prepare_document
from .track_models import OperationState, Track, TrackVersion, digest, now
from .tracks import discovery_projection

CATALOG_PATH = Path(__file__).with_name("lab_tracks.json")
MARKER = "purchase_lab_catalog"


def seed_lab_catalog(app, *, catalog_path=CATALOG_PATH):
    settings = app.state.settings
    if (settings.environment != "development" or not settings.purchase_simulation_enabled
            or not settings.dev_auth_enabled or not settings.database_url.startswith("sqlite:")):
        raise ValueError("Catalog seeding is restricted to the isolated SQLite purchase lab")
    source = json.loads(catalog_path.read_text(encoding="utf-8"))
    documents = source["documents"]
    if source.get("format") != "bmt-purchase-lab-catalog-v1" or not 1 <= len(documents) <= 100:
        raise ValueError("Invalid purchase lab catalog")
    contract = build_contract(app.state.verifier.manifest())
    fingerprint = digest({"source": source, "contract": contract})
    with app.state.session_factory() as session:
        marker = session.get(OperationState, MARKER)
        if marker and marker.details.get("fingerprint") == fingerprint:
            ids = marker.details.get("versions", [])
            versions = list(session.scalars(select(TrackVersion).where(TrackVersion.id.in_(ids))))
            if len(versions) == len(documents) and all(v.state == "published" and build_contract(v.manifest) == contract for v in versions):
                return {"tracks": len(versions), "published": 0, "existing": len(versions)}
        owner = session.scalar(select(Player).join(Identity).where(
            Identity.provider == "development", Identity.subject == "developer"))
        if owner is None:
            owner = Player(display_name=OFFICIAL_NAME)
            session.add(owner)
            session.flush()
            session.add(Identity(player_id=owner.id, provider="development", subject="developer"))
        if owner.disabled:
            raise ValueError("Purchase-lab developer account is disabled")
        owner_id = owner.id
        session.commit()
    ids = []
    published = 0
    for source_document in documents:
        document, manifest = prepare_document(app.state.verifier, source_document)
        if build_contract(manifest) != contract:
            raise RuntimeError("Catalog verifier contract changed during preparation")
        content_hash = app.state.blobs.put_json(document)
        # Namespace catalog authoring identities so seeded content cannot replace
        # the developer's ordinary creator drafts or published revisions.
        authoring_id = "lab_catalog_" + str(document["id"])
        if len(authoring_id) > 80:
            raise ValueError("Catalog authoring ID is too long")
        with app.state.session_factory() as session:
            track = session.scalar(select(Track).where(Track.owner_id == owner_id, Track.authoring_id == authoring_id))
            if track is None:
                track = Track(owner_id=owner_id, authoring_id=authoring_id, official=True)
                session.add(track)
                session.flush()
            versions = list(session.scalars(select(TrackVersion).where(TrackVersion.track_id == track.id)))
            matching = next((v for v in versions if v.content_hash == content_hash
                and v.state == "published" and build_contract(v.manifest) == contract), None)
            if matching is None:
                matching = TrackVersion(track_id=track.id, number=max((v.number for v in versions), default=0)+1,
                    name=document["name"], content_hash=content_hash,
                    revision_key=digest({"hash":content_hash,"contract":contract}), manifest=manifest,
                    discovery=discovery_projection(document), state="published", published_at=now())
                session.add(matching)
                session.flush()
                published += 1
            ids.append(matching.id)
            session.commit()
        print("Purchase lab catalog: " + document["name"], flush=True)
    with app.state.session_factory() as session:
        marker = session.get(OperationState, MARKER)
        if marker is None:
            marker = OperationState(id=MARKER)
            session.add(marker)
        marker.details = {"fingerprint":fingerprint,"versions":ids}
        marker.updated_at = now()
        session.commit()
    return {"tracks":len(ids),"published":published,"existing":len(ids)-published}
