"""Actual in-process HTTP response over a synthetic ten-million-driver snapshot.

Only the creator fixture is an actual verified test account. Weighted counts
exercise response size and native client compatibility, not deployed capacity.
"""
import json
import importlib.util
import tempfile
from pathlib import Path
from types import SimpleNamespace

from test_domains import domain, headers, public_course

from bmt_backend.histogram_population import HistogramPopulation
from bmt_backend.track_models import HistogramSnapshot, digest

folder = Path(__file__).resolve().parent
fixture_dir = Path(tempfile.mkdtemp(prefix="histogram-packet-", dir=Path.cwd() / "build"))
generator = domain.__wrapped__(fixture_dir, SimpleNamespace(param="sqlite"))
fixture = next(generator)
try:
    version, _board = public_course(fixture)
    from bmt_backend.runs import board_manifest
    from bmt_backend.track_models import TrackVersion

    field = HistogramPopulation.from_frequencies([(1000 + i, 10000) for i in range(1000)])
    with fixture.factory() as session:
        pinned = board_manifest(session.get(TrackVersion, version["version_id"]), "compact")
        identity = digest({"version_id": version["version_id"], **pinned, "comparison_population": "all"})
        payload = {"format": 2}
        for metric in ("race", "best_lap"):
            payload[metric] = {"own": {}, "own_mode": "indexed", "ticks": field.ticks, "counts": field.counts,
                "cumulative": field.cumulative,
                "histogram": field.histogram(identity, metric, 16, *field.frame(None, None, None))}
        row = session.get(HistogramSnapshot, (version["version_id"], "compact", False))
        row.generation, row.population, row.invalidated, row.payload = "synthetic-ten-million", 10000000, False, payload
        session.commit()
    response = fixture.client.get(
        f"/v1/track-versions/{version['version_id']}/results-comparison?vehicle_id=compact", headers=headers(fixture))
    assert response.status_code == 200, response.text
    packet = response.json()
    assert packet["race"]["comparison_approximate"]
    assert sum(row["count"] for row in packet["race"]["bins"]) == 10000000
    # Execute the preserved original reader against the new serialized payload.
    # A separate API process has a cold cache, so clear this fixture's cache.
    from bmt_backend import board_cache
    spec = importlib.util.spec_from_file_location("bmt_backend.owned_histogram_reader_before",
        folder / "before/backend__bmt_backend__histogram_snapshots.py")
    original_reader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(original_reader)
    with board_cache._lock:
        board_cache._caches.pop(fixture.app.state.engine, None)
    with fixture.factory() as session:
        _generation, _revision, fields = original_reader.load_snapshot(session, version["version_id"], "compact", False)
        assert fields[0].cumulative[-1] == 10000000 and fields[0].own.get("any-player") is None
    destination = folder / "synthetic-api-packet.json"
    destination.write_text(json.dumps({"comparison_status": 200, "track": "Synthetic histogram field",
        "synthetic": True, "represented_drivers": 10000000, "packet": packet}, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": response.status_code, "response_bytes": len(response.content),
                      "original_reader_compatible": True, "artifact": str(destination)}))
finally:
    generator.close()
