# Reference-led music audition, 2026-09-25

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
