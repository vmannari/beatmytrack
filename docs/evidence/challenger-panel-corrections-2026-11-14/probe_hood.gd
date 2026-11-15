extends SceneTree
func _initialize() -> void:
    var mesh: ArrayMesh = load("res://assets/vehicles/challenger_hellcat_v1/full_hood_paint.res")
    var tree: TriangleMesh = mesh.generate_triangle_mesh()
    var point := Vector2(.181364,-.978308)
    var faces: PackedVector3Array = mesh.get_faces()
    for i: int in range(0,faces.size(),3):
        var a: Vector3 = faces[i];var b: Vector3=faces[i+1];var c: Vector3=faces[i+2]
        if Geometry2D.is_point_in_polygon(point,PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])):
            print("COVERING ",a," ",b," ",c," cross_y=",(b-a).cross(c-a).y)
    for dz: float in [-.006,-.004,-.002,-.001,0,.001,.002,.004]:
        var row: String = ""
        for dx: float in [-.004,-.002,-.001,0,.001,.002,.004]: row += "." if tree.intersect_ray(Vector3(point.x+dx,1.1,point.y+dz),Vector3.DOWN).is_empty() else "X"
        print(dz," ",row)
    quit()
