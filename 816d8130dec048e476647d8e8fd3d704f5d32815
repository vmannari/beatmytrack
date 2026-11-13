# Bundled text encoding audit — 28 October 2026

AT01 checks all bundled game text/resources, twelve language catalogues, authored translation inputs, first-party backend/UI and native adapters. The final scan covers **1,540 files with zero encoding findings**. It detects reversible UTF-8 misdecoding, replacement characters, unexpected controls, invalid UTF-8 and unpaired surrogates, including Unicode hidden in JSON escapes. Legitimate accents, CJK, emoji, combining marks and notice page breaks remain intact. Historical test fixtures, generated caches/builds, external vendor trees, private saves and live server records are outside this source audit.

AT02 repairs the confirmed damage:

- `game/core/app.gd`: fifteen lines, twenty-eight damaged sequences in achievement separators, challenge/share text, image preparation, editor hints, width/rotation controls and help. These restore `·`, `×`, `…`, `→`, `−`, `✓`, `°` and `–`.
- `backend/bmt_backend/studio_simulator.py`: two validation-message lines, three damaged range separators. Behavior and bounds stay exact.
- `game/legal/GOOGLEID-NOTICES.txt`: eight lost quotation marks on three lines. Quote positions were checked against Mozilla's [MPL 1.1 text](https://www.mozilla.org/en-US/MPL/1.1/) and [archived NPL 1.1 text](https://website-archive.mozilla.org/www.mozilla.org/mpl/mpl/npl/1.1/). Every other byte, including page breaks, remains exact to the archived task start.
- `game/assets/menu/challenges/three-by-three-tracks-tickets-v7.json`: four damaged multiplication signs hidden in JSON escapes, on three metadata lines. Artwork, references, hashes and every other byte remain exact.
- `game/localization/messages.pot` and `en.po`: sixteen source keys repaired. All sixteen already have nonempty translations in each of the twelve catalogues; fixing the keys reconnects their original translations. This task makes no encoding edits to the eleven non-English catalogues; concurrent updates to those catalogues are preserved.

AT03 adds `scripts/text_encoding.py` and seven focused tests. `scripts/localization.py check` now includes the source scan and rejects damaged source/translation fields. One additional localization test verifies that syntactically valid broken source/translation strings fail. The checker reports findings without modifying files.

Q01 actual final commands and outcomes:

```text
python scripts/text_encoding.py --json docs/evidence/all-text-encoding-2026-10-28/encoding-after.json
python -m unittest discover -s scripts -p test_text_encoding.py
python -m unittest discover -s scripts -p test_localization.py
python -m unittest discover -s scripts -p test_translation_authoring.py
python docs/evidence/all-text-encoding-2026-10-28/run_checks.py translations
python docs/evidence/all-text-encoding-2026-10-28/run_checks.py capture
python docs/evidence/all-text-encoding-2026-10-28/verify.py
```

The final scan is clean. Python tests pass **7 + 15 + 7 = 29**. Pinned Godot **4.7.2 stable ed1daf0bf**, Compatibility: **224 checks, zero failures**, including all sixteen repaired keys in all twelve native catalogues and four English/Finnish before/after text-sheet captures. These use original `MenuStyle` labels/fonts with captions extracted directly from task-start/current App source; the English before/after and Finnish after images were visually inspected. Every nonempty translation in every catalogue preserves its source placeholders. Focused Ruff checks for the new checker/tests, updated localization tests and backend source pass. The extractor retains three pre-existing Ruff findings; the baseline comparison is saved in evidence.

The broader existing `test_translations.gd` run reports eleven packaged-inventory mismatches, then aborts on the concurrently missing `header_cars_v1/hovercraft.png`. Its failure is retained; this is not a full UI regression pass. The strict translation-completeness gate still fails for existing missing/stale/untranslated copy, independently of encoding and placeholder correctness. An initial raw scan also exposed valid legal form-feed page breaks; the checker explicitly accepts them. Extending the check to decoded JSON then found and repaired the four escaped metadata sequences. Initial lint findings in the new tools were corrected and rerun.

R01: exact source audits confine this task to the fifteen App lines, two backend lines, notice quotes and metadata replacements. Concurrent handling, Hovercraft, Garage, editor and translation changes remain. The native runner restores only metadata still bearing its own generated identity; it preserved concurrent metadata during the broader run and restored exact pre-run bytes after capture. The task-only patch excludes concurrent catalogue additions/removals and passes Git reverse-apply and whitespace checks. No main-index staging/commit, deployment, APK, real authentication/purchase, owner-save mutation or owner-process restart.

Evidence: [report](evidence/all-text-encoding-2026-10-28/report.json), [source-only patch](evidence/all-text-encoding-2026-10-28/task.patch), [English before](evidence/all-text-encoding-2026-10-28/en-before-text.png), [English after](evidence/all-text-encoding-2026-10-28/en-after-text.png), [Finnish after](evidence/all-text-encoding-2026-10-28/fi-after-text.png).

Reload/rebuild and owner appearance acceptance remain. No physical-device test or attachment query was performed.
