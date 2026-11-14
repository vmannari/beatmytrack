extends SceneTree
## Physical error bounds and attribute preservation for the third Garage pass.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)
func run() -> void:
	var root := Node3D.new()
	var finish := StandardMaterial3D.new()
	for radius: float in [0.003,0.012,0.01201,0.035,0.03501,0.08]:
		var tube: MeshInstance3D = GarageFurnishings.tube(root,Vector3.ZERO,Vector3.UP*0.4,radius,finish)
		check(tube.mesh.rings == 0 and tube.mesh.cap_top and tube.mesh.cap_bottom,"tube keeps straight shaft and both caps")
		check(tube.mesh.get_aabb().size.is_equal_approx(Vector3(radius*2,0.4,radius*2)),"tube axis dimensions exact")
		check(radius*(1.0-cos(PI/tube.mesh.radial_segments)) <= 0.0011,"default tube chord error below 1.1 mm")
	for sides: int in [6,8,12,20,24,32,48,64]:
		var tube: MeshInstance3D = GarageFurnishings.tube(root,Vector3.ZERO,Vector3.UP,0.01,finish,sides)
		check(tube.mesh.radial_segments == sides,"explicit authored polygon count exact")
	for radius: float in [0.016,0.03499,0.035,0.08999,0.09,0.23999,0.24,0.48]:
		var profile: Array[Vector2] = [Vector2(0,0),Vector2(radius*0.8,0),Vector2(radius,0.02),Vector2(radius,0.11),Vector2(radius*0.8,0.14),Vector2(0,0.14)]
		var part: MeshInstance3D = GarageFurnishings.lathe(root,Vector3.ZERO,profile,finish)
		var arrays: Array = part.mesh.surface_get_arrays(0)
		var sides: int = GarageFurnishings.lathe_sides(radius)
		check(sides%4 == 0,"lathe keeps all four cardinal extrema")
		if radius < 0.24: check(radius*(1.0-cos(PI/sides)) < 0.0012,"small lathe chord error below 1.2 mm")
		else: check(sides == 48,"large lathe retains original silhouette samples")
		check(part.mesh.get_aabb().size.is_equal_approx(Vector3(radius*2,0.14,radius*2)),"lathe dimensions retained")
		var matching: bool = true
		for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
			var vertex: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
			var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][index]
			var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][index]
			matching = matching and uv.is_equal_approx(Vector2(vertex.x,vertex.y)) and is_equal_approx(normal.length(),1.0)
			var on_profile: bool = false
			for point: Vector2 in profile:
				if is_equal_approx(vertex.y,point.y) and is_equal_approx(Vector2(vertex.x,vertex.z).length(),point.x): on_profile = true
			matching = matching and on_profile
		check(matching,"lathe vertices remain on authored profile with unit normals and original UV mapping")
		var repeated: MeshInstance3D = GarageFurnishings.lathe(root,Vector3.ONE,profile,finish)
		check(repeated.mesh == part.mesh,"identical turned prop mesh reused")
	for outer: float in [0.034,0.05,0.05001,0.128,0.12801,0.307]:
		var ring: MeshInstance3D = GarageFurnishings.ring(root,Vector3.ZERO,outer-0.006,outer,finish)
		check(ring.mesh.ring_segments == 8,"rolled ring cross-section detail retained")
		if outer <= 0.128: check(outer*(1.0-cos(PI/ring.mesh.rings)) < 0.0011,"small ring chord error below 1.1 mm")
		else: check(ring.mesh.rings == 32,"large ring silhouette samples unchanged")
	root.free()
	print("GARAGE_PROP_DETAIL ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
