"""Google's browser UI hands verified identity to only the initiating game session."""

import secrets
from urllib.parse import urlsplit

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from pydantic import Field
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from .auth import ProfileBody, StrictBody, complete_google_login
from .db import get_session
from .identity_models import BrowserLogin, now
from .security import digest

router = APIRouter(tags=["identity"])


class HandoffToken(StrictBody):
    token: str = Field(min_length=43, max_length=128)


class BrowserCredential(HandoffToken):
    id_token: str = Field(min_length=20, max_length=16384)


def configured(request):
    settings = request.app.state.settings
    url = urlsplit(settings.public_base_url)
    if not settings.google_web_client_id:
        raise HTTPException(503, "GOOGLE_SIGN_IN_NOT_CONFIGURED")
    if not url.hostname or url.username or url.password or url.query or url.fragment or url.path.rstrip("/"):
        raise HTTPException(503, "GOOGLE_PUBLIC_URL_NOT_CONFIGURED")
    if url.scheme != "https" and not (
        settings.environment == "development"
        and url.scheme == "http"
        and url.hostname in ("localhost", "127.0.0.1")
    ):
        raise HTTPException(503, "GOOGLE_PUBLIC_URL_NOT_CONFIGURED")
    return settings


@router.post("/auth/google/browser/start", status_code=201)
def start(body: ProfileBody, request: Request, session: Session = Depends(get_session)):
    settings = configured(request)
    browser, poll = secrets.token_urlsafe(32), secrets.token_urlsafe(32)
    row = BrowserLogin(
        browser_hash=digest(browser),
        poll_hash=digest(poll),
        nonce=secrets.token_urlsafe(32),
        display_name=body.display_name,
        expires_at=now() + 300,
    )
    session.add(row)
    session.commit()
    return {
        # Fragment is never sent in HTTP paths, proxy logs or Referer headers.
        "browser_url": settings.public_base_url.rstrip("/") + "/v1/auth/google/browser#" + browser,
        "poll_token": poll,
        "expires_in": 300,
        "interval": 5,
    }


def browser_row(body, session):
    row = session.scalar(
        select(BrowserLogin).where(
            BrowserLogin.browser_hash == digest(body.token),
            BrowserLogin.expires_at > now(),
            BrowserLogin.consumed.is_(False),
            BrowserLogin.subject.is_(None),
        )
    )
    if row is None:
        raise HTTPException(401, "LOGIN_EXPIRED")
    return row


@router.post("/auth/google/browser/prepare")
def prepare(body: HandoffToken, request: Request, session: Session = Depends(get_session)):
    settings = configured(request)
    row = browser_row(body, session)
    return {"client_id": settings.google_web_client_id, "nonce": row.nonce, "display_name": row.display_name}


@router.post("/auth/google/browser/complete")
def complete(body: BrowserCredential, request: Request, session: Session = Depends(get_session)):
    configured(request)
    row = browser_row(body, session)
    claims = request.app.state.identity_verifier.verify(body.id_token)
    if claims.get("aud") != request.app.state.settings.google_web_client_id:
        raise HTTPException(401, "INVALID_GOOGLE_TOKEN")
    if not isinstance(claims.get("nonce"), str) or not secrets.compare_digest(
        claims["nonce"].encode(), row.nonce.encode()
    ):
        raise HTTPException(401, "INVALID_LOGIN_CHALLENGE")
    result = session.execute(
        update(BrowserLogin)
        .where(
            BrowserLogin.id == row.id,
            BrowserLogin.subject.is_(None),
            BrowserLogin.consumed.is_(False),
            BrowserLogin.expires_at > now(),
        )
        .values(subject=claims["sub"])
    )
    if result.rowcount != 1:
        raise HTTPException(401, "LOGIN_EXPIRED")
    session.commit()
    return {"status": "complete"}  # Browser never receives game bearer credentials.


