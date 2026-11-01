"""The game's public introduction, served by the same API as account deletion."""
from html import escape
from pathlib import Path
from urllib.parse import urlsplit

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import FileResponse, HTMLResponse, Response

router = APIRouter(tags=["game website"])
ROOT = Path(__file__).with_name("public_ui")
HEADERS = {
    "Content-Security-Policy": "default-src 'none'; style-src 'self'; img-src 'self'; "
    "font-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
    "Referrer-Policy": "no-referrer",
    "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
    "Cache-Control": "public, max-age=300",
}
ASSETS = {
    "style-v1.css": "text/css",
    "style-v2.css": "text/css",
    "style-v3.css": "text/css",
    "style-v4.css": "text/css",
    "game-logo-v1.svg": "image/svg+xml",
    "game-mark-v1.svg": "image/svg+xml",
    "mark-v1.svg": "image/svg+xml",
    "forest-drive-v1.webp": "image/webp",
    "winter-race-v1.webp": "image/webp",
    "social-gameplay-v1.png": "image/png",
    "social-gameplay-20261031.png": "image/png",
    "blind-spot-social-v1.png": "image/png",
    "blind-spot-race-endurance-v1.webp": "image/webp",
    "blind-spot-race-rally-v1.webp": "image/webp",
    "blind-spot-editor-v1.webp": "image/webp",
    "gameplay-livery-20261031.webp": "image/webp",
    "gameplay-livery-alt-20261031.webp": "image/webp",
    "create-biomes-20261031.webp": "image/webp",
    "garage-current-20261031.webp": "image/webp",
    "track-editor-current-20261031.webp": "image/webp",
    "track-editor-v1.webp": "image/webp",
    "garage-v1.webp": "image/webp",
    "worlds-v1.webp": "image/webp",
    "Barlow-Regular.ttf": "font/ttf",
    "BarlowCondensed-SemiBold.ttf": "font/ttf",
    "font-license.txt": "text/plain",
}


def public_origin(request: Request) -> str:
    """Use the configured origin, never the untrusted request Host header."""
    value = request.app.state.settings.public_base_url.rstrip("/")
    if any(ord(c) <= 32 or c in "\\\"'<>" for c in value):
        return ""
    try:
        parsed = urlsplit(value)
        if (parsed.scheme not in ("http", "https") or not parsed.hostname or parsed.username
                or parsed.password or parsed.path or parsed.query or parsed.fragment):
            return ""
        if parsed.scheme != "https" and request.app.state.settings.environment == "production":
            return ""
        _ = parsed.port  # Reject malformed ports.
    except ValueError:
        return ""
    return value


def no_index(request: Request, origin: str) -> bool:
    host = (urlsplit(origin).hostname or "") if origin else ""
    return (not origin or request.app.state.settings.environment in ("development", "test")
            or host in ("localhost", "127.0.0.1", "::1") or "-stg-" in host)


@router.get("/", response_class=HTMLResponse, include_in_schema=False)
def home(request: Request):
    origin = public_origin(request)
    metadata = ""
    if origin:
        root = escape(origin + "/", quote=True)
        picture = escape(origin + "/site/blind-spot-social-v1.png", quote=True)
        metadata = (f'<link rel="canonical" href="{root}">\n'
                    f'  <meta property="og:url" content="{root}">\n'
                    f'  <meta property="og:image" content="{picture}">\n'
                    '  <meta property="og:image:alt" content="Overhead racing on Blind Spot with a customised car">')
    body = (ROOT / "index.html").read_text(encoding="utf-8").replace("<!--PUBLIC_SOCIAL_METADATA-->", metadata)
    headers = {**HEADERS, **({"X-Robots-Tag": "noindex, nofollow"} if no_index(request, origin) else {})}
    return HTMLResponse(body, headers=headers)


@router.get("/robots.txt", include_in_schema=False)
def robots(request: Request):
    origin = public_origin(request)
    if not origin or no_index(request, origin):
        body = "User-agent: *\nDisallow: /\n"
    else:
        body = f"User-agent: *\nAllow: /\nDisallow: /v1/\nDisallow: /docs\nSitemap: {origin}/sitemap.xml\n"
    return Response(body, media_type="text/plain", headers=HEADERS)


@router.get("/sitemap.xml", include_in_schema=False)
def sitemap(request: Request):
    origin = public_origin(request)
    if not origin or no_index(request, origin):
        raise HTTPException(404, "NOT_FOUND")
    locations = ("/", "/privacy", "/community-rules", "/account-deletion")
    entries = "".join(f"<url><loc>{escape(origin + path)}</loc></url>" for path in locations)
    body = '<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + entries + "</urlset>"
    return Response(body, media_type="application/xml", headers=HEADERS)


@router.get("/site/{filename}", include_in_schema=False)
def asset(filename: str):
    media_type = ASSETS.get(filename)
    if media_type is None:
        raise HTTPException(404, "NOT_FOUND")
    return FileResponse(ROOT / filename, media_type=media_type,
                        headers={**HEADERS, "Cache-Control": "public, max-age=86400"})
