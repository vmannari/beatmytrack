# Kart driver backrest, wrists and knee clearance — 2026-11-08

The owner identifies three remaining defects: the torso floats away from the backrest, the wrists bend unnaturally, and the knees intersect the centre fairing. KCP01–KCP03 supersede the previous pose. The actual kart seat, steering rim, fairings, pedals, side pods, camera and handling remain unchanged.

| Requirement | Change |
| --- | --- |
| KCP01 — support the torso | Recline 35° → 44°, move the hip reference back from Z −0.065 to +0.021, and add a smooth 22 mm thoracic curve. Horizontal rays independently measure the actual suit rear surface against the actual padded backrest at three heights on both sides. Final sample gaps are −1.62 to +4.85 mm; small negative values represent garment/padding compression, within the final −3/+12 mm support gate. The upright helmet retains its physical size. |
| KCP02 — neutral wrists | Solve the elbow to nine-and-three grip points with the forearm and proximal palm on one axis. Their target bend changes from 27.25° to approximately zero. Subdivide each source glove once before deformation, taper the distal palm and curl the fingers around a 20 mm rim-grip arc. The forearm/palm stays straight; the finger curl starts beyond it. Actual glove/rim vertex distances and close-up native pictures supplement the authoring-axis measurement; no runtime rig or animation is introduced. |
| KCP03 — knees around the beam | Move the knee pole outward, rather than raising the knees into the fairing. Thigh/shin targets are 0.470/0.465 model metres, and knee centres move from approximately ±0.158 to ±0.29. Preserve actual pedal contact. Outward boot orientation, an outsole lip and a 2 mm tangential placement correction also clear the wider fairings without losing the nine-sample sole patch. |

The native mesh contains **8,717 triangles / seven materials**: 6,164 cloth, 1,536 gloves, 401 helmet/face, 72 boots and 544 fitted seam triangles. The dense reconstruction remains an offline intermediate. The existing matte, text-free suit and previously retouched helmet texture remain; no raster asset is newly generated. CC BY 4.0 attribution by tomkart remains in Settings → Licences. This is a pose/fit correction, not a claim of AAA art acceptance.

Review actual native pictures: [backrest](evidence/kart-driver-cockpit-fit-2026-11-08/cached-backrest.png), [wrists](evidence/kart-driver-cockpit-fit-2026-11-08/cached-wrists.png), [knees](evidence/kart-driver-cockpit-fit-2026-11-08/cached-knees.png), [side](evidence/kart-driver-cockpit-fit-2026-11-08/candidate-side-right.png). Final Garage/race captures and cache checks are recorded in the same evidence directory.

## Physical verification

`test_kart_driver_cockpit.gd` independently loads the native driver and the existing kart geometry. It tests all nine hood styles and all nine body styles, factorized because the fairing and pods are independent, in both quality tiers. Bidirectional bounded triangle-edge rays detect actual garment/hand/boot intersections with the centre fairing and both pods. Additional checks keep the driver inboard of the real pod centres, fit the helmet behind the actual seat envelope, and measure back-pad support. The final matrix passes **286/0**; the rejected driver fails **80/286** checks. It does not move or enlarge any vehicle part to obtain clearance.

The existing actual pedal/hand/floor/pan matrix passes **27/0** on the shipping mesh. Both feet cover all nine pedal samples in both tiers at at most **1.017 mm** measured clearance. Full-detail gloves have 47 nearby rim vertices per hand and about 1.98 mm nearest-vertex distance; the reduced rim has 21 vertices per hand within the established 12 mm proximity gate. That is a static grasp check, not an animation claim. Direct native mesh/material/paint/articulation checks pass **63/0**. Driving passes **72/0**, and the current six-car wash fixture passes **54/0 in both tiers**.

The previous 0.65-wide/1.4-deep whole-driver box and “knee above 0.50” assertions were pose proxies, not measurements of cockpit surfaces. The old driver passed them while intersecting the fairing and missing the backrest. The physically seated, splayed pose has a 0.685-wide/1.502-deep envelope, so those proxies are explicitly superseded by the stronger actual shell/support tests. The original 0.65 upper-body width gate remains, with measured upper-body width 0.560. Floor, head-height, normal-finiteness, material, helmet-size, paint and articulation gates remain. `RETIRED_POSE_ENVELOPE` logs the old box result; the original assertions and source are preserved under `before/` rather than silently erased.

