extends SceneTree
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}
var prefix: String = SuperRallyModel.ROOT
var label: String = "live"
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; print("FAIL: ",message)
func mirrored(mesh: ArrayMesh,other: ArrayMesh = null) -> int:
    var a: Array = mesh.surface_get_arrays(0)
    var b: Array = (other if other != null else mesh).surface_get_arrays(0)
    # Blender loop-normal and native octahedral packing each round normals;
    # one milliradian (0.057 degrees) is the maximum accepted shading mismatch.
    var available: Dictionary = {}
    var bp: PackedVector3Array = b[Mesh.ARRAY_VERTEX]; var bn: PackedVector3Array = b[Mesh.ARRAY_NORMAL]
    for i: int in range(bp.size()):
        var key := Vector3i((bp[i]*10000).floor())
        if not available.has(key): available[key] = []
        available[key].append([bp[i],bn[i]])
    # Native vertex compression can place mirror mates one 16-bit AABB unit apart.
    var position_tolerance: float = maxf(mesh.get_aabb().size.x,(other.get_aabb().size.x if other != null else 0.0))/65535.0+.000002
    var missing: int = 0
    var ap: PackedVector3Array = a[Mesh.ARRAY_VERTEX]; var an: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
    for i: int in range(ap.size()):
        var p: Vector3 = ap[i]; var n: Vector3 = an[i]; p.x = -p.x; n.x = -n.x
        var key := Vector3i((p*10000).floor())
        var matched: bool = false
        var near: Array = []
        for dx: int in range(-1,2):
            for dy: int in range(-1,2):
                for dz: int in range(-1,2):
                    for candidate: Array in available.get(key+Vector3i(dx,dy,dz),[]):
                        if p.distance_to(candidate[0]) < position_tolerance:
                            near = candidate
                            if n.distance_to(candidate[1]) < .001: matched = true
        if not matched:
            missing += 1
    return missing
