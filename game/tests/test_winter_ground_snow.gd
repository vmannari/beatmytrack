extends "res://tests/test_winter_snow_wind.gd"
const EVIDENCE: String = "res://../docs/evidence/winter-ground-snow-2026-10-13"

func _initialize() -> void:
    OUT = EVIDENCE+("/mobile" if RenderingServer.get_current_rendering_method() == "mobile" else "")
    super._initialize()

func capture(game: Node, fx: WinterSnowWind) -> void:
    check(not fx.surface_materials.is_empty() and fx.ground.multimesh.visible_instance_count == 0 and fx.powder.multimesh.visible_instance_count == 0,"actual opaque Winter surfaces replace floating powder cards")
    check(fx.surface_materials.all(func(m: ShaderMaterial) -> bool: return m.shader.code.contains("uniform vec2 wind_surface_car;")),"cached and fresh Winter shaders contain the current car-protection interface")
    check(fx.car_visual == game.car and is_instance_valid(fx.car_visual),"weather binds the actual car after startup creation")
    game.call("_process",0.0)
    fx._sync_surfaces()
    await super.capture(game,fx)
    await ground_capture(game,fx)

func settled(game: Node) -> Image:
    game.hud.pause_menu.hide()
    for frame: int in range(20): await RenderingServer.frame_post_draw
    return root.get_texture().get_image()

func ground_capture(game: Node, fx: WinterSnowWind) -> void:
    root.size = Vector2i(1280,720)
    var saved_aa: Viewport.MSAA = root.msaa_3d
    root.msaa_3d = Viewport.MSAA_DISABLED
    game.hud.visible = false
    var focus := Vector3(34,0,10)
    game.camera.position = focus+Vector3(0,20,15)
    game.camera.look_at(focus); game.camera.size = 29.0
    fx.elapsed = 5.0; fx.travel = 95.0; fx.intensity = 1.0
    fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
    fx.present(0.0,Vector2(34,-10),1.0,false,false)
    var snapshot: Array = game.sim.state.snapshot().duplicate(true)
    var originals: Array[Material] = []
    var initial_material_count: int = fx.surface_materials.size()
    for binding: Dictionary in fx.surface_bindings: originals.append(binding.original)
    fx.visible = false
    var baseline: Image = await settled(game)
    check(fx.surface_materials.all(func(m: ShaderMaterial) -> bool: return float(m.get_shader_parameter("wind_surface_strength")) == 0.0),"hidden weather disables opaque surface powder")
    fx.visible = true
    var powder: Image = await settled(game)
    var changed: int = 0
    for y: int in range(0,720,2):
        for x: int in range(0,1280,2):
            if powder.get_pixel(x,y) != baseline.get_pixel(x,y): changed += 1
    check(changed > 500,"actual opaque ground pigment and finish visibly carry moving powder")
    fx.present(0.25,Vector2(34,-10),1.0,true,false)
    check((await settled(game)).get_data() == powder.get_data(),"paused clock freezes actual opaque surface snow pixels")
    fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
    var previous_clock: float = fx.elapsed
    fx.present(0.25,Vector2(34,-10),1.0,false,false)
    check(is_equal_approx(fx.elapsed,previous_clock+0.25),"active diagnostic explicitly resumes OS background suspension and advances the presentation clock")
    var moved: Image = await settled(game)
    check(moved.get_data() != powder.get_data(),"surface powder moves while fixed ground geometry stays in place")
    fx.visible = false
    check((await settled(game)).get_data() == baseline.get_data(),"disabling powder restores original opaque world pixel-exactly")
    check(game.sim.state.snapshot() == snapshot,"ground powder leaves canonical driving snapshot exact")
    for material: Material in originals:
        if material is ShaderMaterial:
            check(float(material.get_shader_parameter("wind_surface_strength")) == 0.0,"prepared source material stays unmodified by race wind")
    var bindings: Array[Dictionary] = fx.surface_bindings.duplicate()
    fx._release_surfaces()
    var restored: bool = not bindings.is_empty()
    for binding: Dictionary in bindings:
        var mesh: MeshInstance3D = binding.node.get_ref()
        var actual: Material = mesh.material_override if binding.surface < 0 else mesh.get_surface_override_material(binding.surface)
        restored = restored and actual == binding.original
    check(restored and fx.surface_materials.is_empty(),"teardown restores exact original material identities without changing prepared resources")
    fx._bind_surfaces()
    fx.present(0.0,Vector2(34,-10),1.0,false,false)
    check(fx.surface_materials.size() == initial_material_count,"surface wind can rebind after restoration without accumulating material copies")
    fx.visible = true
    baseline.save_png(OUT+"/surface-before.png"); powder.save_png(OUT+"/surface-powder.png"); moved.save_png(OUT+"/surface-moved.png")
    var report := FileAccess.open(OUT+"/ground-powder.json",FileAccess.WRITE)
    report.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"changed_samples":changed,"surface_materials":fx.surface_materials.size(),"surface_bindings":fx.surface_bindings.size(),"floating_ground_cards":fx.ground.multimesh.visible_instance_count,"floating_bank_cards":fx.powder.multimesh.visible_instance_count,"grain_count":fx.airborne.multimesh.instance_count},"\t"))
    print("WINTER_GROUND_POWDER: ",changed," changed samples; ",fx.surface_materials.size()," run-owned materials")
    game.hud.visible = true
    root.msaa_3d = saved_aa
