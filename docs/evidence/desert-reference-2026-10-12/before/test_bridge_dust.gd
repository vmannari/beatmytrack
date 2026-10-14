extends SceneTree
## Actual GPU mask and emitter-layer lifecycle; canonical simulation is untouched.
var failures: int = 0
var checks: int = 0
var mask: ShaderMaterial
var dust: SandDust
var track: NativeTrack

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func bind_mask(upper: bool) -> void:
	var actual: ShaderMaterial = dust.dust_emitters[0].draw_pass_1.surface_get_material(0)
	for uniform: Dictionary in mask.shader.get_shader_uniform_list():
		if str(uniform.name).begins_with("dust_bridge_"):
			var value: Variant = actual.get_shader_parameter(uniform.name)
			if value!=null: mask.set_shader_parameter(uniform.name,value)
	mask.set_shader_parameter("dust_upper_layer",upper)

func pixel(point: Vector3, visible: bool, label: String) -> void:
	mask.set_shader_parameter("sample_world",point)
	await process_frame
	await RenderingServer.frame_post_draw
	var color: Color = root.get_texture().get_image().get_pixel(32,32)
	check(color.r>0.95 if visible else color.r<0.02,label)

func run() -> void:
	root.size = Vector2i(64,64)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.position.z = 3
	world.add_child(camera)
	camera.current = true
	var quad := MeshInstance3D.new()
	quad.mesh = QuadMesh.new()
	(quad.mesh as QuadMesh).size = Vector2(2,2)
	quad.extra_cull_margin = 16384
	world.add_child(quad)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
