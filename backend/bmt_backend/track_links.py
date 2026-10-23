"""Public track links reuse the normal published-version visibility checks."""
import html
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse

from .db import get_session
from .security import bearer
from .tracks import public_version

router = APIRouter(tags=["track links"])


@router.get("/t/{version_id}", response_class=HTMLResponse)
def preview(version_id: UUID, request: Request, session=Depends(get_session), credentials=Depends(bearer)):
    value = public_version(str(version_id), request, session, credentials)
    title = html.escape(value["name"])
    creator = html.escape(value["creator"])
    target = f"beatmytrack://track/{version_id}"
    return HTMLResponse(f'''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>{title} — Beat my track</title>
<meta property="og:title" content="{title}"><meta property="og:description" content="Race {creator}'s track in Beat my track">
<style>body{{background:#080f16;color:#f1f4f3;font:20px system-ui;margin:0;min-height:100vh;display:grid;place-items:center}}
main{{background:#101e29;padding:32px;border-radius:12px;max-width:480px;margin:20px}}small{{color:#a4bac7}}
a{{display:block;padding:16px;background:#ffd348;color:#080f16;text-decoration:none;border-radius:5px;margin-top:24px}}</style>
<main><small>BEAT MY TRACK · FREE RACE</small><h1>{title}</h1><p>Created by {creator}</p>
<a href="{target}">Open track in Beat my track</a></main></html>''',
        headers={"Cache-Control": "no-store", "X-Robots-Tag": "noindex", "Referrer-Policy": "no-referrer"})