@router.post("/auth/google/browser/poll")
def poll(body: HandoffToken, request: Request, session: Session = Depends(get_session)):
    configured(request)
    row = session.scalar(
        select(BrowserLogin).where(
            BrowserLogin.poll_hash == digest(body.token),
            BrowserLogin.expires_at > now(),
            BrowserLogin.consumed.is_(False),
        )
    )
    if row is None:
        raise HTTPException(401, "LOGIN_EXPIRED")
    if row.subject is None:
        return {"status": "pending"}
    # Compare-and-set works on PostgreSQL and SQLite, including two simultaneous polls.
    claimed = session.execute(
        update(BrowserLogin)
        .where(
            BrowserLogin.id == row.id,
            BrowserLogin.consumed.is_(False),
            BrowserLogin.expires_at > now(),
        )
        .values(consumed=True)
    )
    if claimed.rowcount != 1:
        raise HTTPException(401, "LOGIN_EXPIRED")
    return complete_google_login(row.subject, row.display_name, request, session)


@router.post("/auth/google/browser/cancel", status_code=204)
def cancel(body: HandoffToken, session: Session = Depends(get_session)):
    session.execute(
        update(BrowserLogin).where(BrowserLogin.poll_hash == digest(body.token)).values(consumed=True)
    )
    session.commit()


@router.get("/auth/google/browser", response_class=HTMLResponse)
def page():
    nonce = secrets.token_urlsafe(24)
    return HTMLResponse(
        PAGE.replace("SCRIPT_NONCE", nonce),
        headers={
            "Referrer-Policy": "strict-origin-when-cross-origin",
            "Cross-Origin-Opener-Policy": "same-origin-allow-popups",
            "Content-Security-Policy": "default-src 'self'; script-src 'nonce-"
            + nonce
            + "' https://accounts.google.com/gsi/client; frame-src https://accounts.google.com; "
            "connect-src 'self' https://accounts.google.com; style-src 'unsafe-inline' https://accounts.google.com; "
            "img-src 'self' data: https://*.googleusercontent.com; base-uri 'none'; frame-ancestors 'none'",
        },
    )


PAGE = """<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Beat my track — Sign in</title>
<style>body{background:#101e29;color:#f1f4f3;font:18px system-ui;margin:0;padding:24px}
main{max-width:440px;margin:12vh auto}h1{font-size:32px}p{line-height:1.5;color:#a4bac7}</style>
<main><h1>Sign in to Beat my track</h1><p id="status">Preparing sign-in…</p><div id="google"></div>
<p>Only continue if you opened this page from your own game. Return to the game after signing in.</p></main>
<script nonce="SCRIPT_NONCE">
const token = location.hash.slice(1);
history.replaceState(null, '', location.pathname);
const status = document.getElementById('status');
async function post(action, data) {
  const r = await fetch('/v1/auth/google/browser/' + action, {method:'POST',
    headers:{'Content-Type':'application/json'},body:JSON.stringify({token,...data})});
  if (!r.ok) throw new Error('Sign-in failed or expired. Return to the game and try again.');
  return r.json();
}
async function begin() {
  try {
    const config = await post('prepare', {});
    status.textContent = 'Your new player name: ' + config.display_name + '. Existing accounts keep their saved name.';
    google.accounts.id.initialize({client_id:config.client_id,nonce:config.nonce,auto_select:false,
      callback:async result => {
        try {
          await post('complete', {id_token:result.credential});
          document.getElementById('google').replaceChildren();
          status.textContent = 'Signed in. You can return to the game.';
        } catch(e) { status.textContent = e.message; }
      }});
    google.accounts.id.renderButton(document.getElementById('google'), {theme:'outline',size:'large'});
  } catch(e) { status.textContent = e.message; }
}
const script = document.createElement('script');
script.src = 'https://accounts.google.com/gsi/client';
script.onload = begin;
script.onerror = () => {status.textContent = 'Google could not be reached. Return to the game and try again.';};
document.head.appendChild(script);
</script></html>"""
