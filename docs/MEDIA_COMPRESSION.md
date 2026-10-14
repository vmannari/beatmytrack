# Audio and artwork compression — 2026-10-12

Requirements **MC01–MC05 / SND05 / V04–V06 / G01 / R01 / Q01**. The owner
authorizes processing/compressing existing audio and pictures, removing obsolete
unused artwork, and retaining accepted quality. Engine, architecture, release
template and deployment work remain outside this task.

## Delivered and measured

The new **local debug APK is 227,412,160 bytes (227.4 MB / 216.9 MiB)**,
SHA-256 `c3debd9e088310cfdeda39af88aa05396446135227743ecffb2806b4d0c0bf39`.
The previously deployed package is 275,917,226 bytes, hash
`52fd58bef9bad528552d3d11ed30afcb60ba94a185252194ed02a0964627fd70`.
The local package is **48,505,066 bytes / 17.6% smaller** despite also containing
newer workspace content, including the owner's replacement menu recording.
This comparison is not an otherwise-identical before/after game build.

Both ARM64 and x86-64 native-library sets are **byte-identical** to the deployed
package. No installation, backend write or deployment occurred. The former
package remains at `build/media-compression/deployed-before.apk`.

| Media | Pre-task resource footprint* | Final APK media payload |
| --- | ---: | ---: |
| 19 active long audio loops | 41.11 MB | 11.13 MB |
| 16 colour pictures | 31.69 MB | 9.45 MB |
| Four superseded artwork resources | 4.70 MB | 0 |
| 33 inactive audio resources | 18.51 MB | 0 |

\* Pre-task imported-resource bytes were measured with ZIP-compatible deflate,
not with a second full Android export. Their same-source media saving estimate
is 75.43 MB. The actual APK comparison above is separately measured.
The PCM masters for the 19 loops total 44.91 MB; derived Ogg files total 11.06 MB.

Evidence: [package audit](evidence/media-compression-2026-10-12/package-audit.json),
[initial asset inventory](evidence/media-compression-2026-10-12/before-assets.json),
[audio quality](evidence/media-compression-2026-10-12/audio-quality.json),
[texture quality](evidence/media-compression-2026-10-12/texture-quality.json).

## Audio: MC01–MC02

Local FFmpeg/libvorbis encodes the unchanged PCM masters at 44.1 kHz, preserving
channels and every original frame. Nineteen long beds cover the actual menu,
Desert wind/sand, Winter wind, Night/Grass cicadas, Storm rain/distant rumble and
the long vehicle road/wind/water/grass/loose/sand/kerb textures. Quality 8 passes
for Winter wind, distant rumble and kerb rumble; the remaining recordings require
quality 10. No EQ, pitch, loudness normalization, new fade or loop edit is applied.
Short impacts, interface cues, tire/scrape voices and all engine orders stay PCM.

Independent complete-file decode gates require exact duration/channel count,
SNR >=30 dB, RMS change <0.15 dB, material spectral-band change <0.75 dB,
50 ms envelope change <1 dB, headroom and a bounded cyclic seam. Final minimum
SNR is **30.33 dB**, menu SNR **36.31 dB**, maximum RMS change **0.042 dB** and
maximum measured band change **0.163 dB**. All nineteen independent rebuilds
match their encoded hashes exactly; original master hashes remain unchanged.

`AudioLoop.prepare` duplicates native Vorbis resources and enables full-file
looping. Existing `PcmAudioLoop` and its exact interpolation-frame guard remain
unchanged for PCM. VehicleAudio selects the nine compressed beds explicitly;
impact/native-Windows PCM paths remain intact. Ambience/menu resource references
use the compressed files directly. Gains, timing, pitch variation, voice counts,
pause/focus/finish/retry behavior and canonical state are preserved.

Headless VehicleAudio keeps its presentation logic but allocates no output
decoder voices. Output-pause fixtures explicitly enable dummy playback so their
original assertions still check actual player state. Exit stops players, clears
their streams and releases the bank. This fixes the decoder shutdown leaks
observed during the first quick export; it does not suppress engine errors.

The package omits the nineteen PCM masters and 33 already-inactive files: thirty
disabled racing-score layers, the replaced menu theme, old synthetic rain and
the rejected wet-road derivative. All remain local for provenance, rebuilding
and explicitly offline diagnostics. Finish/PB/interface cues remain packaged.
The encoded bank manifest and notices ship; existing source/license limitations
remain exactly those of the original recordings. No runtime dependency/API added.

## Artwork: MC03–MC04

Reference inspection includes explicit paths, concatenated VehicleCatalog paths,
runtime screens and offline baking tools. The five fictional car illustrations
remain necessary for MenuStage and challenge-car selection.

Removed from `game/assets`: unused podium compact cutout, replaced procedural
grass albedo, rejected Winter ice v2 and replaced ice-finish v2. Original masters
and import metadata are preserved under `archive/artwork/retired-2026-10-12/`,
outside the export root. The old ice bake reads/writes its archive paths; the
grass generator also sends its retired albedo to the archive, preserving its RNG
sequence for the still-used macro/normal maps. No player files were removed.
See [retirement receipts](evidence/media-compression-2026-10-12/retired-artwork.json).

Sixteen active menu/colour textures use Godot's lossy disk compression at 0.95
quality; `discovery-biomes.png` uses 0.98 after its first candidate narrowly
failed the fixed 38 dB PSNR gate. Resolution, mipmap settings, framing and alpha
are preserved. Actual imported base-level pixels pass **PSNR >=38.12 dB** and
**luminance SSIM >=0.9869**, with exact alpha. The other **24 retained pictures
are pixel-identical** to baseline: shader data, normals, masks, dust/frost/glass,
editor/HUD icons and Google artwork remain lossless. PNG masters are unchanged.

