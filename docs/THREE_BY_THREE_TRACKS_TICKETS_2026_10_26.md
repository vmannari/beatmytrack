# 3×3 challenge picture: three tracks and three tickets

The owner requested a clearer 3×3 challenge picture showing three tracks and three tickets. TT01–TT03 replace the previous repeated car-at-start scenes with three complete, separate circuit dioramas—pine forest, compacted-sand desert and snowy alpine—and three individually visible ivory racing tickets. The illustration retains the existing cel-shaded style and has no baked-in text or branding.

The built-in image_gen tool created `game/assets/menu/challenges/three-by-three-v7.png` from the previous project-generated v6 poster. The exact prompt, reference, provider output, source hash and visual review are in [the asset provenance](../game/assets/menu/challenges/three-by-three-tracks-tickets-v7.json). The source is 1254×1254; the lossless runtime import retains the existing 1024-pixel limit and mipmaps.

The only runtime code change is the `three` entry in `ChallengeCreate.POSTERS`. The existing whole-image fit, selection states, captions and responsive card layout are retained. Tickets are an illustration of the existing three tries; this adds no ticket economy, purchase or race restriction. The depicted circuits are illustrative rather than the challenge's selected tracks. The previous image and both other format posters remain available.

Validation used the pinned Godot 4.7.2 build through `scripts/dev.ps1` and isolated workspace fixture data. Final focused captures reuse the existing format-page assertions from `test_challenge_cards.gd`, stopping before track/car steps: **39 checks, zero failures in Compatibility; 39 checks, zero failures in desktop Mobile/Vulkan**. Native captures cover 1280×720, 1440×900, 960×540, 390×844 and 844×390, including the selected 3×3 card scrolled fully into view. This focused subset does not replace the broader suite.

The full retained challenge-card suite reports **302 checks, 19 failures**, concerning carousel edge motion and forklift/electric hero synchronization. Repeating the same suite with the previous v6 texture substituted only in fixture memory reproduces the exact same 19 failure messages. Neither the assertions nor the car/carousel code were changed. Initial restricted executions failed on PowerShell policy, Windows certificate-store access or the default user log path; those interruptions are retained, with subsequent native runs using workspace fixture data and the required Windows access. The final pinned import succeeds.

Evidence, source snapshots, actual logs/commands, the archived capture scripts, matched previous-poster failure output and the reverse-checked production patch are in [report.json](evidence/three-by-three-tracks-tickets-2026-10-26/report.json). The runner restores archived probes temporarily and removes its own copy after execution:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-tracks-tickets-2026-10-26/run.ps1 -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-tracks-tickets-2026-10-26/run.ps1 -Probe poster -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-tracks-tickets-2026-10-26/run.ps1 -Probe poster -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-tracks-tickets-2026-10-26/run.ps1 -Probe previous -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-tracks-tickets-2026-10-26/run.ps1 -Import
```

The full-suite and import runner commands were run; the report preserves the exact direct commands for the focused and previous-picture captures. The equivalent probe-runner forms above are repeat instructions.

Reload/reopen challenge creation to see the picture. Owner appearance and physical-device readability remain acceptance checks. Device attachment was not checked and no device test was performed. No APK, live account/service mutation, deployment, Git staging/commit/merge or owner-process restart was performed. Concurrent work is preserved.
