# Compatible background-music bank: first listening pass

2026-09-25. MUS01/MUS03/MUS06/MUS09/MUS10. The owner rejected both the slow solo and distorted-rock finale, requested independently interchangeable phrase options per race, and emphasized unobtrusive background music. The agreed next step is a small bank plus several auditions **before another runtime replacement**. Production remains v6; this isolated bank is version 1 and is not exported into the game.

## Listen

Each preview lasts 30 seconds at 128 BPM: 0-7.5 s opening, 7.5-15 s chord/bass support, 15-22.5 s full arrangement, 22.5-30 s opening again. The final section demonstrates removal of layers, not a completed collision-specific melancholic phrase. All files use identical fixed gain; no section or file is independently normalized. The offline audition applies one constant 3x gain to the core's conservative mix. No proposed runtime bus gain is established by that choice.

| Preview | Melody / answer / accompaniment / bass / drums | RMS / peak dBFS |
|---|---|---|
| [A](evidence/music-bank/combination-a.wav) | 0 / 0 / 0 / 0 / 0 | -27.35 / -9.20 |
| [B](evidence/music-bank/combination-b.wav) | 1 / 1 / 1 / 1 / 1 | -26.90 / -9.40 |
| [C](evidence/music-bank/combination-c.wav) | 2 / 2 / 2 / 2 / 2 | -26.57 / -9.38 |
| [D](evidence/music-bank/combination-d.wav) | 0 / 1 / 2 / 2 / 1 | -26.81 / -9.22 |

A and D share their opening melody but combine it with different supporting parts. This isolates the value of interchangeability from simply replacing an entire tune. These are musical candidates, not approved production sound; I have not listened to or assessed their timbre acoustically.

## Composition contract

Three authored variants for each of five roles give **243 combinations**. All use one D-major-context progression: D / Bm / G / A, one bar each, in 4/4. No part chooses its own chord progression or key. Foreground notes use current-chord tones and a restrained register (melody G3-A4 across the progression). Two-bar rhythmic patterns repeat against the four-bar harmony. Melody occupies the first half of each bar; answers occupy the second half, with short gates/releases and at least two sixteenth-note steps between foreground events. This allows every option to combine structurally without conflicting chord timelines or foreground overlaps. It does not prove every combination is equally attractive to listeners.

The opening uses short, rounded, softly attacked electric-key-style notes rather than a sustained organ-like line. Accompaniment is quiet, low-voiced chord support; bass remains central. Kick/snare/hats are restrained, without fills, impacts or open-hat splashes. The answer is quieter than the opening melody. There is no distorted guitar, metallic FM lead, bright saw or large reverb. Fuller texture comes from complementary roles, not a foreground solo or a master-volume boost. Tone and repetition fatigue still require ear review, especially against engine and tyre sounds.

## Code and eventual race integration

`native/music/modular_bank.hpp`: pattern tables, immutable `Selection`, fixed-pool synth and sample-clock sequencer. `native/music/audition_bank.cpp`: exhaustive checks and offline WAV renderer. These files are outside Godot's export root. No gameplay/audio-controller or vehicle-handling changes were made.

Selection IDs 0-242 encode all role choices in base three. The constructor chooses once; intensity only gates the chosen roles on bar boundaries. For later runtime integration, choose an ID at race start outside canonical simulation, retain it through laps, and save the full seed/selection alongside bank version for replay. Randomness must not reshuffle phrases while driving. This intentionally supersedes identical per-track arrangements while preserving reproducibility for a saved race seed. The current preview tool explicitly takes an ID; random race-start selection is **not yet wired into Godot**.

Future approved integration should use the existing clean-speed progression to reveal these roles and collision recovery to remove them; a recovery-specific phrase can then be authored within the same harmonic contract. Track character can influence the selection distribution without changing compatibility. No BPM/key roulette per part. Production v6 and its previous rejected sound remain unchanged pending this listening pass.

DSP uses 24 reusable voices, additive band-limited harmonic sums, lookup-table oscillators, smoothed attacks/releases and a conservative bounded mix. No allocations during render, locks, runtime services or recorded samples. Coefficients currently target the 48 kHz auditions; multi-rate acoustic matching and mobile callback profiling are future integration work, not claimed complete here.

## Actual verification

Commands:

```powershell
C:/msys64/mingw64/bin/g++.exe -std=c++17 -O2 -static native/music/audition_bank.cpp -o build/audition-bank.exe
./build/audition-bank.exe
./build/audition-bank.exe docs/evidence/music-bank/combination-a.wav 0
./build/audition-bank.exe docs/evidence/music-bank/combination-b.wav 121
./build/audition-bank.exe docs/evidence/music-bank/combination-c.wav 242
./build/audition-bank.exe docs/evidence/music-bank/combination-d.wav 156
```

Pass: all 243 combinations rendered through a full four-bar harmony at 24 kHz; finite/bounded/non-silent output, render allocation guard, distinct PCM hashes, common chord-tone and foreground-slot contracts. Peak 10/24 active voices, largest core sample .115820. Additional 48 kHz checks verify exact repeated-seed PCM, solo-only start, and bar-aligned full/solo changes. All four 48 kHz stereo WAVs rendered with finite/peak assertions; levels above and raw logs are retained under `docs/evidence/music-bank`.

No UI change, screenshot, Godot rebuild, Android export, installation or physical-device test was performed: this is an offline composition/DSP review slice. No new dependencies, runtime AI or external services. Human acceptance remains the decisive gate for instrument character, liveliness without irritation, background balance, and variation quality.
