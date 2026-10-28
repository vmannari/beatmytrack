"""Bounded, read-only Google resource observations and optional billing analysis.

No provider is contacted unless an explicit project and resource inventory are set.
Provider failures retain their source and never become zero usage.
"""
import copy
import json
import math
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation

import google.auth
from google.auth.exceptions import GoogleAuthError
from google.auth.transport.requests import AuthorizedSession
from requests import RequestException

from .studio_usage_settings import (
    inventory,
    validate_settings,  # noqa: F401 - retain the public validation import
)

METRICS = {
    "cpu": "run.googleapis.com/container/cpu/utilizations",
    "memory": "run.googleapis.com/container/memory/utilizations",
    "instances": "run.googleapis.com/container/instance_count",
    "concurrency": "run.googleapis.com/container/max_request_concurrencies",
    "requests": "run.googleapis.com/request_count",
    "sent_bytes": "run.googleapis.com/container/network/sent_bytes_count",
    "billable_seconds": "run.googleapis.com/container/billable_instance_time",
    "sql_cpu": "cloudsql.googleapis.com/database/cpu/utilization",
    "sql_memory": "cloudsql.googleapis.com/database/memory/utilization",
    "sql_disk": "cloudsql.googleapis.com/database/disk/bytes_used",
    "sql_disk_limit": "cloudsql.googleapis.com/database/disk/quota",
    "quota_usage": "serviceruntime.googleapis.com/quota/allocation/usage",
    "quota_limit": "serviceruntime.googleapis.com/quota/limit",
    "quota_rate_usage": "serviceruntime.googleapis.com/quota/ratev2/net_usage",
    "quota_rate_limit": "serviceruntime.googleapis.com/quota/ratev2/limit",
}



def number(value):
    try:
        result = float(value)
        return result if math.isfinite(result) and result >= 0 else None
    except (ValueError, TypeError, OverflowError):
        return None


def epoch(value):
    return int(datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp())


def sample(value):
    """Return mean, conservative peak, and whether that peak is a lower bound."""
    if "distributionValue" not in value:
        n = number(value.get("doubleValue", value.get("int64Value")))
        return n, n, False
    d = value["distributionValue"]
    mean = number(d.get("mean", 0)) if int(d.get("count", 0)) > 0 else None
    if mean is None:
        return None, None, False
    if "max" in d.get("range", {}):
        return mean, number(d["range"]["max"]), False
    options = d.get("bucketOptions", {})
    bounds = options.get("explicitBuckets", {}).get("bounds", [])
    if "exponentialBuckets" in options:
        p = options["exponentialBuckets"]
        bounds = [p["scale"] * p["growthFactor"] ** i for i in range(int(p["numFiniteBuckets"]) + 1)]
    elif "linearBuckets" in options:
        p = options["linearBuckets"]
        bounds = [p.get("offset", 0) + p["width"] * i for i in range(int(p["numFiniteBuckets"]) + 1)]
    occupied = [i for i, count in enumerate(d.get("bucketCounts", [])) if int(count) > 0]
    if not bounds or not occupied:
        # Mean alone cannot establish peak headroom.
        return mean, None, False
    index = max(occupied)
    return mean, number(bounds[min(index, len(bounds) - 1)]), index >= len(bounds)


def summarize(series, *, additive=False):
    buckets, means, peaks, observed = {}, [], [], []
    for row in series:
        for point in row.get("points", []):
            at = epoch(point["interval"]["endTime"])
            mean, peak, is_lower = sample(point.get("value", {}))
            if mean is None:
                continue
            observed.append(at)
            if additive:
                buckets[at] = buckets.get(at, 0) + mean
            else:
                means.append((at, mean))
                if peak is not None:
                    distribution = point.get("value", {}).get("distributionValue")
                    kind = ("lower_bound" if is_lower else "upper_bound"
                        if distribution is not None and "max" not in distribution.get("range", {}) else "exact")
                    peaks.append((peak, kind))
    if additive and buckets:
        means = list(buckets.items())
        peaks = [(v, "exact") for v in buckets.values()]
    if not means:
        return {"current": None, "peak": None, "observed_at": None}
    latest = max(t for t, _ in means)
    peak, peak_kind = max(peaks, key=lambda p: p[0]) if peaks else (None, "unavailable")
    proven_peak = max([v for _, v in means] + [v for v, kind in peaks if kind != "upper_bound"])
    return {"current": max(v for t, v in means if t == latest), "peak": peak,
            "peak_kind": peak_kind,
            "proven_peak": proven_peak,
            "observed_at": max(observed), "peak_is_lower_bound": peak_kind == "lower_bound",
            "total": sum(buckets.values()) if additive else None}


