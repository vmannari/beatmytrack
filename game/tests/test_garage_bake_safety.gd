extends SceneTree
const Transaction = preload("res://tests/support/asset_bake_transaction.gd")
const Comparison = preload("res://tests/support/garage_geometry_comparison.gd")
class FailingTransaction extends Transaction:
	var moves: int = 0
	func _move(source: String, target: String) -> Error:
		moves += 1
		# Fail installing the manifest, after an image has already been installed.
		if moves == 4: return ERR_CANT_CREATE
		return super._move(source, target)

var checks: int = 0
var failures: int = 0
var folder: String = "res://../build/garage-bake-safety-" + str(Time.get_ticks_usec())
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)
func write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()
func original() -> bool:
	return FileAccess.get_file_as_string(folder.path_join("image.png")) == "accepted image" and FileAccess.get_file_as_string(folder.path_join("provenance.json")) == "accepted receipt"
func candidates(transaction: RefCounted) -> void:
	write(transaction.candidate("image.png"), "new image")
	write(transaction.candidate("provenance.json"), "new receipt")
func geometry(node: Node) -> Array:
	var rows: Array = []
	Comparison.geometry(node, rows)
	return rows
func run() -> void:
	folder = ProjectSettings.globalize_path(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	write(folder.path_join("image.png"), "accepted image")
	write(folder.path_join("provenance.json"), "accepted receipt")
	var files: Array[String] = ["image.png", "provenance.json"]
	var first := Transaction.new()
	check(first.begin(folder, files) == OK, "writer acquires its own lock")
	var second := Transaction.new()
	check(second.begin(folder, files) != OK, "overlapping writer rejected")
	candidates(first)
	check(original(), "candidate generation leaves accepted files exact")
	first.close()
	check(original(), "aborted generation preserves accepted files")
	check(not DirAccess.dir_exists_absolute(first.staging), "abort removes owned candidates and lock")
	var stale := Transaction.new()
	check(stale.begin(folder, files) == OK, "next writer can acquire released lock")
	candidates(stale)
	write(folder.path_join("image.png"), "concurrent image")
	check(stale.publish(files) == ERR_BUSY, "concurrent image mutation rejects publication")
	check(FileAccess.get_file_as_string(folder.path_join("image.png")) == "concurrent image", "rejection preserves concurrent output")
	stale.close()
	write(folder.path_join("image.png"), "accepted image")
	var stale_manifest := Transaction.new()
	stale_manifest.begin(folder, files)
	candidates(stale_manifest)
	write(folder.path_join("provenance.json"), "concurrent receipt")
	check(stale_manifest.publish(files) == ERR_BUSY, "concurrent manifest mutation rejects publication")
	stale_manifest.close()
	write(folder.path_join("provenance.json"), "accepted receipt")
	var failure := FailingTransaction.new()
	failure.begin(folder, files)
	candidates(failure)
	check(failure.publish(files) == ERR_CANT_CREATE, "injected mid-publication IO failure returned")
	check(original(), "failed manifest installation rolls back image and manifest exactly")
	failure.close()
	var accepted := Transaction.new()
	accepted.begin(folder, files)
	candidates(accepted)
	check(accepted.publish(files) == OK, "valid complete generation publishes")
	check(FileAccess.get_file_as_string(folder.path_join("image.png")) == "new image" and FileAccess.get_file_as_string(folder.path_join("provenance.json")) == "new receipt", "accepted image and receipt both installed")
	accepted.close()
	check(not DirAccess.dir_exists_absolute(accepted.staging), "success releases writer lock")
	var missing := Transaction.new()
	missing.begin(folder, files)
	write(missing.candidate("image.png"), "partial")
	check(missing.publish(files) == ERR_INVALID_DATA, "incomplete candidate set rejected before replacement")
	missing.close()
	var protected := Transaction.new()
	protected.begin(folder, files)
	write(protected.candidate("provenance.json"), "receipt with protected image")
	check(protected.publish(["provenance.json"]) == OK, "excluded image can be fenced without replacement")
	check(FileAccess.get_file_as_string(folder.path_join("image.png")) == "new image", "excluded image bytes stay exact")
	protected.close()
	var empty_folder: String = folder.path_join("empty")
	var empty := FailingTransaction.new()
	empty.begin(empty_folder, files)
	candidates(empty)
	# No backups are needed here: move 2 is the manifest installation.
	empty.moves = 2
	check(empty.publish(files) == ERR_CANT_CREATE, "first-generation manifest failure returned")
	check(not FileAccess.file_exists(empty_folder.path_join("image.png")) and not FileAccess.file_exists(empty_folder.path_join("provenance.json")), "first-generation failure leaves no partial published files")
	empty.close()
	var root_a := Node3D.new()
	var root_b := Node3D.new()
	root_a.name = "Room"; root_b.name = "Room"
	root.add_child(root_a); root.add_child(root_b)
	# Adding unnamed sibling meshes produces different process-global numbers.
	for parent: Node3D in [root_a, root_b]:
		for index: int in range(2):
			var mesh := MeshInstance3D.new()
			mesh.mesh = BoxMesh.new()
			mesh.material_override = StandardMaterial3D.new()
			parent.add_child(mesh)
	var a: Node = root_a.get_child(1)
	var b: Node = root_b.get_child(1)
	check(str(a.name).begins_with("@") and a.name != b.name, "fixture exercises differing engine-generated names")
	check(geometry(a) == geometry(b), "equivalent generated nodes compare equal")
	b.name = "AuthoredPart"
	check(geometry(a) != geometry(b), "authored node names stay significant")
	var baseline: Array = geometry(b)
	b.position.x = 0.1
	check(baseline != geometry(b), "transform changes still rejected")
	b.position.x = 0.0
	b.mesh.size.x = 2.0
	check(baseline != geometry(b), "mesh-array changes still rejected")
	b.mesh.size.x = 1.0
	b.material_override.roughness = 0.2
	check(baseline != geometry(b), "finish changes still rejected")
	root_a.free(); root_b.free()
	print("GARAGE_BAKE_SAFETY ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
