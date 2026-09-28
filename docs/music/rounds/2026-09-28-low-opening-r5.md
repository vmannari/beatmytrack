# R5 — replace the rejected high acoustic motif

Requirements: MUS03/MUS06/MUS09/MUS10/V03/V05/Q01. Focused standalone audition revision.

Owner feedback: “The acoustic motif is horrible, don't use anything like that. It has too high note, too brief and disturbing.” This explicitly rejects the R3/R4 opening, not just its volume or one variant. Do not reuse its high, short plucked pattern. No approval of the other instruments is inferred.

## Revision

Replaced all three opening alternatives with low, sustained sampled cello, MIDI D3–A3 (50–57), four note events per eight-bar phrase. Each note is held for 6.8 beats: 3.4 seconds at fixed 120 BPM and 2.72 seconds at the fastest 150 BPM. The attack is eased over 250 ms, the end over 400 ms, and a smooth 1.4 kHz low-pass reduces upper harmonics. All notes remain chord tones within their harmonic section. The opening now supplies a low foundation; the upper organ answer is separated by register instead of requiring a short opening note window.

The three alternatives use different low contours within the same long-note approach. Fixed and evolving modes receive the replacement, including every 90/102/114/126/138/150 BPM render. Existing choices remain once-per-drive. Other instruments retain their exact source score and performance, with a shared 0.85 level multiplier to reserve headroom for sustained notes occupying previously silent gaps. Their relative balance remains unchanged. All renders retain the existing <0.681 all-choice/subset sample-peak bound.

**Revised · New drive** loads the new fixed bank; **Evolving tempo · same score** uses its matching tempo bank. The rejected program-24 opening is excluded from the active catalog, including all old tempo versions. Source audio is retained on disk. Saved setups containing retired recordings report that a revised drive is needed instead of suggesting an impossible re-import. Browser tabs need a refresh to receive the updated catalog/UI.

## Files and provenance

- `tools/music_generator/refine_opening.py`: renders only the 21 new opening files, reuses backing performances, writes fresh fixed/tempo banks and manifests. Source WAVs, scores and raw renders are preserved.
- `additive_bank.py`, `tempo_bank.py`: future generation uses the revised low score and softening rather than resurrecting the rejected figure.
- `serve.py`: excludes rejected acoustic opening jobs from the catalog.
- `ui/app.js`, `ui/index.html`: revised opening labels and retired-setup message.
- `test_opening.py`, `test_additive.py`: actual opening-specific validation and updated register-separation contract.
- `docs/evidence/music-r5/`: fixed/tempo manifests, opening analysis, export/browser results and desktop/compact screenshots.

New local banks: `build/music/additive/shared-road-r3-20260928-051230-8f1afd-r5/` and `build/music/tempo/evolving-r4-20260928-051230-8f1afd-r5/`. Family IDs remain unchanged for workbench compatibility; manifests identify `opening_revision: low_hold_r5`. GeneralUser GS cello program 42 and the existing pinned TinySoundFont renderer are used; no artist source audio or new dependency. Source/input hashes and inherited license information are retained in the manifests and bank directories. GeneralUser's historical sample-provenance caveat remains a shipping review item, as recorded in R3/R4.

## Actual commands and results

```text
python tools/music_generator/refine_opening.py
  PASS: revised banks generated. Initial unchanged-backing attempt exceeded the
  established bound (0.7225); overly conservative lead attenuation then proved
  too quiet. Final version reserves backing headroom with a shared 0.85 gain,
  retains the original peak limit and passes an explicit opening audibility check.
python tools/music_generator/test_opening.py
  PASS: 9 grouped checks: four notes, low register, long gates, harmony, audible
  RMS, restrained upper spectrum, backing preservation/gain, loops and retirement.
python tools/music_generator/test_additive.py
  PASS: 6 grouped score/export checks.
python tools/music_generator/test_tempo.py
  PASS: 5 grouped tempo/export checks.
.tools/review/Scripts/python.exe tools/music_generator/test_additive_browser.py
  PASS: 15 grouped fixed-mode browser checks.
.tools/review/Scripts/python.exe tools/music_generator/test_tempo_browser.py
  PASS: 19 grouped evolving-mode browser checks.
wsl bash tools/music_generator/scripts/run_from_windows_repo.sh python -m unittest discover -s tools/music_generator -p test_toolkit.py
  PASS: 10 tests, including server/toolkit regressions.
```

Old evidence was preserved; results/screenshots from rerunning fixed/tempo tests were copied into music-r5. The premature quiet revision is marked superseded in its local manifests. New screenshot inspected: revised button, low-cello row and evolving BPM readout visible. New PCM analysis requires RMS >0.005 for every opening, <3% energy above 2 kHz, correct loop lengths and boundary delta <0.002. All pass; these are technical measures, not a claim that the cello sounds good.

No subjective listening claimed. Owner review remains needed for tone, sustain, repetition, mix and transitions at different stages. No Godot/runtime music changes, Android export or phone/device test performed. Existing collision/reset/recovery behavior is unchanged. This is an audition replacement, not a shipping approval.
