extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func run() -> void:
	cases()
	await process_frame
	print("DENSE_TYRE_CONTACTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func cases() -> void:
	check(ClassDB.class_exists("BmtTyreContacts"),"matching native tyre kernel is installed")
	if failures: return
	var original := GDScript.new()
	original.source_code = FileAccess.get_file_as_string("res://tests/fixtures/gameplay_f04_f05_before/loose_tyres.gd.txt").replace("\r\n","\n").replace("class_name LooseTyres\n","")
	check(original.reload() == OK,"task-original solver compiles independently")
	var random := RandomNumberGenerator.new(); random.seed = 2026102304
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var wall: Callable = func(p: Vector2,r: float,_e: bool) -> Vector3: return Vector3(1,0,1) if absf(p.x)+r > 12 else Vector3.ZERO
	for count: int in [48,96,192,576]:
		for layout: int in range(5):
			var origins := PackedVector2Array()
			var a := VehicleState.new(); var b := VehicleState.new()
			for index: int in range(count):
				var p := Vector2.ZERO
				if layout == 1: p = Vector2((index%24)*1.0-12,(index/24)*1.0)
				if layout == 2: p = Vector2((index%12)*0.6-3,(index/12)*0.6)
				if layout == 3: p = Vector2(random.randf_range(-2,2),random.randf_range(-2,2))
				if layout == 4: p = Vector2((index%24)*2+20,(index/24)*2+20)
				origins.append(p)
				var v := Vector2(random.randf_range(-12,12),random.randf_range(-12,12)) if layout == 3 else Vector2.ZERO
				a.loose_tyres.append([p.x,p.y,v.x,v.y,-0.0 if index%2 == 0 else -TAU])
			b.loose_tyres = a.loose_tyres.duplicate(true)
			a.position = Vector2(0,-4); b.position = a.position
			var saved: Dictionary = {}
			for tick: int in range(3 if count == 576 else 12 if count == 192 else 60):
				var previous: Vector2 = a.position
				a.velocity = Vector2(sin(tick*0.31)*8,12); b.velocity = a.velocity
				a.position += a.velocity*VehicleSimulation.STEP; b.position += b.velocity*VehicleSimulation.STEP
				a.track_elevated = tick%17 > 12; b.track_elevated = a.track_elevated
				original.step(a,origins,wall,previous,config,VehicleSimulation.STEP)
				LooseTyres.step(b,origins,wall,previous,config,VehicleSimulation.STEP)
				check(var_to_bytes(a.snapshot()) == var_to_bytes(b.snapshot()),"byte exact count %d layout %d tick %d" % [count,layout,tick])
				if failures:
					for index: int in range(a.snapshot().size()):
						if var_to_bytes(a.snapshot()[index]) != var_to_bytes(b.snapshot()[index]): print("DIFF_FIELD ",index," before=",a.snapshot()[index]," after=",b.snapshot()[index])
					return
				if tick == 5: saved = RewindHistory.properties(a)
				if tick == 10: RewindHistory.restore(a,saved); RewindHistory.restore(b,saved)
				if tick == 15:
					a.loose_tyres[0][0] += 0.02; b.loose_tyres[0][0] += 0.02
				if tick == 25:
					a.loose_tyres.append([8.0,8.0,1.0,0.0,0.0]); b.loose_tyres.append([8.0,8.0,1.0,0.0,0.0])
			check(b.has_meta(&"native_tyre_contacts"),"dense scenario executes compiled path")
			check(not RewindHistory.properties(b).has("native_tyre_contacts"),"native scratch stays out of rewind/score state")
	# The exact base-track certificate can skip only empty world-query regions.
	for layout: int in range(3):
		var track := NativeTrack.new(); track.grid_width = 64; track.grid_height = 64; track.half_extent = Vector2(16,16); track.cell_size = 0.5
		track.cells.resize(4096); track.cells.fill(4 if layout == 2 else 1)
		if layout == 1:
			for y: int in range(64): track.cells[y*64+38] = 4
		var origins := PackedVector2Array()
		var a := VehicleState.new(); var b := VehicleState.new()
		for index: int in range(96):
			var p := Vector2(random.randf_range(-2,2),random.randf_range(-2,2))
			origins.append(p); a.loose_tyres.append([p.x,p.y,0.0,0.0,0.0])
		b.loose_tyres = a.loose_tyres.duplicate(true)
		a.position = Vector2(0,-4); b.position = a.position
		var clear_count: int = 0; var full_count: int = 0
		for tick: int in range(20):
			var previous: Vector2 = a.position
			a.velocity = Vector2(1,10); b.velocity = a.velocity
			a.position += a.velocity*VehicleSimulation.STEP; b.position += b.velocity*VehicleSimulation.STEP
			original.step(a,origins,track._contact,previous,config,VehicleSimulation.STEP)
			LooseTyres.step(b,origins,track._contact,previous,config,VehicleSimulation.STEP)
			check(var_to_bytes(a.snapshot()) == var_to_bytes(b.snapshot()),"grid-certified contacts exact including walls/boundary/mutation: %d/%d" % [layout,tick])
			var counters: Dictionary = b.get_meta(&"native_tyre_contacts").work_stats()
			clear_count += int(counters.clear_queries); full_count += int(counters.full_queries)
			if tick == 10: track.cells[33*64+33] = 4
		check(clear_count>0 if layout == 0 else full_count>0,"exercise certified clear or original solid query path: "+str(layout))
	var origins := PackedVector2Array()
	for index: int in range(48): origins.append(Vector2.ZERO)
	for repeat: int in range(100):
		var disposable := VehicleState.new(); disposable.position = Vector2(-20,-20)
		LooseTyres.step(disposable,origins,wall,disposable.position,config,VehicleSimulation.STEP)
		var solver_ref: WeakRef = weakref(disposable.get_meta(&"native_tyre_contacts"))
		disposable = null
		check(solver_ref.get_ref() == null,"canonical owner release frees native scratch")
