# Night broken glass — 2026-11-08

NIG01: Owner reports broken glass is too light in Night. The CanvasItem overlay previously used the same bright texture in every biome and received no world lighting. Night now multiplies its RGB by a blue-grey tint `(0.34, 0.40, 0.50)`; other biomes use white. Alpha, texture, reveal geometry and accumulated side damage remain unchanged.

NIG02: Race creation and weather refresh configure the tint. Clearing damage and restoring rewind damage preserve it. Concurrent simpler-model changes in `game/core/game.gd` are preserved and are outside this change.

Changed files: `game/camera/impact_glass.gdshader`, `game/camera/impact_cracks.gd`, two configuration calls in `game/core/game.gd`, and `game/tests/test_night_impact_glass.gd`.

Verification used the pinned Godot 4.7.2 standard console engine through `scripts/dev.ps1`, launched using `powershell -NoProfile -ExecutionPolicy Bypass -File`. Each process used a task-specific `APPDATA` directory under `build/night-impact-*-user`; no owner save was edited.

| Actual command arguments to dev.ps1 | Result |
| --- | --- |
| `TestScript -ScriptPath res://tests/test_night_impact_glass.gd` | 8 checks, 0 failures, headless actual race |
| `TestScript -ScriptPath res://tests/test_night_impact_glass.gd -Graphical -RenderingMethod gl_compatibility` | 12 checks, 0 failures |
| `TestScript -ScriptPath res://tests/test_night_impact_glass.gd -Graphical -RenderingMethod mobile` | 12 checks, 0 failures, desktop Vulkan |
| `TestScript -ScriptPath res://tests/test_impact_cracks.gd` | 9 checks, 0 failures |
| `TestRewind` | 61 checks, 0 failures |

The actual race fixture verifies Night initialization, weather refresh, restart clearing, damage restoration, and original tint in Pine/Desert/Winter/Storm. Native comparisons use the same captured Night backdrop and damage. Compatibility changes 194241 pixels, lowering their summed luminance from 48855.376 to 21529.717. Desktop Mobile changes 217777 pixels, lowering summed luminance from 51115.409 to 23790.854. Neither comparison has brighter pixels above the 0.01 luminance threshold. These are image measurements, not performance results.

Before/after PNGs are in [evidence/night-impact-glass-2026-11-08](evidence/night-impact-glass-2026-11-08). The white tint recreates the original shader appearance over the exact same backdrop; it is not a separate old executable. Both final after images were visually inspected.

Retained findings: initial direct script launch was blocked by PowerShell execution policy. Sandboxed engine runs reported certificate-store/Access denied errors; the dev wrapper treats ERROR output as fatal. Isolated offline runs outside the sandbox passed. The initial live-background Mobile pixel comparison failed its no-brighter-pixels check because successive rendered frames were not frozen. The corrected fixture freezes the actual rendered backdrop before comparing the glass; the assertion and production tint were retained. Original native Compatibility comparison also passed 12/0. Raw wrapper logs remain under `build/logs`; selected logs are copied into the evidence directory.

Reload the client to see the change. Owner appearance acceptance remains. No device query/test, APK build/install, backend request, deployment, owner-process restart, main-index write, or prepared vehicle asset rebuild was performed.
