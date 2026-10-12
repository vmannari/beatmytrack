# Preloaded comparisons and Slippery first opening, 2026-10-10

Owner requires ordinary browsing to avoid Loading captions and reports that
Slippery was blank on first opening. Owner confirmed the **compact** car.
Requirements **HSTART03** preload initial/nearby comparisons; **HSTART04** show
Loading only for exceptional waits; **HSTART05** reproduce actual Slippery
data; **HOPT02/RR06/TD06/TD08/R01/B07/Q01** preserve one unified field,
cached frames/personal overlays, account/car/contract fences and no polling.

## Behavior

Startup/authenticated catalog arrival warms the restored track and up to six
metadata entries for the selected car. Car changes warm that car's field.
Actual track selection also warms nearby entries before download/compilation
finishes. This does no geometry compilation, racing, rewards or account writes.

The new adapter runs at most two comparison jobs, with a six-target queue and
foreground selection priority. Requests for the same version/car coalesce.
Leaderboard reads start independently and cannot hold a histogram pending.
Completed packets persist through the existing bounded atomic cache: 32
entries, 2 MiB, ten-minute maximum age. Keys include version, car/configuration,
physics, rules, compiler, engine and histogram resolution; the containing
cache is scoped to server/account/development configuration. Late account
responses and corrupt packets are rejected. Background failures do not spin
automatic retries. Data from another car/account is never substituted.

The first visible comparison consumes a ready/in-flight prefetch when it has
no previous frame or personal overlay to preserve. Existing completed charts
stay visible while their ordinary retained-frame/personal-overlay request
runs. This retains the prior no-polling behavior for repeated draws and same
selection. Pending data never claims an empty population. Actual empty fields
keep the existing **No times yet** state; request failures remain explicit.

Ordinary pending histogram/high-score/selected-track preparation shows no
Loading text or LOADING race-button caption. If an unresolved request lasts
**2.5 seconds**, the existing Loading caption becomes visible. This is a local
presentation threshold, not a guaranteed HTTP deadline. Successful/failing
completion removes it. Prewarming and cache reuse reduce the wait itself;
the delay rule also suppresses brief caption flashes during a genuine cold
miss. Race-start preparation and a genuinely uncached catalog retain their
existing separate loading behavior.

## Slippery inspection

Read-only gameplay probe used an **existing artificial diagnostic account**;
diagnostic authentication sessions were issued. No race tickets, uploads,
scores, profiles or deployments were changed. Public document and comparison
packets were retained outside the game/export root for reproducible tests.

| Car | HTTP | Race drivers/bins | Lap drivers/bins |
|---|---:|---:|---:|
| Compact | 200 | 100 / 16 | 100 / 16 |
| Pickup | 200 | 0 / 0 | 0 / 0 |
| Classic | 200 | 0 / 0 | 0 / 0 |
| Formula | 200 | 0 / 0 | 0 / 0 |
| Kart | 200 | 0 / 0 | 0 / 0 |

Compact reads measured 188.21–200.07 ms from this workstation. All car reads
across two probes ranged 141.36–349.32 ms. The confirmed compact case should
display data; it was not a lack of recorded times. The first-open native
regression compiles Slippery's actual published document and uses the actual
100-driver compact packet, asserting both charts and exact population.
The independent high-score row in that UI fixture is fictional controlled
test data, not claimed to be Slippery's live leaderboard.

[Sanitized live receipt](evidence/instant-comparisons-2026-10-10/slippery-live.json),
[compact packet](evidence/instant-comparisons-2026-10-10/slippery-compact-packet.json),
[public document](evidence/instant-comparisons-2026-10-10/slippery-document.json).
Inspected [first-open Slippery](evidence/instant-comparisons-2026-10-10/slippery-first-open.png).
Also retained [exceptional delay](evidence/instant-comparisons-2026-10-10/exceptional-delay.png)
and [actual empty kart field](evidence/instant-comparisons-2026-10-10/slippery-kart-empty.png).

## Files, commands and outcomes

Runtime: new `game/backend/comparison_preloader.gd`,
`game/ui/track_discovery_provider.gd`, `game/ui/track_browser.gd`,
`game/core/app.gd`. New `game/tests/test_instant_comparisons.gd`/UID;
updated startup fixture helper, ordinary-pending caption assertion in
`test_menu_loading_speed.gd`, and cold-selection assertion in
`test_menu_loading.gd`. No canonical simulation, rule or backend code changes.

Pinned Godot **4.7.2.stable.official.ed1daf0bf**, Windows Compatibility.
Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `TestScript -ScriptPath res://tests/test_instant_comparisons.gd -Graphical`:
  **28 checks, zero failures**. Actual Slippery first opening, restart cache,
  corrupt-safe validation, account/car isolation, no ordinary Loading,
  exceptional completion, exact empty field, bounds/foreground priority,
  duplicate coalescing and independent held leaderboard/late-account checks.
- `TestScript -ScriptPath res://tests/test_startup_histogram.gd -Graphical`:
  **26 checks, zero failures**.
- `TestScript -ScriptPath res://tests/test_unified_histograms.gd -Graphical`:
  **150 checks, zero failures**; retained sixteen-bin frames and player markers.
  Retained source fixture uses `BMT_RESULTS_EVIDENCE=docs/evidence/histogram-grid-2026-10-09`.
- `TestScript -ScriptPath res://tests/test_menu_loading_speed.gd -Graphical`:
  **30 checks, zero failures**, with capture directory under
  `build/instant-comparisons/menu-speed-final`.
- `TestScript -ScriptPath res://tests/test_menu_loading.gd`:
  **40 checks, zero failures**, including quiet metadata preparation and real
  failure recovery with an optional read-only adapter.
- `TestApp`: **99 checks, zero failures**.
- `TestScript -ScriptPath res://tests/test_script_parse.gd`:
  initial **458 scripts**, then **459 scripts, zero failures** after concurrent additions; final source fixture also passed after the last helper edits.
- `Import`: exit zero; generated UID metadata for the new scripts and scanned
  concurrent workspace presentation changes.
- `.tools/backend-venv/Scripts/python.exe build/instant-comparisons/inspect_slippery.py`:
  two successful bounded probes, existing diagnostic sign-in only, no gameplay writes.

Initial startup regression caught prewarming a repeated already-loaded
selection; moving warming after that early return preserved no-polling.
An existing immediate Loading expectation was updated to the owner's new
quiet ordinary-wait requirement while retaining the missing-field assertion.
A read-only cloud test adapter lacks sign-in and correctly skips optional
prewarming; its retained isolation/failure assertions pass. An initial app
compile encountered transient `_dust_car` references during an independent
dust update; the settled workspace App99/parser458 passed without editing
that task. No unrelated source is included in this checkpoint.

Task-only review checkpoint: `refs/codex/instant-comparisons-20261010`.
No phone attachment check, physical-device test, Android export/install, full
Validate, backend deployment or real player-score writes. Restart/rebuild the
client to use the change. The owner's exact installed first-open/device case,
network loss and long-session cache/network behavior remain acceptance checks;
no universal instant-data guarantee is claimed.
