# Car-free customisation purchase sheet — 2026-10-27

The owner requests removing the car, fixing insufficient-coins layout/scrolling, and completing missing purchase translations. NC01 removes the preview; NC02 keeps ordinary affordable/zero/low-balance layouts stable and fully visible; NC03 covers every purchase caption in all 12 supported languages; NC04 keeps the translation source inventory safe. R01 preserves the existing account/purchase/context fences and Q01 covers actual native UI checks.

The window is now a compact 760-unit-wide sheet with a quiet scenic heading, actual item title, permanent-unlock scope and one price/balance row. It creates no car, viewport, callout or rotation hint. The Garage purchase builder no longer prepares car appearances, settles transitions or passes model data to this dialog. The previous preview helper remains as unused source; it is not instantiated by this flow.

The availability message has a reserved area outside the scrollable details. Zero and low balances show the factual amount still needed in place of an impossible after-purchase balance. The primary action retains the existing native disabled state. Footer heights use the actual multilingual button minimums, avoiding Japanese/Korean overlap. Within each language, affordable, zero-balance and low-balance windows have identical dimensions, and ordinary content fits without either scrollbar. The genuine long-copy/tiny-viewport fallback remains accessible above the fixed status/actions.

All purchase copy uses the existing localization bindings, including title, category, permanent-unlock scope, coin label, both balance captions, shortfall, unlock/sign-in actions, Not now, availability and Close tooltip. Eight newly authored rows supply 88 non-English translations in `scripts/translations/customisation_purchase_2026_10_27.tsv`. Existing captions are restored to the current compiled source inventory. The shared production fonts and bundled fallbacks are reused, avoiding per-window font copies and their small-label rendering artifacts. Language changes update the open sheet and tooltip.

Refreshing the catalogues exposed shader fragments and regex word-boundary strings incorrectly entering the display-copy inventory; one fragment's unmatched brace caused the placeholder validator to throw. `scripts/localization.py` now excludes shader syntax (`render_mode`, `MODEL_MATRIX`, function declarations) and regex word-boundary fragments from inferred copy. Explicit translation calls still enter the inventory. Independent tests retain real named placeholders and purchase copy while rejecting these code fragments.

Runtime files are `cosmetic_purchase_dialog.gd`, its existing background shader and the purchase-builder function in `garage_page.gd`. Support changes are the focused purchase test, eight-row translation table, extractor and its tests, refreshed POT/12 PO catalogues, this document and the evidence folder. No model, paint, lighting, physics, save format, economy authority, art bitmap or language manifest changes.

Actual validation:

| Check | Result |
|---|---|
| Initial native layout | 4,178 checks, 28 failures: 14 Japanese/Korean action overlaps and 14 invalid identical-word fallback assertions |
| Corrected native layout / shared-font refinement | 4,325 checks, 0 failures in each recorded run |
| Final Compatibility | 5,107 checks, 0 failures |
| Final desktop Mobile/Vulkan | 5,107 checks, 0 failures |
| Existing economy/real Garage suite | 56 checks, 0 failures |
| Translation authoring | 7 tests, pass |
| Localization extractor / English inventory / placeholder tests | 14 tests, pass |
| Existing GDScript parser | Final 1,329 scripts, 0 failures; initial unrelated preloader error retained |
| Pinned imports | All recorded import runs pass |

The focused suite covers all 12 languages with affordable, zero, low, busy, pending, guest and paint states; six production-stretched sizes; live language change; a raw narrow portrait with zero balance; real long-copy overflow; zero preview viewports; complete visible captions; equal paid/no-money dimensions; native availability, Close/Escape/Not now, stale-context rejection, sign-in and duplicate confirmation guards. The earlier car/camera/drag requirements are explicitly superseded by NC01 and archived task-start tests; transaction, layout, accessibility and overflow assertions remain. Spanish/Portuguese `Exterior` is a correct authored cognate: packaged translation presence remains required rather than incorrectly demanding different spelling.

Full-project localization completeness was already failing with 589 errors before this task. It now reports 176 untranslated entries for 16 unrelated source strings across 11 non-English languages, mainly recent Rivalry/result/editor recovery copy. No current purchase string is among those gaps. Complete release translation validation is still blocked; it is not reported as passing. The existing compiler's explicit development `--allow-incomplete` mode retains empty entries for these unrelated gaps. The catalogue comparison records zero changes to previously nonempty translations, 40 new inventory entries and one removed obsolete `Report or block this player` entry per catalogue. No private text was sent to a translation service; the new text was authored directly.

The initial placeholder-validator exception, initial bounds/cognate findings, small-label font review, original question-mark placeholder draft, intermediate and final captures remain in evidence. The incorrect placeholder draft is replaced with a factual shortfall, and shared fonts render the final Finnish labels correctly. The first broad parser run encountered undefined `result` in concurrent `garage_preloader.gd:103`; after that file changed externally, the retry passed all 1,329 scripts. This task did not edit that preloader. No genuine layout or transaction assertion is weakened.

Actual commands use the existing pinned-engine entry point and separate task-owned `APPDATA` fixture directories:

```powershell
python scripts/localization.py extract
python scripts/translate_catalogues.py --allow-incomplete
python scripts/localization.py check
python -m unittest discover -s scripts -p test_localization.py
python -m unittest discover -s scripts -p test_translation_authoring.py
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_customisation_purchase_layout.gd -Graphical -RenderingMethod gl_compatibility -TestArgument "--evidence=res://../docs/evidence/customisation-purchase-no-car-2026-10-27/review-gl_compatibility" -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_customisation_purchase_layout.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument "--evidence=res://../docs/evidence/customisation-purchase-no-car-2026-10-27/mobile" -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_earned_coins.gd -TestArgument "--evidence-root=res://../docs/evidence/customisation-purchase-no-car-2026-10-27/economy" -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
git apply --reverse --check docs/evidence/customisation-purchase-no-car-2026-10-27/checkpoint.patch
```

Task-start sources/catalogues, comparison, original failures, native views, hashes and the task-only checkpoint are under `docs/evidence/customisation-purchase-no-car-2026-10-27`. The Garage checkpoint restores only the original purchase function against current surrounding code so concurrent work is excluded. Generated build identity and unrelated runtime changes are excluded.

Reload/rebuild and owner appearance/touch/translation acceptance remain. No device attachment check or physical-device test was performed. No APK, real authentication/purchase, owner-save/live mutation, deployment, staging, commit, merge or owner-process restart was performed.
