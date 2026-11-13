"""Accepted publication prepares durable race geometry before releasing a track."""
from copy import deepcopy

import pytest
from sqlalchemy.exc import OperationalError
from test_publication_intents import domain as domain_fixture
from test_publication_intents import publications as publications_fixture
from test_publication_intents import request, status

from bmt_backend import verifier as adapters
from bmt_backend.publications import process_one
from bmt_backend.track_models import OperationState
from bmt_backend.verifier import VerificationError

domain = domain_fixture
publications = publications_fixture


def native_publication(monkeypatch, context):
    adapter = context.app.state.verifier
    monkeypatch.setattr(adapters, "GodotVerifier", type(adapter))
    geometries = []

    def geometry(document):
        result = {"checkpoint_layout_version": 24, "manifest": adapter.validate_track(document),
                  "gates": [[1, 0, 0, 0, 1, 0, -1, 1, 0]]}
        geometries.append(deepcopy(result))
        return result

    monkeypatch.setattr(adapter, "race_geometry", geometry, raising=False)
    return geometries


def test_accepted_creator_lap_persists_exact_geometry(publications, monkeypatch):
    generated = native_publication(monkeypatch, publications)
    intent = request(publications)
    assert process_one(publications.app)
    assert status(publications, intent["publication_id"])["state"] == "published"
    assert len(publications.proof_calls) == len(generated) == 1
    with publications.factory() as session:
        from bmt_backend.publication_models import PublicationIntent
        key = session.get(PublicationIntent, intent["publication_id"]).content_hash
        cached = session.get(OperationState, "geom:24:" + key)
        assert cached is not None and cached.details == generated[0]


def test_rejected_creator_lap_never_prepares_geometry(publications, monkeypatch):
    generated = native_publication(monkeypatch, publications)

    def reject(*args, **kwargs):
        raise VerificationError("Unfinished creator lap")

    monkeypatch.setattr(publications.app.state.verifier, "verify_run", reject)
    intent = request(publications)
    assert process_one(publications.app)
    assert status(publications, intent["publication_id"])["failure_code"] == "invalid_creator_proof"
    assert not generated


@pytest.mark.parametrize("error", [OSError("cache unavailable"),
                                  OperationalError("cache write", {}, Exception("database unavailable"))])
def test_optional_cache_failure_does_not_block_valid_publication(publications, monkeypatch, error):
    native_publication(monkeypatch, publications)

    def unavailable(*args, **kwargs):
        raise error

    monkeypatch.setattr("bmt_backend.trajectory_verifier.prepared_geometry", unavailable)
    intent = request(publications)
    assert process_one(publications.app)
    assert status(publications, intent["publication_id"])["state"] == "published"