func run() -> void:
    for arg: String in OS.get_cmdline_user_args():
        if arg.begins_with("--root="): prefix = arg.trim_prefix("--root=")
        if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefix+"manifest.json"))
    for tier: String in ["simple","full"]:
        var body: ArrayMesh = load(prefix+tier+"_body_paint.res")
        var hood: ArrayMesh = load(prefix+tier+"_hood_paint.res")
        check(mirrored(body) == 0,tier+" body positions and normals match reflected geometry within native compression precision")
        check(mirrored(hood) == 0,tier+" bonnet positions and normals match reflected geometry within native compression precision")
        check(mirrored(load(prefix+tier+"_tail_left_red.res"),load(prefix+tier+"_tail_right_red.res")) == 0,tier+" matching reflected taillights")
        var triangles: TriangleMesh = body.generate_triangle_mesh()
        var door_error: float = 0
        var missing: int = 0
        for y: float in [.38,.42,.48,.55]:
            for z: float in [-.4,-.3,-.2,-.1,0,.1,.2,.3,.4]:
                var a: Dictionary = triangles.intersect_ray(Vector3(2,y,z),Vector3.LEFT)
                var b: Dictionary = triangles.intersect_ray(Vector3(2,y,z+.03),Vector3.LEFT)
                if a.is_empty() or b.is_empty(): missing += 1
                else: door_error = maxf(door_error,absf(a.position.x-b.position.x-.00021))
        check(missing == 0,tier+" supported lower door sheet")
        check(door_error < .002,tier+" lower door has no triangular longitudinal dent")
        var rear_error: float = 0
        for y: float in [.50,.58,.65,.73]:
            var values: Array[float] = []
            for i: int in range(-14,15):
                var hit: Dictionary = triangles.intersect_ray(Vector3(i*.05,y,3),Vector3.FORWARD)
                if hit.is_empty(): missing += 1; values.append(NAN)
                else: values.append(hit.position.z)
            for i: int in range(1,values.size()-1):
                if is_finite(values[i-1]) and is_finite(values[i]) and is_finite(values[i+1]): rear_error = maxf(rear_error,absf(values[i-1]+values[i+1]-2*values[i]))
        check(missing == 0,tier+" rear face samples have complete coverage")
        check(rear_error < .003,tier+" rear fascia has no local dimples or waviness")
        var quarter_missing: int = 0
        var quarter_error: float = 0
        for y: float in [.50,.60,.70]:
            var values: Array[float] = []
            for i: int in range(13):
                var hit: Dictionary = triangles.intersect_ray(Vector3(2,y,1.8+i*.025),Vector3.LEFT)
                if hit.is_empty(): quarter_missing += 1; values.append(NAN)
                else: values.append(hit.position.x)
            for i: int in range(1,values.size()-1):
                if is_finite(values[i-1]) and is_finite(values[i]) and is_finite(values[i+1]): quarter_error = maxf(quarter_error,values[i-1]+values[i+1]-2*values[i])
        check(quarter_missing == 0,tier+" rear quarter has a closed exterior")
        check(quarter_error < .001,tier+" rear quarter has no reverse-curvature dents")
        var lens: TriangleMesh = (load(prefix+tier+"_body_lens_red.res") as ArrayMesh).generate_triangle_mesh()
        var guide: PackedVector3Array = (load(prefix+tier+"_tail_right_red.res") as ArrayMesh).get_faces()
        var hidden_guides: int = 0
        for offset: int in range(0,guide.size(),3):
            var point: Vector3 = (guide[offset]+guide[offset+1]+guide[offset+2])/3.0
            var backing: Dictionary = lens.intersect_ray(Vector3(point.x,point.y,3),Vector3.FORWARD)
            if not backing.is_empty() and point.z < backing.position.z+.002: hidden_guides += 1
        check(hidden_guides == 0,tier+" curved taillight guide stays ahead of its lens at triangle centres")
        var reflector: ArrayMesh = load(prefix+tier+"_body_red.res")
        var reflector_points: PackedVector3Array = reflector.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
        var hidden_reflectors: int = 0
        for point: Vector3 in reflector_points:
            if point.z < 2.0 or point.y < .45 or point.y > .65 or absf(point.x) > .80: continue
            var backing: Dictionary = triangles.intersect_ray(Vector3(point.x,point.y,3),Vector3.FORWARD)
            if not backing.is_empty() and point.z < backing.position.z+.002: hidden_reflectors += 1
        check(hidden_reflectors == 0,tier+" lower rear reflectors remain ahead of the corrected fascia")
        var lower_error: float = 0
        for i: int in range(27):
            var x: float = i*.025
            var edge: float = -1
            for step: int in range(125):
                var y: float = .70-step*.001
                var hit: Dictionary = triangles.intersect_ray(Vector3(x,y,-3),Vector3.BACK)
                if not hit.is_empty() and hit.position.z < -2.17: edge = y; break
            lower_error = maxf(lower_error,absf(edge-(.616+.004*pow(x/.78,6))))
        check(lower_error < .004,tier+" smooth grille lower contour within four millimetres of guide")
        var contour: ArrayMesh = load(prefix+tier+"_body_contour.res")
        check(body.has_meta("car_surface_guide_locked") and hood.has_meta("car_surface_guide_locked") and contour.has_meta("car_surface_guide_locked"),tier+" compact panel boundaries survive production reduction")
        check(bool(contour.get_meta("bonnet_contour_baked",false)),tier+" bonnet marking is fitted offline")
        var decoded: ArrayMesh = preload("res://vehicle/panel_contour.gd").mesh(contour)
        check(decoded.has_meta("pixel_integrated_contour"),tier+" door and bonnet ribbons retain paired topology")
        var outline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefix+"bonnet_contour.json"))
        var smooth: float = 0
        for i: int in range(outline.points.size()):
            var a: Array = outline.points[posmod(i-1,outline.points.size())]
            var b: Array = outline.points[i]
            var c: Array = outline.points[(i+1)%outline.points.size()]
            var u := Vector3(a[0]-b[0],a[1]-b[1],a[2]-b[2])
            var v := Vector3(c[0]-b[0],c[1]-b[1],c[2]-b[2])
            if u.length() > .005 and v.length() > .005: smooth = maxf(smooth,(u.normalized()+v.normalized()).length())
        check(smooth < .25,tier+" clean bonnet edge has no angular kinks")
        var samples: int = 0
        var holes: int = 0
        var bonnet_skin: TriangleMesh = hood.generate_triangle_mesh()
        for i: int in range(1,outline.points.size()-1,3):
            var p: Array = outline.points[i]
            var previous: Array = outline.points[i-1]
            var next: Array = outline.points[i+1]
            var tangent := Vector3(next[0]-previous[0],0,next[2]-previous[2])
            var inward := Vector3(-tangent.z,0,tangent.x).normalized()
            # Determine loop orientation from the signed area.
            if inward.dot(Vector3(-p[0],0,-1.4-p[2])) < 0: inward = -inward
            var hit: Dictionary = bonnet_skin.intersect_ray(Vector3(p[0],1.3,p[2])+inward*.003,Vector3.DOWN)
            samples += 1
            if hit.is_empty(): holes += 1
        check(holes == 0,tier+" bonnet perimeter remains supported")
        metrics[tier] = {"door_longitudinal_error_mm":door_error*1000,"rear_second_difference_mm":rear_error*1000,"grille_lower_error_mm":lower_error*1000,"hood_corner_turn":smooth,"quarter_second_difference_mm":quarter_error*1000,"hidden_taillight_triangles":hidden_guides,"hood_edge_holes":holes,"hood_edge_samples":samples}
    var file := FileAccess.open("res://../docs/evidence/challenger-panel-corrections-2026-11-14/panels-"+label+".json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"));file.close()
    print("CHALLENGER_PANELS ",checks," checks, ",failures," failures; ",JSON.stringify(metrics))
    quit(1 if failures else 0)
