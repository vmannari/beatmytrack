"""Real browser UI with a simulated identity provider; no Google account is used."""

import json
from dataclasses import replace
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from test_studio_identity import claims, settings

from bmt_backend.app import create_app
from bmt_backend.migrate import upgrade

playwright = pytest.importorskip("playwright.sync_api")

FAKE_APP = "export function initializeApp(config){return config;}"
FAKE_AUTH = """
export const inMemoryPersistence={}, browserPopupRedirectResolver={};
export function initializeAuth(){return {};}
export class GoogleAuthProvider {setCustomParameters(value){window.googleParameters=value;}}
const user={getIdToken:async()=>window.providerToken,mfa:{enrolledFactors:[],getSession:async()=>({}),
 enroll:async assertion=>{if(assertion.code!=='123456')throw {code:'auth/invalid-verification-code'};window.enrolled=true;}}};
export async function signInWithPopup(){
 window.popupCount=(window.popupCount||0)+1;
 if(window.providerMode==='challenge')throw {code:'auth/multi-factor-auth-required'};
 if(window.providerMode==='pending')await new Promise(resolve=>window.finishPopup=resolve);
 return {user};
}
export async function signOut(){window.signedOut=(window.signedOut||0)+1;}
export function multiFactor(){return user.mfa;}
export class TotpMultiFactorGenerator {
 static FACTOR_ID='totp';
 static async generateSecret(){return {secretKey:'FAKE-LOCAL-TEST-KEY'};}
 static assertionForEnrollment(secret,code){return {code};}
 static assertionForSignIn(id,code){return {code};}
}
export function getMultiFactorResolver(){return {hints:[{factorId:'totp',uid:'factor'}],
 resolveSignIn:async assertion=>{if(assertion.code!=='123456')throw {code:'auth/invalid-verification-code'};
 window.providerToken='verified-owner-token-1234';return {user};}};}
"""


