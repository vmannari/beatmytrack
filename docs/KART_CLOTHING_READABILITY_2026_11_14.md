# Kart clothing made visibly clearer

14 November 2026. The owner reports that the previous clothing pass is barely visible. That assessment is supported by the matched native captures: its small grey variations and fine weave did not establish clear garment construction at ordinary Garage scale.

The revised suit uses a dark blue-grey base, light shoulder reinforcement and chest inserts, a contrasting zip placket, warm muted piping and trouser inserts. Its masks follow the reclined torso axis rather than only world height. Fine UV-anchored woven colour/normal detail, rolled seam shading and subtle waist/knee compression relief make the surface respond as cloth. The weave fades before becoming subpixel. Relief changes fragment normals; it does not displace the mesh.

- [Before, front](evidence/kart-clothing-2026-11-14/before/gl_compatibility/front.png) and [after, front](evidence/kart-clothing-2026-11-14/final/gl_compatibility/front.png).
- [After, side](evidence/kart-clothing-2026-11-14/final/gl_compatibility/side.png) and [after, overhead](evidence/kart-clothing-2026-11-14/final/gl_compatibility/overhead.png).
- [Vulkan Mobile front](evidence/kart-clothing-2026-11-14/final/mobile/front.png).
- [Actual Garage before](evidence/visual-fixes-2026-11-13/app-gl_compatibility/kart-garage.png) and [actual Garage after](evidence/kart-clothing-2026-11-14/app-gl_compatibility/kart-garage.png).

The production edit is confined to `game/vehicle/kart_driver_cloth.gdshader`. Native driver/helmet resources, positions, normals, UVs, topology, all ten steering poses, grip, vehicle geometry and handling are preserved. The existing per-car material bindings serve the full and split driver layouts. No new texture, mesh instance or render pass is added.

Validation uses pinned Godot `4.7.2.stable.official.ed1daf0bf`, isolated disposable profiles and empty backend configuration. Driver material/mesh/morph/serialization checks pass **64/0**. Retained actual-CarVisual steering checks pass **157/0**. Front/side/overhead captures compile and render cleanly in Compatibility and desktop Vulkan Mobile. These results are not physical-device performance acceptance.

The Kart's profile/header, 49 livery pictures, news picture and two Rivalry textures are refreshed from the native renderer. Livery preview files are conservative shared inputs in the existing identity scheme, so the prepared refresh also rebuilds dependent fleet bases, kits, Garage rest scenes and the Compact header template. The constructors for other vehicles are not edited. Existing transactional Garage picture publication and strict source/resource/provenance gates remain in use.

Commands and receipts are under [the evidence directory](evidence/kart-clothing-2026-11-14/). `scripts/refresh_kart_clothing.py --art` creates the Kart pictures; `scripts/import_kart_clothing_images.py` verifies 53 Kart image imports, five refreshed fleet Garage pictures and two native texture hashes; `scripts/refresh_kart_clothing.py` performs the source-fenced prepared refresh. The native capture and actual-App fixtures are retained there for review.

Final prepared checks pass **551 resources / 2,267 checks / 0 failures**. The catalogue verifies six exact pictures against 168 current source hashes, and the workshop verifies its scene and all 27 declared sources. Actual Kart Garage/race checks pass **16/0 per desktop renderer**, including canonical handling, production geometry and animated steering. The initial Compatibility run retained the known intermittent two-object/one-resource shutdown diagnostic; an identical repeat exited cleanly, as did Mobile. No product leak fix is claimed.

A concurrent edit to `garage_news_menu.gd` rejected the initial broad source fence. Its exact before/after hashes are retained. That display-only menu is not a vehicle geometry or native-photo producer dependency; the resumed refresh required unchanged vehicle revision keys and the complete existing native metadata/provenance gates. No concurrent code was reverted.

The source-only checkpoint verifies the one production shader edit plus the new tooling/report byte-exactly forward and backward, preserving native controls and the shared index during verification. The active task pin was removed and prescribed build retention applied; recent/protected output remains subject to the normal retention policy. No device query/test, export, deployment, live backend request or owner-save/process change was performed. Owner appearance acceptance and physical-device performance remain separate.
