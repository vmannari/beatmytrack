"""Actual maintenance transactions consume immutable local continuations."""
import os

from sqlalchemy import event, update
from test_domains import domain as domain_fixture

from bmt_backend import local_object_listing as listing
from bmt_backend.maintenance import retain
from bmt_backend.object_models import ObjectPin
from bmt_backend.track_models import now

domain = domain_fixture


def test_manifest_preparation_precedes_database_work(domain, monkeypatch):
    observed = []
    original = listing.candidates

    def scan(root, **kwargs):
        observed.append("prepare")
        yield from original(root, **kwargs)

    def checkout(*_args):
        observed.append("database")

    monkeypatch.setattr(listing, "candidates", scan)
    event.listen(domain.app.state.engine, "checkout", checkout)
    try:
        retain(domain.factory, domain.app.state.blobs, scan_limit=3)
    finally:
        event.remove(domain.app.state.engine, "checkout", checkout)
    assert observed[0] == "prepare" and "database" in observed


def test_applied_pages_delete_each_old_orphan_once_and_retain_live_pin(domain):
    blobs = domain.app.state.blobs
    old = now() - 100 * 86400
    keys = {blobs.put_json({"orphan": n}) for n in range(31)}
    for key in keys:
        os.utime(blobs._path(key), (old, old))
    protected = min(keys)
    with domain.factory() as session:
        session.execute(update(ObjectPin).where(ObjectPin.digest.in_(keys - {protected})).values(expires_at=0))
        session.commit()
    cursor, removed = None, 0
    for _ in range(20):
        result = retain(domain.factory, blobs, apply=True, online=True, scan_limit=3, object_cursor=cursor)
        assert result["objects_inspected"] <= 3
        removed += result["orphaned_objects"]
        cursor = result["next_object_cursor"]
        if cursor is None:
            break
    assert cursor is None and removed == len(keys) - 1
    assert blobs._path(protected).exists()
    assert all(not blobs._path(key).exists() for key in keys - {protected})