class ProviderUnavailable(Exception):
    pass


class UsageCloud:
    """At most one collection per process; two cached windows; 60s refresh floor."""
    def __init__(self, settings, *, transport=None, clock=time.time):
        self.settings, self.transport, self.clock = settings, transport, clock
        self.lock, self.cache = threading.Lock(), {}
        self.last_started, self.latest = None, None

    def _request(self, method, url, **kwargs):
        # Exact server-owned Google URLs; never accept a browser-provided URL/query.
        try:
            if self.transport:
                body = self.transport(method, url, **kwargs)
                if not isinstance(body, dict):
                    raise ProviderUnavailable("invalid_provider_response")
                return body
            credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
            with AuthorizedSession(credentials) as session:
                response = session.request(method, url, timeout=(2, 5), allow_redirects=False, **kwargs)
                if not response.ok:
                    code = {401: "permission_denied", 403: "permission_denied", 404: "not_found",
                            429: "provider_rate_limited"}.get(response.status_code, "provider_unavailable")
                    if response.status_code == 400 and "bigquery.googleapis.com" in url:
                        reasons = {e.get("reason") for e in response.json().get("error", {}).get("errors", [])}
                        if reasons & {"billingTierLimitExceeded", "resourcesExceeded"}:
                            code = "query_budget_exceeded"
                    raise ProviderUnavailable(code)
                if len(response.content) > 4 * 1024 * 1024:
                    raise ProviderUnavailable("response_limit")
                body = response.json()
                if not isinstance(body, dict):
                    raise ProviderUnavailable("invalid_provider_response")
                return body
        except (GoogleAuthError, RequestException, ValueError, TypeError):
            raise ProviderUnavailable("connection_unavailable") from None

    def _metric(self, key, at):
        quota = key.startswith("quota_")
        start = at - (172800 if quota and key.endswith("limit") else 3600)
        params = {"filter": 'metric.type="' + METRICS[key] + '"', "pageSize": 1000,
            "interval.startTime": datetime.fromtimestamp(start, timezone.utc).isoformat(),
            "interval.endTime": datetime.fromtimestamp(at, timezone.utc).isoformat()}
        if quota:
            params["filter"] += ' AND resource.type="consumer_quota" AND resource.labels.service=one_of("run.googleapis.com","sqladmin.googleapis.com","storage.googleapis.com","bigquery.googleapis.com","logging.googleapis.com")'
            params.update({"aggregation.alignmentPeriod": "300s", "aggregation.perSeriesAligner": "ALIGN_MAX"})
        elif key.startswith("sql_"):
            names = [self.settings.studio_usage_project + ":" + n for n in inventory(self.settings).get("instances", [])]
            params["filter"] += ' AND resource.type="cloudsql_database" AND resource.labels.database_id=one_of(' + ','.join(json.dumps(n) for n in names) + ')'
        else:
            # Monitoring rejects OR between resource types. The metric and
            # common location label select all supported Run resource types.
            params["filter"] += ' AND resource.labels.location="' + self.settings.studio_usage_region + '"'
        rows = []
        for _ in range(3):
            data = self._request("GET", "https://monitoring.googleapis.com/v3/projects/"
                + self.settings.studio_usage_project + "/timeSeries", params=params)
            rows.extend(data.get("timeSeries", []))
            if not data.get("nextPageToken"):
                return rows
            params["pageToken"] = data["nextPageToken"]
        raise ProviderUnavailable("series_limit: narrow inventory/project")

    def _resource(self, item):
        kind, name = item
        project, region = self.settings.studio_usage_project, self.settings.studio_usage_region
        url = ("https://sqladmin.googleapis.com/sql/v1beta4/projects/" + project + "/instances/" + name
            if kind == "instances" else "https://run.googleapis.com/v2/projects/" + project
            + "/locations/" + region + "/" + kind + "/" + name)
        body = self._request("GET", url)
        if kind == "instances":
            cfg = body.get("settings", {})
            return {"kind": kind, "name": name, "disk_autogrow": cfg.get("storageAutoResize", False),
                "disk_max_gib": cfg.get("storageAutoResizeLimit"), "tier": cfg.get("tier")}
        execution = body.get("template", {})
        template = execution.get("template", {}) if kind == "jobs" else execution
        scaling = body.get("scaling", {})
        limits = [c.get("resources", {}).get("limits", {}) for c in template.get("containers", [])]
        revision_cap = template.get("scaling", {}).get("maxInstanceCount")
        service_cap = scaling.get("maxInstanceCount")
        # A revision cap is not a service-wide limit when traffic is split.
        split = bool(body.get("reconciling")) or len([s for s in body.get("trafficStatuses", []) if s.get("percent", 0) > 0]) > 1
        cap = service_cap or (None if split else revision_cap)
        return {"kind": kind, "name": name, "instance_limit": cap,
            "manual_instances": scaling.get("manualInstanceCount") if kind == "workerPools" else None,
            "concurrency_limit": None if split else template.get("maxInstanceRequestConcurrency"),
            "allocations": limits, "traffic_split": split,
            "task_parallelism": execution.get("parallelism") if kind == "jobs" else None,
            "task_timeout": template.get("timeout") if kind == "jobs" else None,
            "request_based": not split and len(template.get("containers", [])) == 1
                and template["containers"][0].get("resources", {}).get("cpuIdle") is True}

    def billing(self, first, until):
        table = self.settings.studio_usage_billing_table
        if not table:
            return {"status": "not_configured", "rows": []}
        # Verify the exact configured export before creating a query job. Google
        # examples use both '-' and '_' in billing-account suffixes; accept only
        # an unambiguous equivalent in this explicit dataset, never another account.
        project, dataset, name = table.split(".")
        base = "https://bigquery.googleapis.com/bigquery/v2/projects/" + project + "/datasets/" + dataset
        try:
            self._request("GET", base + "/tables/" + name)
        except ProviderUnavailable as error:
            if str(error) != "not_found":
                raise
            tables = self._request("GET", base + "/tables", params={"maxResults": 100})
            if tables.get("nextPageToken"):
                raise ProviderUnavailable("export_discovery_limit") from None
            equivalent = [t["tableReference"]["tableId"] for t in tables.get("tables", [])
                if t["tableReference"]["tableId"].replace("-", "_") == name.replace("-", "_")]
            if not equivalent:
                return {"status": "export_pending", "rows": [], "checked_at": int(self.clock()),
                    "coverage": "Waiting for the configured detailed billing export table. Export setup can precede the first delivery. No charges or forecast can be verified yet."}
            if len(equivalent) != 1:
                raise ProviderUnavailable("export_binding_ambiguous") from None
            table = project + "." + dataset + "." + equivalent[0]
        query = """SELECT DATE(usage_start_time, 'UTC') AS day, service.description AS service,
          currency, COALESCE(resource.name, '') AS resource, COALESCE(resource.global_name, '') AS global_resource,
          sku.description AS sku, sku.id AS sku_id, cost_type,
          SUM(CAST(cost AS NUMERIC)) AS gross,
          SUM(IFNULL((SELECT SUM(CAST(c.amount AS NUMERIC)) FROM UNNEST(credits) c),0)) AS credits,
          UNIX_SECONDS(MAX(export_time)) AS exported_at, UNIX_SECONDS(MAX(usage_end_time)) AS usage_through,
          UNIX_SECONDS(MIN(usage_start_time)) AS usage_from, COUNT(*) AS line_items
          FROM `TABLE` WHERE project.id=@project
          AND _PARTITIONTIME >= TIMESTAMP_SUB(TIMESTAMP_SECONDS(@first), INTERVAL 2 DAY)
          AND usage_start_time >= TIMESTAMP_SECONDS(@first)
          AND usage_start_time < TIMESTAMP_SECONDS(@until)
          GROUP BY 1,2,3,4,5,6,7,8 ORDER BY 1,2,3,4,5,6,7,8 LIMIT 2001""".replace("TABLE", table)
        parameters = [{"name": name, "parameterType": {"type": typ}, "parameterValue": {"value": str(value)}}
            for name, typ, value in (("project", "STRING", self.settings.studio_usage_project),
                ("first", "INT64", first), ("until", "INT64", until))]
        data = self._request("POST", "https://bigquery.googleapis.com/bigquery/v2/projects/"
            + table.split(".")[0] + "/queries", json={"query": query, "useLegacySql": False,
                "parameterMode": "NAMED", "queryParameters": parameters, "maximumBytesBilled": "100000000",
                "timeoutMs": 3000, "maxResults": 2001, "location": self.settings.studio_usage_billing_location})
        if not data.get("jobComplete") or data.get("errors") or data.get("pageToken") or int(data.get("totalRows", 0)) > 2000 or len(data.get("rows", [])) > 2000:
            raise ProviderUnavailable("billing_incomplete_or_limit")
        rows = []
        for row in data.get("rows", []):
            day, service, currency, resource, global_resource, sku, sku_id, cost_type, gross, credits, exported, through, start, lines = [f.get("v") for f in row["f"]]
            try:
                gross, credits = Decimal(gross), Decimal(credits)
            except InvalidOperation:
                raise ProviderUnavailable("invalid_billing_value") from None
            if not gross.is_finite() or not credits.is_finite():
                raise ProviderUnavailable("invalid_billing_value")
            rows.append({"day": day, "service": service, "currency": currency, "resource": resource,
                "global_resource": global_resource, "sku": sku, "sku_id": sku_id, "cost_type": cost_type,
                "gross": str(gross), "credits": str(credits), "net": str(gross + credits),
                "exported_at": int(exported) if exported else None, "usage_through": int(through) if through else None,
                "usage_from": int(start) if start else None, "line_items": int(lines)})
        return {"status": "observed" if rows else "no_data", "rows": rows,
            "source": "detailed_billing_export", "first": first, "until": until,
            "observed_at": int(self.clock()), "bytes_processed": data.get("totalBytesProcessed"),
            "coverage": "Usage-date charges for this project only, with credits included. Other projects and billing-account-only charges are excluded. Reporting is delayed, can be restated, and does not reconcile an invoice month."}

    def endpoint_summaries(self, at):
        names = [n for n in inventory(self.settings).get("services", []) if n.endswith("-api")]
        if len(names) != 1:
            return {"status":"not_configured","rows":[]}
        start = datetime.fromtimestamp(at-3600, timezone.utc).isoformat()
        end = datetime.fromtimestamp(at, timezone.utc).isoformat()
        data = self._request("POST", "https://logging.googleapis.com/v2/entries:list", json={
            "resourceNames":["projects/"+self.settings.studio_usage_project],
            "filter":'resource.type="cloud_run_revision" AND resource.labels.service_name="'+names[0]
                +'" AND jsonPayload.event="http_cost_summary" AND timestamp>="'+start+'" AND timestamp<"'+end+'"',
            "orderBy":"timestamp desc","pageSize":1000})
        if data.get("nextPageToken"):
            raise ProviderUnavailable("http_summary_limit")
        totals, seen, latest = {}, set(), None
        for entry in data.get("entries", []):
            insert_id = entry.get("insertId")
            identity = entry.get("logName"), entry.get("timestamp"), insert_id
            if not insert_id or identity in seen:
                continue
            seen.add(identity)
            payload = entry.get("jsonPayload", {})
            if payload.get("event") != "http_cost_summary" or not payload.get("body_bytes_after_compression"):
                raise ProviderUnavailable("invalid_http_summary")
            latest = max(latest or 0, epoch(entry["timestamp"]))
            for row in payload.get("rows", []):
                key = row["route"], row["method"], row["status"]
                if not isinstance(key[0],str) or len(key[0])>200 or not isinstance(key[1],str) or len(key[1])>10 or len(totals)>512:
                    raise ProviderUnavailable("http_summary_bounds")
                target = totals.setdefault(key,{k:0 for k in ("requests","request_wire_bytes","response_wire_bytes","duration_ms")})
                for field in target:
                    value = number(row.get(field))
                    if value is None:
                        raise ProviderUnavailable("invalid_http_counter")
                    target[field] += value
        return {"status":"observed" if totals else "no_data", "observed_at":latest,
            "rows":[{"route":r,"method":m,"status":s,**values} for (r,m,s),values in
                    sorted(totals.items(),key=lambda kv:-kv[1]["duration_ms"])],
            "coverage":"Emitted application summary intervals in the last hour; boundary intervals and unflushed/lost logs can differ from provider totals. Counts cover all requests recorded in each summary; individual success logs are sampled separately."}

    def collect(self, first, until):
        settings, at = self.settings, int(self.clock())
        if not settings.studio_usage_project or not inventory(settings):
            return {"status": "not_configured", "resources": [], "metrics": {}, "billing": {"status": "not_configured", "rows": []},
                    "sources": [{"source": "Google Cloud", "status": "not_configured"}]}
        cache_key = (first, until // 60)
        existing = self.cache.get(cache_key)
        if existing and at - existing["collected_at"] < 60:
            return copy.deepcopy(existing)
        if not self.lock.acquire(blocking=False):
            return {"status": "collecting", "resources": [], "metrics": {}, "billing": {"status": "collecting", "rows": []},
                    "sources": [{"source": "Google Cloud", "status": "collecting"}]}
        try:
            if self.last_started is not None and at - self.last_started < 60:
                result = copy.deepcopy(self.latest) if self.latest else {"resources": [], "metrics": {}, "sources": []}
                result.update(status="refresh_limited", billing={"status":"refresh_limited","rows":[]})
                result["sources"] = [s for s in result["sources"] if s["source"] != "billing"] + [{"source":"billing","status":"refresh_limited"}]
                return result
            self.last_started = at
            result = {"status": "observed", "collected_at": at, "resources": [], "metrics": {}, "sources": [],
                "billing": {"status": "unavailable", "rows": []}}
            tasks = [("resource", (kind, name)) for kind, names in inventory(settings).items() for name in names]
            metric_keys = [k for k in METRICS if not k.startswith("sql_") or inventory(settings).get("instances")]
            tasks += [("metric", key) for key in metric_keys] + [("billing", None), ("endpoints", None)]
            def run(task):
                kind, key = task
                try:
                    value = (self._resource(key) if kind == "resource" else self._metric(key, at)
                             if kind == "metric" else self.billing(first, until) if kind == "billing" else self.endpoint_summaries(at))
                    return kind, key, value, None
                except ProviderUnavailable as error:
                    allowed = {"permission_denied", "not_found", "provider_rate_limited", "query_budget_exceeded",
                        "billing_incomplete_or_limit", "response_limit", "connection_unavailable", "export_binding_ambiguous"}
                    return kind, key, None, str(error) if str(error) in allowed else "provider_unavailable"
                except (KeyError, ValueError, TypeError, AttributeError, IndexError, OverflowError):
                    return kind, key, None, "invalid_provider_response"
            with ThreadPoolExecutor(max_workers=4, thread_name_prefix="studio-usage") as executor:
                for kind, key, value, error in executor.map(run, tasks):
                    source = ("/".join(key) if kind == "resource" else key) or kind
                    result["sources"].append({"source": source, "status": "unavailable" if error else
                        (value.get("status", "observed") if isinstance(value, dict) else "observed" if value else "no_data"),
                        **({"reason": error} if error else {})})
                    if error:
                        if kind in ("billing", "endpoints"):
                            result[kind] = {"status": "unavailable", "reason": error, "rows": []}
                        continue
                    if kind == "resource":
                        result["resources"].append(value)
                    elif kind == "metric":
                        result["metrics"][key] = value
                    elif kind == "billing":
                        result["billing"] = value
                    else:
                        result["endpoints"] = value
            self.cache[cache_key] = copy.deepcopy(result)
            self.latest = copy.deepcopy(result)
            while len(self.cache) > 2:
                self.cache.pop(next(iter(self.cache)))
            return result
        finally:
            self.lock.release()
