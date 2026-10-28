"""The game's public introduction, served by the same API as account deletion."""
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse, HTMLResponse

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
    "mark-v1.svg": "image/svg+xml",
    "forest-drive-v1.webp": "image/webp",
    "winter-race-v1.webp": "image/webp",
    "track-editor-v1.webp": "image/webp",
    "garage-v1.webp": "image/webp",
    "worlds-v1.webp": "image/webp",
    "Barlow-Regular.ttf": "font/ttf",
    "BarlowCondensed-SemiBold.ttf": "font/ttf",
    "font-license.txt": "text/plain",
}


@router.get("/", response_class=HTMLResponse, include_in_schema=False)
def home():
    return HTMLResponse((ROOT / "index.html").read_text(encoding="utf-8"), headers=HEADERS)


@router.get("/site/{filename}", include_in_schema=False)
def asset(filename: str):
    media_type = ASSETS.get(filename)
    if media_type is None:
        raise HTTPException(404, "NOT_FOUND")
    return FileResponse(ROOT / filename, media_type=media_type,
                        headers={**HEADERS, "Cache-Control": "public, max-age=86400"})
