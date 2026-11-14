extends SceneTree
## The reusable contact meshes share the original App retention allowance.
const Memory = preload("res://editor/editor_memory.gd")
const Contacts = preload("res://vehicle/visible_contact_audio.gd")
const Fixture = preload("res://tests/test_memory_policy_loading.gd")
var checks: int = 0
var failures: int = 0

class ReservedWorld extends Node:
	var visual_cache_bytes: int = 0
	func trim_cache() -> void: pass
	func trim_prop_cache() -> void: pass
	func prop_cache_bytes() -> int: return 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("MEMORY_CONTACT_FAIL ",label)

func run() -> void:
	Contacts.trim_cache()
	var owner := Fixture.Owner.new()
	root.add_child(owner)
	var world := ReservedWorld.new()
	owner.add_child(world)
	owner.editor_world = world
	var car := Node3D.new()
	root.add_child(car)
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	part.mesh = mesh
	car.add_child(part)
	var contact := Contacts.new()
	contact.configure(car,true)
	var expected: PackedByteArray = var_to_bytes(contact.outline)
	var bytes: int = Contacts.bytes_used()
	check(bytes > 0 and not contact.outline.is_empty(),"fixture retains actual contact mesh and outline")
	check(Memory.retained(owner).other.visible_contact_bytes == bytes,"App counts the complete contact allocation")
	# As in the scenery budget tests, inflate only a reservation to force real
	# policy arbitration without allocating tens of megabytes of throwaway data.
	world.visual_cache_bytes = Memory.RETAINED_BUDGET-int(Memory.retained(owner).retained_bytes)+maxi(1,bytes/2)
	check(Memory.retained(owner).retained_bytes > Memory.RETAINED_BUDGET,"fixture exceeds unchanged shared allowance")
	var policy := Memory.new()
	policy.tick(owner)
	check(Contacts.bytes_used() == 0,"ordinary pressure releases reproducible contact retention")
	check(Memory.retained(owner).retained_bytes <= Memory.RETAINED_BUDGET,"shared allowance is respected")
	check(part.mesh == mesh and var_to_bytes(contact.outline) == expected,"active geometry and contact hull survive cache eviction")
	world.visual_cache_bytes = 0
	contact.configure(car,true)
	check(Contacts.bytes_used() > 0,"normal use can repopulate the bounded cache")
	policy.pressure_requested = true
	policy.next_sample = 0
	policy.tick(owner)
	check(Contacts.bytes_used() == 0 and Memory.retained(owner).other.visible_contact_bytes == 0,"explicit pressure releases contact retention and accounting")
	check(part.mesh == mesh and var_to_bytes(contact.outline) == expected,"explicit pressure preserves active geometry and contact hull")
	check(Memory.RETAINED_BUDGET == 64*1024*1024 and Memory.GARAGE_BUDGET == 96*1024*1024,"no allowance increase")
	car.free()
	owner.free()
	print("MEMORY_CONTACT ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
