"""Real desktop/phone-width browser checks against an owned local seeded service."""

import argparse
import json
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [
    str(ROOT / "backend"),
    str(ROOT / "backend/tests"),
    str(ROOT / "scripts"),
]


def serve(folder, port):
    from dataclasses import replace

    import uvicorn
    from bmt_backend.race_statistics_models import RaceStatisticsDay
    from bmt_backend.studio_finance import import_admob
    from bmt_backend.studio_incidents import Observation, record
    from bmt_backend.studio_platform_models import (
        AnalysisDay,
        AnalysisPerson,
        AnalysisState,
        StudioDelivery,
        StudioIncident,
        StudioRelease,
    )
    from bmt_backend.track_models import digest, now
    from test_backend_studio_console import serve as base_serve

    original = uvicorn.run

    def seeded(app, **kwargs):
        config = json.loads((folder / "config.private.json").read_text())
        app.state.settings = replace(
            app.state.settings,
            telemetry_enabled=True,
            client_quality_enabled=True,
            studio_business_cohorts=True,
            studio_monitor_source_tokens=json.dumps({"fixture": config["monitor"]}),
        )
        fixture = json.loads((folder / "fixture.json").read_text())
        at = now()
        day = at // 86400
        with app.state.session_factory() as db:
            state = db.get(AnalysisState, 1)
            state.started_at = (day - 40) * 86400
            state.processed_through = at
            state.latest_client_at = at - 15
            for index, player in enumerate(
                [fixture["player_id"], fixture["artificial_player_id"]]
            ):
                db.add(
                    AnalysisPerson(
                        player_id=player,
                        first_at=(day - 10) * 86400,
                        first_build="release-a",
                        first_platform="android",
                        artificial=bool(index),
                        journey={
                            "anchor": (day - 5) * 86400,
                            "steps": 6 - index * 2,
                            "truncated": False,
                        },
                    )
                )
                for offset in (10, 9, 7, 3, 1, 0):
                    db.add(
                        AnalysisDay(
                            day=day - offset,
                            player_id=player,
                            dimension=digest({"player": index, "build": "release-a"}),
                            build_id="release-a",
                            platform="android",
                            mode="free_race",
                            artificial=bool(index),
                            device_model="Fixture phone",
                            os_version="14",
                            renderer="mobile",
                            first_at=(day - offset) * 86400,
                            last_at=(day - offset) * 86400 + 300,
                            counters={
                                "active": 1,
                                "race_started": 3,
                                "race_finished": 2,
                                "race_accepted": 2,
                                "foreground_ms": 180000,
                                "quality_attempts": 3,
                                "quality_slow_frames": 40,
                            },
                        )
                    )
            for build, races, slow in [("release-a", 20, 40), ("release-b", 10, 10)]:
                db.add(
                    RaceStatisticsDay(
                        day=day,
                        dimension=digest({"build": build}),
                        track_version_id=fixture["version_id"],
                        build_id=build,
                        platform="android",
                        device_class="phone",
                        device_model="Fixture phone",
                        os_version="14",
                        outcome="finished",
                        races=races,
                        elapsed_ms=120000,
                        frame_buckets=[0, 0, 600, 40, 20, slow, 10, 0],
                        latest_received_at=at,
                        position_samples=30,
                        cells={"0:0": [15, 2], "1:0": [15, 1]},
                        segments={"0": [15, 2], "1": [15, 1]},
                    )
                )
                db.add(
                    StudioRelease(
                        build_id=build,
                        name=build.title(),
                        state="testing",
                        notes="Seeded browser evidence",
                        actor="owner",
                    )
                )
            db.commit()

        def signal(key, active):
            return {
                "key": key,
                "active": active,
                "severity": "critical",
                "title": "Results are waiting for a worker",
                "evidence": "Seeded fixture: oldest result245seconds",
                "next_step": "Compare the compatible worker build and inspect the pending queue.",
                "target": "system/jobs",
            }

        with app.state.session_factory() as db:
            record(
                db,
                app.state.settings,
                "fixture",
                Observation(
                    id=str(uuid4()),
                    observed_at=at - 10,
                    signals=[signal("queue_delay", True)],
                ),
            )
        date = time.strftime("%Y%m%d", time.gmtime(at - 86400))
        with app.state.session_factory() as db:
            from sqlalchemy import select

            incident = db.scalar(select(StudioIncident))
            db.add(
                StudioDelivery(
                    id=digest({"fixture": "dead-delivery"}),
                    incident_id=incident.id,
                    event_id=str(uuid4()),
                    state="dead",
                    attempts=12,
                    payload={},
                    last_error="HTTP_503",
                    created_at=at,
                )
            )
            db.commit()
        with app.state.session_factory() as db:
            import_admob(
                db,
                "accounts/pub-12345678",
                [
                    {"header": {"localizationSettings": {"currencyCode": "EUR"}}},
                    {
                        "row": {
                            "dimensionValues": {
                                "DATE": {"value": date},
                                "APP": {"value": "fixture-app"},
                            },
                            "metricValues": {
                                "ESTIMATED_EARNINGS": {"microsValue": "6500000"}
                            },
                        }
                    },
                    {"footer": {"matchingRowCount": 1}},
                ],
                at,
            )
        original(app, **kwargs)

    uvicorn.run = seeded
    base_serve(folder, port)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serve", type=Path)
    parser.add_argument("--port", type=int)
    parser.add_argument(
        "--output", type=Path, default=ROOT / "docs/evidence/studio-platform-2026-10-16"
    )
    args = parser.parse_args()
    if args.serve:
        return serve(args.serve, args.port)
    import httpx
    from playwright.sync_api import expect, sync_playwright

    folder = ROOT / "build" / ("studio-platform-browser-" + uuid4().hex[:8])
    folder.mkdir(parents=True)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    config = {
        key: secrets.token_urlsafe(32)
        for key in ("owner", "analyst", "development", "monitor")
    }
    (folder / "config.private.json").write_text(json.dumps(config))
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    results = []
    errors = []
    failures = []
    with (folder / "server.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(
            [
                sys.executable,
                str(Path(__file__).resolve()),
                "--serve",
                str(folder),
                "--port",
                str(port),
            ],
            stdout=log,
            stderr=log,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        try:
            with httpx.Client(base_url=base, timeout=15) as client:
                for _ in range(100):
                    if process.poll() is not None:
                        raise RuntimeError(
                            "Owned fixture exited; inspect "
                            + str(folder / "server.log")
                        )
                    try:
                        if client.get("/health").status_code == 200:
                            break
                    except httpx.ConnectError:
                        pass
                    time.sleep(0.2)
                else:
                    raise RuntimeError("Owned fixture startup timeout")
                fixture = json.loads((folder / "fixture.json").read_text())
                created_case = client.post(
                    "/v1/admin/cases",
                    headers={"Authorization": "Bearer " + config["owner"]},
                    json={
                        "command_id": str(uuid4()),
                        "title": "Fixture quality investigation",
                        "player_id": fixture["player_id"],
                    },
                )
                assert created_case.status_code == 200, created_case.text
                case_id = created_case.json()["id"]
                with sync_playwright() as driver:
                    browser = driver.chromium.launch(
                        headless=True,
                        executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
                    )
                    page = browser.new_page(
                        viewport={"width": 1440, "height": 1050}, accept_downloads=True
                    )
                    page.on("pageerror", lambda e: errors.append(str(e)))
                    page.on(
                        "response",
                        lambda r: (
                            failures.append(
                                {
                                    "path": r.url.split("/v1/admin/")[-1],
                                    "status": r.status,
                                }
                            )
                            if "/v1/admin/" in r.url and r.status >= 500
                            else None
                        ),
                    )
                    page.goto(base + "/admin")
                    page.locator("#key").fill(config["owner"])
                    page.locator("#login button").click()

                    def visit(route, width=1440):
                        page.set_viewport_size(
                            {"width": width, "height": 1050 if width > 500 else 844}
                        )
                        at = time.perf_counter()
                        page.evaluate("(route)=>location.hash=route", route)
                        expect(page.locator("#main")).not_to_have_attribute(
                            "aria-busy", "true", timeout=20000
                        )
                        # Hash change dispatch is asynchronous; wait for the requested route to settle.
                        page.wait_for_function(
                            "route=>lastRenderedRoute===route", arg=route, timeout=20000
                        )
                        expect(page.locator("#main")).not_to_contain_text(
                            "Unable to load records"
                        )
                        overflow = page.evaluate(
                            "document.documentElement.scrollWidth>innerWidth+1"
                        )
                        assert not overflow, (
                            route,
                            width,
                            "global horizontal overflow",
                        )
                        results.append(
                            {
                                "route": route,
                                "width": width,
                                "milliseconds": round(
                                    (time.perf_counter() - at) * 1000, 1
                                ),
                                "main_height": page.locator("#main").bounding_box()[
                                    "height"
                                ],
                            }
                        )

                    routes = [
                        "overview",
                        "alarms",
                        "alarms?tab=history",
                        "alarms?tab=notifications",
                        "product",
                        "product?tab=retention",
                        "product?tab=journey",
                        "product?tab=engagement",
                        "product?tab=history",
                        "product?build_id=missing-fixture-build",
                        "quality?build_id=release-a&baseline=release-b",
                        "quality?tab=diagnostics",
                        "quality?tab=frames",
                        "quality?tab=network",
                        "economy",
                        "economy?tab=delivery",
                        "tracks",
                        "publications",
                        "competitions",
                        "cases",
                        "players",
                        "studio",
                        "studio?tab=releases",
                        "studio?tab=experiments",
                        "studio?tab=access",
                        "studio?tab=saved",
                        "system/jobs",
                        "system",
                        "system/audit",
                        "system/access",
                        "live",
                        "cases/" + case_id,
                    ]
                    for route in routes:
                        visit(route)
                    visit('product?build_id=missing-fixture-build')
                    expect(page.locator('#filters select[name=build_id]')).to_have_value('missing-fixture-build')
                    assert page.locator("#nav a").count() == 8
                    visit("product?build_id=release-a&platform=android")
                    page.get_by_role("link", name="Retention", exact=True).click()
                    page.wait_for_function(
                        "()=>location.hash.includes('tab=retention') && lastRenderedRoute===location.hash.slice(1)"
                    )
                    assert "build_id=release-a" in page.url
                    for route in [
                        "overview",
                        "product",
                        "quality?build_id=release-a&baseline=release-b",
                        "alarms",
                    ]:
                        visit(route)
                        page.screenshot(
                            path=str(output / (route.split("?")[0] + "-desktop.png")),
                            full_page=True,
                        )
                    visit("alarms")
                    page.get_by_role(
                        "link", name="Investigate", exact=True
                    ).first.click()
                    expect(
                        page.get_by_role("button", name="Acknowledge", exact=True)
                    ).to_be_visible()
                    identity = page.url.split("#alarms/")[1].split("?")[0]
                    page.get_by_role("button", name="Acknowledge", exact=True).click()
                    page.locator("#platform-command textarea").fill(
                        "Investigating seeded worker mismatch"
                    )
                    page.locator("#platform-command button.btn-primary").click()
                    expect(page.locator("#dialog")).not_to_be_visible()
                    expect(page.locator("#main")).to_contain_text("ACKNOWLEDGED")
                    signal = {
                        "key": "queue_delay",
                        "active": False,
                        "severity": "critical",
                        "title": "Results are waiting for a worker",
                        "evidence": "Seeded fixture worker recovered",
                        "next_step": "Review recovery and clear the occurrence.",
                        "target": "system/jobs",
                    }
                    response = client.post(
                        "/v1/monitor/fixture/observations",
                        headers={"Authorization": "Bearer " + config["monitor"]},
                        json={
                            "id": str(uuid4()),
                            "observed_at": int(time.time()),
                            "signals": [signal],
                        },
                    )
                    assert response.status_code == 200, response.text
                    page.locator("#refresh").click()
                    expect(
                        page.get_by_role("button", name="Clear recovered issue")
                    ).to_be_visible()
                    page.get_by_role("button", name="Clear recovered issue").click()
                    page.locator("#platform-command textarea").fill(
                        "Verified seeded worker recovery"
                    )
                    page.locator("#platform-command button.btn-primary").click()
                    expect(page.locator("#main")).to_contain_text("CLOSED")
                    results.append(
                        {
                            "workflow": "open acknowledge recover clear",
                            "incident": identity,
                            "passed": True,
                        }
                    )
                    visit("cases/" + case_id)
                    page.get_by_role("button", name="Assign & prioritise").click()
                    page.locator(
                        "#platform-command select[name=priority]"
                    ).select_option("urgent")
                    page.locator("#platform-command textarea[name=reason]").fill(
                        "Prioritise seeded quality regression"
                    )
                    page.locator("#platform-command button.btn-primary").click()
                    expect(page.locator("#dialog")).not_to_be_visible()
                    expect(page.locator("#main")).to_contain_text("urgent")
                    visit("alarms?tab=notifications")
                    page.get_by_role("button", name="Dismiss", exact=True).click()
                    page.locator("#platform-command textarea").fill(
                        "Close seeded dead-letter investigation"
                    )
                    page.locator("#platform-command button.btn-primary").click()
                    expect(page.locator("#dialog")).not_to_be_visible()
                    visit("product")
                    page.locator("#platform-save").click()
                    page.locator("#platform-command input").fill(
                        "Fixture saved activity"
                    )
                    page.locator("#platform-command button.btn-primary").click()
                    expect(page.locator("#dialog")).not_to_be_visible()
                    visit("studio?tab=saved")
                    expect(page.locator("#main")).to_contain_text(
                        "Fixture saved activity"
                    )
                    for route in routes:
                        visit(route, 390)
                    for route in [
                        "product",
                        "alarms",
                        "quality?build_id=release-a&baseline=release-b",
                    ]:
                        visit(route, 390)
                        page.screenshot(
                            path=str(output / (route.split("?")[0] + "-mobile.png")),
                            full_page=True,
                        )
                    visit("alarms/" + identity, 390)
                    page.locator("#logout").click()
                    page.locator("#key").fill(config["analyst"])
                    page.locator("#login button").click()
                    expect(page.locator("#main")).to_contain_text(
                        "Owner access is required"
                    )
                    assert page.locator("[data-incident]").count() == 0
                    assert not errors, errors
                    assert not failures, failures
                    browser.close()
            report = {
                "fixture": "Owned local SQLite service; all player/quality/money data seeded, no live provider or deployment",
                "checks": results,
                "javascript_errors": errors,
                "failed_reads": failures,
            }
            (output / "browser.json").write_text(
                json.dumps(report, indent=2), encoding="utf-8"
            )
            print(
                json.dumps(
                    {
                        "checks": len(results),
                        "javascript_errors": errors,
                        "failed_reads": failures,
                        "output": str(output),
                    },
                    indent=2,
                )
            )
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)


if __name__ == "__main__":
    main()
