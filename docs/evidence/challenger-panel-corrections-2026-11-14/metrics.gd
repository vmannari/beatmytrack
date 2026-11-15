extends SceneTree
func payload(mesh: Mesh) -> int:
    var bytes: int = 0
    for surface: Dictionary in mesh.get("_surfaces"):
        for field: String in ["vertex_data","attribute_data","skin_data","index_data","blend_shapes"]: bytes += surface.get(field,PackedByteArray()).size()
    return bytes
func _initialize() -> void:
    var rows: Array = []
    var out: String = "res://../docs/evidence/challenger-panel-corrections-2026-11-14/"
    for stage: String in ["before","after"]:
        var prefix: String = out+"before/game/assets/vehicles/challenger_hellcat_v1/" if stage == "before" else SuperRallyModel.ROOT
        var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefix+"manifest.json"))
        for tier: String in ["simple","full"]:
            var triangles: int = 0; var raw: int = 0; var disk: int = 0
            for entry: Dictionary in manifest.tiers[tier]:
                var mesh: Mesh = load(prefix+str(entry.mesh))
                triangles += mesh.get_faces().size()/3
                raw += payload(mesh); disk += FileAccess.get_file_as_bytes(prefix+str(entry.mesh)).size()
            rows.append({"stage":stage,"tier":tier,"native_triangles":triangles,"raw_bytes":raw,"disk_bytes":disk,"material_batches":manifest.tiers[tier].size()})
    var file := FileAccess.open(out+"metrics.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"\t"));file.close()
    print("PANEL_METRICS ",JSON.stringify(rows));quit()