Actual final screens were captured and inspected:
[Race](evidence/media-compression-2026-10-12/menu-play.png),
[Garage](evidence/media-compression-2026-10-12/menu-garage.png).
Before/after imported pixels are at `build/media-compression/textures/`.
The initial whole-app baseline capture failed during a concurrent workspace class
cache change, so no exact paired whole-app screenshot claim is made.

## Actual verification: MC05

Build/run entry point is `scripts/dev.ps1`, using exact pinned
`4.7.2.stable.official.ed1daf0bf` and matching templates. Offline processing uses
the already-installed WSL music Python and FFmpeg 7.0.2; no packages were installed.

| Actual command | Final outcome |
| --- | --- |
| `python scripts/optimize_media_assets.py audit` | 162 source assets inventoried; pre-task checkpoint captured. |
| Existing WSL Python `scripts/optimize_media_assets.py encode` | All 19 full decoded quality gates pass. |
| Same Python `... verify-rebuild` | 19 encoded hashes exact; every initial master hash preserved, including archived art. |
| `dev.ps1 -Action Import` | Exit 0; compressed imports and updated scripts registered. |
| `dev.ps1 -Action TestScript -ScriptPath res://tests/capture_media_textures.gd -TestArgument --media-stage=before/after` | 44 before /40 after imported pictures captured. |
| Existing WSL Python `... review-textures` | All 40 retained images pass their quality/exact-pixel gates. |
| `dev.ps1 -Action TestScript -ScriptPath res://tests/test_media_compression.gd` | 301 checks, zero failures; all native seeks/wraps at 0.85/1.0/1.3 pitch, no clipping/new gaps/excessive discontinuity; real runtime compressed selection and headless no-output behavior. |
| Same entry point: `test_audio_loops.gd`, `test_soundtrack.gd` | 208 and 1,158 checks, zero failures; retained PCM synthetic interpolation tests and soundtrack lifecycle/settings/source pins. |
| Same: `test_desert_ambience.gd`, `test_winter_wind.gd`, `test_night_ambience.gd`, `test_grass_nature.gd` | 111/87/25/107 checks, zero failures. |
| Same: `test_vehicle_audio.gd`, `test_biome_music_off.gd` | 1,454/42 checks, zero failures, including exact 960-tick audio/no-audio canonical equivalence. |
| Same: `test_continuous_desert_audio.gd`, `test_wet_road_audio.gd`, `test_desert_audio.gd`, `test_surface_impact_audio.gd`, `test_grass_kerb_audio.gd` | 28/50/25/67/76 checks, zero failures. |
| `dev.ps1 -Action TestScript -Graphical -ScriptPath res://tests/capture_menu_exploration.gd` | Final exit 0; 9 checks, two actual compressed wraps, focus pause/resume and exact delivered mute. |
| Existing WSL Python `... review-native` | Native wraps 6.93/7.00 seconds, peaks 0.5984, minimum 50 ms RMS -32.33/-32.25 dBFS; no clipping/silent gap; mute exactly zero. |
| `dev.ps1 -Action TestApp` | 99 checks, zero failures. |
| `dev.ps1 -Action TestDriving` | 72 checks, zero failures. |
| `dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 574 scripts, zero failures. |
| `dev.ps1 -Action Snapshot -Screen play/garage` | Actual captures saved and inspected. |
| `dev.ps1 -Action ExportAndroid -QuickValidation -CommandTimeoutSeconds 600` | Final exit 0; import/startup/driving72/catalog21/menus48 pass, fresh APK produced. Full Validate not run. |
| `python scripts/optimize_media_assets.py audit-package` | All 56 excluded asset resources absent; all 19 encoded loops and notices present; all native libraries byte-identical. |
| `dev.ps1 -Action Doctor` | Exact engine/templates present; ADB list empty. **No phone attached; no physical device test.** |

Initial failed attempts were corrected and are not counted as passed: restricted
certificate/ADB access (normal-access reruns succeeded), temporary Windows DLL
locks during simultaneous import/tests (sequential export succeeded), incomplete
concurrent PropNature/PropGeometry class-cache states (reimport), serialization
cycle and Ogg muxer-flag placement in the offline tool, one overly-compressed
biome image, the old loop fixture's stale 40-versus-actual-42 count, pending freed
control callbacks, output-pause fixtures requiring explicit dummy playback, and
a nested fixture indentation error. No canonical or quality assertion was removed.

## Changed files and remaining acceptance

The exact file list and baseline/final hashes accompany the scoped checkpoint:
[task paths](evidence/media-compression-2026-10-12/task-paths.json),
[task-only patch](evidence/media-compression-2026-10-12/task-only.patch).
Changes cover the new offline media tool/audio helper/manifest, nineteen Ogg/import
pairs, sixteen image import settings, four artwork removals/archive moves, audio
runtime references/vehicle lifecycle, export filters, relevant diagnostic fixtures
and these status/phase records. Existing unrelated workspace work is preserved.

Remaining: owner subjective listening and artwork acceptance; phone speakers,
mono output, real focus/navigation/loop behavior and decode CPU/frame/thermal cost
on device. Automated quality measurements and desktop captures cannot substitute
for that review. No phone installation, full Validate, full physics regression,
backend mutation/deployment, release export, engine/template/ABI optimization or
purchase was performed. APK/library audit pins the concrete local deliverable.

Godot's documented native
[Vorbis stream](https://docs.godotengine.org/en/stable/classes/class_audiostreamoggvorbis.html),
[playback mixing](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayback.html)
and [texture import modes](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)
support the chosen pipeline; empirical quality and packaging results above are
from this repository, not estimates drawn from documentation.
