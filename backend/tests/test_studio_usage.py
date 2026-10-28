"""Resource saturation, missing sources and a Ville-only denominator on real SQL facts."""
import copy
from dataclasses import replace
from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from test_auth_postgres import postgres_auth  # noqa: F401

from bmt_backend.identity_models import Player
from bmt_backend.studio_platform_models import AnalysisDay, AnalysisState
from bmt_backend.studio_reporting import StudioReporting
from bmt_backend.studio_usage import cloud_capacity, cost_summary, headroom
from bmt_backend.studio_usage_cloud import ProviderUnavailable, UsageCloud, sample, summarize
from bmt_backend.track_models import now

OWNER = {"Authorization": "Bearer " + "o" * 40}
ANALYST = {"Authorization": "Bearer " + "a" * 40}


def series(value, *, name="fixture-api", at=None, distribution=False, labels=None):
    at = now() if at is None else at
    raw = {"distributionValue": {"count": 10, "mean": value, "range": {"max": value}}} if distribution else {"doubleValue": value}
    return {"resource": {"labels": {"service_name": name}}, "metric": {"labels": labels or {}},
        "points": [{"interval": {"endTime": datetime.fromtimestamp(at, timezone.utc).isoformat()}, "value": raw}]}


def cloud_fixture(at=None):
    at = now() if at is None else at
    day = datetime.fromtimestamp(at, timezone.utc).date().isoformat()
    def bill(service, sku, amount, resource="fixture-api", currency="EUR"):
        return {"day": day, "service": service, "sku": sku, "net": amount, "gross": amount,
                "currency": currency, "resource": resource}
    return {"status": "observed", "resources": [{"kind": "services", "name": "fixture-api", "instance_limit": 2,
        "concurrency_limit": 16, "request_based": True}], "metrics": {
            "cpu": [series(.96, distribution=True, at=at)], "memory": [series(.78, distribution=True, at=at)],
            "instances": [series(1, at=at)], "concurrency": [series(4, distribution=True, at=at)]},
        "sources": [{"source": "fixture", "status": "observed"}], "billing": {"status": "observed", "observed_at": at,
            "coverage":"Synthetic billing fixture for local acceptance; these are not real charges.",
            "rows": [bill("Cloud Run", "CPU allocation", 10), bill("Cloud Run", "Idle minimum instances", 2),
                     bill("Cloud SQL", "CPU", 8, "fixture-db"), bill("Cloud Run", "Requests", 3, currency="USD")]}}


@pytest.fixture
def usage(auth_app, auth_client):
    return seed_usage(auth_app, auth_client)