#include "res://vehicle/dust_bridge_clip.gdshaderinc"
uniform vec3 sample_world;
uniform bool surface_sample = false;
uniform bool birth_sample = false;
uniform float particle_height = 0.0;
void vertex() { POSITION = vec4(VERTEX.xy,1.0,1.0); }
void fragment() { ALBEDO = vec3(1.0); ALPHA = surface_sample ? dust_bridge_surface_visibility(sample_world,particle_height) : (birth_sample ? dust_bridge_visibility_at_height(sample_world,particle_height) : dust_bridge_visibility(sample_world)); }
"""
	mask = ShaderMaterial.new()
	mask.shader = shader
	quad.material_override = mask
	dust = SandDust.new()
	world.add_child(dust)
	track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.theme = "desert"
	track.cells.fill(2)
	track.deck_cells.fill(0)
	var state := VehicleState.new()
	state.velocity = Vector2(0,12)
	for angle: float in [0.0,37.0,90.0,213.0]:
		var span: Dictionary = {"kind":"bridge","position":[-10.0,-6.0],"heading":angle,"length":32.0,"width":10.0}
		track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
		track.metadata.theme = "desert"
		track.cells.fill(2)
		track.deck_cells.fill(0)
		track.creator_bridges = [span]
		var center: Vector2 = Vector2(-10,-6)+Vector2(16,0).rotated(deg_to_rad(angle))
		state.position = center
		state.track_elevated = false
		var snapshot: Array = state.snapshot()
		dust.sample(state,DriveFrame.new(),track,BridgePresentation.new(track))
		check(state.snapshot()==snapshot,"dust sampling never changes canonical state")
		bind_mask(false)
		await pixel(VisualGeometry.world(center)+Vector3.UP, true,"ground haze remains below the roof")
		await pixel(VisualGeometry.world(center)+Vector3.UP*4.5, false,"ground cloud cannot cross the rotated deck")
		var outside: Vector2 = center+Vector2(0,8).rotated(deg_to_rad(angle))
		await pixel(VisualGeometry.world(outside)+Vector3.UP*4.5,true,"open-air dust is not clipped")
		bind_mask(true)
		await pixel(VisualGeometry.world(center)+Vector3.UP*4.5,true,"deck dust remains visible above its road")
		await pixel(VisualGeometry.world(center)+Vector3.UP,false,"deck cloud cannot spill into the underpass")
		mask.set_shader_parameter("surface_sample",true)
		mask.set_shader_parameter("particle_height",0.7)
		await pixel(VisualGeometry.world(center)+Vector3.UP*3.525,false,"low-ramp upper particle cannot cover a higher opaque roof")
		await pixel(VisualGeometry.world(center),true,"open underpass ground does not become a roof mask")
		mask.set_shader_parameter("particle_height",3.525)
		await pixel(VisualGeometry.world(center)+Vector3.UP*3.525,true,"newly emitted deck particle retains above-deck visibility")
		mask.set_shader_parameter("surface_sample",false)
		mask.set_shader_parameter("birth_sample",true)
		mask.set_shader_parameter("particle_height",0.7)
		await pixel(VisualGeometry.world(center)+Vector3.UP,true,"low-ramp upper puff may linger beneath a higher bridge")
		await pixel(VisualGeometry.world(center)+Vector3.UP*4.5,false,"low-ramp upper puff cannot rise through a higher bridge")
		mask.set_shader_parameter("birth_sample",false)
		var ramp: Vector2 = Vector2(-10,-6)+Vector2(2,0).rotated(deg_to_rad(angle))
		bind_mask(false)
		await pixel(VisualGeometry.world(ramp)+Vector3.UP*2,false,"ground dust is blocked by the ramp")
		for along: float in [6.0,8.0,12.0,16.0,24.0,26.0]:
			var point: Vector2 = Vector2(-10,-6)+Vector2(along,0).rotated(deg_to_rad(angle))
			var roof: float = CreatorBridges.height(span,point)+DesertBridgeVisual.underside(span,along)
			await pixel(VisualGeometry.world(point)+Vector3.UP*(roof-0.3),true,"visible haze remains below actual sandstone soffit")
			await pixel(VisualGeometry.world(point)+Vector3.UP*(roof+0.1),false,"dust stops at actual arch/ramp underside")
	var original: ShaderMaterial = dust.dust_emitters[0].draw_pass_1.surface_get_material(0)
	state.track_elevated = true
	dust.sample(state,DriveFrame.new(),track,BridgePresentation.new(track))
	check(dust.deck_dust_emitters.size()==4 and dust.deck_tyre_emitters.size()==4,"deck clouds are lazily created for each wheel")
	check(not dust.dust_emitters[0].emitting and dust.deck_dust_emitters[0].emitting,"only the current emission layer spawns particles")
	check(dust.dust_emitters[0].draw_pass_1.surface_get_material(0)==original and original.get_shader_parameter("dust_upper_layer")==false,"lingering ground puffs retain their original layer/material")
	var upper: ShaderMaterial = dust.deck_dust_emitters[0].draw_pass_1.surface_get_material(0)
	check(upper!=original and upper.get_shader_parameter("dust_upper_layer")==true,"deck particles have independent layer state")
	check(upper.get_shader_parameter("dust_birth_height_available")==true and dust.deck_dust_emitters[0].process_material is ShaderMaterial,"desert deck particles record immutable birth height")
	var source: ParticleProcessMaterial = dust._deck_cloud_sources[dust.deck_dust_emitters[0]]
	var converted: ShaderMaterial = dust.deck_dust_emitters[0].process_material
	for key: String in ["gravity","spread","damping_min","damping_max","scale_min","scale_max","initial_linear_velocity_min","initial_linear_velocity_max"]:
		check(converted.get_shader_parameter(key)==RenderingServer.material_get_param(source.get_rid(),key),"native dust motion uniform retained: "+key)
	check(converted.get_shader_parameter("color_ramp")==source.color_ramp and converted.get_shader_parameter("scale_curve")==source.scale_curve and converted.get_shader_parameter("angular_velocity_texture")==source.angular_velocity_curve,"native colour/growth/rotation curves retained")
	check(dust.deck_dust_emitters[0].lifetime==1.4 and dust.dust_emitters[0].lifetime==1.4,"both layers use owner localized dust lifetime")
	state.track_elevated = false
	dust.sample(state,DriveFrame.new(),track,BridgePresentation.new(track))
	check(dust.dust_emitters[0].emitting and not dust.deck_dust_emitters[0].emitting and upper.get_shader_parameter("dust_upper_layer")==true,"leaving a deck does not reclassify its lingering cloud")
	dust.clear()
	check(dust.cloud_emitters().all(func(emitter: GPUParticles3D) -> bool: return not emitter.emitting),"restart clears both particle layers")
	var last_span: Dictionary = track.creator_bridges[0]
	track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.theme = "desert"
	for index: int in range(15): track.creator_bridges.append({"position":[1000.0+index*40,1000.0],"heading":0.0,"length":32.0,"width":10.0})
	track.creator_bridges.append(last_span)
	dust.sample(state,DriveFrame.new(),track)
	bind_mask(false)
	await pixel(VisualGeometry.world(state.position)+Vector3.UP*4.5,false,"the sixteenth supported bridge is included")
	var crossing: Dictionary = last_span.duplicate(true)
	crossing.heading = float(last_span.heading)+90.0
	var origin: Vector2 = state.position-Vector2(16,0).rotated(deg_to_rad(float(crossing.heading)))
	crossing.position = [origin.x,origin.y]
	check(CreatorBridges.validate([last_span,crossing]).is_empty(),"junction witness has approved matching deck heights")
	track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.theme = "desert"
	track.creator_bridges = [last_span,crossing]
	dust.sample(state,DriveFrame.new(),track)
	bind_mask(false)
	await pixel(VisualGeometry.world(state.position)+Vector3.UP*4.5,false,"overlapping spans cannot expose a ground cloud")
	dust.bridge_clipping_enabled = false
	bind_mask(false)
	await pixel(VisualGeometry.world(state.position)+Vector3.UP*4.5,true,"diagnostic control reproduces unmasked bridge dust")
	dust.bridge_clipping_enabled = true
	bind_mask(false)
	await pixel(VisualGeometry.world(state.position)+Vector3.UP*4.5,false,"restoring clipping keeps the same bridge geometry")
	track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	dust.sample(state,DriveFrame.new(),track)
	bind_mask(false)
	await pixel(VisualGeometry.world(state.position)+Vector3.UP*4.5,true,"a track without bridges keeps original cloud visibility")
	# Witness actual particle CUSTOM data after lofting and moving its emitter.
	quad.visible = false
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0
	camera.position = Vector3(0,3,12)
	camera.look_at(Vector3(0,3,0))
	var birth_particles := GPUParticles3D.new()
	birth_particles.amount = 1
	birth_particles.lifetime = 9.0
	birth_particles.one_shot = true
	birth_particles.explosiveness = 1.0
	birth_particles.local_coords = false
	birth_particles.visibility_aabb = AABB(Vector3(-20,-20,-20),Vector3(40,40,40))
	var birth_process: ShaderMaterial = converted.duplicate()
	for key: String in ["initial_linear_velocity_min","initial_linear_velocity_max","damping_min","damping_max"]: birth_process.set_shader_parameter(key,0.0)
	birth_process.set_shader_parameter("gravity",Vector3(0,1,0))
	birth_particles.process_material = birth_process
	var birth_draw := ShaderMaterial.new()
	var birth_shader := Shader.new()
	birth_shader.code = """shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
