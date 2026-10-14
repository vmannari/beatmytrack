"""Real local Studio acceptance with seeded records and actual diagnostic ingress.

This owns a new loopback database. No existing player database, provider service
or remote endpoint is used. Screenshots are seeded UI evidence, not live metrics.
"""
import argparse
import copy
import hashlib
import json
import secrets
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path
from urllib.parse import urlencode, urlsplit
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT / "backend/tests"))


def serve(folder, port):
    """Extend the existing owned fixture before application construction."""
    from dataclasses import replace

    import bmt_backend.app as application
    import uvicorn
    from bmt_backend.product_analytics import project_pending
    from test_backend_studio_console import serve as base_serve

    original_create = application.create_app
    original_run = uvicorn.run

    def create_enabled(settings, **kwargs):
        # Bootstrap closures and middleware must see the initial enabled values.
        return original_create(replace(settings, telemetry_enabled=True, client_quality_enabled=True), **kwargs)

    def seeded(app, **kwargs):
        from bmt_backend.challenge_models import Challenge, ChallengeMember
        from bmt_backend.publication_models import PublicationIntent
        from bmt_backend.telemetry_models import ProductPlayerDay
        from bmt_backend.track_models import Run, RunTicket, TrackVersion, now
        from studio_catalogue_browser_checks import seed_catalogue

        fixture_path = folder / "fixture.json"
        fixture = json.loads(fixture_path.read_text())
        with app.state.session_factory() as session:
            run = session.get(Run, fixture["run_id"])
            version = session.get(TrackVersion, fixture["version_id"])
            version.discovery = {"theme": "pine", "points": [[0, 0], [50, 0], [50, 50], [0, 50], [0, 0]]}
            challenge = Challenge(code="MONITOR1", creator_id=run.player_id, board_id=run.board_id,
                mode="beat", target_run_id=run.id, target_ticks=run.time_ticks, ends_at=now() + 86400)
            session.add(challenge)
            session.flush()
            session.add(ChallengeMember(challenge_id=challenge.id, player_id=run.player_id,
                run_id=run.id, time_ticks=run.time_ticks))
            phone_ticket = RunTicket(player_id=run.player_id, board_id=run.board_id,
                created_at=now(), expires_at=now() + 3600)
            session.add(phone_ticket)
            session.flush()
            publication = PublicationIntent(player_id=run.player_id,
                operation_key="PRIVATE_SEEDED_PUBLICATION_OPERATION", request_hash="d" * 64,
                authoring_id="seeded-explicit-publish-reference", name="Seeded explicit publication",
                content_hash="e" * 64, replay_hash="f" * 64, vehicle_id="compact",
                contract=dict(version.manifest), status="failed", attempts=1,
                lease_token="00000000-0000-4000-8000-000000000099", failure_code="build_mismatch",
                detail="Seeded saved creator lap requires its original track and game build. The local recording is preserved.",
                created_at=now() - 60, finished_at=now() - 55)
            session.add(publication)
            session.flush()
            fixture.update(challenge_id=challenge.id, track_id=version.track_id,
                ticket_id=run.ticket_id, phone_ticket_id=phone_ticket.id,
                publication_id=publication.id,
                **seed_catalogue(session, run.player_id, now()))
            # The combined fixture establishes activity via real ingress, not a
            # manually inserted membership without matching prepared metrics.
            seeded_day = session.get(ProductPlayerDay, (now() // 86400, run.player_id))
            if seeded_day is not None:
                session.delete(seeded_day)
            session.commit()
        fixture_path.write_text(json.dumps(fixture))
        stopping = threading.Event()

        def project():
            while not stopping.is_set():
                try:
                    project_pending(app.state.session_factory, limit=100)
                except Exception:
                    (folder / "projector.failed").write_text("Local fixture projector failed")
                    raise # The owned log retains the traceback; the suite fails.
                stopping.wait(0.25)

        worker = threading.Thread(target=project, name="owned-studio-fixture-projector", daemon=True)
        worker.start()
        try:
            original_run(app, **kwargs)
        finally:
            stopping.set()
            worker.join(timeout=5)

    application.create_app = create_enabled
    uvicorn.run = seeded
    base_serve(folder, port)


def packets(fixture, archive):
    sample_path = ROOT / "build/studio-monitor-2026-10-12/client-test/statistics-sample.json"
    sample = sample_path.read_bytes()
    original = json.loads(sample)
    assert len(original["events"]) == 1 and original["events"][0]["name"] == "race_statistics"
    assert not {"access_token", "refresh_token", "authorization", "lease_token"} & set(original)
    archive.write_bytes(sample)
    first = copy.deepcopy(original)
    event = first["events"][0]
    event["occurred_at"] = int(time.time())
    event["properties"]["track_version_id"] = fixture["version_id"]
    event["properties"]["ticket_id"] = fixture["ticket_id"]
    first["batch_id"] = str(uuid4())
    second = copy.deepcopy(first)
    second["batch_id"] = str(uuid4())
    second["platform"] = "android"
    second["build_id"] = "seeded-monitor-android"
    event = second["events"][0]
    event["id"] = event["properties"]["race_id"] = str(uuid4())
    event["session_id"] = str(uuid4())
    event["seq"] += 1
    event["properties"].update(device_class="android_arm64", device_model="BMT seeded phone",
        os_version="Android 15 fixture", frame_buckets=[0, 0, 900, 120, 120, 60, 0, 0],
        cells=[[0, 0, 8, 2], [1, 0, 8, 0], [2, 1, 4, 1]],
        segments=[[0, 8, 2], [8, 8, 0], [20, 4, 1]], position_samples=20, dropped_samples=0,
        elapsed_ms=120000, ticket_id=fixture["phone_ticket_id"])
    if event["properties"]["schema_version"] == 3:
        event["properties"].update(render_context={"schema_version": 1, "renderer": "mobile", "car_detail": "simple",
            "viewport_width": 2400, "viewport_height": 1080, "scale_percent": 100, "frame_limit": 60,
            "vsync": "enabled", "refresh_hz": 90}, render_context_changed=False)
    return first, second, hashlib.sha256(sample).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serve", type=Path)
    parser.add_argument("--port", type=int)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/evidence/studio-monitor-2026-10-12")
    parser.add_argument("--network-sample", type=Path)
    args = parser.parse_args()
    if args.serve:
        serve(args.serve, args.port)
        return

    import httpx
    from playwright.sync_api import expect, sync_playwright
    from studio_catalogue_browser_checks import exercise_catalogue

    folder = ROOT / "build" / ("studio-monitor-browser-" + uuid4().hex[:8])
    folder.mkdir(parents=True)
    args.output.mkdir(parents=True, exist_ok=True)
    config = {name: secrets.token_urlsafe(32) for name in ("owner", "analyst", "development")}
    (folder / "config.private.json").write_text(json.dumps(config))
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    checks, errors, requests, responses = [], [], [], []
    receipt = {"seeded_loopback_only": True, "remote_writes": 0,
        "diagnostics_source": "Actual Godot-generated fixture packet plus a clearly seeded Android slice",
        "checks": checks, "javascript_errors": errors}

    with (folder / "server.log").open("w", encoding="utf-8") as log:
        server = subprocess.Popen([sys.executable, str(Path(__file__)), "--serve", str(folder), "--port", str(port)],
            stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            with httpx.Client(base_url=base, timeout=15) as http:
                for _ in range(100):
                    if server.poll() is not None:
                        raise RuntimeError("Owned monitor fixture failed; inspect private server.log")
                    try:
                        if http.get("/health").status_code == 200:
                            break
                    except httpx.ConnectError:
                        pass
                    time.sleep(0.2)
                else:
                    raise RuntimeError("Owned monitor fixture did not become ready")
                fixture = json.loads((folder / "fixture.json").read_text())
                admin = {"Authorization": "Bearer " + config["owner"]}
                bootstrap = http.get("/v1/bootstrap").json()["product_telemetry"]
                assert bootstrap["enabled"] is True and bootstrap["quality_schema_version"] == 2
                assert bootstrap["quality_schema_versions"] == [2, 3]
                checks.append("Initial Settings negotiate enabled signed-in quality schema 2")
                signed = http.post("/v1/auth/development", json={"subject": "PRIVATE_PROVIDER_SUBJECT"},
                    headers={"X-Dev-Auth-Key": config["development"]})
                signed.raise_for_status()
                actor = {"Authorization": "Bearer " + signed.json()["access_token"]}
                assert signed.json()["player"]["id"] == fixture["player_id"]
                first, second, sample_hash = packets(fixture, args.output / "client-statistics-sample.json")
                receipt["client_sample_sha256"] = sample_hash
                assert hashlib.sha256((args.output / "client-statistics-sample.json").read_bytes()).hexdigest() == sample_hash

                def diagnostic(params=None):
                    response = http.get("/v1/admin/race-statistics", params=params or {}, headers=admin)
                    response.raise_for_status()
                    return response.json()

                before = diagnostic({"track_version_id": fixture["version_id"]})
                assert not before["totals"] and not before["cells"]
                assert before["track"]["preview"]["available"] and before["collection"]["latest_race_receipt_at"] is None

                with sync_playwright() as driver:
                    browser = driver.chromium.launch(headless=True,
                        executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
                    page = browser.new_page(viewport={"width": 1440, "height": 1000})
                    page.on("pageerror", lambda error: errors.append(str(error)))
                    page.on("request", lambda request: requests.append({"method": request.method,
                        "path": urlsplit(request.url).path, "local": request.url.startswith(base + "/")}))
                    page.on("response", lambda response: responses.append({"status": response.status,
                        "path": urlsplit(response.url).path}))

                    def navigate(fragment):
                        if page.url.split("#", 1)[-1] == fragment:
                            # The real refresh control is intentionally hidden
                            # at phone width; call its existing click handler.
                            page.evaluate("document.querySelector('#refresh').click()")
                        else:
                            page.evaluate("fragment => { location.hash = fragment; }", fragment)

                    def ready_quality():
                        expect(page.locator("#mon-quality-filters")).to_be_visible()
                        expect(page.locator("#main")).not_to_have_attribute("aria-busy", "true")

                    def contained():
                        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth + 1"), page.url

                    quality = "quality?" + urlencode({"version": fixture["version_id"]})
                    page.goto(base + "/admin#" + quality)
                    page.fill("#key", config["owner"])
                    page.locator("#login button").click()
                    ready_quality()
                    expect(page.locator("#main")).to_contain_text("No race summaries for this scope")
                    expect(page.locator(".mon-heatmap")).to_be_visible()
                    assert page.locator(".mon-heatmap rect title").count() == 0
                    assert page.locator(".mon-heatmap polyline").count() == 2
                    page.screenshot(path=str(args.output / "quality-empty-1440.png"), full_page=True)
                    checks.append("Empty heatmap preserves published route shape and explains missing collection")

                    activity_packet = copy.deepcopy(first)
                    activity_packet["batch_id"] = str(uuid4())
                    activity_packet["events"] = [{"id": str(uuid4()), "name": "session_started",
                        "occurred_at": int(time.time()), "session_id": str(uuid4()), "seq": 1,
                        "monotonic_ms": 0, "properties": {"reason": "launch"}}]
                    active = http.post("/v1/telemetry/batches", headers=actor, json=activity_packet)
                    active.raise_for_status()
                    assert active.json()["events"][0]["status"] == "accepted"

                    for packet in (first, second):
                        received = http.post("/v1/telemetry/batches", headers=actor, json=packet)
                        received.raise_for_status()
                        acknowledgements = received.json()["events"]
                        assert len(acknowledgements) == 1 and acknowledgements[0]["id"] == packet["events"][0]["id"] and acknowledgements[0]["status"] == "accepted", received.json()
                        duplicate = http.post("/v1/telemetry/batches", headers=actor, json=packet)
                        duplicate.raise_for_status()
                        assert duplicate.json()["events"][0]["status"] == "duplicate"
                    exit_packet = copy.deepcopy(second)
                    exit_packet["batch_id"] = str(uuid4())
                    exit_packet["events"] = [{"id": str(uuid4()), "name": "process_exit",
                        "occurred_at": int(time.time()), "session_id": str(uuid4()), "seq": 1,
                        "monotonic_ms": 0, "properties": {"device_class": "android_arm64", "exit_reason": 6}}]
                    exited = http.post("/v1/telemetry/batches", headers=actor, json=exit_packet)
                    exited.raise_for_status()
                    assert exited.json()["events"][0]["status"] == "accepted"
                    for _ in range(100):
                        projected = diagnostic({"track_version_id": fixture["version_id"]})
                        if projected["totals"].get("races") == 2:
                            break
                        if (folder / "projector.failed").exists():
                            raise RuntimeError("Owned projector failed; inspect private server.log")
                        time.sleep(0.1)
                    else:
                        raise RuntimeError("Accepted race packages did not reach the actual projector")
                    assert projected["totals"]["position_samples"] == 520
                    assert projected["frame_buckets"] == [a + b for a, b in zip(first["events"][0]["properties"]["frame_buckets"], second["events"][0]["properties"]["frame_buckets"], strict=True)]
                    checks.append("Real authenticated ingress and bounded projector turn two immutable packages into prepared counters without duplicate effects")

                    navigate(quality)
                    ready_quality()
                    assert page.locator(".mon-heatmap rect title").count() > 3
                    expect(page.locator("#main")).not_to_contain_text("No race summaries for this scope")
                    checks.append("Projected real HTTP response renders route shape and actual observed heatmap cells")

                    if args.network_sample:
                        sample = json.loads(args.network_sample.read_text())
                        network_packet = copy.deepcopy(sample)
                        network_packet["batch_id"] = str(uuid4())
                        network_packet["events"] = [event for event in network_packet["events"]
                            if event["name"] in ("network_summary", "network_failure")]
                        for event in network_packet["events"]:
                            event["id"] = str(uuid4()); event["occurred_at"] = int(time.time())
                        expected_attempts = sum(event["properties"]["attempts"] for event in network_packet["events"] if event["name"] == "network_summary")
                        response = http.post("/v1/telemetry/batches", headers=actor, json=network_packet)
                        response.raise_for_status()
                        assert all(event["status"] == "accepted" for event in response.json()["events"])
                        for _ in range(100):
                            response = http.get("/v1/admin/network-health", headers=admin)
                            response.raise_for_status(); observed_network = response.json()
                            if observed_network["totals"].get("attempts") == expected_attempts: break
                            time.sleep(.1)
                        else: raise RuntimeError("Network summaries did not reach their prepared projection")
                        count_before = len(requests)
                        navigate("quality?tab=network")
                        expect(page.get_by_role("heading", name="Client network health", exact=True)).to_be_visible()
                        expect(page.locator("#mon-network-filters")).to_be_visible()
                        identifier = next(event["properties"]["request_id"] for event in network_packet["events"]
                            if event["name"] == "network_failure" and "request_id" in event["properties"])
                        expect(page.locator("#main")).to_contain_text(identifier)
                        expect(page.locator("#main")).to_contain_text("unverified hints")
                        assert page.locator(".mon-network-table").first.evaluate("element => element.scrollWidth <= element.clientWidth+1")
                        assert not any("race-statistics" in row["path"] or "catalogue/tracks" in row["path"] for row in requests[count_before:])
                        page.screenshot(path=str(args.output / "network-health-1440.png"), full_page=True)
                        form = page.locator("#mon-network-filters")
                        form.locator("[name=category]").select_option("score_upload"); form.locator("button").click()
                        expect(page.locator("#mon-network-filters [name=category]")).to_have_value("score_upload")
                        expect(page.locator("#main")).to_contain_text("server-time anchor")
                        for width in (960, 390):
                            page.set_viewport_size({"width": width, "height": 1000})
                            page.wait_for_timeout(100)
                            assert page.evaluate("document.documentElement.scrollWidth <= window.innerWidth+1")
                            page.screenshot(path=str(args.output / f"network-health-{width}.png"), full_page=True)
                        page.set_viewport_size({"width": 1440, "height": 1000})
                        checks.append("Network tab uses prepared native-fixture counters and selected request IDs, preserves category filters, avoids unrelated race/catalogue queries, and stays contained at1440/960/390")
                        navigate(quality); ready_quality()

                    form = page.locator("#mon-quality-filters")
                    form.locator("[name=renderer]").select_option("mobile")
                    form.locator("[name=context_state]").select_option("stable")
                    mobile_context = next(row["key"] for row in projected["render_options"]
                        if row["context"]["renderer"] == "mobile")
                    form.locator("[name=render_context_key]").select_option(mobile_context)
                    form.locator("button").click()
                    ready_quality()
                    assert diagnostic({"track_version_id": fixture["version_id"], "renderer": "mobile",
                        "context_state": "stable"})["totals"]["position_samples"] == 20
                    assert page.locator(".mon-heatmap rect title").count() == 3
                    expect(page.locator("#main")).to_contain_text("2400×1080")
                    expect(page.locator("p.mon-caption").filter(has_text="2400×1080")).to_be_visible()
                    page.screenshot(path=str(args.output / "quality-render-context-1440.png"), full_page=True)
                    checks.append("Actual Studio renderer/context filters isolate the explicitly seeded Android render setup; dimensions and frame pacing remain visible")
                    navigate(quality)
                    ready_quality()

                    form = page.locator("#mon-quality-filters")
                    form.locator("[name=device_model]").select_option("BMT seeded phone")
                    form.locator("button").click()
                    ready_quality()
                    assert "device_model=BMT" in page.url and page.locator(".mon-heatmap rect title").count() == 3
                    assert diagnostic({"track_version_id": fixture["version_id"], "device_model": "BMT seeded phone"})["totals"]["position_samples"] == 20
                    checks.append("Device filter narrows the prepared heatmap to its actual three-cell fixture slice")
                    form.locator("[name=os_version]").select_option("Android 15 fixture")
                    form.locator("button").click()
                    ready_quality()
                    assert "os_version=Android+15+fixture" in page.url
                    assert page.locator(".mon-heatmap rect title").count() == 3
                    page.screenshot(path=str(args.output / "quality-filtered-1440.png"), full_page=True)
                    checks.append("OS filter is applied together with version and device and survives real response rendering")

                    page.get_by_role("link", name="Show slow-frame share", exact=True).click()
                    ready_quality()
                    expect(page.locator(".mon-map-legend")).to_contain_text("Slow sampled seconds")
                    checks.append("Heatmap toggles sampled presence and slow-second share without inventing precise percentiles")
                    page.get_by_role("link", name="Frame times", exact=True).click()
                    expect(page.get_by_role("img", name="Merged race frame-time histogram", exact=True)).to_be_visible()
                    assert page.locator(".mon-histogram > div").count() == 8
                    expect(page.locator("#main")).to_contain_text("900")
                    page.screenshot(path=str(args.output / "quality-frames-1440.png"), full_page=True)
                    page.get_by_role("link", name="Route segments", exact=True).click()
                    expect(page.get_by_role("heading", name="Route segment diagnostics", exact=True)).to_be_visible()
                    assert page.locator(".mon-quality-grid tbody tr").count() == 3
                    page.screenshot(path=str(args.output / "quality-segments-1440.png"), full_page=True)
                    checks.append("Frame and segment tabs retain the same device/OS/version scope and measured values")
                    page.get_by_role("link", name="Collection status", exact=True).click()
                    expect(page.get_by_role("heading", name="Collection and freshness", exact=True)).to_be_visible()
                    expect(page.locator("#main")).to_contain_text("One bounded package")
                    expect(page.locator("#main")).to_contain_text("No diagnostic HTTP requests during driving")
                    page.screenshot(path=str(args.output / "quality-collection-1440.png"), full_page=True)
                    checks.append("Collection status exposes schema, durable receipts, processor freshness and bounded capture policy")
                    page.get_by_role("link", name="Crash / ANR", exact=True).click()
                    expect(page.get_by_role("heading", name="Crash / ANR observations", exact=True)).to_be_visible()
                    expect(page.locator("#main")).to_contain_text("Device / OS attribution unavailable")
                    form.locator("[name=device_model]").select_option("")
                    form.locator("[name=os_version]").select_option("")
                    form.locator("button").click()
                    ready_quality()
                    expect(page.locator("#main")).to_contain_text("Application not responding")
                    expect(page.locator("#main")).to_contain_text("no crash-free denominator")
                    page.screenshot(path=str(args.output / "quality-exits-1440.png"), full_page=True)
                    checks.append("Actual OS-exit ingress remains a separate Crash/ANR lane without invented crash-free rates or player/track attribution")

                    missing = quality + "&" + urlencode({"device_model": "No such fixture device"})
                    navigate(missing)
                    ready_quality()
                    expect(page.locator("#main")).to_contain_text("No race summaries for this scope")
                    expect(page.locator("[name=device_model]")).to_have_value("No such fixture device")
                    assert page.locator(".mon-heatmap rect title").count() == 0
                    page.screenshot(path=str(args.output / "quality-filter-empty-1440.png"), full_page=True)
                    checks.append("No-data device scope remains selected and preserves route context with actionable empty state")

                    exercise_catalogue(page, fixture, args.output, expect, checks)

                    navigate("publications")
                    expect(page.locator("#publication-filters")).to_be_visible()
                    expect(page.locator("#main")).to_contain_text("Seeded explicit publication")
                    publication_filters = page.locator("#publication-filters")
                    publication_filters.locator("[name=state]").select_option("queued")
                    with page.expect_response(lambda response: "/v1/admin/publications?" in response.url):
                        publication_filters.locator("button").click()
                    expect(page.get_by_role("heading", name="No publication requests in this scope", exact=True)).to_be_visible()
                    publication_filters.locator("[name=state]").select_option("failed")
                    with page.expect_response(lambda response: "/v1/admin/publications?" in response.url):
                        publication_filters.locator("button").click()
                    expect(page.locator("#main")).not_to_have_attribute("aria-busy", "true")
                    expect(page.locator("#main")).to_contain_text("build_mismatch")
                    page.get_by_role("link", name="Seeded explicit publication", exact=True).click()
                    expect(page.get_by_role("heading", name="Seeded explicit publication", exact=True)).to_be_visible()
                    expect(page.locator("#main")).to_contain_text("Client retry available after the issue is resolved")
                    expect(page.locator("#main")).to_contain_text("No committed version")
                    expect(page.locator("#main")).to_contain_text("No committed creator run")
                    assert page.locator("#main a[href^='#players/" + fixture["player_id"] + "']").count() == 1
                    assert page.locator("#main [data-action],#main [data-case-action],#main [data-product]").count() == 0
                    text = page.locator("#main").inner_text()
                    assert "PRIVATE_SEEDED_PUBLICATION_OPERATION" not in text
                    assert "00000000-0000-4000-8000-000000000099" not in text
                    page.screenshot(path=str(args.output / "publication-1440.png"), full_page=True)
                    checks.append("Explicit failed-publication metadata stays separate from published catalogue; state filters, retry guidance, creator links and read-only evidence retain no raw document or private operation fields")

                    case_route = "cases/" + fixture["catalogue_case_id"]
                    navigate(case_route)
                    expect(page.get_by_role("heading", name="Activity", exact=True)).to_be_visible()
                    expect(page.locator("#main")).to_contain_text("Owned fixture evidence only")
                    page.locator("[data-case-action=note]").click()
                    note = "Seeded browser evidence <img src=x onerror=alert(1)>"
                    page.locator("#dialog textarea[name=text]").fill(note)
                    with page.expect_response(lambda response: response.request.method == "POST" and response.url.endswith("/cases/" + fixture["catalogue_case_id"] + "/events")) as saved:
                        page.get_by_role("button", name="Save", exact=True).click()
                    assert saved.value.status == 200
                    expect(page.locator("#main")).to_contain_text(note)
                    assert page.locator("#main img").count() == 0
                    page.locator("[data-case-action=transition]").click()
                    permitted = page.locator("#dialog select[name=status] option").evaluate_all("options => options.map(o=>o.value)")
                    assert set(permitted) == {"investigating", "resolved"}
                    page.locator("#case-cancel").click()
                    page.screenshot(path=str(args.output / "cases-1440.png"), full_page=True)
                    checks.append("Case investigation uses escaped append-only evidence, linked context and only legal revision-fenced transition choices")

                    navigate("overview")
                    expect(page.get_by_role("heading", name="Studio pulse", exact=True)).to_be_visible()
                    expect(page.locator("#main")).to_contain_text("Investigation queue")
                    expect(page.locator("#main")).to_contain_text("Crash-free sessions")
                    expect(page.locator("#main")).to_contain_text("Unavailable")
                    page.screenshot(path=str(args.output / "overview-1440.png"), full_page=True)
                    checks.append("Prototype-led pulse displays actual operational context and explicit unavailable stability denominator")

                    navigate("competitions/" + fixture["challenge_id"] + "?kind=challenge")
                    expect(page.get_by_role("heading", name="Challenge inspector", exact=True)).to_be_visible()
                    expect(page.locator("#main")).to_contain_text("Linked accepted result")
                    expect(page.locator("#main")).to_contain_text("Target source checks pass")
                    expect(page.locator("#main")).to_contain_text("Completed-ticket result")
                    page.screenshot(path=str(args.output / "competition-1440.png"), full_page=True)
                    checks.append("Competition inspector explains exact target, evidence rank, accepted source and pinned contract")

                    navigate("system")
                    expect(page.get_by_role("heading", name="Reliability", exact=True)).to_be_visible()
                    expect(page.locator("#main")).to_contain_text("Unavailable")
                    page.screenshot(path=str(args.output / "reliability-1440.png"), full_page=True)
                    checks.append("Reliability distinguishes observed database and worker evidence from unavailable uptime and latency feeds")

                    navigate("economy")
                    expect(page.get_by_role("heading", name="Monetisation", exact=True)).to_be_visible()
                    headings = page.locator("#main h3").all_text_contents()
                    assert headings.index("Financial source coverage") < headings.index("Purchase history") < headings.index("Development catalogue controls")
                    expect(page.get_by_role("heading", name="No matching purchase records", exact=True)).to_be_visible()
                    expect(page.locator("#main")).to_contain_text("Missing transaction feeds are not zero revenue")
                    control = page.locator("[data-product]").first
                    expect(control).to_be_visible()
                    product_id = control.get_attribute("data-product")
                    control.click()
                    expect(page.locator("#product-command")).to_be_visible()
                    page.locator("#dialog [data-close]").click()
                    expect(page.locator("[data-product='" + product_id + "']")).to_be_focused()
                    filters = page.locator("#purchase-filters")
                    filters.locator("[name=provider]").select_option("google_play")
                    filters.locator("[name=q]").fill("no-matching-purchase-fixture")
                    with page.expect_response(lambda response: "/v1/admin/purchases?" in response.url):
                        filters.locator("button").click()
                    expect(page.locator("#main")).not_to_have_attribute("aria-busy", "true")
                    expect(page.get_by_role("heading", name="No matching purchase records", exact=True)).to_be_visible()
                    assert "provider=google_play" in page.url and "q=no-matching-purchase-fixture" in page.url
                    page.screenshot(path=str(args.output / "monetisation-1440.png"), full_page=True)
                    checks.append("Monetisation prioritizes financial source coverage, preserves purchase filters and empty state, and owner preview cancellation restores focus without changing products")

                    for width in (1440, 960, 390):
                        page.set_viewport_size({"width": width, "height": 1000})
                        for name, fragment, selector in (
                            ("quality", quality + "&" + urlencode({"device_model": "BMT seeded phone", "os_version": "Android 15 fixture"}), "#mon-quality-filters"),
                            ("overview", "overview", ".mon-attention"),
                            ("competition", "competitions/" + fixture["challenge_id"] + "?kind=challenge", ".mon-score-table"),
                            ("reliability", "system", ".mon-view"),
                            ("cases", case_route, ".case-workspace"),
                            ("monetisation", "economy", ".commerce-workspace"),
                            ("publication", "publications/" + fixture["publication_id"], ".case-workspace"),
                        ):
                            navigate(fragment)
                            expect(page.locator(selector)).to_be_visible()
                            expect(page.locator("#main")).not_to_have_attribute("aria-busy", "true")
                            contained()
                            if width == 390:
                                expect(page.locator("#sidebar")).to_be_hidden()
                                assert page.locator("h1").evaluate("heading => {const r=heading.getBoundingClientRect();return !document.elementFromPoint(r.x+r.width/2,r.y+r.height/2)?.closest('#sidebar');}")
                            page.evaluate("window.scrollTo(0,0)")
                            page.screenshot(path=str(args.output / f"{name}-{width}.png"), full_page=True)
                    checks.append("Quality, pulse, competition and reliability stay contained at 1440, 960 and 390 pixels")
                    expect(page.locator("#menu")).to_have_attribute("aria-expanded", "false")
                    page.locator("#menu").click()
                    expect(page.locator("#sidebar")).to_be_visible()
                    expect(page.locator("#menu")).to_have_attribute("aria-expanded", "true")
                    page.locator("#close-nav").click()
                    expect(page.locator("#sidebar")).to_be_hidden()
                    expect(page.locator("#menu")).to_have_attribute("aria-expanded", "false")
                    page.locator("#menu").click()
                    expect(page.locator("#sidebar")).to_be_visible()
                    page.keyboard.press("Escape")
                    expect(page.locator("#sidebar")).to_be_hidden()
                    expect(page.locator("#menu")).to_be_focused()
                    checks.append("Closed mobile navigation cannot occlude content; menu opens, close control and Escape close it, with keyboard focus restored")

                    navigate(case_route)
                    expect(page.locator("[data-case-action=note]")).to_be_visible()
                    page.locator("[data-case-action=note]").click()
                    page.locator("#dialog textarea[name=text]").fill("Uncommitted locked case note")
                    page.evaluate("document.querySelector('#logout').click()")
                    expect(page.locator("#login")).to_be_visible()
                    expect(page.locator("#dialog")).not_to_be_visible()
                    page.fill("#key", config["analyst"])
                    page.locator("#login button").click()
                    navigate(case_route)
                    expect(page.get_by_role("heading", name="Activity", exact=True)).to_be_visible()
                    assert page.locator("[data-case-action]").count() == 0
                    expect(page.locator("#main")).not_to_contain_text("Uncommitted locked case note")
                    checks.append("Lock closes an outstanding case command; analyst reconnect cannot submit or inherit its uncommitted note")
                    navigate("players/" + fixture["player_id"] + "?all=1")
                    expect(page.locator(".stc-player-hero")).to_be_visible()
                    assert page.locator("[data-support-action]").count() == 0
                    navigate("economy")
                    expect(page.get_by_role("heading", name="Monetisation", exact=True)).to_be_visible()
                    assert page.locator("[data-product]").count() == 0
                    navigate(quality)
                    ready_quality()
                    assert page.locator("[data-action]").count() == 0
                    checks.append("Analyst can inspect improved workspaces without owner mutation controls")
                    assert not errors, errors
                    assert all(row["local"] for row in requests), "Browser attempted a remote application request"
                    assert not any(row["status"] >= 500 for row in responses), "Local UI API returned server errors"
                    checks.append("Zero JavaScript errors, server failures or remote application requests")
                    browser.close()
                receipt.update(status="passed", checks_passed=len(checks), request_count=len(requests),
                    response_count=len(responses), sources={"initial_client_bootstrap": bootstrap,
                        "race_packages": 2, "position_samples": 520, "device_slices": 2,
                        "actual_canonical_races": False})
                (args.output / "browser.json").write_text(json.dumps(receipt, indent=2) + "\n")
                print(f"Studio monitor browser: {len(checks)} checks passed; seeded loopback only")
        except Exception:
            receipt.update(status="failed", completed_checks=len(checks))
            (args.output / "browser-failed.json").write_text(json.dumps(receipt, indent=2) + "\n")
            raise
        finally:
            if server.poll() is None:
                server.terminate()
                server.wait(timeout=10)


if __name__ == "__main__":
    main()
