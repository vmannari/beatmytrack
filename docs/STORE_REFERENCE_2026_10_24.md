# Store reference layout — 2026-10-24

## Vertical scrolling follow-up

SSP01/SSP02: The later owner request applies one quieter scrollbar treatment
throughout menu and race HUD themes: a muted 4-unit thumb inside a 24-unit native
lane, with 10-unit clearance on either side and inset ends. Hover and dragging
increase the thumb contrast. Achievement and Rivalry overrides now inherit the
shared treatment; their existing content gutters remain. Horizontal bars use
the same spacing. Native captures, pixel/drag checks, remaining acceptance and
the task-only checkpoint are in `evidence/scrollbar-style-2026-10-24/report.json`.

SSC01/SSC02: Store now uses the shared `vertical_swipe_scroll.gd` container,
explicit automatic vertical overflow and focus following. Touch swipes and mouse
drags scroll the offers; wheel/trackpad scrolling and native scrollbars remain.
Keyboard focus reveals offscreen actions, and a drag over checkout does not
activate it. The existing menu navigation and recovery footer stay fixed.

The extended `game/tests/test_store_reference.gd` adds twelve fixture offer cards
to exercise a larger catalogue at 1280x720 and 960x540. These extra cards are test
data only. Corrected task-original reproduction: 131 checks, 11 failures; final:
131 headless and 144 each on Windows Compatibility and Mobile, all assertions
passing. Store telemetry (15) and cache/account (9) checks also pass. Commands,
native captures, source hashes and the scoped checkpoint are under
`evidence/store-scrolling-2026-10-24/`.

The first added gesture fixture targeted an offscreen publishing button; the
corrected fixture asserts that its starting checkout is visible. Both initial
logs remain. Sandbox certificate-store diagnostics remain; Compatibility also
reported four ObjectDB instances and one resource at shutdown. No clean-shutdown
claim is made for that run. No phone/tablet attachment check or physical-device
test, APK, real purchase, live mutation, deployment or owner-process restart was
performed. Client reload and owner/device interaction acceptance remain.

The owner's supplied Store example guides the actual Godot page: a larger
permanent ad-free offer, a monthly alternative, a separate publishing section,
account status and a quiet recovery footer. Existing workshop art, fonts, menu
navigation and palette are reused. No new raster assets or provider integration.

## Requirements and files

- STR01: `game/ui/store_page.gd` groups ad-free offers above three publishing
  packs, with navy panels, yellow borders, concise benefits and separate prices.
- STR02: prices, available products and account entitlements remain service
  data. Per-slot prices and the strictly lowest enabled pack's Best value badge
  follow the current catalogue. The reference's three slots are not a new free
  allowance. Copy retains consumed-publication semantics and free racing/drafts.
- STR03: all five actions fit the normal desktop logical viewport. Narrow
  Store layouts stack and scroll, with checkout targets at least 52 units high.
  Resizing adjusts existing containers without replacing pending recovery rows.
- R01: existing scoped reads, passive previews, account fencing, purchase
  journaling, double-press guard and explicit debug simulation remain.
  Impression measurement now includes both offer groups. The telemetry test's
  last-card assertion follows the new order, with ten slots last.
- G01: native Compatibility and desktop Mobile captures show the actual App
  menu and Store. The 600x360 and 390x844 captures exercise Store independently
  of the shared menu header; they are not phone screenshots.
- Q01: `test_store_reference.gd` uses an in-process fake service and disposable
  records. `test_store_cache_reference.gd` independently runs the existing nine
  Store cache/account checks from the broader menu suite. No live checkout.

The example's Restore purchases caption remains Refresh / recover, because the
existing action refreshes access and recovers saved simulation requests. Real
billing remains disconnected and its purchase actions remain disabled. Enabled
debug actions retain their Simulate prefix and NO PAYMENT controls.

## Actual verification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`, native Windows, RTX 3090.
Every run uses a task-specific workspace APPDATA directory. Initial inspection
used `scripts/dev.ps1 CheckScript`; its script-policy and default-userdata
failures were corrected with a process-local execution policy and workspace
APPDATA. The strict development runner stops on the sandbox's certificate-store
diagnostic, so the retained runner invokes the same pinned engine, verifies its
version, and records the complete output without suppressing that diagnostic.

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/store-reference-2026-10-24/run_validation.ps1 -Test TEST -Mode MODE
```

| TEST | MODE | Actual result |
|---|---|---|
| test_store_reference | headless | 104 checks, 0 failures |
| test_store_reference | gl_compatibility | 113 checks, 0 failures |
| test_store_reference | mobile | 113 checks, 0 failures |
| test_product_store_telemetry | headless | 15 checks, 0 failures |
| test_store_cache_reference | headless | 9 checks, 0 failures |
| test_app | headless | 141 checks, 0 failures |
| test_script_parse | headless | 1044 scripts, 0 failures |
| test_menu_medium_priority | headless | 313 checks, 30 washing failures |

The broad suite's nine Store checks pass; its 30 failures are exact mask and
fractional-resistance assertions in unchanged Garage washing. No assertion was
removed or relaxed. `broad-menu-report.json` and the complete log retain this
result; the overall broad suite is not reported as passing.

The first native layout clipped the lower publishing actions at 720p. Smaller
card padding, a single-line value badge and the combined footer correct that;
the focused test now explicitly checks all five desktop action rectangles.
The first compact telemetry run also exposed excessive debug-control height;
its responsive row now stays horizontal at 600 units and stacks below 450.
The earlier native preview is retained under `attempts/`.

Initial graphical fixtures played the menu Ogg and reported four audio objects
at shutdown. Verbose evidence identifies the menu Ogg decoder; the final UI-only
fixture disables music in its disposable settings. Runtime audio is untouched.
The sandbox certificate-store diagnostic remains in logs; no TLS verification
was disabled and no service network calls are required by these fixtures.

## Evidence and remaining acceptance

See `evidence/store-reference-2026-10-24/report.json`, per-renderer reports,
native PNGs and `checkpoint.patch`. The normal 1280x720 capture uses local
fixture catalogue/account values inside the real App; the menu remains Guest.
No owner account or actual purchase is represented by those fixture values.

Client reload and owner appearance/touch review remain. No phone/tablet
attachment check, physical-device test, APK/export/install, live account or
backend mutation, purchase or deployment was performed. Concurrent work and
owner game/editor processes were preserved. The scoped checkpoint excludes
unrelated workspace changes and the development entry point's generated build
identity refresh.
