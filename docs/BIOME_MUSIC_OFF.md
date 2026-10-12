# Background music removed from driving biomes, 2026-10-10

The owner requests removing background music from all biomes. MUS35/SND33,
with SND05/G01/R01/Q01/V06, disable the shared race score in Pine, Desert,
Night City, Winter and Storm, including untimed practice. Race entry stops
menu playback immediately; no six-layer synchronized stream or biome decoder
is allocated. Pause/resume/retry/rewind/finish coast cannot restore it. Race-only
musical breath cues are suppressed. Actual summary entry restores menu/results
music and PB/finish feedback; ordinary menus and interface sounds remain.
Engine/tires/other surfaces, cicadas, rain and thunder stay independent.

No music slider preferences, audio master files, physics, rules, scoring or
server contracts change. Historical score assets/arrangement research remain
available outside active biome playback. The Audio settings description now
says “Menus and results”; obsolete driving-arrangement explanation is removed.

Changed files: `game/soundtrack/audio_world.gd`,
`game/ui/settings_page.gd`, `game/tests/test_soundtrack.gd`,
`game/tests/test_score_flow.gd`, `game/tests/test_biome_music_off.gd` and UID,
`game/tests/capture_settings.gd` (add Audio captures), this page,
`docs/ADAPTIVE_SOUNDTRACK.md`, `docs/music/STATE.md`,
`docs/WET_ROAD_AUDIO.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual engine commands use `powershell -NoProfile -ExecutionPolicy Bypass
-File scripts/dev.ps1` and pinned4.7.2.stable.official.ed1daf0bf:

| Command suffix | Actual outcome |
| --- | --- |
| `TestScript -ScriptPath res://tests/test_soundtrack.gd` | 1,156 checks, zero failures. Menu/settings/results lifecycle and exact960-tick input/state equivalence retained; race-decoder assertions follow the owner's changed contract. |
| `TestScript -ScriptPath res://tests/test_score_flow.gd` | 29 checks, zero failures; all five biome contexts stay score-free. Offline progress diagnostics remain. |
| `TestScript -ScriptPath res://tests/test_biome_music_off.gd -Graphical` | 52 checks, zero failures; five native Music-bus recordings have PCM peak exactly zero. Vehicle/weather ownership, immediate menu stop, pause/resume/retry and silent finish coast checked. |
| `TestApp` | 99 checks, zero failures. |
| `TestScript -ScriptPath res://tests/capture_settings.gd -Graphical` with an absolute `--capture-settings` evidence directory | Initial pre-Audio capture278/zero; full Audio-inclusive capture284 has one camera touch-strength assertion failure. Same failure persists after a direct-window input experiment; that unsuccessful input change is reverted. Camera runtime/assertion is unchanged, failure retained. Audio captures at960/1280/1600 widths succeed; final1280 screenshot inspected. |
| Independent Python PCM/hash review | All five biome music recordings digitally silent. Weather/vehicle/wishlist/audio-source hashes unchanged by the music-removal slice; later requested thunder-tail work is tracked separately. |

Evidence, source snapshots, test receipts and task-only source patch:
`docs/evidence/biome-music-off-2026-10-10/`. Screenshot:
[Audio settings](evidence/biome-music-off-2026-10-10/settings/settings-audio-1280x720.png).
No failing camera invariant is removed or reported as passing. Music removal
does not depend on that unrelated camera capture acceptance.

No phone attachment check, physical-device listening/test, APK export/install,
full Validate, physics merge, backend or deployment. Owner confirmation in
ordinary driving/device listening remains. Source/PCM checks do not establish
zero speaker/Bluetooth output-buffer latency.
