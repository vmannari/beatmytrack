"""Fixture hooks for the combined Studio browser acceptance suite.

Seed only into its newly owned loopback database. These observations do not
represent real players, canonical race validation or production analytics.
"""


def seed_catalogue(session, player_id, timestamp):
    from uuid import uuid4

    from bmt_backend.studio_case_models import StudioCase, StudioCaseEvent
    from bmt_backend.telemetry_models import ProductPlayerDay, ProductProfile
    from bmt_backend.track_models import Track, TrackVersion

    versions = []
    draft_id = None
    for index in range(35):
        track = Track(owner_id=player_id, hidden=index == 1, archived=index == 2,
            official=index % 7 == 0, created_at=timestamp - 1000 + index)
        session.add(track)
        session.flush()
        version = TrackVersion(track_id=track.id, number=1, name=f"Catalogue circuit {index:02}",
            content_hash=f"{index + 1000:064x}", manifest={"laps": 5, "tick_rate": 120},
            state="published", created_at=timestamp - 1000 + index,
            published_at=timestamp - 1000 + index,
            discovery={"theme": "storm" if index % 2 else "pine",
                "points": [[0, 0], [70, 0], [90, 25], [55, 65], [10, 40], [0, 0]]},
            rating_sum=(index % 5 + 1) * 3, rating_count=3, verified_finishers=index * 5)
        session.add(version)
        session.flush()
        versions.append(version.id)
        if index == 0:
            draft = TrackVersion(track_id=track.id, number=2, name="Catalogue PRIVATE local draft",
                content_hash="a" * 64, manifest={}, state="draft", created_at=timestamp - 500)
            session.add(draft)
            session.flush()
            draft_id = draft.id
    case = StudioCase(player_id=player_id, title="Catalogue fixture investigation",
        created_at=timestamp - 500, updated_at=timestamp - 400)
    session.add(case)
    session.flush()
    session.add(StudioCaseEvent(id=str(uuid4()), case_id=case.id, actor="owner", kind="note",
        revision=0, detail={"text": "Owned fixture evidence only"}, request_hash="c" * 64,
        created_at=timestamp - 400))
    if session.get(ProductProfile, player_id) is None:
        session.add(ProductProfile(player_id=player_id, first_activity_at=timestamp - 700,
            milestones=[["menu_ready", timestamp - 700, "private-fixture-session", 0, 0]],
            projection={}, quality={}))
    if session.get(ProductPlayerDay, (timestamp // 86400, player_id)) is None:
        session.add(ProductPlayerDay(day=timestamp // 86400, player_id=player_id))
    session.flush()
    return {"catalogue_version_id": versions[0], "catalogue_draft_id": draft_id,
        "catalogue_case_id": case.id}


def exercise_catalogue(page, fixture, output, expect, checks):
    def navigate(fragment):
        page.evaluate("fragment => { location.hash = fragment; }", fragment)

    player_id = fixture["player_id"]
    page.set_viewport_size({"width": 1440, "height": 1000})
    navigate("tracks?q=Catalogue&sort=name&direction=asc&limit=10")
    expect(page.locator("#catalogue-filters")).to_be_visible()
    expect(page.locator(".stc-track-identity")).to_have_count(10)
    assert page.locator(".stc-route-small").count() == 10
    assert "PRIVATE local draft" not in page.locator("#main").inner_text()
    first_version = page.locator(".stc-track-identity").first.get_attribute("href")
    with page.expect_response(lambda response: "/v1/admin/catalogue/tracks?" in response.url
            and response.request.method == "GET"):
        page.get_by_role("link", name="Next", exact=True).click()
    expect(page.locator("#main")).not_to_have_attribute("aria-busy", "true")
    expect(page.locator(".stc-track-identity")).to_have_count(10)
    assert page.locator(".stc-track-identity").first.get_attribute("href") != first_version
    assert "anchor=" in page.url
    with page.expect_response(lambda response: "/v1/admin/catalogue/tracks?" in response.url
            and response.request.method == "GET"):
        page.get_by_role("link", name="Previous", exact=True).click()
    expect(page.locator("#main")).not_to_have_attribute("aria-busy", "true")
    expect(page.locator(".stc-track-identity")).to_have_count(10)
    expect(page.locator(".stc-track-identity").first).to_have_attribute("href", first_version)
    assert page.locator(".stc-track-identity").first.get_attribute("href") == first_version
    checks.append("Published catalogue uses prepared route previews, creation-anchored paging and excludes draft revisions")

    page.locator("#catalogue-filters [name=theme]").select_option("storm")
    page.locator("#catalogue-filters [name=visibility]").select_option("visible")
    page.locator("#catalogue-filters [name=origin]").select_option("community")
    page.locator("#catalogue-filters [name=sort]").select_option("finishers")
    page.locator("#catalogue-filters [name=direction]").select_option("desc")
    page.locator("#catalogue-filters [name=min_rating]").fill("3")
    page.locator("#catalogue-filters [name=min_finishers]").fill("20")
    with page.expect_response(lambda response: "/v1/admin/catalogue/tracks?" in response.url
            and response.request.method == "GET"):
        page.locator("#catalogue-filters button").click()
    expect(page.locator("#main")).not_to_have_attribute("aria-busy", "true")
    assert "theme=storm" in page.url and "sort=finishers" in page.url
    assert page.locator(".stc-track-identity").count() > 0
    return_url = page.url.split("#", 1)[1]
    page.screenshot(path=str(output / "tracks-1440.png"), full_page=True)
    page.locator(".stc-track-identity").first.click()
    expect(page.get_by_role("heading", name="Stored route shape", exact=True)).to_be_visible()
    expect(page.get_by_role("link", name="Investigate heatmap", exact=True)).to_be_visible()
    assert page.locator("#main details").count()
    with page.expect_response(lambda response: "/v1/admin/catalogue/tracks?" in response.url
            and response.request.method == "GET"):
        page.get_by_role("link", name="← All tracks", exact=True).click()
    expect(page.locator("#main")).not_to_have_attribute("aria-busy", "true")
    expect(page.locator("#catalogue-filters")).to_be_visible()
    assert page.url.split("#", 1)[1] == return_url
    assert page.locator("#catalogue-filters [name=theme]").input_value() == "storm"
    assert page.locator("#catalogue-filters [name=sort]").input_value() == "finishers"
    checks.append("Catalogue biome, visibility, source, rating, finisher and sort filters survive detail and back navigation")

    page.locator("#catalogue-filters [name=q]").fill("No matching catalogue fixture")
    page.locator("#catalogue-filters button").click()
    expect(page.get_by_role("heading", name="No matching published tracks", exact=True)).to_be_visible()
    checks.append("Filtered published catalogue presents an actionable empty state")

    navigate("players/" + player_id + "?all=1")
    expect(page.locator(".stc-player-hero")).to_be_visible()
    expect(page.locator("#support-filters")).to_be_visible()
    expect(page.locator("#main")).to_contain_text("Catalogue fixture investigation")
    expect(page.locator("#main")).to_contain_text("Verified gross spend")
    assert page.locator(".stc-timeline li").count() > 0
    assert "private-fixture-session" not in page.locator("#main").inner_text()
    page.screenshot(path=str(output / "player-1440.png"), full_page=True)
    page.get_by_role("link", name="Entitlements & resumes", exact=True).click()
    expect(page.locator("#main")).to_contain_text("One initial slot; no monthly refill")
    expect(page.locator("#main")).to_contain_text("One UTC calendar month from purchase")
    controls = page.locator("[data-support-action=simulate_purchase]")
    if controls.count():
        page.get_by_text("Development purchase controls", exact=True).click()
        expect(controls).to_be_visible()
        controls.click()
        expect(page.locator("#dev-preview")).to_be_visible()
        page.locator("#dialog [data-close]").click()
    page.get_by_role("link", name="Identity & coverage", exact=True).click()
    expect(page.locator("#main")).to_contain_text("display name is not ownership proof")
    checks.append("Player support combines profile, server timeline, entitlement policy, linked cases and explicit unavailable financial/identity sources")

    for width in (1440, 960, 390):
        page.set_viewport_size({"width": width, "height": 1000})
        navigate("players/" + player_id + "?all=1")
        expect(page.locator(".stc-player-hero")).to_be_visible()
        page.evaluate("window.scrollTo(0,0)")
        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth + 1")
        page.screenshot(path=str(output / f"player-{width}.png"), full_page=True)
        navigate("tracks?q=Catalogue&limit=10")
        expect(page.locator("#catalogue-filters")).to_be_visible()
        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth + 1")
        page.screenshot(path=str(output / f"tracks-{width}.png"), full_page=True)
    checks.append("Published catalogue and player investigation remain contained at desktop, compact and phone-width viewports")
    page.set_viewport_size({"width": 1440, "height": 1000})
