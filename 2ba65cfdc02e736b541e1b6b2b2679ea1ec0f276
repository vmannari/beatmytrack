# Direct translation authoring — 2026-10-25

Requirements: **TR01** author the requested translations directly; **TR02** offer them on login and in Settings; **TR03** preserve names, counts and values; **TR04** bundle script coverage; **TR05** verify actual native UI. Preserve **R01/G01/Q01** and concurrent work.

This is an **unfinished authoring checkpoint**, not a completed multilingual release. The language selectors work and all eleven requested languages are registered, but some copy still falls back to English. The exact outstanding sources are in `authoring-status.json` beside the evidence. Both completeness commands intentionally fail while those entries remain empty; no missing copy is presented as reviewed English identity text.

French, Spanish, German, Brazilian Portuguese, Japanese, Korean, Dutch, Italian, Finnish, Swedish and Norwegian Bokmål are selectable alongside English and System default. Native language names identify the options. Selection applies immediately, persists before login, and survives sign-out. Changing language retains entered login values and unrelated unapplied Settings values.

The owner corrected the authoring approach: an offline translator was not wanted. Earlier M2M100 drafts and a local review-model experiment are superseded. The task-owned helper was stopped and its downloaded translation models and authoring environments removed. Current PO files are compiled solely from assistant-authored text in `scripts/translations/*.tsv` and `scripts/localization_overrides.json`; unresolved entries are empty and use Godot's English fallback. The compiler contains no inference, model or network code. A prior automatic approval review rejected exporting the complete nonpublic catalogue to Google Translate; that export did not occur. No private catalogue was submitted to an external translation service.

The authored files cover common menus, login, Settings, driving controls, tutorial prompts, challenges, Garage/washing, car descriptions, results, rankings, achievement titles and some objectives. A bounded set of complete label templates handles repeated labels such as “Loading tracks”. These are explicitly authored phrases, with terminal punctuation kept outside the inserted noun. They are not a word-substitution translator. Brand names, resource/node identifiers and physical-unit-only formats remain exact. The source inventory is conservative and includes unused diagnostic copy; its size is not a count of visible controls.

Gettext plurals replace English suffix concatenation in search/filter buttons, editor issue counts and browser totals. Achievement objective lookup precedes count substitution and uses real plural pairs; retained objective labels refresh with the locale. Weekly Rivalry keeps its English ordinal appearance in English and omits English ST/ND/RD/TH suffixes in other locales. Race Again uses the existing original vector restart icon and translates its heading and motivation separately. The previously embedded restart character was absent from the bundled fonts; both attempted symbol-font families lacked that glyph and were removed.

Noto Sans JP and Noto Sans KR supplement the original Latin faces. Font variations retain body/display weights and select Korean glyph priority for Korean. The localized Google action uses the original unmodified Google G, bundled Google Sans medium, and localized button text. English keeps its existing approved artwork. Font source revisions, hashes and original OFL licences are retained in [downloads.json](evidence/translations-2026-10-25/downloads.json); all three licences are included in export filters. Google identity guidance: [official branding requirements](https://developers.google.com/identity/branding-guidelines).

Authoring and checking:

```powershell
python scripts/localization.py extract
python scripts/translate_catalogues.py
python scripts/localization.py check
python -m unittest discover -s scripts -p test_localization.py
python -m unittest discover -s scripts -p test_translation_authoring.py
```

The compiler defaults to refusing incomplete data. `--allow-incomplete` is an explicit development-only generation step used for this checkpoint. It writes empty translations for unresolved messages, never copies machine drafts or fills gaps with English text. Complete catalogue validation remains a required release check.

Native validation uses pinned `4.7.2.stable.official.ed1daf0bf`, isolated workspace `APPDATA=build/translations-user`, and `scripts/dev.ps1`. Actual commands/results, retained initial failures, source hashes and a scoped review patch are in [report.json](evidence/translations-2026-10-25/report.json). Screenshots under `native/` are real desktop Godot captures, including 960×540 settings and Japanese/Korean login. They establish rendering and layout, not complete translation coverage or native-speaker acceptance.

The existing App regression passed 141 checks and achievement detail passed 758. The existing race-results regression stopped on a freed lambda capture. Reloading the exact task-start Results source only in an isolated process's memory reproduced the same error; no assertion was changed. That broader suite is not reported as passing. Initial runs also retained the missing restart glyph, first-import font preload errors, and a concurrent electric coachwork typed-array error. Final glyph checks use the original vector icon; the unsuccessful symbol fonts are not shipped.

Remaining work includes the outstanding source list, contextual review of older concatenated messages and newspaper grammar, complete Settings/help and error states, full result/Garage/editor flows in every language, and physical-device layout/performance acceptance. No device attachment check or physical-device test, APK, live account change, real purchase, social send, deployment or owner-process restart was performed.
