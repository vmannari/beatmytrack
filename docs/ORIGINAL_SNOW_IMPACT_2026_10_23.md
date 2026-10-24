# Original snow impact options - 2026-10-23

OSI01-OSI03/R01/Q01 implement the owner's request for original versions of a stronger snow impact. Three short recorded-snow composites are available: packed snow, powder drop and heavy bank. Packed snow is installed as `snow_hit.wav`. [Listen to the comparison](evidence/original-snow-impact-2026-10-23/comparison.wav): two hits each, in the order **previous, packed, powder, heavy bank**. [The listening page](evidence/original-snow-impact-2026-10-23/review.html) also offers individual clips and the actual bank-driving mix.

The supplied Soundsnap search identifies heavy snow-drop/impact recordings by InspectorJ. Its player returned unusable identical clips in these tools; no claim to have heard or matched those recordings is made. These originals use only the existing cleared Nox Sound Design CC0 snow sources, without any Soundsnap sample or copied waveform. The previous licensed-source dependency is superseded for this approach; using the actual Soundsnap recordings would still require their licensed originals.

## Sound and measured result

The installed version layers the existing recorded snow landing, a separately slowed 50-580 Hz body from that landing and recorded hard-snow crumble. Each layer is aligned at its compression peak. Rounded density control and short fades add weight without a longer approach or a clipped master. The powder option adds softer recorded snow detail; heavy bank uses a slower, deeper recorded body and longer settling tail. No synthetic noise or tones are added.

| Version | Length | Strong onset | First 100 ms vs previous | Recorded body, first 150 ms vs previous |
| --- | ---: | ---: | ---: | ---: |
| Previous | 0.28 s | 0.590 ms | Reference | Reference |
| Packed, installed | 0.34 s | 0.204 ms | +2.31 dB | +2.37 dB |
| Powder | 0.38 s | 0.544 ms | +2.30 dB | +1.79 dB |
| Heavy bank | 0.42 s | 0.181 ms | +3.85 dB | +4.31 dB |

These are RMS comparisons, not a subjective loudness certification. An actual desktop capture through the same event pool at 0.65 gain/0.90 pitch, Vehicle compressor and Master limiter confirms **+2.33 dB** for the installed first 100 ms. Peak stays below 0.557 full scale, and every audition settles to exact silence. Asset peaks remain below 0.87 full scale. The strong attack stays below the existing 5 ms limit; no output-buffer change is introduced.

Continuous `snow.wav` is byte-exact, SHA-256 `2feec7c52d56ceb6f5a0d2e45de1afb2577dc0485f643225e5ab1a85bfe498b9`. Contact detection, cue gain/pitch, physics, cooldowns, bus settings, cache/voice bounds and native libraries are unchanged. Fresh native regressions load the new PCM through the existing five-sample/four-slot adapter. Android retains normal playback of the same portable 44.1 kHz mono 16-bit WAV.

## Files and commands

- `scripts/build_snow_audio.py`: original recorded layering, reproducible variant generation and revision-3 manifest; `--impact-variant packed|powder|bank` selects the installed entry. The default is packed. Alternatives are authored outputs, not new game settings.
- `game/assets/audio/vehicles/snow_hit.wav`, `snow_manifest.json`, vehicle NOTICE and `licenses/ASSETS.md`: derivative and provenance update. The four original source hashes remain pinned. No runtime library or source download is added.
- `game/tests/capture_original_snow_impact.gd` and UID, `scripts/review_original_snow_impact.py`: actual equal-gain/equal-pitch mastered auditions and meaningful strength, attack, source, silence and driving-mix checks.
- This report, the source-selection follow-up, status/plan/AGENTS, raw auditions, source fingerprints and a scoped Git-checkable patch. Concurrent work remains preserved.

Actual engine commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, pinned `4.7.2.stable.official.ed1daf0bf`. The evidence report retains exact command variants and selected logs.

| Actual command/check | Result |
| --- | --- |
| `python scripts/build_snow_audio.py` | Three originals and the installed packed entry generated. A repeat build gives identical installed WAV/manifest hashes. |
| `... -Action Import -RenderingMethod gl_compatibility` | Import passes. |
| `capture_original_snow_impact.gd -Graphical -RenderingMethod gl_compatibility` | 13 meaningful checks, zero failures; previous/three new cues captured with the same runtime event processing. An earlier 17-check capture additionally contained four redundant fresh-state comparisons; those were removed before the final capture. |
| `test_snow_bank_audio.gd` headless | 89 checks, zero failures; all cars, exact driving, first contact, continuous push and lifecycle. |
| `test_snow_audio_response.gd` headless / Compatibility / desktop Mobile | 29 / 35 / 35 checks, zero failures; strong attack, actual route, old-DLL fallback and unchanged bounds. |
| `test_windows_impact_audio.gd`, Compatibility | 18 checks, zero failures. |
| `capture_snow_bank_audio.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --output-dir=res://../docs/evidence/original-snow-impact-2026-10-23/driving` | Six checks, zero failures; actual bank entry, sustained/side/reverse contact, departure, stop and pause captured. |
| `python scripts/review_original_snow_impact.py` | 34 checks, zero failures; +2.33 dB mastered entry, exact continuous asset, no clipping, unwanted surfaces or snow during clear ice/departure/pause. |
| `test_script_parse.gd` | 1030 scripts, zero failures at the recorded scan. |
| Scoped whitespace/source/patch checks | Actual results are in `checkpoint.json`. |

## Acceptance and provenance

The sound character is ready for owner review; it is not claimed to be an auditory match to the unavailable Soundsnap previews. Restart the game to replace cached samples. No running owner editor/game was terminated, and no native binary was rebuilt. Owner/physical-device listening remains. No phone/tablet attachment check, physical-device test, APK/export/install, account/backend mutation, purchase or deployment was performed. The scoped checkpoint excludes unrelated dirty work and does not commit the shared index.
