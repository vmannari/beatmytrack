extends "res://tests/test_car_model_revert.gd"
## Correct the review fixture's omitted root scale; never restore live sources.
const RFL_WORK: String="res://../build/rally-front-2026-11-15"
const RFL_OUT: String="res://../docs/evidence/rally-front-2026-11-15"
func _initialize() -> void: repair.call_deferred()
func repair() -> void:
	var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rally_front_baseline.json"))
	var rows: Array=[]
	for mode: String in ["stock","fitted","full"]:
		var path: String=RFL_WORK.path_join("compact-"+mode+"-before.scn")
		var archive: String=RFL_WORK.path_join("fixture-original-"+mode+".scn")
		assert(not FileAccess.file_exists(archive))
		FileAccess.open(archive,FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes(path))
		var holder: Node3D=load(path).instantiate();root.add_child(holder)
		check(signature(holder)==baseline.signatures["compact_"+mode],"saved original GPU streams/transforms still match task-start "+mode)
		var previous: Transform3D=holder.transform
		holder.scale=Vector3.ONE*HandlingConfig.BODY_SCALE
		var meshes: Dictionary={};var materials: Dictionary={}
		for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
			if not meshes.has(part.mesh):meshes[part.mesh]=part.mesh.duplicate(true)
			part.mesh=meshes[part.mesh]
			if part.material_override!=null:
				if not materials.has(part.material_override):materials[part.material_override]=part.material_override.duplicate(true)
				part.material_override=materials[part.material_override]
			for surface: int in range(part.mesh.get_surface_count()):
				var material: Material=part.get_surface_override_material(surface)
				if material!=null:
					if not materials.has(material):materials[material]=material.duplicate(true)
					part.set_surface_override_material(surface,materials[material])
		check(signature(holder)==baseline.signatures["compact_"+mode],"self-contained fixture retains every original GPU stream "+mode)
		var packed:=PackedScene.new();assert(packed.pack(holder)==OK)
		assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
		rows.append({"mode":mode,"before_transform":str(previous),"correct_transform":str(holder.transform),"gpu_signature_exact":true,"snapshot_sha256":FileAccess.get_sha256(path)})
		holder.free()
	FileAccess.open(RFL_OUT.path_join("snapshot-fixture-repair.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"reason":"Initial detached fixture copied children but omitted CarVisual root BODY_SCALE. Correct the fixture only; geometry is exact to the task-start signatures.","rows":rows},"  "))
	print("RALLY_FRONT_SNAPSHOT_REPAIR ",checks," checks, ",failures," failures");quit(1 if failures else 0)
