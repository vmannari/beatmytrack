# Track of the Day card: approved draft implementation

DCR01 implements the owner's final draft: the modest **Chase the podium** title, no page subtitle, one target-time row, more space before Standings and between its heading and players, and the existing yellow Race action. The card uses the established navy surfaces and native fonts. The large empty result dash and repeated position sentence are removed from the normal presentation. An unavailable standings response still exposes the saved best lap and retry.

DCR02 always shows all four labelled medal shapes. Every unreached medal is a near-black silhouette, including Bronze before the first award; Elite retains its laurel outline. Only earned medals show metal shading and the racing relief. The yellow label/underline identifies the next target; the last earned medal retains its selected outline. Elite has no fictional next target. The shared medal control opts into this rendering only for this card, preserving weekly/result medal presentation. Canvas drawing is static; there are no new animation callbacks, 3D worlds or runtime generated images.

DCR03 expands the card to six actual opponents and the local row, retaining flags, name ellipsis/tooltips and exact local milliseconds. An unplayed signed-in player has a dash for rank/time; guests receive no invented identity. The self row uses the approved navy fill and yellow left accent. Seven rows fit the four tested landscape sizes; the list can scroll when space is more constrained, while Race remains outside it. A response with fewer real players is never padded with fabricated competitors.

The existing backend nearby path ignored the requested page size and always returned at most two neighbours. `daily_lap_standings.py` now reserves one requested slot for the candidate and fills the remaining slots around it, including at the fastest/slowest edges. Both retained in-memory and compact SQL-backed snapshots implement the same bounded selection. A request with limit 3 still returns two neighbours. The card asks for limit 6 without a local result and limit 7 with one; six opponents plus a candidate are validated and displayed. Cache keys include the new page size, and existing account/car/day/revision/expiry and stale-response checks remain.

DCR04 supplies directly authored title and Target translations for all twelve languages, without regenerating unrelated catalogue entries. Landscape fit covers 1628×966, 1280×720, 960×540 and 844×390; component portrait checks use 390×844. The owner-approved generated reference is stored as [approved-draft.png](evidence/daily-card-redesign-2026-11-03/approved-draft.png) for comparison only. It is not a shipping asset. The implementation uses native controls and existing vector artwork.

Changed runtime files: `game/ui/daily_result_card.gd`, `game/ui/daily_medal.gd`, `game/ui/track_of_day_page.gd`, and `backend/bmt_backend/daily_lap_standings.py`. Copy lives in `scripts/translations/daily_card_redesign.tsv`, the twelve PO catalogues and message template. The focused native fixture is `game/tests/test_daily_card_redesign.gd`. Four retained fixtures adapt only the approved target-label structure, explicit medal names, self-row style or request size. Backend tests cover six neighbours at both extremes and in the middle, in both snapshot representations.

Actual commands, from the repository root unless stated otherwise:

```powershell
python docs/evidence/daily-card-redesign-2026-11-03/prepare_copy.py
python docs/evidence/daily-card-redesign-2026-11-03/run.py --import
python docs/evidence/daily-card-redesign-2026-11-03/run.py --entry
python docs/evidence/daily-card-redesign-2026-11-03/run.py
python docs/evidence/daily-card-redesign-2026-11-03/run.py --graphical
python docs/evidence/daily-card-redesign-2026-11-03/run.py --graphical --mobile
python docs/evidence/daily-card-redesign-2026-11-03/run.py test_daily_medal_page
python docs/evidence/daily-card-redesign-2026-11-03/run.py test_daily_fixed_presentation
python docs/evidence/daily-card-redesign-2026-11-03/run.py test_daily_standings
python docs/evidence/daily-card-redesign-2026-11-03/run.py test_daily_standings_entry
python docs/evidence/daily-card-redesign-2026-11-03/run.py test_daily_standings_preparing
python docs/evidence/daily-card-redesign-2026-11-03/run.py test_daily_week_fit
python docs/evidence/daily-card-redesign-2026-11-03/run.py test_track_of_day_presentation
& .tools/backend-secure-venv/Scripts/python.exe -m ruff check backend/bmt_backend/daily_lap_standings.py backend/tests/test_daily_lap_standings.py
# From backend/:
& ../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_daily_lap_standings.py -q -m 'not postgres'
# From repository root:
python docs/evidence/daily-card-redesign-2026-11-03/checkpoint.py
```

Final focused results: **221 checks / 0 failures headless** and **237/0 on each desktop renderer**, including all twelve translated layouts. Retained headless results: medal page **115/0**, fixed presentation **436/0**, standings **38/0**, entry/cache **14/0**, preparation/retries **5/0**, week fit **87/0**, daily presentation **63/0**. Backend: **5 passed, 5 PostgreSQL cases deselected**; scoped Ruff passes. Native screenshots use explicitly synthetic local fixtures, never a live account. [Actual native preview](evidence/daily-card-redesign-2026-11-03/native/gl_compatibility/unplayed-1628x966.png), [earned silver](evidence/daily-card-redesign-2026-11-03/native/gl_compatibility/earned-2.png), [Japanese](evidence/daily-card-redesign-2026-11-03/native/gl_compatibility/locale-ja.png), [portrait Finnish](evidence/daily-card-redesign-2026-11-03/native/mobile/portrait-fi.png).

Initial failures remain in the raw logs. The first layout clipped two standings rows; actual row padding and chrome were corrected until all seven fit without relaxing the checks. The existing standings fixture initially expected limit 3; it now checks the approved limit 6 request. The first scoped Ruff run found an import order issue, corrected. A first pytest invocation from the root lacked the backend module path; running from `backend/` succeeds. The `scripts/dev.ps1` entry verifies the pinned 4.7.2 engine but exits with Access denied after the existing certificate-store error in this environment. Subsequent isolated direct launches of that same pinned engine through the required crash-dialog wrapper complete successfully. The entry also regenerated local build identity metadata, which is excluded from the task checkpoint. Import reports the existing Android build-tools-directory warning. The Windows root-certificate-store error remains present in successful native and headless logs; no clean-environment claim is made.

The checked task patch contains only this work, relative to archived task-start runtime sources and current shared catalogues/documents with this task's entries removed. Forward/reverse application and exact normalized UTF-8 text are checked inside an owned temporary repository. The first report pass encountered a PowerShell UTF-16 log; the report reader now detects its BOM without rewriting the raw log. The main index is not written. Concurrent Settings, Volt, Garage assets, backend privileges/achievements and shared documentation changes are preserved and excluded.

Reload/rebuild and owner appearance/touch acceptance remain. The full six-opponent **post-race nearby** list requires the matching backend rollout; no deployment was performed. The existing service can already return six top rows before a local attempt. No physical-device query or test, APK/AAB, live account/service access or mutation, owner-save/process change, main-index staging, commit or merge was performed. Desktop Mobile is the Vulkan renderer on this PC, not a phone test.
