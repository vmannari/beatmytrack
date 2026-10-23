"""A real explicit publication interrupts artificial generation without resubmission."""
import pytest

from bmt_backend.background_work import BackgroundControl, BackgroundYielded
from bmt_backend.publication_models import PublicationIntent
from bmt_backend.publications import process_one
from bmt_backend.track_models import now
from test_publication_intents import domain, publications, request, status  # noqa: F401


def test_publication_interrupts_generation_and_keeps_original_evidence(publications):
    domain = publications
    control = BackgroundControl(domain.app)
    assert not control.is_set()
    intent = request(domain)
    with domain.factory() as session:
        row = session.get(PublicationIntent, intent['publication_id'])
        evidence = row.content_hash, row.replay_hash, row.operation_key, row.request_hash
    control.next_check = 0
    with pytest.raises(BackgroundYielded, match='publication'):
        control.is_set()
    with domain.factory() as session:
        row = session.get(PublicationIntent, intent['publication_id'])
        assert row.status == 'queued' and row.attempts == 0
        assert (row.content_hash, row.replay_hash, row.operation_key, row.request_hash) == evidence
    assert process_one(domain.app)
    assert status(domain, intent['publication_id'])['state'] == 'published'
    assert len(domain.proof_calls) == 1
    control.next_check = 0
    assert not control.is_set()


@pytest.mark.parametrize('state,leased,preempt', [
    ('queued', False, True), ('verifying', False, True),
    ('queued', True, False), ('verifying', True, False),
    ('failed', False, False), ('published', False, False),
])
def test_only_claimable_publications_preempt_generation(publications, state, leased, preempt):
    domain = publications
    intent = request(domain)
    with domain.factory() as session:
        row = session.get(PublicationIntent, intent['publication_id'])
        row.status = state
        row.lease_until = now() + 600 if leased else 0
        session.commit()
    control = BackgroundControl(domain.app)
    if preempt:
        with pytest.raises(BackgroundYielded):
            control.is_set()
    else:
        assert not control.is_set()
