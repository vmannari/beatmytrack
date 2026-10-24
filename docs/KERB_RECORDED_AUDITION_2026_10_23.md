# Recorded kerb audition — 2026-10-23

KRP01/KRP02/Q01: the owner still rejects the kerb effect's sound quality after
the volume-only correction and synthesized tyre/body revision. This turn prepares
recorded alternatives for direction review. It does not install another guess
into the game or claim subjective sound-quality acceptance.

Source: [rumble strip exit 41.wav by bsumusictech](https://freesound.org/people/bsumusictech/sounds/62652/).
The recordist describes leaving I69 using a Zoom recorder. The original source
page explicitly lists CC0. Its public HQ MP3 preview is decoded to 44.1 kHz mono
PCM; the original WAV requires sign-in and was not downloaded. This is a new
source, distinct from the previously rejected sengjinn pass-by recording.

Two six-second edits retain the actual recorded tyre vibration from 4–10 seconds:

- [A — fuller natural rumble](evidence/kerb-recorded-audition-2026-10-23/A-natural.wav): restrained background reduction and broad 55–6500 Hz EQ.
- [B — closer tyre detail](evidence/kerb-recorded-audition-2026-10-23/B-close.wav): 120–5800 Hz EQ and a broad midrange emphasis.

Both retain the recorded timing and phase; no generated tones, repeated authored
thud train or added noise. Short boundary fades prevent audition cut clicks.
Measured loudness is −18.50/−18.51 LUFS; peaks 0.3377/0.4982. Those checks verify
format, headroom and a fair comparison, not whether the sound feels right.

Actual commands/outcomes:

| Command | Result |
| --- | --- |
| Public Freesound search/source-page requests | Located sound62652; retained primary HTML and CC0 notice. Pixabay download page returned a browser challenge and was not used. |
| `Invoke-WebRequest -UseBasicParsing -Uri 'https://cdn.freesound.org/previews/62/62652_791247-hq.mp3' -OutFile build/kerb-recorded-2026-10-23/exit41-source.mp3` | Public preview downloaded; no login/account use. |
| Existing WSL FFmpeg, `-nostdin -v error -y -i .../exit41-source.mp3 -ac 1 -ar 44100 -c:a pcm_s16le .../exit41-source.wav` | 16.6139 seconds decoded. |
| `python scripts/prepare_kerb_recorded_audition.py --source build/kerb-recorded-2026-10-23/exit41-source.wav --source-page build/kerb-recorded-2026-10-23/exit41-source.html --output docs/evidence/kerb-recorded-audition-2026-10-23 --wsl-ffmpeg /home/ville/.local/share/bmt-music-tools/ffmpeg` | Two recorded auditions; actual FFmpeg loudness/headroom assertions pass. |
| `python -m py_compile scripts/prepare_kerb_recorded_audition.py` | Exit0. |

Changed files are the new offline preparation script, this receipt and its evidence
folder. Input MP3/PCM/primary HTML remain under `build/kerb-recorded-2026-10-23/`;
source/preview hashes are in the evidence receipt. Runtime code, assets, manifests
and saved player/account data are not changed by this turn. No game regression
suite is reported as run; these files are preview-only and outside exports.

Remaining: identify whether the rejected sound was heard in a restarted local PC
client or the installed phone build; no updated phone build has been installed by
this conversation. Owner choice/reference is needed to settle sound character
before integration and in-context testing. The async questions cover both items.
No phone attachment check/device test, APK/export/install, backend/account mutation,
deployment or paid asset purchase was performed.

## Owner correction: kerb impacts

The owner rejected both Exit41 edits as steady noise and clarified that a rumble
strip differs from the intended kerbs. Those options are rejected; they were not
integrated. KIP01/KIP02/Q01 now prepares a seven-second impact-direction preview.

Source: [Driving.wav by acarney2019](https://freesound.org/people/acarney2019/sounds/489431/),
a CC0 recording described by its author as a car driving and hitting a bump.
It is car-bump foley, not a claimed circuit-kerb field recording. The primary
HTML and public HQ MP3/mono decode are retained in build/kerb-impacts-2026-10-23.
Six short recorded transients are cut around their attacks with tapered tails.
The preview has three front/rear impact pairs, then a short uneven contact run,
with exact quiet gaps and no rolling/noise bed. Timing is illustrative.

Actual command: python scripts/prepare_kerb_impact_audition.py --source build/kerb-impacts-2026-10-23/car-bump.wav --source-page build/kerb-impacts-2026-10-23/car-bump-page.html --output docs/evidence/kerb-impact-audition-2026-10-23 produces 7 seconds/14 recorded hits; finite/headroom/quiet-gap assertions pass. python -m py_compile scripts/prepare_kerb_impact_audition.py exits0.

[Impact preview](evidence/kerb-impact-audition-2026-10-23/kerb-impacts.wav).
Changed files: this receipt, the new offline preparation script and its evidence
folder. No game code, audio bank, loops or player/account data changed; no game
regression suite is claimed. Source/cut/event/output hashes are in source.json.
Remaining: owner review of impact character, then actual wheel/contact-driven
integration and testing. No phone attachment check/device test, APK, deployment,
paid asset purchase or backend mutation.
