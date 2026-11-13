"""Absolute snapshot freshness and exact-grid omission for private comparisons."""
import json
import os
from pathlib import Path

from sqlalchemy import select
from test_domains import domain as domain_fixture
from test_domains import headers, public_course, race

from bmt_backend.histogram_snapshots import refresh_all_for_diagnostics, refresh_interval
from bmt_backend.track_models import HistogramSnapshot

domain = domain_fixture


def ready(domain):
    version, _ = public_course(domain)
    race(domain, version, "Alice", frames=20)
    refresh_all_for_diagnostics(domain.app)
    route = f'/v1/track-versions/{version["version_id"]}/results-comparison?vehicle_id=compact&bins=16'
    return version, route


def test_freshness_is_absolute_snapshot_metadata(domain):
    version, route = ready(domain)
    response = domain.client.get(route, headers=headers(domain))
    assert response.status_code == 200
    data = response.json()
    with domain.app.state.session_factory() as session:
        row = session.scalar(select(HistogramSnapshot).where(
            HistogramSnapshot.version_id == version["version_id"],
            HistogramSnapshot.vehicle_id == "compact", HistogramSnapshot.include_artificial.is_(False)))
        assert data["freshness"] == {"generated_at": row.updated_at, "expires_at": row.next_refresh_at}
        assert row.next_refresh_at - row.updated_at == refresh_interval(row.population, domain.app.state.settings.histogram_refresh_seconds)
    again = domain.client.get(route, headers=headers(domain))
    assert again.json()["freshness"] == data["freshness"]
    conditional = domain.client.get(route, headers={**headers(domain), "If-None-Match": response.headers["etag"]})
    assert conditional.status_code == 304
    assert len(data["histogram_key"]) == 64


def test_only_exact_retained_grids_can_omit_bins(domain):
    _, route = ready(domain)
    full = domain.client.get(route + "&race_ticks=20&lap_ticks=5", headers=headers(domain)).json()
    # Preserve the visible frame while comparing a different (slower) result.
    frame = "".join(f'&{prefix}_from_ticks={full[metric]["bins"][0]["from_ticks"]}'
                    f'&{prefix}_to_ticks={full[metric]["bins"][-1]["to_ticks_exclusive"]}'
                    for metric, prefix in (("race", "race"), ("best_lap", "lap")) if full[metric]["bins"])
    candidate = route + "&race_ticks=21&lap_ticks=6" + frame
    expected = domain.client.get(candidate, headers=headers(domain)).json()
    response = domain.client.get(candidate + "&known_histogram=" + full["histogram_key"], headers=headers(domain))
    overlay = response.json()
    assert overlay["schema"] == "bmt-comparison-overlay-v1"
    assert overlay["histogram_key"] == full["histogram_key"]
    assert "bins" not in overlay["race"] and "bins" not in overlay["best_lap"]
    for metric in ("race", "best_lap"):
        assert overlay[metric] == {key: value for key, value in expected[metric].items() if key != "bins"}
        overlay[metric]["bins"] = full[metric]["bins"]
    overlay.pop("schema")
    assert overlay == expected
    full_response = domain.client.get(candidate, headers=headers(domain))
    assert len(response.content) < len(full_response.content)
    assert response.headers["content-encoding"] == "gzip"
    assert int(response.headers["content-length"]) < int(full_response.headers["content-length"])
    assert "Accept-Encoding" in response.headers["vary"]
    cached_overlay = domain.client.get(candidate + "&known_histogram=" + full["histogram_key"],
                                       headers={**headers(domain), "If-None-Match": response.headers["etag"]})
    assert cached_overlay.status_code == 304 and "Accept-Encoding" in cached_overlay.headers["vary"]
    uncompressed = domain.client.get(candidate + "&known_histogram=" + full["histogram_key"],
                                     headers={**headers(domain), "Accept-Encoding": "identity"})
    assert "content-encoding" not in uncompressed.headers
    assert uncompressed.json() == response.json()
    refused = domain.client.get(candidate + "&known_histogram=" + full["histogram_key"],
                               headers={**headers(domain), "Accept-Encoding": "gzip;q=0, identity"})
    assert "content-encoding" not in refused.headers
    if destination := os.environ.get("BMT_REQUEST_REUSE_EVIDENCE"):
        Path(destination).write_text(json.dumps({"full": expected, "overlay": response.json(),
            "decoded_bytes": {"full":len(full_response.content), "overlay":len(response.content)},
            "wire_body_bytes": {"full":int(full_response.headers["content-length"]),
                                "overlay":int(response.headers["content-length"])},
            "scope":"Disposable two-driver test fixture; not production traffic or HTTP-header totals"}, indent=2)+"\n")
    wrong = domain.client.get(candidate + "&known_histogram=" + "a" * 64, headers=headers(domain)).json()
    assert "schema" not in wrong and "bins" in wrong["race"]
    assert domain.client.get(candidate + "&known_histogram=invalid", headers=headers(domain)).status_code == 422


def test_new_snapshot_expiry_changes_validator_without_restarting_client_age(domain):
    version, route = ready(domain)
    first = domain.client.get(route, headers=headers(domain))
    with domain.app.state.session_factory() as session:
        row = session.scalar(select(HistogramSnapshot).where(
            HistogramSnapshot.version_id == version["version_id"],
            HistogramSnapshot.vehicle_id == "compact", HistogramSnapshot.include_artificial.is_(False)))
        row.next_refresh_at += 1
        session.commit()
    changed = domain.client.get(route, headers={**headers(domain), "If-None-Match": first.headers["etag"]})
    assert changed.status_code == 200
    assert changed.json()["freshness"]["expires_at"] == first.json()["freshness"]["expires_at"] + 1
    assert changed.json()["histogram_key"] == first.json()["histogram_key"]
