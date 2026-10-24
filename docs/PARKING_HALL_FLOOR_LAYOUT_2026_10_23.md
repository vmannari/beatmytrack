# Parking hall floor and layout — 2026-10-23

The floor is darker matte concrete with fine visible grain, shallow surface detail and clear 6 × 8 m slab joints. The exit crossing has a dedicated corridor and properly joined yellow borders. The central parking bank belongs to section A.

| Requirement | Delivered behaviour |
| --- | --- |
| PFL01 | Replace the pale/noisy floor with an original, seamless, mipmapped concrete material. Restrained tonal variation, slab joints, roughness and shallow normals keep the floor readable at the normal driving camera. Convert authored pigment for the renderer's colour space. |
| PFL02 | Reserve the 6 m wide stair corridor instead of painting across two parking bays. Zebra stripes remain entirely inside it. The yellow perimeter stripe ends at and joins the walkway borders, leaving the crossing clear. |
| PFL03 | Use unique A01–A34 perimeter labels, A35–A62 central labels and B01–B36 south labels. There are 98 spaces after reserving the two former bays. Complete the bank end/back lines. |
| R01 / G01 / Q01 | Preserve existing driving and unrelated workspace work. Retain commands, initial corrections, native views, source hashes and a scoped Git-checkable patch. |

`parking_hall_data.gd` defines the pedestrian bounds. The visual builder uses those bounds and records actual bay rectangles/codes for overlap and section checks. No walls, columns, parked-car collision capsules, handling, camera or physics versions change. The roof remains removed; the corrected filled arrows remain. All five cars, saved cosmetics, pause/reset/background release and retained Garage return remain covered, with no race proof, tickets, PB or condition writes.

The original `parking_concrete_v1.png` is a 512 × 512 numeric atlas: RG shallow slopes, B tone and A roughness. `tests/bake_parking_concrete.gd` creates it offline using fixed-seed seamless FastNoiseLite fields and wrapped differences. Its SHA-256 is `991cfcb31e33393ba0954f48da9d9614bd666d14ec297b46565f81790aa3e7f3`; a second bake is byte-identical. Lossless import retains every base-level channel exactly, with the complete mip payload below 1.4 MB. The shader uses three filtered samples and no floor light pools. The source notice is beside the texture. There is no external artwork, AI bitmap, runtime generation/service or new dependency.

The focused harness checks every bay against the stair corridor, every central label against section A, unique space codes, packed-channel import/mip limits and native floor brightness. It also retains the real five-car flow and native arrow contrast checks. Final views cover entry, turning, slalom, perimeter bays, stairs, arrows, central bays and crossing at 960 × 540, 1280 × 720 and 1600 × 900 in both renderers, plus Garage and pause views.

Actual validation:

- `PARKING_HALL: 608 checks, 0 failures` — `focused-headless`.
- `PARKING_HALL: 642 checks, 0 failures` — `focused-compatibility`.
- `PARKING_HALL: 642 checks, 0 failures` — `focused-mobile`.
- `APP_TESTS: 141 checks, 0 failures` — `app`.
- `SCRIPT_PARSE: 1040 scripts, 0 failures` — `parser`.

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. Native Compatibility/OpenGL and desktop Mobile/Vulkan run on the Windows RTX 3090 with isolated workspace APPDATA and unique local fixture directories. These are desktop checks. The final runner and exact commands are retained with [report.json](evidence/parking-hall-floor-layout-2026-10-23/report.json). Final [Compatibility exit view](evidence/parking-hall-floor-layout-2026-10-23/captures/final-compatibility/crossing-1280.png) and [Mobile exit view](evidence/parking-hall-floor-layout-2026-10-23/captures/final-mobile/crossing-1280.png) show the corrected result.

Initial corrections are retained: a temporary native-library copy lock interrupted one import, and a retry succeeded without changing native files. The first new shader used an unsupported scalar `mat2` constructor, causing the pale fallback seen by the owner; vector columns fix compilation. The first channel test compared mipmapped and unmipmapped buffers; clearing only the test image's mips retains an exact base-level assertion. A first compiling version was too mottled and was refined to fine grain and slab variation. Mobile initially rendered the pigment too lightly; explicit sRGB-to-linear conversion corrects it. Intermediate images and logs remain separate from final receipts. No failing invariant was removed.

Restart the client to load the change. Owner appearance/driving acceptance and sustained physical-device checks remain. Phone/tablet attachment was not checked; no physical-device test, APK export/install, backend/account mutation, native-library rebuild or deployment was performed. Prior evidence and concurrent workspace work are preserved.