def seed_usage(auth_app, auth_client):
    settings = replace(auth_app.state.settings, admin_owner_key="o" * 40, admin_analyst_key="a" * 40,
        studio_usage_project="fixture-project", studio_usage_resources='{"services":["fixture-api"]}')
    auth_app.state.settings = settings
    auth_app.state.studio_reporting.close()
    auth_app.state.studio_reporting = StudioReporting(settings, engine=auth_app.state.engine)
    cloud = cloud_fixture()
    auth_app.state.studio_usage_cloud = SimpleNamespace(collect=lambda *args: copy.deepcopy(cloud))
    at = now()
    with auth_app.state.session_factory() as db:
        ville, other, robot = Player(display_name="Ville"), Player(display_name="Other"), Player(display_name="Robot", is_test_driver=True)
        db.add_all((ville, other, robot))
        db.flush()
        ids = ville.id, other.id, robot.id
        for player, count, dimension in ((ville, 10, "a"), (ville, 10, "b"), (other, 75, "a"), (robot, 5, "a")):
            db.add(AnalysisDay(day=at // 86400, player_id=player.id, dimension=dimension * 64,
                first_at=at-300, last_at=at, counters={"active": 1, "network_attempts": count},
                artificial=player.is_test_driver))
        state = db.get(AnalysisState, 1)
        state.started_at = (at // 86400 - 14) * 86400
        state.processed_through = at
        db.commit()
    return auth_app, auth_client, ids, cloud


@pytest.mark.postgres
def test_postgres_ville_aggregation_and_database_connection_limit(private_postgres):
    app, client = private_postgres
    seed_usage(app, client)
    response = client.get("/v1/admin/usage-costs", headers=OWNER)
    assert response.status_code == 200, response.text
    d = response.json()
    assert d["activity"]["requests"] == 20 and d["activity"]["active_players"] == 1
    connections = next(r for r in d["resources"] if r["key"] == "database_connections")
    assert connections["current"] > 0 and connections["limit"] > connections["current"]
    assert connections["remaining"] == connections["limit"] - connections["current"]


@pytest.fixture
def private_postgres(postgres_auth):  # noqa: F811
    from bmt_backend.app import create_app
    original, _ = postgres_auth
    # The generic auth fixture intentionally creates a public API. Admin routes
    # must be mounted through explicit settings BEFORE construction.
    settings = replace(original.state.settings, workload_role="admin", studio_legacy_keys_enabled=True,
        admin_owner_key="o"*40, admin_analyst_key="a"*40)
    app = create_app(settings, engine=original.state.engine, identity_verifier=original.state.identity_verifier)
    with TestClient(app) as client:
        yield app, client


@pytest.mark.postgres
def test_retained_read_only_snapshot_with_explicit_admin_workload(private_postgres, monkeypatch):
    from test_studio import test_postgres_snapshot_is_read_only_and_does_not_mix_worker_completion
    test_postgres_snapshot_is_read_only_and_does_not_mix_worker_completion(private_postgres, monkeypatch)


def test_ville_only_cost_and_original_global_population(usage):
    app, client, ids, _ = usage
    response = client.get("/v1/admin/usage-costs", headers=OWNER)
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["read_only"] and data["activity"]["player_id"] == ids[0]
    assert data["activity"]["active_players"] == data["activity"]["active_days"] == 1
    assert data["activity"]["requests"] == 20 and data["activity"]["all_observed_requests"] == 100
    assert data["costs"]["request_share"] == .2
    assert data["costs"]["totals"] == [{"currency": "EUR", "gross": 20, "credits": 0, "net": 20},
        {"currency": "USD", "gross": 3, "credits": 0, "net": 3}]
    estimates = data["costs"]["ville_estimates"]
    assert [r["currency"] for r in estimates] == ["EUR", "USD"]
    assert [r["per_active_player"] for r in estimates] == pytest.approx([2, .6])
    assert [r["unallocated"] for r in estimates] == pytest.approx([18, 2.4])
    assert data["resources"][0]["status"] == "critical"
    assert all(r["status"] == "unknown" and r["limit"] is None for r in data["resources"] if r["key"].startswith("ville:"))
    with app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(Player)) == 3
        assert db.scalar(select(func.count()).select_from(AnalysisDay)) == 4


def test_missing_deleted_or_artificial_ville_never_replaces_denominator(usage):
    app, client, ids, _ = usage
    with app.state.session_factory() as db:
        db.get(Player, ids[0]).is_test_driver = True
        db.commit()
    d = client.get("/v1/admin/usage-costs", headers=OWNER).json()
    assert d["activity"]["status"] == "account_not_found"
    assert d["activity"]["active_players"] is None and d["costs"]["ville_estimates"] == []


def test_stable_id_binding_survives_rename_and_erasure_is_next_request_visible(usage):
    app, client, ids, _ = usage
    app.state.settings = replace(app.state.settings, studio_usage_player_id=ids[0])
    with app.state.session_factory() as db:
        db.get(Player, ids[0]).display_name = "Renamed owner"
        db.commit()
    assert client.get("/v1/admin/usage-costs", headers=OWNER).json()["activity"]["player_id"] == ids[0]
    with app.state.session_factory() as db:
        db.get(Player, ids[0]).deleted_at = now()
        db.commit()
    assert client.get("/v1/admin/usage-costs", headers=OWNER).json()["activity"]["player_id"] is None


