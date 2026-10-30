# Volt straighter sides and doors — 2026-10-30

The owner reported that the Volt's sides and doors bend too far inward. The door hollow was reduced from 95 to 20 mm in model coordinates and the lower fold from 40 to 12 mm. The resulting panels retain a subtle contour while removing the deep inward waist. The hood, cabin, wheel positions, saved appearances and handling are unchanged by this task.

Compare the matched [before](evidence/volt-straight-sides-2026-10-30/before/front-quarter-high-clean.png) and [after](evidence/volt-straight-sides-2026-10-30/striped/front-quarter-high-clean.png) native views. Both use a synthetic Apex Twin livery similar to the owner's screenshot; neither reads or changes an owner save. A [side view](evidence/volt-straight-sides-2026-10-30/striped/side-clean.png), opposite side and rear-quarter views are also available. The retained small marks at the hood/fender and rear deck were present in the before control.

The actual-buffer side regression passes 100/100 on procedural and prepared geometry; the exact starting body passes 96/100, with the four failures detecting the door pinch. Its sampled maximum inward deviation from the door chord falls from 62.95 mm detailed / 61.51 mm simplified to zero at the sampled positions. It also checks arch-to-side joins, wheel clearances, handles and application of a saved body colour. Prepared hood 16/16, nose and lighting 64/64, cabin fit 20/20, racing model 23/23 and actual Garage/race 58/58 pass. The App integration run logged frame hitches.

The `electric_reference_straight_sides_v1` asset root contains 221 meshes; all files exist and all source hashes match. Racing shadows, the Electric Garage template and Garage/header/catalogue/news and 49 livery pictures were refreshed. Visible detailed/simple geometry is 119,904/34,872 triangles; shadows total 3,222. Both desktop renderers produced 18 clean/worn views. Noninteractive Godot runs used the crash-dialog wrapper and isolated profiles.

Reload/reimport and owner/device acceptance remain. No physical-device test, APK, live account/backend mutation or deployment was performed.