Early drafts and failures remain. A simple 50° recline supported the upper back but left a roughly 29 mm lumbar gap; shifting the torso and adding its thoracic curve resolves that without loosening the final support tolerance. Straight fingers initially hit some fairings, so their distal sections now curl around the rim. Exact edge checks exposed toe contact with Enduro/Split/Shield after the sampled knee check already passed. Boot placement is corrected against those actual shells. One splayed sole covered only eight pedal samples; the final correction restores all nine without relaxing the 3 mm gate.

## Sources and reproduction

Authoring: `scripts/prepare_kart_driver.py` plus the existing numpy-only geometry helper. Native bake/review/contact/cache tests and the pinned runner are updated; `test_kart_driver_cockpit.gd` is new. The native driver, body shadow, prepared scenes and pictures are derivatives. Runtime kart/seat/controls builders and canonical physics are not changed. Attribution notes and `licenses/ASSETS.md` record the new adaptation.

```powershell
python scripts/prepare_kart_driver.py docs/evidence/kart-tomkart-driver-2026-11-08/source/race_car_driver_-_low_poly.zip --output build/kart-driver-cockpit-fit-2026-11-08/candidate
python scripts/run_kart_driver_review.py complete-fit-bake res://tests/bake_tomkart_driver.gd --headless -- --preview
python scripts/run_kart_driver_review.py complete-fit-cockpit res://tests/test_kart_driver_cockpit.gd --headless
python scripts/run_kart_driver_review.py baseline-cockpit res://tests/test_kart_driver_cockpit.gd --headless -- --before
python scripts/run_kart_driver_review.py complete-fit-contact res://tests/test_kart_driver_contact.gd --headless
python scripts/run_kart_driver_review.py complete-fit-review res://tests/review_tomkart_driver.gd --rendering-method gl_compatibility
python scripts/run_kart_driver_review.py shipping-bake res://tests/bake_tomkart_driver.gd --headless
python scripts/run_kart_driver_review.py shipping-direct res://tests/test_tomkart_driver.gd --headless
python scripts/run_kart_driver_review.py shipping-cockpit res://tests/test_kart_driver_cockpit.gd --headless -- --shipping
python scripts/run_kart_driver_review.py shipping-contact res://tests/test_kart_driver_contact.gd --headless -- --shipping
python scripts/run_kart_driver_review.py shadow-bake res://tests/bake_kart_model.gd --headless
python build/kart-driver-cockpit-fit-2026-11-08/rebuild.py
```

The exact pinned engine is `4.7.2.stable.official.ed1daf0bf`. The established runner keeps private offline APPDATA/LOCALAPPDATA and Dummy audio, and retains the known Windows certificate-store diagnostic. Its actual commands, logs and exit receipts accompany the evidence. The rebuild helper uses terminating PowerShell errors and the existing identity/source-guard recipes. It rebuilds the shared assemblies after livery pictures change their conservative dependencies. No source guard is weakened.

The source-only checkpoint is compared with this task's saved start and round-trip checked using a separate tiny Git index. The main index and concurrent Super Rally/scenery work remain untouched. No device was queried or tested, no APK/export/deployment was performed, and no owner save/process or backend was changed. Mobile rendering here means desktop Vulkan. Owner appearance acceptance, a reload and device qualification remain; passing geometry checks does not establish final art acceptance or a performance improvement. Final prepared/native/App outcomes are recorded in `final-summary.json`.


## Final integrated result

The shipping matrix passes **286/0 physical cockpit checks**, **27/0 control/floor/pan checks**, and **63/0 direct mesh checks**. Current prepared restoration and source-geometry matching pass **80/0 each desktop renderer**. Actual App Garage/race checks pass **16/0 each**, with Garage geometry matching a fresh construction at 30,325 visible triangles. The full refresh completes **520 fitted modules**, all six Garage templates and the header template; final prepared preflight passes **551 resources / 2,267 checks / zero failures**. All 49 kart livery photographs plus catalogue/news/header/Garage images are refreshed. The final image audit reports **six exact native pictures / 157 current source hashes**.

Additional `cached-*` close-ups explicitly require a real prepared-base hit and the 8,717-triangle driver; they capture the approved simple model with its runtime detail levels. They supplement the raw authoring previews. The native resource is 1,462,667 bytes and its body shadow is 1,323 triangles. The unrelated PNG preservation receipt and four wheel-shadow comparisons are retained. First-use frame hitches remain in the logs; neither these tests nor the new art establish a hardware performance claim. All source-only patch and Python checks are recorded in the checkpoint receipts.
