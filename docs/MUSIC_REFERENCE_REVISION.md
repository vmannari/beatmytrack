# Reference-led music audition, 2026-09-25

## Revision 4: Peer Günt “Backseat” direction

The owner named **Peer Günt, “Backseat”** as the musical inspiration. This supersedes the attempted synth/keyboard palette for the next listening candidate. The working brief is a low-register riff-led hard-rock instrumental: distorted rhythm guitar, bass following the riff, and dry backbeat drums, with no exposed upper synth melody. Reference identity verified through [Apple Music](https://music.apple.com/us/song/252143243); [Songsterr's instrument listing](https://www.songsterr.com/a/wsa/peer-gunt-backseat-tab-s78211) identifies distortion guitar. Neither page provides verified listening access here; this is a style interpretation, not a claim to have listened to the recording. No lyric, riff transcription, melody, sample or recording from the song is used.

[Original rock-direction audition, 15 seconds](evidence/music-reference/revision-04-rock.wav). Eight bars at **128 BPM** (chosen within the original game range, not claimed as the reference's tempo), with a new E-minor/blues power-chord rhythm. Synthetic damped string delay lines feed a two-times-oversampled saturator and cabinet filter. Two lightly detuned rhythm parts occupy the sides; additive bass and synthetic kick/snare/hat remain central. There is no pad, high synth lead or metallic pluck layer.

Changed files: `native/music/rock_audition.cpp`, this brief, status/phase notes, WAV/JSON/test log under `docs/evidence/music-reference`. This is an isolated offline sound prototype, **not integrated into the game**; it has no gameplay-state controls yet. Production engine remains v1. MUS01/MUS03/MUS09 apply; acceptance of the earlier proposed signature pluck is superseded by this listening direction, not presumed granted to the new guitar tone.

Actual commands:

```powershell
g++ -std=c++17 -O2 -static native/music/rock_audition.cpp -o build/rock-audition.exe
./build/rock-audition.exe docs/evidence/music-reference/revision-04-rock.wav
python scripts/analyze_music_reference.py docs/evidence/music-reference/revision-04-rock.wav docs/evidence/music-reference/revision-04-rock.json
```

Actual checks: two independent synthesizers produce identical stereo samples across 15 seconds; all samples are finite and bounded; output is non-silent; peak 12 of 24 string voices. Offline normalization gives -18 dBFS RMS and -8.02 dBFS peak. Logs/measurement JSON are retained. Allocation tracing, mobile callback profiling, long-running drift, game integration and listening acceptance are not claimed for this separate prototype. No UI change/screenshot, Android export, installation or phone test; attachment not rechecked. The next acceptance question is whether the guitar/drum timbre is suitable, before expanding the arrangement or replacing runtime instruments.

## Revision 3: rejected upper instrument

The owner also rejected revision 2's instrument sound, especially the higher-frequency part. Revision 2 remains evidence of a rejected direction, not an accepted score. The current offline candidate removes its upper lead register, pluck answers, tension ostinato and repeating lead delay. The replacement moves the foreground down an octave, uses a short, softly attacked detuned band-limited waveform with two-pole 750 Hz damping, and reduces hat/snare brightness. This is an intended muted midrange keyboard character, not a verified listening description.

- [Backing only, 8 seconds](evidence/music-reference/revision-03-backing.wav).
- [Same backing with replacement midrange instrument, 8 seconds](evidence/music-reference/revision-03-warm.wav).

Both use 120 BPM and exactly the same offline gain (1.8); removing the melody does not normalize the backing louder. Measured RMS is -18.59 / -18.40 dBFS, with peaks -7.99 / -7.91 dBFS. Production engine v1 remains unchanged. The candidate's internal version is now 3; `audition_v2.hpp` retains its path to keep the experiment isolated from shipping code.

Actual commands: compile `test_synth.cpp` with `-DBMT_REFERENCE_AUDITION`, run `build/music-reference-tests.exe`; compile `render_audition.cpp`; render `revision-03-backing.wav 120 backing` and `revision-03-warm.wav 120 warm`; analyze both through `scripts/analyze_music_reference.py`. Native determinism, allocation guard, output bounds, clock, pause/finish, bar scheduling and hysteresis pass (11 peak voices). Preview peaks are 8/9 voices. See `native-tests-v3.log` and the matching JSON files. No game UI change, Android build, installation or device test. Phone attachment was not checked this turn. Timbre/ear acceptance remains unresolved; numeric tests do not approve the sound.

The owner rejected the first soundtrack's instruments, melody and composition as a whole, and supplied `wizard-f3b25f658f06473f9b1f60ee300f461e-00-TRACK_01-audio_base64-3a7322c1aac3bea2.wav` from Downloads as a closer reference. This is a replacement sound/composition audition for MUS01/MUS03/MUS09, not a claim that the original Grass score is accepted.

## Reviewable result

- [120 BPM, 32 seconds](evidence/music-reference/revision-02-120bpm.wav): reference-tempo audition.
- [128 BPM, 30 seconds](evidence/music-reference/revision-02-128bpm.wav): same original composition inside the original 128–135 BPM range.

Both are 16 bars of new local synthesis: lighter opening, main phrase, restrained technical passage, release. They are normalized offline to -18 dBFS RMS for useful audition volume, with peaks below -6.8 dBFS. That normalization does not run in the audio callback. These are finite previews with a short ending fade, not new prerecorded shipping songs.

**The game build still uses engine v1.** The new candidate is isolated in `native/music/audition_v2.hpp`; `extension.cpp` still includes `synth.hpp`. No Android export, installation or phone test was performed for this audition. An Android device was attached in the preceding music task; its connection was not rechecked in this audition. The next useful acceptance check is the owner's listening judgment before integrating another palette they may reject. No audible-match or final-quality claim is made from numeric analysis.

## What changed in the candidate

- One D-natural-minor tonal centre and explicit voice-led Dm7 / Bbmaj7 / Fadd9 / Cadd9 harmony. The motif stays in the key instead of transposing wholesale with each root.
- A six-note repeating lead phrase with restrained endings, fewer overlapping lead/pluck gestures and a secondary pluck response.
- Explicit note gates/releases. The old pad used a 1.6-second exponential time constant with a very long lifetime, allowing old chords to overlap subsequent harmonies. The candidate releases each chord before the next; no discarded voice is allowed to ring indefinitely through chord changes.
- Richer bass octave/harmonics, filtered band-limited saw pads, a rounded lead, less metallic pluck, controlled snare and hats, and a shorter kick.
- Delay receives only lead/pluck, preventing kick and bass echoes from clouding the low end. No full-song samples or reference audio are used.
- Same fixed 32-voice budget, sample-based scheduling and lock-free control model. Candidate synthesis version is 2; production seed/version remains 1 until integration.

## Evidence and limits

The supplied WAV is 80 seconds, 44.1 kHz, 16-bit dual-mono. Local onset autocorrelation strongly suggests 120 BPM; this is an estimate, not supplied metadata. Spectral inspection suggests root changes every four seconds/two bars. It cannot establish the intended instrumentation or subjective feel. The tools available in this session did not provide reliable direct listening access, which was disclosed to the owner.

The reference has approximately 50.7% spectral power at 20–150 Hz and 39.9% at 150–500 Hz. The rejected render measured 79.8% / 11.5%; the 120 BPM candidate measures 53.4% / 37.7%. This supports the specific change toward low-mid body, not a claim of musical equivalence. Pitch/genre inference from broadband measurements is deliberately not used as acceptance. The provided file is kept outside the repository/export; its rights are not assumed.

Files: `native/music/audition_v2.hpp` (candidate DSP and composition), `native/music/render_audition.cpp` (offline WAV renderer), `native/music/test_synth.cpp` (optional candidate test include), `scripts/analyze_music_reference.py` (local measurement utility), and `docs/evidence/music-reference/` (WAVs, measurements, native test log). Production gameplay, camera, track mapping, native binaries and Grass configuration are unchanged.

Actual commands:

```powershell
g++ -std=c++17 -O2 -static -DBMT_REFERENCE_AUDITION native/music/test_synth.cpp -o build/music-reference-tests.exe
./build/music-reference-tests.exe
g++ -std=c++17 -O2 -static native/music/render_audition.cpp -o build/render-music-audition.exe
./build/render-music-audition.exe docs/evidence/music-reference/revision-02-120bpm.wav 120
./build/render-music-audition.exe docs/evidence/music-reference/revision-02-128bpm.wav 128
python scripts/analyze_music_reference.py docs/evidence/music-reference/revision-02-120bpm.wav docs/evidence/music-reference/revision-02-120bpm.json
python scripts/analyze_music_reference.py docs/evidence/music-reference/revision-02-128bpm.wav docs/evidence/music-reference/revision-02-128bpm.json
```

Native tests passed: seeded PCM determinism, different-seed divergence, render allocation guard, finite output/gain bounds, clock duration, pause, finish fade, bar scheduling and hysteresis. Peak 13 voices in the test; 12/13 in the auditions. The three concurrent 60-second test renders took 1.971 seconds offline on this desktop. This is not a measured real-time/phone deadline guarantee. No UI changes, so no screenshot is required. Acceptance remains entirely open for timbre, melody, arrangement, reference similarity and repeated-lap enjoyment.
