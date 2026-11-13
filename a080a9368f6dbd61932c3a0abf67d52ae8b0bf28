# Kart construction review — 2026-10-25

The owner asks to review the current go-kart model after the helmet, body, seat, leg and neck corrections. This is a read-only model review. No production geometry, materials, photos, handling, camera or existing test assertion is changed.

Three findings remain, each P2 (visible construction quality; no canonical gameplay defect identified):

1. **KCR01 — Seat support stays are detached from the bucket.** The two metal struts visible behind the seat still terminate at (+/-0.25, 0.54, 0.55), while the corrected bucket has moved forward. Actual end-rim-to-seat-triangle distances are **0.190843** detailed and **0.191854** simple model metres. This is a real gap in the native batched model, not a shadow. Route the stays to fitted bucket mounts. Source: [kart_model.gd:40](../game/vehicle/kart_model.gd#L40). Evidence: [Compatibility](evidence/kart-construction-review-2026-10-25/gl_compatibility/full-batched-seat-support.png), [Mobile](evidence/kart-construction-review-2026-10-25/mobile/full-batched-seat-support.png).

2. **KCR02 — Helmet underside has visible empty gaps around the neck.** The same low side/rear close-ups show the showroom background through the lower opening. The shell has an open annular lining strip, with a narrower balaclava beneath it. Fit a dark opaque inner head/lining around the wearer while retaining the outer shell and shorter-neck pose. Source: [kart_helmet.gd:124](../game/vehicle/kart_helmet.gd#L124), [kart_driver.gd:74](../game/vehicle/kart_driver.gd#L74). Evidence: [native underside in context](evidence/kart-construction-review-2026-10-25/mobile/full-batched-seat-support.png). This is a visual observation; no numerical head-closure test is claimed.

3. **KCR03 — Shoulder/hip joins still look like separate intersecting cloth pieces.** The sleeve and trouser patches have open root rings. In each detailed sleeve 13/24 root samples fall outside the torso; each trouser root has 19/24. Maximum rim-to-torso distances are **0.04498/0.03675** model metres. The simpler model gives 7/12 and 9/12, with **0.04544/0.03822** distances. Shoulder close-ups show abrupt edges and an angular shoulder transition. Blend fitted shared seam rings or join topology while preserving the corrected limb lengths and control/seat fit. Source: [kart_driver.gd:85](../game/vehicle/kart_driver.gd#L85), [sleeves:91](../game/vehicle/kart_driver.gd#L91). Evidence: [detailed shoulder](evidence/kart-construction-review-2026-10-25/gl_compatibility/full-shoulder-front.png), [simple shoulder](evidence/kart-construction-review-2026-10-25/mobile/simple-shoulder-front.png), [rear/batched shoulder](evidence/kart-construction-review-2026-10-25/gl_compatibility/full-batched-shoulder.png). Sidepods and the seat conceal parts of the trouser rims; outside-torso counts alone do not prove every sample is visible.

The helmet/neck and leg/torso corrections now give a more coherent seated silhouette. The main next work is attachment and seam construction. The most recent actual Garage/race and overhead captures were inspected alongside front/rear/top/side images, and their kart source/assets still match. No new wheel/nose, engine/tyre, exhaust-clamp or sleeve-piping regression was identified from the reviewed images. This is not a universal absence-of-intersections or device-performance claim.

`game/tests/review_kart_model.gd` is a new read-only diagnostic. It loads the actual prepared detailed and racing geometry, finds stays by their cached mesh identity, measures tube end vertices against seat triangles, and checks cloth root rings against the torso. Its diagnostic cameras are separate from production cameras. It saves original and production-batched close-ups; no part is hidden in the evidence images. Each renderer saves sixteen images. Both renderer measurements agree exactly. Measurements are in unscaled model metres, not real-world dimensions. The visible triangle budgets remain 93,520/28,706.

Actual commands use pinned Godot 4.7.2 through scripts/dev.ps1, isolated APPDATA/LOCALAPPDATA under build/kart-construction-review, and approved native Windows certificate-store access:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-construction-review-2026-10-25/run.ps1 -Job review
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-construction-review-2026-10-25/run.ps1 -Job review -Renderer mobile
python docs/evidence/kart-construction-review-2026-10-25/finalize.py
```

The review scripts compile and execute successfully in both renderers. Their zero process exits mean that the diagnostics ran, not that the model is free of findings. Existing regression results are the preceding short-neck report's fit32/proportions24/model86+86/retained172/Garage-race15+15/kart42/parser1184; they were **not rerun in this review**. Exact current source/asset hashes and manifest pins confirm the reviewed geometry matches that prior evidence. The current review adds checks for construction areas those suites do not cover. No assertion is relaxed.

[report.json](evidence/kart-construction-review-2026-10-25/report.json) records the findings, actual source hashes, measurements and a diagnostic/document-only isolated Git checkpoint. Its patch passes whitespace and reverse-application checks and leaves the normal index untouched. The model and photos remain unchanged; corrective work is pending.

No device attachment check/test, APK, real authentication/purchase, live mutation/deployment or owner-process restart was performed. Desktop Mobile is a desktop Vulkan renderer test. Owner/device visual and motion/cost acceptance remain.
