extends SceneTree
var checks: int = 0
var failures: int = 0
var evidence: String
var helper = preload("res://tests/fixtures/editor_t05_t11_before/prop_comparison.gd").new()
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures += 1; print("FAIL: ",label)
func compare_props(theme_id: String) -> void:
    var track: NativeTrack = helper.props_fixture(theme_id)
    var old := NativeTrackVisual.new(); old.theme_id = theme_id; old.colors = TrackTheme.palette(theme_id)
    var fresh := NativeTrackVisual.new(); fresh.theme_id = theme_id; fresh.colors = old.colors
    var viewport := SubViewport.new(); viewport.size = Vector2i(1280,720); viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var stage := Node3D.new(); viewport.add_child(stage)
    stage.add_child(old); stage.add_child(fresh)
    await old._build_placed_objects(track)
    if "--same-source" in OS.get_cmdline_user_args(): await fresh._build_placed_objects(track)
    else: await fresh.refresh_editor_objects(track,false)
    if "--single-craft" in OS.get_cmdline_user_args():
        var components: Array = []
        for key: String in fresh.editor_objects._editor_authored_batches.baked_plan:
            if key.begins_with("opaque:winter_craft:"):
                components.append_array(fresh.editor_objects._editor_authored_batches.baked_plan[key].components)
        for child: Node in fresh.editor_objects.get_children():
            if child is MeshInstance3D and child.material_override==PropWinterCraft.material(): child.free()
        var single := MeshInstance3D.new()
        single.mesh = preload("res://editor/placed_object_batches.gd")._assemble(components)
        single.material_override=PropWinterCraft.material()
        fresh.add_child(single)
    if "--lighting-bounds" in OS.get_cmdline_user_args():
        var box := AABB()
        for child: Node in old.get_children():
            if child.name=="WinterCraft": box = child.mesh.get_aabb()
        for child: Node in fresh.editor_objects.get_children():
            if child is MeshInstance3D and child.material_override==PropWinterCraft.material(): child.custom_aabb = box
    var original_triangles: Dictionary = helper.triangles(old)
    var updated_triangles: Dictionary = helper.triangles(fresh)
    check(helper.same_triangles(original_triangles,updated_triangles),theme_id+" triangle multiplicity, pigments, positions and normals are exact")
    var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 75
    stage.add_child(camera); camera.look_at_from_position(Vector3(0,88,-78),Vector3(0,0,-1)); camera.current = true
    var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-58,-35,0); light.shadow_enabled = "--no-shadows" not in OS.get_cmdline_user_args()
    stage.add_child(light)
    var ambient := WorldEnvironment.new(); ambient.environment = Environment.new()
    ambient.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; ambient.environment.ambient_light_energy = 0.45
    ambient.environment.background_mode = Environment.BG_COLOR; ambient.environment.background_color = Color("45535a")
    stage.add_child(ambient)
    for node: Node in stage.find_children("*","Node",true,false):
        if node is NightPropEffects:
            node.externally_ticked = true; node.elapsed = 0.0; node._publish()
    await process_frame
    for object: Dictionary in track.metadata.creator_document.objects:
        var p: Vector2 = camera.unproject_position(Vector3(object.position[0],0,-object.position[1]))
        if p.distance_to(Vector2(721,173))<70.0:print("NEAR_DIFFERENCE ",object," projected=",p)
    if DisplayServer.get_name() != "headless":
        fresh.hide(); old.show()
        for frame: int in range(6): await RenderingServer.frame_post_draw
        var before: Image = viewport.get_texture().get_image()
        old.hide(); fresh.show()
        for frame: int in range(6): await RenderingServer.frame_post_draw
        var after: Image = viewport.get_texture().get_image()
        before.save_png(evidence+"/"+theme_id+"-original.png"); after.save_png(evidence+"/"+theme_id+"-incremental.png")
        var a: PackedByteArray = before.get_data(); var b: PackedByteArray = after.get_data()
        var maximum: int = 0; var changed: int = 0
        for index: int in range(a.size()):
            var delta: int = absi(int(a[index])-int(b[index]))
            maximum = maxi(maximum,delta)
            if delta > 0: changed += 1
        print("EDITOR_INCREMENTAL_PIXELS ",theme_id," changed_channels=",changed," maximum=",maximum)
        check(maximum == 0,theme_id+" paired authored pixels preserve original shading exactly")
    if "--same-source" in OS.get_cmdline_user_args():
        viewport.queue_free(); await process_frame; return
    # Forced yield followed by a newer immediate edit must publish only the newest data.
    var obsolete: NativeTrack = helper.props_fixture(theme_id)
    obsolete.metadata.creator_document.objects[0].position[0] += 4.0
    var latest: NativeTrack = helper.props_fixture(theme_id)
    latest.metadata.creator_document.objects.append({"kind":"tyre_stack","position":[3.0,4.0],"rotation":0.0})
    latest.tyre_origins = LooseTyres.positions(latest.metadata.creator_document)
    fresh.refresh_editor_objects(obsolete,false,true)
    fresh.refresh_editor_objects(latest,false,false)
    for frame: int in range(3): await process_frame
    check(fresh.editor_objects.tyre_instances.multimesh.instance_count == latest.tyre_origins.size(),theme_id+" late refresh retains latest tyre population")
    check(fresh.editor_objects._editor_authored_batches.sources == latest.metadata.creator_document.objects,theme_id+" superseded refresh cannot replace current authored sources")
    viewport.queue_free(); await process_frame

func run() -> void:
 evidence = ProjectSettings.globalize_path("res://../docs/evidence/editor-t05-t11-2026-10-23/")+ ("pixel-no-shadows" if "--no-shadows" in OS.get_cmdline_user_args() else "pixel-frozen")
 DirAccess.make_dir_recursive_absolute(evidence)
 for theme: String in ["pine","winter","night_city"]: await compare_props(theme)
 print("PIXEL_PROBE ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
