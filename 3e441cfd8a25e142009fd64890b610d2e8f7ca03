# Kart construction fixes — 2026-10-25

The owner asks to fix all three findings in the preceding review. KCF01-KCF03 / KCR01-KCR03 / V02-V05 / R01 / G01 / Q01 close those specific findings.

| Finding | Correction and validation |
| --- | --- |
| KCF01 / KCR01 — detached seat stays | Derive attachment positions and frames from the actual bucket's surface/normal, place closed shaped pads and fasteners, and route both stays from the existing chassis rails into those pads. The old end-rim-to-seat gap of about 0.191 model metres becomes 0.00393 detailed / at most 0.00593 simple, with the pad filling that small offset. Actual end-to-bucket rays pass, and both pads and stays are present. |
| KCF02 / KCR02 — see-through helmet underside | Reform the existing dark lining from the lower binding's actual inner edge to a small neck opening tucked inside the balaclava. All nine lower sight-line rays meet opaque liner/neck geometry before the upper shell. External helmet geometry, visor, hardware, short chin and lowered head pose remain exact. |
| KCF03 / KCR03 — open/angular suit joins | Remove four matching patches from the torso grid and form shared shoulder/hip boundary rings. Hermite transitions meet the existing limb surfaces with shared positions and normals. End caps close the hidden wrist/ankle and torso ends. The complete core suit has **zero unmatched edges and zero inconsistent directed edges**, with **96 detailed / 48 simple** shared seam vertices and **0.01875 degrees** maximum normal difference. Distal arms/legs, hands and boots retain their original locations; sleeve trim starts after the new shoulder transition and passes its original actual-surface backing checks. |

The existing driver build interface is preserved. Seat attachment creation is called from the kart chassis builder with its existing metal material; no extra material role, shader, light, frame callback or canonical simulation operation is introduced. Complex seam generation runs only when authoring/baking immutable resources. Production loads the prepared meshes.

Matched native review images:

- [Before supports/helmet underside](evidence/kart-construction-review-2026-10-25/gl_compatibility/full-batched-seat-support.png), [fixed](evidence/kart-construction-fixes-2026-10-25/review/full-batched-seat-support.png).
- [Before shoulder](evidence/kart-construction-review-2026-10-25/gl_compatibility/full-shoulder-front.png), [shared smooth shoulder](evidence/kart-construction-fixes-2026-10-25/review/full-shoulder-front.png), [simple rear shoulder](evidence/kart-construction-fixes-2026-10-25/review-mobile/simple-batched-shoulder.png).
- [Complete revised driver](evidence/kart-construction-fixes-2026-10-25/model/full-driver.png), [side](evidence/kart-construction-fixes-2026-10-25/model/full-driver-side.png), [actual Garage](evidence/kart-construction-fixes-2026-10-25/native/garage-1280.png), [actual race](evidence/kart-construction-fixes-2026-10-25/native/race.png).

Final validation passes **32 construction**, **32 existing fit**, **24 existing proportions**, **86/86** Compatibility/desktop Mobile model, **172 existing mechanical**, **15/15 actual Garage/race**, **42 kart handling**, and **1205** parsed scripts. The previous assertions and tolerances remain unchanged. Original task-start sources reloaded only inside a disposable process give **32 checks / 22 failures**, demonstrating the three defects. Undefined old attachment distances are retained in the raw Godot report as its overflow numeric representation; the summary uses null for missing ray hits.

The first implementation's new cap vertices exposed an auto-generated tangent-array length mismatch; clearing the stale generated tangents corrected it. The added directed-edge audit then caught local triangle flips in the underarm transition. Preserving the tube's global parameter winding and analytic normals corrects all of them without relaxing the audit. The first isolated baseline reload also caught a changed build signature; the original interface is restored and the exact old-source regression now runs. These logs and the original pre-winding images remain in evidence. All 238 prepared mesh binaries are identical across the later interface-preservation refactor. A final bake repins the exact source hashes.

The original review's horizontal torso-ray counters can classify shared seam edges as outside after the torso has real joint openings. Those legacy counters are retained unchanged; they are not a valid closure test for this topology. Their nearest-triangle distances now fall below 0.000063 model metres, while the new independent actual-face edge/normal audit proves the seams close. No old invariant is removed.

Detailed/simple visible triangles are **94,128/29,006**, below the unchanged 95,000 detailed cap. There are **238 prepared meshes**, **210 byte-identical** to task start; fourteen old keys retire, twenty-two new keys are added and six existing binaries change. Original resources and retired keys are archived. The rebuilt body shadow has 1228 triangles; all four wheel shadow binaries are identical. Catalogue/news and all 49 appearance photos are refreshed and imported.

Kart configuration, wheel/pedal/steering positions, engine/exhaust geometry, shared geometry helper and original regression test sources remain exact. Concurrent electric launch/drift work changes the shared simulation/handling and EV configuration; the Garage focus work changes garage_customisation_camera.gd. Their task-start/final hashes and per-command shared-source receipts are recorded, and those changes are preserved and excluded from this checkpoint. A concurrent camera save occurred during an otherwise passing parser run; its original receipt/log are retained as parser-concurrent-save-command.json and parser-concurrent-save.log, and the final parser check is rerun with stable source hashes. Actual Garage/race and handling checks use the current shared sources. No verifier/config rollout or physics claim is made for this visual task.

Changed source files: game/vehicle/kart_model.gd, kart_driver.gd and kart_helmet.gd; a new game/tests/test_kart_construction.gd adds the independent regression. The review diagnostic gains optional evidence-root and unbaked flags to preserve historical captures. Exact file hashes and results are in [report.json](evidence/kart-construction-fixes-2026-10-25/report.json).

Actual commands use pinned Godot 4.7.2 through scripts/dev.ps1, isolated APPDATA/LOCALAPPDATA under build/kart-construction-fixes and approved native Windows access. Job arguments/exit codes and shared-source hashes are saved in *-command.json; logs retain failed attempts:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-construction-fixes-2026-10-25/run.ps1 -Job construction-before
foreach ($job in @('construction-draft','fit-draft','proportions-draft','draft','review-draft','bake','construction','fit','proportions','model','retained','review','art','liveries','news','import','native','handling','parser')) {
    powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-construction-fixes-2026-10-25/run.ps1 -Job $job
}
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-construction-fixes-2026-10-25/run.ps1 -Job model -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-construction-fixes-2026-10-25/run.ps1 -Job review -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-construction-fixes-2026-10-25/run.ps1 -Job native -Renderer mobile
python docs/evidence/kart-construction-fixes-2026-10-25/finalize.py
```

The isolated Git checkpoint compares exact task-start kart sources/assets and current shared documents with only this task block removed. Its binary patch passes whitespace/reverse-application checks; the normal index is untouched and concurrent work is preserved.

Client reload and owner visual acceptance remain. No device attachment check/test, APK build/install, real authentication/purchase, live mutation/deployment or owner-process restart was performed. Desktop Mobile is a desktop Vulkan test; startup hitch logs are retained and no physical-device motion/performance claim is made.
