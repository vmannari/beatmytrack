# Public website publication — 25 October 2026

The owner approved the completed design and explicitly requested publication: “looks good, publish”. The public game homepage and matching account-deletion disclosure are now deployed to the existing Google Cloud API service.

- [Beat my track](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/)
- [Delete game account](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/account-deletion)
- [Privacy](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/privacy)

| Requirement | Actual result |
| --- | --- |
| GWP01 Publish approved page | The existing public Cloud Run service `bmt-stg-e7a444ab-api`, project `beat-my-track`, region `europe-west1`, serves the approved page at its original origin. No domain purchase, new hosting service, IAM expansion or secret change. |
| GWP02 Compatible deletion flow | Matching private remaining-benefits preview, web-session response, deletion HTML/JavaScript and Home navigation are included. Existing Google web configuration is retained. Browsing never authorizes deletion; the actual Google verification screen loads. |
| R01 Narrow compatible release | An immutable derivative of the exact deployed image overlays 18 files and preserves the other 258 package files. `app.py` gets only two registrations; `privacy.py` gets only the additive read-only disclosure. Existing account erasure/retries, native verifier, assets, migrations, environment, service account, resources and autoscaling remain from the live release. No schema/worker/Studio release. |
| Q01 Verification and recovery | Frozen-source backend27/browser135, publication guards4, candidate HTTP9, public HTTP9 and actual live browser25 pass. Candidate is checked before 100% traffic promotion. The previous revision remains available; a failed post-promotion HTTP check would restore it. The temporary preview tag is removed after acceptance. |

## Deployed identity

- Base API revision: `bmt-stg-e7a444ab-api-00099-ret`.
- Base image: `europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend@sha256:16c22624a9bf5f1995c8315fbf1554d62dc3707826ba6a9217ff0f2d65327c0e`.
- New revision: `bmt-stg-e7a444ab-api-web-3f4205261369`.
- Published image: `europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/website@sha256:3f42052613699329aa7fad7e492eaba320b3edfacb4f526a502369667124c143`.
- Final public traffic: **100%** to the new revision. All runtime settings compare equal after excluding the image/revision identity; public invocation already existed and was retained.

Runtime source receipt: [image.json](evidence/website-publication-2026-10-25/image.json). Cloud checks: [candidate](evidence/website-publication-2026-10-25/candidate-http.json), [public](evidence/website-publication-2026-10-25/live-http.json), [final service](evidence/website-publication-2026-10-25/final-service.json). The full pre-deployment service description stays under ignored `build/website-publication-2026-10-25/release2/service-before.private.json`; environment values are not copied into tracked evidence.

## Commands and tests actually run

```powershell
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/studio_recovery.py
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/public_website.py --prepare build/website-publication-2026-10-25/release2
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/public_website.py --build build/website-publication-2026-10-25/release2
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_public_website_deploy.py -q --disable-warnings
.tools/backend-venv/Scripts/python.exe backend/deploy/gcp/public_website.py --deploy build/website-publication-2026-10-25/release2
.tools/review/Scripts/python.exe scripts/check_public_website_live.py https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app
```

The actual deploy creates a revision without traffic, checks its tagged URL, then promotes that exact revision. Only the image is updated. Docker login receives the existing access token through stdin; the temporary Docker credential file is removed after pushing. No credentials or handoff tokens are printed or copied to evidence.

Before publication, `PYTHONPATH` was set to the extracted/patched frozen release and the public website, privacy and deletion-preview tests ran against it: **27 passed**. The public website browser review was imported with that same frozen package and a separate output directory: **135 checks passed** at eight window sizes. The Docker build imports the actual packaged website and disclosure module and checks the declared assets. Publication guards pass **4 tests**, including retained erasure code, duplicate registration rejection, environment preservation and frozen-source drift rejection. These are deployment-focused checks; no full-workspace backend rollout or physics regression claim is made.

Candidate/public HTTP checks each verify health, readiness, homepage, deletion, privacy, community rules, stylesheet, hero image and matching deletion script. The public homepage body SHA-256 exactly matches the approved HTML. The real live browser checks **25 assertions**, loads every image/font, checks both 1440×1000 and 390×844 layouts, visits legal pages and opens Google's actual verification UI in a fresh session. It does not enter credentials or call account deletion. Its temporary five-minute verification challenge is explicitly cancelled. There are no failed page/provider requests or JavaScript errors in the final check.

Live captures: [desktop](evidence/website-publication-2026-10-25/live-home-1440.png), [mobile](evidence/website-publication-2026-10-25/live-home-390.png), [deletion](evidence/website-publication-2026-10-25/live-delete-390.png), [Google verification](evidence/website-publication-2026-10-25/live-google-verification.png). These are desktop browser windows; no physical-phone check/test was performed.

The worker remains on the original backend image, revision `bmt-stg-e7a444ab-worker-00040-kvd`. The private Studio stays on its separate shared-reporting image `sha256:cf37730d2883c1a604a11a89f859c0b4bcbec75f13225c5afa1d700799484f82`, revision `bmt-stg-e7a444ab-studio-00004-kb6`; neither workload was updated by this task. Exact inspection: [other-workloads.json](evidence/website-publication-2026-10-25/other-workloads.json).

## Retained failures and corrections

- The initial sandboxed inspection could not access the existing gcloud credential store. Authorized elevated execution succeeds with the existing trusted CA bundle; TLS verification stays enabled.
- The first frozen preparation refuses to replace `privacy.py`: the live image lacks an unrelated archive-key cleanup present in workspace HEAD. The corrected preparation applies only the read-only disclosure additions and retains the deployed erasure implementation. The rejected directory is retained as `build/website-publication-2026-10-25/release`; final release is `release2`.
- Initial publication-guard tests: **1 failed / 3 passed**, exposing duplicate homepage registration on an already patched source. An explicit rejection is added; the same assertion then passes. No test weakened.
- The first live browser checker uses Playwright's string-evaluating wait helper, which the deployed strict CSP correctly blocks. The checker now waits for image decoding through the browser automation protocol; the site's CSP is unchanged.
- A subsequent live assertion sees Google's `g_state` cookie after deliberately opening Google's SDK. The final checker separately asserts that the homepage is cookie-free before verification and that only Google's expected state cookie appears after opening verification. This is a corrected test boundary; it does not add cookies/scripts to the homepage. The failed check still cancels its temporary verification challenge. Initial log is retained as `live-browser-cookie-initial.log`.

## Rollback and remaining acceptance

The prior revision is retained. An operator can restore traffic with the existing configured gcloud credentials:

```text
gcloud run services update-traffic bmt-stg-e7a444ab-api --project=beat-my-track --region=europe-west1 --to-revisions=bmt-stg-e7a444ab-api-00099-ret=100
```

The homepage is public and the configured Google verification screen loads. Real owner authentication and end-to-end account deletion remain owner acceptance; no account was deleted for a publication test. The existing privacy page still explicitly marks developer identity/contact as placeholders. Complete those details before treating the page as store-submission-ready. Broader backend/client releases, credential cutovers, translations and provider lifecycle work remain separate.

No database migration/data loss, real account authentication/deletion/purchase, APK, device attachment check/device test, owner-process restart or change to the private Studio/worker was performed. Temporary verification challenges and image/revision/traffic publication are the only relevant live writes. Concurrent workspace changes are preserved. Sources added for this task: `backend/deploy/gcp/public_website.py`, `backend/tests/test_public_website_deploy.py`, `scripts/check_public_website_live.py`; documentation/evidence records the actual deployment. Full report: `docs/evidence/website-publication-2026-10-25/report.json`.