varying float birth;
varying float loft;
void vertex() { birth = INSTANCE_CUSTOM.z; loft = MODEL_MATRIX[3].y; }
void fragment() { ALBEDO = abs(birth-0.7)>0.01 ? vec3(1,0,0) : (loft>3.0 ? vec3(0,1,0) : vec3(0,0,1)); }
"""
	birth_draw.shader = birth_shader
	var birth_mesh := QuadMesh.new()
	birth_mesh.size = Vector2(0.5,0.5)
	birth_mesh.material = birth_draw
	birth_particles.draw_pass_1 = birth_mesh
	birth_particles.position.y = 0.7
	world.add_child(birth_particles)
	birth_particles.restart()
	await create_timer(0.5).timeout
	birth_particles.position.y = 4.0
	await create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	var birth_image: Image = root.get_texture().get_image()
	var green: int = 0
	var red: int = 0
	for y: int in range(birth_image.get_height()):
		for x: int in range(birth_image.get_width()):
			var color: Color = birth_image.get_pixel(x,y)
			if color.g>0.9 and color.r<0.1: green += 1
			if color.r>0.9 and color.g<0.1: red += 1
	check(green>4,"actual lofted GPU puff retains its low birth height after emitter moves to the deck")
	check(red==0,"no particle reclassifies its birth height while aging")
	print("BRIDGE_DUST_TESTS: ",checks," checks, ",failures," failures")
	world.free()
	quit(1 if failures else 0)
