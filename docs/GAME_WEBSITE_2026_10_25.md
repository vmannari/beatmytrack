# Public game website

Published after owner approval on 25 October 2026: [open Beat my track](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/). [Actual Google Cloud publication, live checks and remaining acceptance](GAME_WEBSITE_PUBLICATION_2026_10_25.md). The implementation-stage evidence below remains historical.

Implemented locally on 25 October 2026. The owner requests a page presenting Beat my track and its features, with an account-deletion option. The existing game API now serves the homepage at `/`, alongside its existing `/account-deletion`, `/privacy` and `/community-rules` pages.

| Requirement | Result |
| --- | --- |
| GW01 Game presentation | Original game branding, clear in-development status, five-lap overhead racing, Free Race, Weekly Rivalry and Challenges. No invented download link, release date, player count or testimonials. |
| GW02 Feature tour | Track creation, local drafts/practice, validated publication, Garage appearance/test driving/washing and the current vehicle selection. Existing cleared artwork is labelled as artwork; three native development screens are labelled as actual game screens. Online sign-in/service requirements and cosmetic unlocks are disclosed. |
| GW03 Account control | Direct deletion links in the header, account section and footer. Privacy and sharing rules remain available. Informational pages link back Home. The existing Google verification, private remaining-benefits preview, acknowledgement and erasure/retry protocol remain authoritative. Opening the homepage or following a link cannot delete an account. |
| GW04 Responsive/accessibility | Eight browser windows from 320 to 1440 pixels, native section links, keyboard skip/focus, reduced motion, image descriptions and self-hosted fonts. The presentation and navigation work with JavaScript disabled. No third-party browser requests, cookies or browser storage in the review. |
| GW05 Hosting/package | Same API origin; explicit public-asset allowlist; restrictive CSP; no new runtime dependencies or migrations. The website stays out of the private admin workload. Wheel inspection verifies all 12 website module/assets byte-for-byte. |

## Preview

From the repository root:

```powershell
.tools/backend-venv/Scripts/python.exe scripts/preview_public_website.py
```

Open `http://127.0.0.1:8086`; stop with Ctrl+C. This loopback-only preview has no database and no account mutation endpoints. Google verification is visibly disabled. Real deletion is available only through the configured game backend, using its established identity verification.

Full-page browser captures: [desktop](evidence/game-website-2026-10-25/home-1440.png), [phone](evidence/game-website-2026-10-25/home-390.png), [narrow phone](evidence/game-website-2026-10-25/home-320.png), [deletion on phone](evidence/game-website-2026-10-25/delete-390.png). Screens show development content, not a published store listing.

## Validation actually performed

- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_public_website.py -q --disable-warnings`: **4 passed**. Exercises real application routing, every public asset/link, no cookies, path traversal/unknown-asset denial, deletion verification and admin isolation.
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_privacy.py backend/tests/test_deletion_preview.py -q --disable-warnings`: **23 passed**. Existing privacy, deletion, benefit disclosure and recovery tests retained.
- `scripts/review_public_website.py`, with the existing review Playwright installation on `PYTHONPATH`: **135 checks passed**. Actual FastAPI routes and disposable SQLite database, all browser traffic intercepted locally, eight viewport sizes, loaded images, keyboard/no-JavaScript navigation, legal/deletion navigation and zero account mutations/external requests/browser errors.
- Existing `scripts/review_deletion_warning_browser.py`: **23 checks passed** against the current deletion page, with intercepted identity/API fixtures. This task's results and current-page capture are copied into this task's evidence; the preceding task's capture is reproduced from the exact captured pre-task page/CSS to retain its original navigation. No real Google account was used.
- Existing setuptools **84.0.0** builds the backend wheel offline. All 12 public module/assets, including both fonts and their licence, match the source bytes in the wheel. Existing Docker packaging copies this backend package; no image build, registry push or deployment was performed.
- Real loopback preview HTTP: homepage, deletion page, privacy, community rules and a screenshot asset all return **200**. The owned preview process was stopped after checking.
- Python compilation and scoped `git diff --check` pass. Task-only patch is checked against the captured task-start files and the current files; the shared index is not changed.

Initial failures remain recorded: the backend Python environment lacks Pillow (the existing review environment supplies it); the first focused run has **2 failures / 25 passes**, exposing a duplicate `nosniff` header and an outdated direct-route introspection fixture. The route now relies on the existing global `nosniff` header, and the fixture uses FastAPI's installed route-context iterator. Neither assertion was weakened. The first full-page screenshots missed below-the-fold lazy images after navigating back Home; the capture now scrolls and waits for every image before taking the final screenshots. The initial `python -m build` command resolves the repository's `build` directory instead of an installed build frontend; a subsequent legacy-environment wheel attempt lacks `bdist_wheel`. The existing pinned setuptools 84 environment succeeds without downloading dependencies. Logs and initial captures are retained.

## Assets and scope

`scripts/prepare_public_website_assets.py` converts five existing project images to WebP quality 82/method 6 without cropping or resizing. Both Barlow fonts and their SIL Open Font License are copied unchanged. The small website mark is original SVG code. Source/output paths, sizes and hashes: `docs/evidence/game-website-2026-10-25/assets.json`. The eight image/font/licence files total 1,052,999 bytes; most imagery loads lazily. No new provider, generated art, font service, tracking or frontend dependency is added.

Runtime: `backend/bmt_backend/public_pages.py`, `public_ui/*`, two small registrations in `app.py`, package-data declaration, and Home navigation/wrapping on the established informational pages. The existing deletion handler and its JavaScript are unchanged. Tests and helpers: `backend/tests/test_public_website.py`, `scripts/prepare_public_website_assets.py`, `scripts/review_public_website.py`, `scripts/preview_public_website.py`.

## Remaining release work

The scoped website publication now serves the approved page and matching disclosure from the existing API, with verified public access/origin and Google verification UI. Privacy developer/contact information and real-owner deletion acceptance remain before submitting the deletion URL to Google Play. Current source contains other release work; a whole-backend deployment must review its independent migrations/credential cutovers rather than treating the website change as authorization to roll them out. The Sites publishing tools are unavailable in this session; implementation uses the existing Google Cloud backend architecture.

No cloud mutation/deployment, migration, APK, device attachment check/device test, real authentication/deletion/purchase, external social message or owner-process restart was performed. Desktop browser checks do not establish phone-device appearance or release readiness. Concurrent changes remain in place. Evidence and task-only review checkpoint: `docs/evidence/game-website-2026-10-25/report.json` and `task-only.patch`.
