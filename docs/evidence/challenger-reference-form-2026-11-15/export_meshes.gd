extends SceneTree
func _initialize() -> void:
    var prefix: String = "res://assets/vehicles/challenger_hellcat_v1/"
    var dest: String = "res://../build/challenger-reference-form-2026-11-15/decoded.json"
    for arg: String in OS.get_cmdline_user_args():
        if arg.begins_with("--root="): prefix = arg.trim_prefix("--root=")
        if arg.begins_with("--output="): dest = arg.trim_prefix("--output=")
    var result: Dictionary = {}
    for tier: String in ["simple","full"]:
        result[tier] = {}
        for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(prefix+"manifest.json")).tiers[tier]:
            var name: String = str(entry.group)+"_"+str(entry.role)
            var mesh: ArrayMesh = load(prefix+tier+"_"+name+".res")
            var a: Array = mesh.surface_get_arrays(0)
            var pp: Array = []; var nn: Array = []
            for v: Vector3 in a[Mesh.ARRAY_VERTEX]: pp.append([v.x,v.y,v.z])
            for n: Vector3 in a[Mesh.ARRAY_NORMAL]: nn.append([n.x,n.y,n.z])
            result[tier][name] = {"points":pp,"normals":nn,"indices":Array(a[Mesh.ARRAY_INDEX])}
    var file := FileAccess.open(dest,FileAccess.WRITE)
    file.store_string(JSON.stringify(result));file.close()
    print("EXTERIOR_NATIVE_EXPORT: 8 meshes")
    quit()
