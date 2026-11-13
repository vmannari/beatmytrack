"""Independent financial reconciliation and capacity interpretation regressions."""
from dataclasses import replace
from types import SimpleNamespace

import pytest
from test_studio_usage import seed_usage, series

from bmt_backend.studio_usage import cloud_capacity, cost_summary, headroom
from bmt_backend.studio_usage_cloud import ProviderUnavailable, UsageCloud, summarize


@pytest.fixture
def usage(auth_app, auth_client):
    return seed_usage(auth_app, auth_client)


def settings(**kw):
    return SimpleNamespace(studio_usage_resources='{"services":["fixture-api"]}', **kw)


def activity(**kw):
    return {"status": "observed", "fresh": True, "full_window_observed": True,
        "requests": 1, "all_observed_requests": 4, "active_players": 1, **kw}


def bill(net, *, gross=None, currency="EUR", resource="fixture-api", **kw):
    return {"day": "2026-10-25", "service": "Cloud Run", "sku": "CPU allocation", "currency": currency,
        "resource": resource, "gross": str(net if gross is None else gross), "net": str(net), **kw}


def cloud(rows):
    return {"resources": [{"name": "fixture-api", "request_based": True}],
        "billing": {"status": "observed", "observed_at": 10000, "rows": rows}}


def test_decimal_credits_reconcile_independently_at_every_breakdown():
    data = cloud([bill(".09", gross=".1"), bill(".18", gross=".2"), bill("-2", gross="0"),
        bill("7", currency="USD"), bill("2", resource="worker")])
    result = cost_summary(data, activity(), settings(), 10000)
    assert result["totals"] == [{"currency": "EUR", "gross": 2.3, "credits": -2.03, "net": .27},
        {"currency": "USD", "gross": 7, "credits": 0, "net": 7}]
    for key in ("services", "daily", "resources"):
        for c in ("EUR", "USD"):
            assert sum(r["net"] for r in result[key] if r["currency"] == c) == pytest.approx(.27 if c == "EUR" else 7)
    eur = result["ville_estimates"][0]
    assert eur["eligible_api_net"] == -1.73
    assert eur["per_active_player"] + eur["unallocated"] == pytest.approx(.27)
    assert eur["confidence"] == "low" and result["measured_cost_per_active_player"] is None


def test_export_watermark_is_not_the_successful_query_timestamp():
    result = cost_summary(cloud([bill(2, exported_at=100, usage_through=90)]), activity(), settings(), 10000)
    assert result["last_export_at"] == 100 and result["usage_through"] == 90
    assert result["observed_at"] == 10000
    assert result["forecast"] is None and "final bill" in result["forecast_reason"].lower()


def test_global_resource_binding_regular_costs_and_cloud_run_service_required():
    rows = [bill(4, resource="", global_resource="//run.googleapis.com/projects/fixture-project/locations/europe-west1/services/fixture-api"),
        bill(100, service="Different provider"), bill(100, cost_type="tax"), bill(100, sku="Idle CPU"),
        bill(100, resource="other-api")]
    result = cost_summary(cloud(rows), activity(), settings(), 10000)
    assert result["ville_estimates"][0]["per_active_player"] == 1
    assert result["totals"][0]["net"] == 404


@pytest.mark.parametrize("a", [activity(requests=5), activity(requests=-1), activity(fresh=False),
    activity(full_window_observed=False), activity(requests=None)])
def test_invalid_or_incomplete_client_denominator_never_allocates(a):
    assert cost_summary(cloud([bill(1)]), a, settings(), 10000)["ville_estimates"] == []


@pytest.mark.parametrize("current,peak,expected", [(.2,.99,"warning"),(.8,.99,"warning"),(.95,.99,"critical")])
def test_conservative_bucket_bound_alone_is_not_a_critical_observation(current, peak, expected):
    r = headroom("memory", "Memory", current, 1, peak=peak, peak_kind="upper_bound", observed_at=10000, at=10000)
    assert r["status"] == expected
    assert r["current_percent"] == current*100
    if current < .9:
        assert r["reason"] == "verify_peak"
    exact = headroom("memory", "Memory", current, 1, peak=peak, observed_at=10000, at=10000)
    assert exact["status"] == "critical"


