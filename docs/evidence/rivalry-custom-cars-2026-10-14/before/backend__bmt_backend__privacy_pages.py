"""Public, self-hosted privacy and deletion resources; no cookies or analytics."""
from html import escape
from pathlib import Path

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse, Response

router = APIRouter(tags=["privacy information"])
ROOT = Path(__file__).with_name("privacy_ui")
HEADERS = {"Content-Security-Policy": "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'",
           "Referrer-Policy": "no-referrer", "Cache-Control": "no-store"}


def page(title, body):
    return HTMLResponse('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
        f'<title>{escape(title)} · Beat my track</title><link rel="stylesheet" href="/privacy/style.css">'
        '<body><main><nav><a href="/privacy">Privacy</a><a href="/account-deletion">Delete account</a></nav>'
        f'<p class="brand">BEAT MY TRACK</p><h1>{escape(title)}</h1>{body}</main></body></html>', headers=HEADERS)


@router.get("/privacy/style.css", include_in_schema=False)
def style():
    return Response((ROOT / "style.css").read_text(encoding="utf-8"), media_type="text/css", headers=HEADERS)


@router.get("/privacy/deletion.js", include_in_schema=False)
def script():
    return Response((ROOT / "deletion.js").read_text(encoding="utf-8"), media_type="text/javascript", headers=HEADERS)


@router.get("/privacy", response_class=HTMLResponse)
def policy(request: Request):
    s = request.app.state.settings
    developer = escape(s.privacy_developer_name)
    contact = escape(s.privacy_contact_email) if s.privacy_contact_email else "[Privacy contact — to be confirmed]"
    placeholder = '<aside>Pre-release information. Developer identity and privacy contact are placeholders awaiting confirmation.</aside>' if not s.privacy_contact_email or s.privacy_developer_name.startswith("[") else ""
    return page("Privacy policy", f'''{placeholder}<p>Version bmt-privacy-v1 · 14 October 2026</p>
<h2>Who operates the game</h2><p>{developer}. Privacy contact: {contact}.</p>
<h2>What stays on your device</h2><p>Local tracks, car paint, parts, stickers, dirt and washing, local records and game preferences stay on your device. Local play is available without an online account. Saved sign-in credentials are protected by Windows DPAPI or Android Keystore; platforms without protection use memory-only sign-in.</p>
<h2>Online accounts and racing</h2><p>Google supplies a verified identity identifier for sign-in. We store that identifier, an account identifier, your racing name and selected country; we do not use Google email addresses to link accounts. Online play sends track documents when you publish, race tickets, timestamped movement evidence, optional ghost recordings, verified results, ratings and competition participation. These support publication, race verification and standings.</p>
<h2>Optional usage and performance information</h2><p>The rebuilt app asks you to choose whether to share optional analytics. This is off until you choose to enable it. It includes menu and race observations, bounded timing and performance summaries, device model, operating system, renderer/settings, network category counts and selected server request IDs. It excludes authentication credentials, request bodies and full request URLs. Change the choice in Settings → Privacy; disabling it stops collection/uploads and clears pending observations on that device. Verified online results and essential security processing still operate.</p>
<h2>Providers, ads and purchases</h2><p>Google processes Google sign-in. The service uses configured hosting and storage providers. Android development builds include Google Mobile Ads 25.5.0 for test ads and may offer simulated purchases, which do not charge money. Google's ads SDK can process network addresses, advertising/app-set identifiers, interactions and diagnostic information for advertising, analytics and fraud prevention. Our optional analytics choice controls our own observations; provider SDK processing has separate controls. See <a href="https://developers.google.com/admob/android/privacy/play-data-disclosure">Google's SDK data disclosure</a> and <a href="https://policies.google.com/privacy">Google's privacy policy</a>. Production ads or purchases require matching provider disclosures, consent where required, and updated store declarations before release. Optional analytics goes to our backend.</p>
<h2>Retention</h2><p>Scheduled processing normally removes raw optional observations after {max(7, s.telemetry_raw_days + 1)} days, including the receipt retry allowance. Prepared reporting facts expire after {s.telemetry_fact_days} days; facts with no account identifiers may remain until expiry. Ordinary superseded race evidence follows the configured {s.retention_days}-day reference-aware retention. Account deletion removes private evidence through a resumable worker, including file cleanup after active storage leases expire. Service outages or active leases can delay physical cleanup; operators must monitor its progress. Minimal purchase token digests and transaction records are retained for up to {s.privacy_purchase_days} days for replay/fraud prevention. Deletion retry receipts expire after 90 days. Backups must expire within the configured {s.privacy_backup_days}-day period; erasure records are reapplied before any restored service becomes available.</p>
<h2>Deleting your account</h2><p><a href="/account-deletion">Request deletion here</a> or use Manage account → Delete account in the game. We remove Google identity links and credentials, racing name, country, account-linked optional observations, private recordings and recovery data. Existing published tracks, their authored titles/content and historical standings remain. Their author/player is shown as “Removed account”; the creator metadata in published track files is redacted. The remaining opaque historical identity cannot sign in. Signing in again creates a separate account and does not reclaim those records.</p>
<p>Deletion removes online account access and balances. It does not delete your Google account, cancel any provider subscription, or erase local tracks, car condition or cosmetics. Clear local app data yourself if you want those removed. Tracks you intentionally named or designed to contain personal information may still contain it; contact us about that content. Previously downloaded public copies are outside our control. Minimal erasure records prevent restoration of a removed account from backups.</p>
<h2>Security and your choices</h2><p>Authentication and transmission use protected credentials and HTTPS in release environments. Access to private service data is restricted. You can change your racing profile, disable optional analytics, request account deletion, and contact the privacy contact above about access, correction, processing or retained content.</p>''')


@router.get("/account-deletion", response_class=HTMLResponse)
def deletion_page(request: Request):
    configured = bool(request.app.state.settings.google_web_client_id)
    return page("Delete your account", '''<p>Remove your Beat my track online account even if you have uninstalled the game.</p>
<section><h2>What happens</h2><p>Your sign-in identity, racing name, country, private recordings and account-linked analytics are removed. Published tracks and historical standings remain under <strong>Removed account</strong>. Signing in again starts a separate account.</p><p>Local tracks, paint, parts and car condition on your device remain. This does not delete your Google account or cancel a provider subscription. Minimal purchase/security records and expiring backups follow the <a href="/privacy">privacy policy</a>.</p></section>
<button id="signin"''' + ("" if configured else " disabled") + '''>Verify with Google</button>
<section id="confirm" hidden><h2>Confirm deletion</h2><p>Account: <strong id="name"></strong></p><p>This permanently removes access to this account. Published tracks and historical results stay under “Removed account”.</p><label><input id="agreement" type="checkbox"> I understand and want to delete this account.</label><button id="delete" disabled>Delete account permanently</button></section>
<p id="status" role="status" aria-live="polite">''' + ("Verify the Google identity used for your account. No new game account will be created." if configured else "Google web verification is awaiting service configuration. Use Delete account in the game for a signed-in account.") + '''</p>
<script src="/privacy/deletion.js" defer></script>''')
