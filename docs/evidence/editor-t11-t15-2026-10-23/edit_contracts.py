from pathlib import Path

def replace(path, old, new):
    p=Path(path); s=p.read_text(encoding='utf-8'); assert old in s,(path,old)
    p.write_text(s.replace(old,new,1),encoding='utf-8',newline='\n')

replace('game/editor/track_document.gd','(data.theme not in THEMES and data.theme != "coast")','data.theme not in THEMES')
replace('game/editor/track_document.gd','errors.append("This track format is not supported.")','return ["Unsupported track format. Import a creator-track-v5 file exported by this build."]')
replace('game/ui/track_catalog.gd','data.get("theme") not in TrackDocument.THEMES and data.get("theme") != "coast"','data.get("theme") not in TrackDocument.THEMES')
replace('docs/schemas/creator-track-v5.schema.json','        "coast",\n','')
replace('game/track/native_track.gd','data.get("schema", "") not in ["surface-grid-v1", "surface-grid-v2"]','data.get("schema", "") != "surface-grid-v2"')
replace('game/track/native_track.gd','\t# Trusted native data only. Creator imports are validated and compiled first.','\t# Trusted current native data only. Older imports are never upgraded.\n\tif data.get("schema") != "surface-grid-v2": return null')
replace('game/track/prop_geometry.gd','\ttool.remove_meta("prop_cpu_appends")','\tif tool.has_meta("prop_cpu_appends"): tool.remove_meta("prop_cpu_appends")')
# Exercise supported biomes in the optional evidence path. The other coast
# string in this test deliberately checks that the editor rejects biome edits.
replace('game/tests/test_app.gd','for theme: String in ["pine", "coast", "desert"]:','for theme: String in ["pine", "winter", "desert"]:')

p=Path('game/tests/test_road_pieces.gd'); s=p.read_text(encoding='utf-8')
s=s.replace('var asphalt_detail_materials: int = 0','var asphalt_detail_materials: int = 0\n\t\t\tvar asphalt_rim: bool = false\n\t\t\tvar rendered_kerbs := PackedVector3Array()\n\t\t\tvar kerb_lift: float = preload("res://track/road_surface_height.gd").RISE',1)
s=s.replace('var material: ShaderMaterial = mesh.material_override as ShaderMaterial','var applied: ShaderMaterial = mesh.material_override as ShaderMaterial\n\t\t\t\tvar material: ShaderMaterial = applied.get_meta("surface_dynamic_material",applied)',1)
s=s.replace('if material.shader.resource_path == "res://track/creator_road.gdshader" and material.get_shader_parameter("asphalt_surface"):','if material.get_shader_parameter("asphalt_surface") == true:',1)
s=s.replace('if material.shader.resource_path == "res://track/creator_road.gdshader" and material.get_shader_parameter("road_marking"):','if material.get_shader_parameter("road_marking") == true:',1)
s=s.replace('for normal: Vector3 in normals: upward = upward and normal.distance_to(Vector3.UP) < 0.0001','''# Raised asphalt and fitted Grass verges have real bevels.
\t\t\t\t\t# Keep the strict up-normal invariant for genuinely flat roles.
\t\t\t\t\tvar shaped: bool = material.get_shader_parameter("raised_road_edge") == true or material.get_shader_parameter("grass_shoulder") == true
\t\t\t\t\tfor normal: Vector3 in normals:
\t\t\t\t\t\tupward = upward and normal.is_finite() and absf(normal.length()-1.0) < 0.001
\t\t\t\t\t\tif not shaped: upward = upward and normal.distance_to(Vector3.UP) < 0.0001
\t\t\t\t\t\tif material.get_shader_parameter("asphalt_surface") == true: asphalt_rim = asphalt_rim or absf(normal.y) < 0.98''',1)
s=s.replace('kerb_vertices += vertices.size()','kerb_vertices += vertices.size()\n\t\t\t\trendered_kerbs.append_array(vertices)',1)
s=s.replace('vertex.y >= 0.0179 and vertex.y <= 0.1181','vertex.y >= 0.0179+kerb_lift and vertex.y <= 0.1181+kerb_lift',1)
s=s.replace('check(asphalt_detail_materials == 2,"creator asphalt has separate solid and UV-controlled edge-fringe materials")','check(asphalt_detail_materials > 0 and asphalt_rim,"creator solid asphalt retains its actual raised bevel geometry and masked surface role")',1)
s=s.replace('check(upward,"flat road/grass/sand/paint triangles retain upward normals")','check(upward,"flat surface roles retain upward normals; raised road/verge normals remain finite unit vectors")',1)
old='\t\t\tcheck(matched and kerb_vertices == track.kerbs.triangles.size()*3,"rendered kerb triangles match bounded canonical geometry")'
assert old in s
s=s.replace(old,'''\t\t\tvar expected_kerbs := PackedVector3Array()
\t\t\tfor triangle: Dictionary in track.kerbs.triangles:
\t\t\t\tfor i: int in range(3): expected_kerbs.append(Vector3(triangle.points[i].x,0.018+kerb_lift+triangle.heights[i],triangle.points[i].y))
\t\t\tvar exact: bool = rendered_kerbs.size() == expected_kerbs.size()
\t\t\tif exact:
\t\t\t\tfor i: int in range(expected_kerbs.size()): exact = exact and rendered_kerbs[i].distance_to(expected_kerbs[i]) < 0.00001
\t\t\tcheck(matched and exact and kerb_vertices == track.kerbs.triangles.size()*3,"every rendered kerb vertex matches canonical geometry plus the cosmetic asphalt lift")''',1)
p.write_text(s,encoding='utf-8',newline='\n')
