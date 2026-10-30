# Super Wash beside the manual tools — 2026-10-29

**SWL01:** Super Wash is now the third tile beside Wash mitt and Hose, with the shared Garage droplet/sparkle emblem. It is an immediate action and does not join the manual tools' selection group. Its previous bottom-row button is removed.

**SWL02:** The three tiles have equal widths, share the cleanliness panel's left and right edges, and follow that panel when its width changes. The row sits eight logical pixels below the panel. Captions fit the narrower tiles by reducing their font size when needed. Existing compact/large tile heights remain.

**R01/Q01:** Cleaning, local saving, paint/parts, per-car isolation, future ad status, manual washing and unrelated concurrent work are preserved. The retained Super Wash regression now finds the relocated control and checks exact row alignment, equal widths, caption fit, option order and independent action/selection behaviour alongside its existing cleaning and persistence assertions.

Changed runtime sources: `game/ui/garage_page.gd` and `game/ui/garage_wash_tool.gd`. Updated regression: `game/tests/test_super_wash.gd`. No new message identifiers, images, dependencies or gameplay contracts are introduced. Before sources, logs, captures, hashes and the task-only source checkpoint are in `docs/evidence/super-wash-layout-2026-10-29/`.

Actual results:

| Check | Result |
| --- | --- |
| Updated Super Wash, headless | 286 checks, 0 failures |
| Updated Super Wash, native Compatibility | 300 checks, 0 failures; 14 captures |
| Updated Super Wash, native desktop Mobile | 300 checks, 0 failures; 14 captures |
| Existing hose regression, headless | 91 checks, 0 failures |

Native captures cover all six cars and 960×540, 1280×720 and 1600×720 viewports. The Compact capture and narrow layout were visually inspected. The scripts run with isolated workspace-only application-data directories and an empty backend URL. Runtime logs retain the sandbox's Windows certificate-store error; there are no script errors or failing assertions in these runs. The prior task's typed-array problem is absent from the current runs.

Commands from the repository root:

```powershell
python docs/evidence/super-wash-layout-2026-10-29/run_validation.py
python docs/evidence/super-wash-layout-2026-10-29/run_validation.py --mode gl_compatibility
python docs/evidence/super-wash-layout-2026-10-29/run_validation.py --mode mobile
python docs/evidence/super-wash-layout-2026-10-29/run_validation.py --test test_garage_hose
git diff --check -- game/ui/garage_page.gd game/ui/garage_wash_tool.gd
```

Reload/rebuild and owner/device appearance/input acceptance remain. Desktop Mobile is a desktop renderer test, not Android evidence. No device attachment query/test, APK, auth/purchase, live/backend/owner-save mutation, deployment, owner-process restart or main-index staging/commit/merge was performed.
