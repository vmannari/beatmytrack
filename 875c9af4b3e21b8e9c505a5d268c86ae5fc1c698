# Multilingual preparation — 2026-10-25

Owner request: prepare the game for multilingual support, with language selected on login and changeable in Settings. Task requirements: **ML01** pre-login selection, **ML02** durable installation preference and Settings, **ML03** translatable presentation, **ML04** catalogue workflow, **ML05** native verification; retain **R01/G01/Q01**.

## Delivered behaviour

- The account/login card has a Language picker. Settings has a Language category using the same picker. A selection saves and applies immediately; other staged Settings values, text entered during login and a pending provider request remain alive.
- `System default` and `English` are the shipping choices. Other languages appear only when their packaged gettext catalogue is explicitly approved in `game/localization/languages.json`. French is a small test fixture under the export-excluded tests directory, not a released translation.
- The installation stores `{schema: 1, language: ...}` atomically in `language.json` beside the original guest records. App startup loads it before constructing login or tutorial UI. This intentionally sits outside account-specific records, preserving the choice across sign-out/account switches and avoiding changes to the existing strict records schema.
- Missing, corrupt, unavailable or unsupported preferences resolve safely to the system language or English. Unsupported system locales fall back to English. A failed write keeps the previous active choice and displays a retry message in the picker.
- Settings categories grow with wrapped text. Expanded text at 960×540 no longer overlaps the next category. Language changes do not rebuild the Settings page or apply unrelated preferences.

## Translation boundary

`game/localization/language.gd` owns the installation preference and native `TranslationServer` locale. `game/localization/game_text.gd` supplies complete-message lookup, named placeholders, gettext plurals and optional node bindings. Bindings refresh in place and when detached retained UI re-enters the tree. Plain game-owned Label/Button strings use Godot's native automatic translation.

Formatted presentation strings in the app and menu modules now look up their templates before printf formatting. Named templates are preferable for new copy because translators can reorder values. Creator captions use bound named messages; collisions/remaining tries and the custom-drawn challenge distance have explicit plural forms. User-label helpers and explicit protection cover login/profile names, main profile buttons, track headings and important standings names, including names identical to catalogue keys.

Custom-drawn challenge cards, route legends, track biomes and record availability text have translation lookups and redraw notifications. The canonical simulation, immutable track documents, backend protocol values and stored achievement definitions have no locale dependency.

The source catalogue is a conservative inventory of presentation literals and achievement display metadata, including arrays passed through shared UI helpers. It can include unused UI/diagnostic copy; it is not a count of distinct visible controls or a claim that every historical concatenated phrase is ready to translate without review. English composition in older dynamic screens, achievement singularisation, locally generated article grammar and baked text assets need in-context review as each real language is produced. The existing Google sign-in button uses approved English artwork; a translated release needs the corresponding approved artwork/resource remap. These items must be reviewed before approving that language in the manifest.

## Adding a language

1. Run `python scripts/localization.py extract`. This updates `game/localization/messages.pot` and the English identity catalogue. It leaves other language files untouched.
2. Create/update a standard UTF-8 gettext `<locale>.po` from that template in a PO editor. Use the proper `Language` and `Plural-Forms` headers, retain placeholders and distinguish ambiguous words with translation context. The extractor understands constant `tr`, `tr_n`, `GameText.message`, `GameText.plural` and `GameText.bind` arguments, including contexts.
3. Register the reviewed resource in `project.godot` under `internationalization/locale/translations`, then add its native language name to `languages.json`. This explicit approval prevents partial/unregistered catalogues from appearing to players. The manifest is included in Android export filters; test fixtures remain excluded.
4. Run `python scripts/localization.py check` and `python scripts/test_localization.py`. Checks reject stale message/context/plural inventories, missing/obsolete/fuzzy/empty entries and changed placeholders. Moving code without changing copy does not invalidate a catalogue solely because a reference line moved. Named placeholders may move; ordered printf argument types must retain their sequence.
5. Verify the actual login, Settings, tutorial, HUD, results, Garage, editor, commerce and online states in context. Check special grammar, player-generated names, articles, unavailable/error states and baked artwork. Add bundled licensed font fallbacks for the chosen scripts, then verify glyphs, shaping, line breaks and directional layout on Android. Pseudo mode cannot certify Arabic/Hebrew or CJK support.

Example for a value that may change language while retained:

```gdscript
GameText.bind(label, "by {creator}", {"creator": creator_name})
```

For counted text, use complete singular/plural templates with `GameText.plural`, rather than concatenating English suffixes. Keep user-authored names and protocol identifiers outside translation. Canonical numeric values and UTC/race timing continue to use their existing storage and calculation conventions; locale-specific display formatting is separate presentation work when languages are chosen.

## Developer expanded-text mode

Launch the debug game with `--pseudo-localization`. The flag does not become a saved player language and is ignored by release builds. Godot's expansion/accents expose missing lookups, narrow controls and missing glyphs. The pinned engine also accents brace-placeholder names; the named-message helper protects those spans before substituting player data. The regression retains the initial failing assertion and verifies the correction.

## Verification and evidence

All native runs use pinned `4.7.2.stable.official.ed1daf0bf`, through `scripts/dev.ps1`, with an isolated workspace `APPDATA`. No owner process is stopped. Detailed commands, counts, initial failures and source hashes are in [report.json](evidence/localization-2026-10-25/report.json); the task-only patch is beside it.

Verified during this task:

| Check | Result |
| --- | --- |
| Dependency-free catalogue tooling | 9 tests pass |
| App integration | 141 checks pass |
| Records | 54 checks pass |
| Graphics/Settings | 146 checks pass |
| Race results | 515 checks pass |
| Challenges | 216 checks pass |
| Weekly Rivalry | 1124 checks pass |
| First-play tutorial | 168 checks pass; actual five-lap Ellipse completes at tick 7116 |
| Full script parser | 1138 scripts pass after one retained archived-Garage resolution failure; direct Garage check also passes |

The focused suite checks the actual login and Settings pages, touch-opened choice menu, region/English fallback, approved-language filtering, reload persistence, retained text, detached-node refresh, unchanged provider state/entered name/unapplied settings, French gettext zero/multiple plurals, reordered named values, save failure/retry UI and expanded sidebar geometry. It records native English, test-French and expanded views at 1280×720 and 960×540 on Compatibility and Mobile/Vulkan desktop renderers. See the report for final focused counts.

Initial sandbox failures accessing the native extension/Windows certificate store were resolved by running only the task's isolated native tests with the required local access. Initial standalone autoload-identifier compilation, test-expectation case/encoding and named-placeholder pseudo failures are retained in logs. An initial parser pass succeeded; a later archived Garage subclass could not resolve its base; the direct base check and subsequent complete parser pass succeeded without weakening the parser. No underlying cause is claimed for that transient resolution failure.

Concurrent login sizing, Garage/sticker, vehicle, driving-control, backend and deployment work is preserved and excluded from the task-only patch. Existing sources shared with those tasks are recorded separately in the report. The earlier source screenshots are retained separately from the final renderer captures.

No device attachment check, physical-phone/tablet test, APK build/install, real sign-in/purchase, live backend mutation, deployment or owner-process restart was performed by this task. Full translations, native-language review, script-specific fonts/RTL and owner/device acceptance remain release work after the initial languages are chosen.

Engine references: [gettext](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_gettext.html), [internationalisation](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html), [pseudolocalisation](https://docs.godotengine.org/en/stable/tutorials/i18n/pseudolocalization.html).
