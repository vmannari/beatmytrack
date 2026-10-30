# Volt rounded front shoulder — 2026-10-30

The marked front shoulder now rolls into the side panel, with a slightly deeper swept nose. The bonnet and front fascia share the same edge, and the light follows the fascia. The rounding fades out toward the cabin; handling and saved liveries are unchanged. Prepared meshes use the new `electric_reference_sport_nose_v1` directory, leaving earlier assets intact.

The pinned Godot 4.7.2 bake produced 221 full/simple meshes. Existing nose checks passed 64/64 for both procedural and prepared geometry; the retained hood reference checks passed 15/15, the native model checks 15/15, and the actual App checks 58/58. The detailed/simple models report 119,904/38,036 triangles. The Garage template, electric shadows, header/Garage pictures, 49 livery previews and news picture were refreshed. The App run logged race frame hitches; these checks are not a performance certification.

Native views are in [the Compatibility capture folder](evidence/volt-sport-nose-2026-10-30/aligned/), including [the front quarter](evidence/volt-sport-nose-2026-10-30/aligned/front-quarter-clean.png). Initial deeper-nose captures and the first failed seam check are retained in the evidence directory. Reload and visual acceptance on the owner's installation remain.

Most engine runs used isolated profiles. Four accidentally launched with the normal Windows profile when a nested PowerShell command expanded environment variables prematurely; they were interrupted, and only the standalone render/geometry scripts had been invoked. They could have created ordinary Godot log files in that profile. No owner save or live service operation was intended or observed.
