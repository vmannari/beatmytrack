# Garage Workshop navigation — 2026-10-24

GWN01 groups Customise, Tuning and Care into one Workshop destination with Appearance, Parts and Wash tabs above the car. GWN02 retains separate Record player, News and Trophy wall destinations and keeps Select car available in a stable five-entry rail. GWN03 remembers the last Workshop section during the page lifetime, retaining the live car/viewport and existing editing, washing, preview and purchase paths.

Runtime changes are in `game/ui/garage_page.gd` and `game/ui/garage_mode_icons.gd`. `game/tests/test_garage_sidebar.gd` follows the new navigation contract and checks pointer activation, remembered Parts after News, fixed rail bounds, tab targets, retained car/viewport, full-height News and visible window footer bounds. Existing assertions remain; only the former individual Care/Tuning rail targets now address the Workshop tabs.

Native navigation passes 472 checks each in Compatibility and desktop Mobile, at 960×540, 1280×720 and 1600×720. Existing headless suites pass: studio polish 57, cosmetic carousel 227, App 141, News 70, record player 64 and clean customisation 262. Desktop Mobile is a desktop renderer check, not a physical-device result.

All commands use `scripts/dev.ps1`, pinned Godot 4.7.2, and process-local `APPDATA` set to `build/workshop-nav-user`. Native tests required host access after sandbox log/certificate-store failures. Commands:

```powershell
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_sidebar.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../docs/evidence/garage-workshop-navigation-2026-10-24/compatibility'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_sidebar.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/garage-workshop-navigation-2026-10-24/mobile'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_studio_polish.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_customisation_carousel.gd
scripts/dev.ps1 -Action TestApp
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_news.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_records.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_clean_customisation.gd
git diff --check -- game/ui/garage_page.gd game/ui/garage_mode_icons.gd game/tests/test_garage_sidebar.gd
```

The initial full-width tab row caused six actual-App footer failures. Moving tabs into the preview column restores the full control height. Native image inspection then caught an empty expanding preview column above News; hiding that column outside car views restores the newspaper layout, with an additional assertion. The initial failed studio log is retained alongside passing runs.

Review [Appearance at 960×540](evidence/garage-workshop-navigation-2026-10-24/compatibility/customise-960.png), [Parts](evidence/garage-workshop-navigation-2026-10-24/mobile/tuning-1280.png), [Wash](evidence/garage-workshop-navigation-2026-10-24/compatibility/care-1280.png), [Record player](evidence/garage-workshop-navigation-2026-10-24/compatibility/records-1280.png) and [News](evidence/garage-workshop-navigation-2026-10-24/compatibility/news-1280.png). Results, hashes and a scoped reviewable Git patch are in [report.json](evidence/garage-workshop-navigation-2026-10-24/report.json) and [task-only.patch](evidence/garage-workshop-navigation-2026-10-24/task-only.patch). The runtime patch uses task-start snapshots to exclude existing concurrent edits.

Reload the client for review. Owner appearance/touch acceptance remains. No device attachment check or physical-device test was performed. No APK, deployment, purchase, live mutation or owner-process restart.