@pytest.mark.parametrize("limited", [False, True])
def test_browser_enroll_verify_lock_cancel_and_other_account(tmp_path, limited):
    configured = settings(tmp_path)
    if limited:
        configured = replace(configured, studio_analysis_mode="shared_limited",
            studio_analysis_database_url="postgresql+psycopg://bmt_studio_report:fixture@localhost/bmt")
    app = create_app(configured)
    upgrade(app.state.engine)
    tokens = {"verified-owner-token-1234": claims(),
        "unenrolled-owner-token-123": claims(firebase={"tenant": "studio-tenant",
            "sign_in_provider": "google.com", "identities": {"google.com": ["google-owner"]}}),
        "unlisted-owner-token-123": claims(firebase={**claims()["firebase"],
            "identities": {"google.com": ["other-user"]}})}
    verifier = app.state.staff_identity_verifier
    verifier.verify = lambda token: verifier.validate_claims(tokens[token])
    screenshots = Path(__file__).resolve().parents[2] / "docs/evidence" / (
        "studio-shared-reporting-2026-10-25" if limited else "studio-recovery-2026-10-25")
    screenshots.mkdir(parents=True, exist_ok=True)
    with TestClient(app) as client, playwright.sync_playwright() as p:
        browser = p.chromium.launch(channel="msedge", headless=True)
        context = browser.new_context(viewport={"width": 1280, "height": 800})
        page = context.new_page()
        errors = []
        requests = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        def handle(route):
            request = route.request
            if request.url.startswith("https://www.gstatic.com/firebasejs/12.4.0/"):
                route.fulfill(status=200, body=FAKE_AUTH if request.url.endswith("firebase-auth.js") else FAKE_APP,
                    content_type="application/javascript", headers={"Access-Control-Allow-Origin": "*"})
                return
            assert request.url.startswith("http://studio.test/")
            path = request.url.removeprefix("http://studio.test")
            requests.append((request.method, path))
            headers = {key: value for key, value in request.headers.items() if key.lower() not in ("host", "content-length")}
            result = client.request(request.method, path, headers=headers,
                content=request.post_data_buffer)
            response_headers = {key: value for key, value in result.headers.items()
                if key.lower() not in ("content-encoding", "content-length")}
            route.fulfill(status=result.status_code, body=result.content, headers=response_headers)
        page.route("**/*", handle)
        page.goto("http://studio.test/admin")
        google = page.get_by_role("button", name="Sign in with Google", exact=True)
        playwright.expect(google).to_be_visible()
        page.screenshot(path=str(screenshots / "signin-desktop.png"))
        page.evaluate("window.providerToken='unenrolled-owner-token-123'")
        google.click()
        playwright.expect(page.get_by_role("heading", name="Set up your authenticator")).to_be_visible()
        playwright.expect(page.get_by_text("FAKE-LOCAL-TEST-KEY", exact=True)).to_be_visible()
        assert not any(path == "/v1/admin/staff" for _method, path in requests)
        page.get_by_label("Authenticator code").fill("000000")
        page.get_by_role("button", name="Continue", exact=True).click()
        playwright.expect(page.get_by_role("alert")).to_contain_text("not accepted")
        page.get_by_label("Authenticator code").fill("123456")
        page.get_by_role("button", name="Continue", exact=True).click()
        playwright.expect(google).to_be_visible()
        playwright.expect(page.get_by_text("Authenticator added.", exact=False)).to_be_visible()
        page.evaluate("window.providerMode='challenge'")
        google.click()
        playwright.expect(page.get_by_role("heading", name="Verify your sign-in")).to_be_visible()
        page.screenshot(path=str(screenshots / "verify-desktop.png"))
        page.get_by_label("Authenticator code").fill("123456")
        page.get_by_role("button", name="Continue", exact=True).click()
        playwright.expect(page.locator('#role')).to_contain_text("owner")
        if limited:
            assert page.locator('#days option[value="30"]').is_disabled()
            assert page.locator('#days option[value="90"]').is_disabled()
            page.get_by_role("button", name="Choose reporting dates in UTC").click()
            page.locator('#report-from').fill('2026-10-01')
            page.locator('#report-through').fill('2026-10-10')
            page.get_by_role("button", name="Apply dates", exact=True).click()
            playwright.expect(page.locator('#dates-error')).to_contain_text('1–7 calendar days')
            page.screenshot(path=str(screenshots / "limited-range-desktop.png"))
            page.locator('#dialog').get_by_role("button", name="Cancel", exact=True).click()
        else:
            assert not page.locator('#days option[value="30"]').is_disabled()
        page.get_by_role("button", name="Lock", exact=True).click()
        playwright.expect(google).to_be_visible()
        assert page.evaluate("window.signedOut") >= 2
        page.evaluate("window.providerMode='normal';window.providerToken='unlisted-owner-token-123'")
        google.click()
        playwright.expect(page.get_by_role("alert")).to_contain_text("does not have Studio access")
        page.evaluate("window.providerToken='unenrolled-owner-token-123'")
        google.click()
        playwright.expect(page.get_by_role("heading", name="Set up your authenticator")).to_be_visible()
        page.get_by_role("button", name="Cancel", exact=True).click()
        playwright.expect(google).to_be_visible()
        playwright.expect(page.get_by_text("FAKE-LOCAL-TEST-KEY", exact=True)).to_have_count(0)
        # Locking a pending provider popup cannot restore Studio access later.
        page.evaluate("window.providerMode='pending';window.providerToken='verified-owner-token-1234'")
        google.click()
        page.wait_for_function("typeof window.finishPopup==='function'")
        page.get_by_role("button", name="Lock", exact=True).click()
        page.evaluate("window.finishPopup()")
        playwright.expect(google).to_be_visible()
        playwright.expect(page.locator('#role')).to_contain_text("Authentication required")
        page.set_viewport_size({"width": 390, "height": 844})
        page.screenshot(path=str(screenshots / "signin-mobile.png"))
        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
        assert errors == [], json.dumps(errors)
        assert not any(method != "GET" and path != "/v1/admin/auth/eligibility" for method, path in requests)
        context.close()
        browser.close()
    app.state.engine.dispose()
