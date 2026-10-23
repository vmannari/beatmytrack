"""Real local HTTP over weighted ten-million counts, plus old reader compatibility."""
import importlib.util
import json
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace

from test_domains import domain, headers, public_course

from bmt_backend import board_cache
from bmt_backend.histogram_population import HistogramPopulation
from bmt_backend.runs import board_manifest
from bmt_backend.track_models import HistogramSnapshot, TrackVersion, digest

folder = Path(__file__).resolve().parent
fixture_dir = Path(tempfile.mkdtemp(prefix="histogram-followup-packet-", dir=Path.cwd() / "build"))
generator = domain.__wrapped__(fixture_dir, SimpleNamespace(param="sqlite"))
fixture = next(generator)
try:
    version, _board = public_course(fixture)
    field = HistogramPopulation.from_frequencies([(1000+i, 10000) for i in range(1000)])
    with fixture.factory() as session:
        pinned = board_manifest(session.get(TrackVersion, version["version_id"]), "compact")
        identity = digest({"version_id":version["version_id"], **pinned, "comparison_population":"all"})
        row = session.get(HistogramSnapshot, (version["version_id"], "compact", False))
        row.generation, row.population, row.invalidated = "synthetic-followup-ten-million", 10000000, False
        row.payload = {"format":3, **{metric:field.snapshot_payload(identity, metric) for metric in ("race", "best_lap")}}
        session.commit()
    url = f"/v1/track-versions/{version['version_id']}/results-comparison?vehicle_id=compact"
    response = fixture.client.get(url, headers=headers(fixture))
    assert response.status_code == 200, response.text
    repeated = fixture.client.get(url, headers={**headers(fixture), "If-None-Match":response.headers["etag"]})
    assert repeated.status_code == 304 and repeated.content == b""
    packet = response.json()
    assert sum(row["count"] for row in packet["race"]["bins"]) == 10000000
    spec = importlib.util.spec_from_file_location("histogram_followup_previous_population",
        folder / "before/backend__bmt_backend__histogram_population.py")
    old_population = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = old_population
    spec.loader.exec_module(old_population)
    spec = importlib.util.spec_from_file_location("bmt_backend.histogram_followup_previous_reader",
        folder / "before/backend__bmt_backend__histogram_snapshots.py")
    old_reader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(old_reader)
    old_reader.HistogramPopulation = old_population.HistogramPopulation
    with board_cache._lock:
        board_cache._caches.pop(fixture.app.state.engine, None)
    with fixture.factory() as session:
        _generation, _revision, fields = old_reader.load_snapshot(session, version["version_id"], "compact", False)
        assert type(fields[0]) is old_population.HistogramPopulation
        assert fields[0].cumulative[-1] == 10000000 and fields[0].own is None
        assert fields[0].histogram(identity, "race", 16, 1000, 2000) == field.histogram(identity, "race", 16, 1000, 2000)
    destination = folder / "synthetic-api-packet.json"
    destination.write_text(json.dumps({"comparison_status":200, "track":"Synthetic histogram field",
        "synthetic":True, "represented_drivers":10000000, "packet":packet}, indent=2))
    result = {"status":response.status_code, "response_bytes":len(response.content),
        "repeated_status":repeated.status_code, "repeated_body_bytes":len(repeated.content),
        "previous_format2_reader_compatible":True, "format":3}
    (folder / "http-probe.json").write_text(json.dumps(result, indent=2))
    print(json.dumps(result))
finally:
    generator.close()