def test_inactive_and_stale_ville_do_not_produce_cost_per_active_player(usage):
    app, client, ids, _ = usage
    with app.state.session_factory() as db:
        for row in db.scalars(select(AnalysisDay).where(AnalysisDay.player_id == ids[0])):
            row.counters = {**row.counters, "active": 0}
        db.commit()
    d = client.get("/v1/admin/usage-costs", headers=ANALYST).json()
    assert d["activity"]["active_players"] == 0
    assert all(v["per_active_player"] is None for v in d["costs"]["ville_estimates"])
    with app.state.session_factory() as db:
        db.get(AnalysisState, 1).processed_through = now() - 601
        db.commit()
    assert client.get("/v1/admin/usage-costs", headers=OWNER).json()["costs"]["ville_estimates"] == []


def test_reporting_failure_keeps_resource_observations_and_costs(usage, monkeypatch):
    app, client, _, _ = usage
    def unavailable(*args, **kwargs):
        raise HTTPException(503, "STUDIO_ANALYSIS_BUSY")
    monkeypatch.setattr(app.state.studio_reporting, "snapshot", unavailable)
    d = client.get("/v1/admin/usage-costs", headers=OWNER).json()
    assert d["activity"]["status"] == "reporting_unavailable"
    assert d["summary"]["critical"] > 0 and d["costs"]["totals"]
    assert d["costs"]["ville_estimates"] == []