def test_mean_does_not_overwrite_histogram_bound_provenance():
    s = series(.3, at=10000)
    s["points"][0]["value"] = {"distributionValue": {"count": 2, "mean": .3,
        "bucketOptions": {"explicitBuckets": {"bounds": [.5,.8,1]}}, "bucketCounts": [1,0,1,0]}}
    result = summarize([s])
    assert result["current"] == .3 and result["peak"] == 1 and result["peak_kind"] == "upper_bound"


def test_real_earlier_pressure_is_retained_when_the_latest_mean_recovers():
    s = series(.3, at=10000)
    s["points"][0]["value"] = {"distributionValue": {"count": 1, "mean": .3,
        "bucketOptions": {"explicitBuckets": {"bounds": [1]}}, "bucketCounts": [1,0]}}
    older = series(.96, at=9940, distribution=True)
    summary = summarize([s, older])
    row = headroom("memory", "Memory", summary["current"], 1, peak=summary["peak"],
        peak_kind=summary["peak_kind"], proven_peak=summary["proven_peak"], observed_at=10000, at=10000)
    assert row["status"] == "critical" and row["reason"] == "sampled_peak"
    assert summary["proven_peak"] == .96


def test_one_idle_instance_at_configured_ceiling_is_not_load_saturation():
    data = {"resources": [{"kind": "services", "name": "fixture-api", "instance_limit": 1}],
        "metrics": {"instances": [series(1, at=10000)]}}
    row = next(r for r in cloud_capacity(data, settings(), 10000)[0] if r["key"].endswith(":instances"))
    assert row["current"] == row["limit"] == 1 and row["remaining"] == 0
    assert row["status"] == "configured" and row["reason"] == "scaling_ceiling"


def test_missing_export_table_returns_pending_without_a_query_job(usage):
    cfg = replace(usage[0].state.settings, studio_usage_billing_table="fixture-project.billing.gcp_billing_export_resource_v1_A_B_C")
    calls = []
    def transport(method, url, **kw):
        calls.append((method,url))
        if url.endswith("/tables"):
            return {"tables": []}
        raise ProviderUnavailable("not_found")
    r = UsageCloud(cfg, transport=transport).billing(100,200)
    assert r["status"] == "export_pending" and not r["rows"]
    assert len(calls) == 2 and all(method=="GET" for method,_ in calls)


def test_export_discovery_only_accepts_equivalent_configured_account(usage):
    cfg = replace(usage[0].state.settings, studio_usage_billing_table="fixture-project.billing.gcp_billing_export_resource_v1_A_B_C")
    calls = []
    def transport(method, url, **kw):
        calls.append((method,url,kw))
        if url.endswith("/tables"):
            return {"tables": [{"tableReference": {"tableId": "gcp_billing_export_resource_v1_A-B-C"}},
                {"tableReference": {"tableId": "gcp_billing_export_resource_v1_DIFFERENT"}}]}
        if method == "GET":
            raise ProviderUnavailable("not_found")
        return {"jobComplete": True, "totalRows": "0"}
    assert UsageCloud(cfg, transport=transport).billing(100,200)["status"] == "no_data"
    body = calls[-1][2]["json"]
    assert "`fixture-project.billing.gcp_billing_export_resource_v1_A-B-C`" in body["query"]
    assert "CAST(cost AS NUMERIC)" in body["query"] and "MAX(export_time)" in body["query"]
    assert body["maximumBytesBilled"] == "100000000"


def test_provider_failure_reasons_survive_collection_without_private_error_text(usage):
    cfg = replace(usage[0].state.settings, studio_usage_billing_table="fixture-project.billing.detailed")
    def transport(*args, **kwargs):
        raise ProviderUnavailable("permission_denied")
    data = UsageCloud(cfg, transport=transport).collect(100,200)
    assert data["billing"]["reason"] == "permission_denied"
    assert all(s["status"] == "unavailable" and s["reason"] == "permission_denied" for s in data["sources"])
