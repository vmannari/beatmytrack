# Public website review fixes — 31 October 2026

The owner requested fixes for the public website review and confirmed that the developer is Ville Mannari. There is no public download, playtest or updates link yet, and the privacy contact must remain unfilled for now.

| ID | Change |
| --- | --- |
| WRF01 | The homepage leads with a labelled native gameplay screenshot. Repetitive promotional copy is replaced with concrete game features, the AI-generated environment montage is no longer displayed, and the development status is explicit. Account deletion remains available in the header, account section and footer. |
| WRF02 | Privacy, community and deletion pages share the site's logo, type and colours. The configured developer defaults to Ville Mannari; the missing contact is disclosed without inventing an address. Existing configuration overrides remain available. |
| WRF03 | Closing the verification window checks for completed sign-in, cancels unfinished sessions and enables retry. A blocked popup does not create a session. Matching popup isolation headers prevent an open window being mistaken for a closed one. |
| WRF04 | A bounded, process-local fallback keeps only exact anonymous public GET pages and allowlisted assets available when the shared database limiter fails. API operations and authenticated requests retain the existing database-backed gate. |
| WRF05 | The configured public origin supplies canonical and Open Graph URLs; the request Host header is never used. Production sites get robots and a sitemap; development and the existing staging hostname are marked non-indexable. |

## Scope and evidence

- Runtime changes: `backend/bmt_backend/public_ui/index.html`, new `style-v3.css`, `social-gameplay-v1.png`, `public_pages.py`, `privacy_pages.py`, `privacy_ui/style.css`, `privacy_ui/deletion.js`, `config.py` and `middleware.py`. The earlier `style-v2.css` is retained byte-for-byte for cached pages. Existing unrelated workspace changes are retained.
- `social-gameplay-v1.png` is an exact copy of `docs/evidence/winter-road-edge-snow-2026-10-24/mobile/after.png`, an existing native game capture. SHA-256: `bbfa8c8b6a15f519b26c0dd651eac5e25262a9a221b859700855111711e66100`. Existing WebP and logo assets are reused; no new generated artwork is introduced.
- The focused website, outage, browser-auth and privacy suite passed **39 tests** before the final popup-isolation refinement. The popup owner subsequently ran **34 privacy, browser-auth and deletion-preview tests** with the final headers. The website and outage suite passed **8 tests** after the metadata changes.
- The final website, outage, browser-auth and privacy suite passed **39 tests inside the frozen candidate image**, with networking disabled and the test directory mounted read-only.
- `scripts/review_deletion_popup_browser.py` uses actual page HTML and security headers with intercepted provider and API responses. It exercises an open popup, successful verification, immediately closed successful verification, pending cancellation and a blocked popup; no live account is used.
- Local Edge checked the homepage, privacy, deletion and community pages at 1440, 768, 390 and 320 pixels: **16 page/viewport combinations**, with no overflow, broken images or page errors. [Desktop homepage](evidence/website-review-fixes-2026-10-31/home-1440.png), [mobile homepage](evidence/website-review-fixes-2026-10-31/home-390.png), [privacy](evidence/website-review-fixes-2026-10-31/privacy-390.png), [deletion](evidence/website-review-fixes-2026-10-31/account-deletion-390.png), [browser results](evidence/website-review-fixes-2026-10-31/results.json).
- The retained full browser review completed **135 checks**, including keyboard navigation, public links, no-JavaScript navigation, storage and accidental-mutation checks, using a disposable database. The [source manifest](evidence/website-review-fixes-2026-10-31/source-manifest.json) records the exact reviewed workspace bytes, including pre-existing context.
- Focused Ruff and `git diff --check` passed. The first combined test command named a nonexistent community fixture; it ran no tests and was corrected. Initial metadata fixtures required correction for production settings validation. A request-trace fixture failure reproduced with the original middleware, and two optional PostgreSQL tests could not connect to the configured local test database.

## Release status and limits

After the owner's explicit deployment request, the reviewed candidate was published to the existing public staging service on revision `bmt-stg-e7a444ab-api-web-9f7cd85ce28e`. The previous revision remains available and retains its existing `website-preview` tag. Candidate and public HTTP checks passed, as did 103 read-only browser checks on each address. See [deployment evidence](WEBSITE_REVIEW_DEPLOYMENT_2026_10_31.md). A later [game-image refresh](WEBSITE_IMAGE_REFRESH_2026_10_31.md) is now serving.

The candidate was built on the exact previous staging revision `bmt-stg-e7a444ab-api-web-244328226403`. A file-by-file comparison confirmed that only the nine reviewed overlay files changed among the 349 original package files; two new files account for the 351-file candidate. The staging configuration has neither an explicit developer-name nor privacy-contact override. [Local candidate identity and hashes](evidence/website-review-fixes-2026-10-31/local-release.json).

During an outage the fallback rate limits apply independently per process and replica; a shared edge limiter would supply a stronger global bound. Real Google sign-in, a real account deletion, a physical phone and production deployment were not tested. The privacy contact and any public download or update channel remain to be supplied when ready.
