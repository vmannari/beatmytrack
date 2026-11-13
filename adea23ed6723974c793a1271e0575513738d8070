"""Public navigation must reach the established, verified deletion flow."""
from copy import copy
from html.parser import HTMLParser
from xml.etree import ElementTree

from bmt_backend.public_pages import ASSETS, ROOT


class Links(HTMLParser):
    def __init__(self, body):
        super().__init__()
        self.targets = set()
        self.feed(body)

    def handle_starttag(self, tag, attrs):
        self.targets.update(value for name, value in attrs if name in ("href", "src") and value)


def settings_for_metadata(settings, environment, origin):
    # Exercise origin rendering without constructing a real production service.
    result = copy(settings)
    object.__setattr__(result, "environment", environment)
    object.__setattr__(result, "public_base_url", origin)
    return result


def test_home_and_all_assets_are_public_and_same_origin(auth_client):
    response = auth_client.get("/")
    assert response.status_code == 200
    assert "Beat my track" in response.text
    assert "In development" in response.text
    assert "set-cookie" not in response.headers
    assert "frame-ancestors 'none'" in response.headers["content-security-policy"]
    assert "default-src 'none'" in response.headers["content-security-policy"]
    assert "nosniff" == response.headers["x-content-type-options"]
    assert "<script" not in response.text
    for target in Links(response.text).targets:
        if target == auth_client.app.state.settings.public_base_url.rstrip("/") + "/":
            continue  # Canonical URL is deliberately absolute.
        assert target.startswith(("/", "#")), target
        if not target.startswith("#"):
            linked = auth_client.get(target)
            assert linked.status_code == 200, target
            assert "set-cookie" not in linked.headers
    for name, media_type in ASSETS.items():
        asset = auth_client.get("/site/" + name)
        assert asset.status_code == 200, name
        assert asset.content == (ROOT / name).read_bytes(), name
        assert asset.headers["content-type"].split(";")[0] == media_type
        assert asset.headers["cache-control"] == "public, max-age=86400"


def test_delete_link_requires_existing_verification_and_can_return_home(auth_client):
    home = auth_client.get("/").text
    assert home.count('href="/account-deletion"') == 3
    deletion = auth_client.get("/account-deletion")
    assert deletion.status_code == 200
    assert 'href="/"' in deletion.text
    assert 'id="delete" disabled' in deletion.text
    assert 'id="confirm" hidden' in deletion.text
    assert 'id="agreement"' in deletion.text
    assert "permanently" in deletion.text
    assert "Google account" in deletion.text
    assert auth_client.post("/v1/privacy/web-delete", json={}).status_code in (401, 422)


def test_only_allowlisted_public_assets_can_be_read(auth_client):
    for path in ("/site/app.py", "/site/index.html", "/site/.env", "/site/nope.css",
                 "/site/%2E%2E%2Fapp.py", "/site/%2E%2E%5Capp.py"):
        assert auth_client.get(path).status_code == 404, path
    assert auth_client.post("/").status_code == 405
    assert auth_client.post("/site/style-v1.css").status_code == 405


def test_search_metadata_uses_configured_origin_never_host_header(auth_client):
    settings = auth_client.app.state.settings
    auth_client.app.state.settings = settings_for_metadata(settings, "production", "https://game.example")
    try:
        page = auth_client.get("/", headers={"host": "attacker.example"})
        assert '<link rel="canonical" href="https://game.example/">' in page.text
        assert 'property="og:image" content="https://game.example/site/blind-spot-social-v1.png"' in page.text
        assert "attacker.example" not in page.text
        assert "x-robots-tag" not in page.headers
        robots = auth_client.get("/robots.txt")
        assert "Sitemap: https://game.example/sitemap.xml" in robots.text
        sitemap = auth_client.get("/sitemap.xml")
        root = ElementTree.fromstring(sitemap.content)
        urls = [node.text for node in root.findall("{*}url/{*}loc")]
        assert urls == ["https://game.example/", "https://game.example/privacy",
                        "https://game.example/community-rules", "https://game.example/account-deletion"]
    finally:
        auth_client.app.state.settings = settings


def test_staging_and_invalid_origins_do_not_advertise_indexable_urls(auth_client):
    settings = auth_client.app.state.settings
    try:
        auth_client.app.state.settings = settings_for_metadata(settings, "development", "https://stage.example")
        assert auth_client.get("/").headers["x-robots-tag"] == "noindex, nofollow"
        assert "Disallow: /" in auth_client.get("/robots.txt").text
        assert auth_client.get("/sitemap.xml").status_code == 404
        auth_client.app.state.settings = settings_for_metadata(settings, "production", "https://bmt-stg-example.run.app")
        assert auth_client.get("/").headers["x-robots-tag"] == "noindex, nofollow"
        assert auth_client.get("/sitemap.xml").status_code == 404
        auth_client.app.state.settings = settings_for_metadata(settings, "production", 'https://host.example/\"x')
        page = auth_client.get("/")
        assert "canonical" not in page.text
        assert 'property="og:image"' not in page.text
        assert "Disallow: /" in auth_client.get("/robots.txt").text
        assert auth_client.get("/sitemap.xml").status_code == 404
    finally:
        auth_client.app.state.settings = settings


def test_public_site_does_not_add_admin_service_routes(tmp_path):
    from fastapi.routing import iter_route_contexts

    from bmt_backend.app import create_app
    from bmt_backend.config import Settings

    app = create_app(Settings(environment="test", workload_role="admin",
                              database_url="sqlite://", object_dir=str(tmp_path / "objects")))
    try:
        paths = {context.path for context in iter_route_contexts(app.routes)}
        assert "/" not in paths and "/site/{filename}" not in paths
    finally:
        app.state.engine.dispose()