def test_access_dates_and_assets(usage):
    app, client, _, _ = usage
    assert client.get("/v1/admin/usage-costs").status_code == 401
    assert client.post("/v1/admin/usage-costs", headers=OWNER).status_code == 405
    first = (now() // 86400 - 2) * 86400
    assert client.get(f"/v1/admin/usage-costs?since={first+1}&until={first+86400}", headers=OWNER).status_code == 422
    app.state.studio_reporting.limited = True
    assert client.get(f"/v1/admin/usage-costs?since={first-8*86400}&until={first}", headers=OWNER).status_code == 422
    for asset in ("usage.js", "usage.css"):
        assert client.get("/admin/assets/" + asset).status_code == 200


def test_usage_view_can_be_saved_without_expanding_other_saved_routes(usage):
    _, client, _, _ = usage
    body={"command_id":str(uuid4()),"id":str(uuid4()),"expected_revision":0,
          "name":"Resource headroom","route":"usage","filters":{}}
    response=client.post("/v1/admin/saved-views",headers=OWNER,json=body)
    assert response.status_code == 200, response.text
    assert any(row["route"] == "usage" for row in client.get("/v1/admin/saved-views",headers=OWNER).json()["items"])
    assert client.post("/v1/admin/saved-views",headers=OWNER,json={**body,"id":str(uuid4()),
        "command_id":str(uuid4()),"route":"usage/private"}).status_code == 422
    first=(now()//86400-3)*86400
    old_until=first+86400+36000
    response=client.get(f"/v1/admin/usage-costs?since={first}&until={old_until}",headers=OWNER)
    assert response.status_code == 200, response.text
    assert response.json()["until"] == first+2*86400


@pytest.mark.parametrize("current,peak,limit,age,state", [(.7,.74,1,0,"normal"),(.7,.75,1,0,"warning"),
    (.7,.9,1,0,"critical"),(1.2,1.2,1,0,"critical"),(.2,.3,None,0,"unknown"),
    (.2,.3,1,601,"unknown"),(None,None,100,0,"unknown"),(1,1,0,0,"unknown")])
def test_headroom_threshold_peak_missing_and_stale(current, peak, limit, age, state):
    row = headroom("k", "Resource", current, limit, peak=peak, observed_at=10000-age, at=10000)
    assert row["status"] == state
    if age > 600:
        assert row["remaining"] is None and row["used_percent"] is None
    if current is not None and current > (limit or current):
        assert row["remaining"] == 0


def test_histogram_peaks_are_not_mistaken_for_means_or_finite_overflow():
    d = {"distributionValue": {"count": 2, "mean": .3, "bucketOptions": {"explicitBuckets": {"bounds": [.5,.8,1]}}, "bucketCounts": [1,0,1,0]}}
    assert sample(d) == (.3,1,False)
    d["distributionValue"]["bucketCounts"] = [1,0,0,1]
    assert sample(d) == (.3,1,True)
    d["distributionValue"].pop("bucketOptions")
    assert sample(d) == (.3,None,False)
    # Protobuf JSON omits the zero offset and zero mean in actual Run metrics.
    assert sample({"distributionValue":{"count":1,"bucketOptions":{"linearBuckets":{
        "width":.05,"numFiniteBuckets":20}},"bucketCounts":[1]}}) == (0,.0,False)


def test_instance_states_sum_at_each_time_not_across_history():
    a,b = series(1,at=10000),series(2,at=10000)
    a["points"].append(series(10,at=9940)["points"][0])
    result = summarize([a,b],additive=True)
    assert result["current"] == 3 and result["peak"] == 10


def test_manual_workers_are_not_reported_saturated_just_by_running():
    settings = SimpleNamespace(studio_usage_resources='{"workerPools":["fixture-worker"]}')
    cloud = {"resources": [{"kind":"workerPools","name":"fixture-worker","manual_instances":1}], "metrics":{}}
    rows, _ = cloud_capacity(cloud, settings, now())
    worker = next(r for r in rows if r["key"].endswith(":instances"))
    assert worker["limit"] is None and worker["status"] == "unknown"


def test_instance_billing_or_unidentified_resources_are_not_attributed(usage):
    app, _, _, cloud = usage
    activity = {"status":"observed","fresh":True,"full_window_observed":True,"requests":20,"all_observed_requests":100,"active_players":1}
    cloud["resources"][0]["request_based"] = False
    assert cost_summary(cloud,activity,app.state.settings,now())["ville_estimates"] == []
    cloud["resources"][0]["request_based"] = True
    activity["full_window_observed"] = False
    assert cost_summary(cloud,activity,app.state.settings,now())["ville_estimates"] == []
    activity["full_window_observed"] = True
    cloud["resources"][0]["request_based"] = True
    for row in cloud["billing"]["rows"]:
        row["resource"] = "other-api"
    assert cost_summary(cloud,activity,app.state.settings,now())["ville_estimates"] == []


@pytest.mark.parametrize("field,value", [("studio_usage_project",'bad/../../project'),
    ("studio_usage_resources",'{"services":["../secrets"]}'),("studio_usage_resources",'{"services":"bad"}'),
    ("studio_usage_resources",'{"services":[["invalid"]]}'),("studio_usage_resources",'{"services":[]}'),("studio_usage_player_id","Ville"),
    ("studio_usage_billing_table","project.dataset.table` UNION SELECT secret")])
def test_provider_configuration_is_validated(usage,field,value):
    with pytest.raises(ValueError):
        replace(usage[0].state.settings, **{field:value})


def test_billing_query_has_project_date_and_scan_bounds(usage):
    settings = replace(usage[0].state.settings,studio_usage_billing_table="fixture-project.billing.detailed_export")
    calls=[]
    def transport(method,url,**kwargs):
        calls.append((method,url,kwargs))
        if method == "GET":
            return {}
        return {"jobComplete":True,"totalRows":"1","rows":[{"f":[{"v":v} for v in
            ("2026-10-27","Cloud Run","EUR","fixture-api","","CPU allocation","sku","regular","10","-2","100","90","80","2")]}]}
    result=UsageCloud(settings,transport=transport).billing(100,200)
    body=calls[-1][2]["json"]
    assert body["maximumBytesBilled"] == "100000000" and body["parameterMode"] == "NAMED"
    assert "project.id=@project" in body["query"] and "usage_start_time < TIMESTAMP_SECONDS(@until)" in body["query"]
    assert result["rows"][0]["net"] == "8"
    provider=UsageCloud(settings,transport=lambda *a,**k:{"jobComplete":False})
    with pytest.raises(ProviderUnavailable):
        provider.billing(100,200)


def test_provider_missing_permissions_empty_and_partial_series_never_become_zero(usage):
    settings=usage[0].state.settings
    def missing(*a,**kw):
        raise ProviderUnavailable("fixture permission denied")
    cloud=UsageCloud(settings,transport=missing).collect(100,200)
    rows,_=cloud_capacity(cloud,settings,now())
    assert all(r["status"] == "unknown" for r in rows)
    assert all(r["current"] is None for r in rows)
    provider=UsageCloud(settings,transport=lambda *a,**kw:{"nextPageToken":"more"})
    with pytest.raises(ProviderUnavailable):
        provider._metric("cpu",now())


def test_provider_cache_and_no_default_cloud_calls(usage):
    calls=[]
    settings=usage[0].state.settings
    provider=UsageCloud(settings,transport=lambda *a,**k:calls.append(a) or {})
    provider.collect(100,200)
    count=len(calls)
    provider.collect(100,200)
    assert len(calls) == count
    assert provider.collect(0,300)["billing"]["status"] == "refresh_limited"
    assert len(calls) == count
    empty=UsageCloud(replace(settings,studio_usage_project=""),transport=lambda *a,**k:pytest.fail("No default cloud access"))
    assert empty.collect(100,200)["status"] == "not_configured"


def test_endpoint_summary_counts_all_recorded_requests_and_deduplicates_intervals(usage):
    body={"insertId":"fixture-summary","timestamp":datetime.now(timezone.utc).isoformat(),
        "jsonPayload":{"event":"http_cost_summary","body_bytes_after_compression":True,
            "rows":[{"route":"/v1/runs","method":"POST","status":202,"requests":120,
                     "request_wire_bytes":10000,"response_wire_bytes":1000,"duration_ms":5000}]}}
    calls=[]
    provider=UsageCloud(usage[0].state.settings,transport=lambda *a,**kw:calls.append(kw) or {"entries":[body,body]})
    result=provider.endpoint_summaries(now())
    assert result["rows"][0]["requests"] == 120
    assert 'jsonPayload.event="http_cost_summary"' in calls[0]["json"]["filter"]
    assert result["rows"][0]["response_wire_bytes"] == 1000


def test_metric_filters_follow_actual_google_selectors_and_jobs_use_task_template(usage):
    calls=[]
    settings=replace(usage[0].state.settings,studio_usage_resources='{"services":["fixture-api"],"instances":["fixture-db"],"jobs":["fixture-job"]}')
    def transport(method,url,**kwargs):
        calls.append((url,kwargs))
        if url.endswith("/jobs/fixture-job"):
            return {"template":{"parallelism":2,"template":{"timeout":"300s","containers":[{
                "resources":{"limits":{"cpu":"1","memory":"768Mi"}}}]}}}
        return {}
    provider=UsageCloud(settings,transport=transport)
    provider._metric("cpu",now())
    assert " OR resource.type" not in calls[-1][1]["params"]["filter"]
    provider._metric("sql_cpu",now())
    assert 'resource.labels.database_id=one_of("fixture-project:fixture-db")' in calls[-1][1]["params"]["filter"]
    assert "resource.labels.region" not in calls[-1][1]["params"]["filter"]
    job=provider._resource(("jobs","fixture-job"))
    assert job["allocations"] == [{"cpu":"1","memory":"768Mi"}] and job["task_timeout"] == "300s"
