extends SceneTree
const OUTPUT: String="res://../docs/evidence/barrel-slowdown-2026-10-17"
var checks: int=0
var failures: int=0
var metrics: Array=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: ",label)
func object() -> Dictionary: return {"kind":"burning_barrel","position":[0.0,0.0],"rotation":0.0,"scale":1.0}
func clear(_p: Vector2,_radius: float,_layer: bool) -> Vector3: return Vector3.ZERO
func run() -> void:
	compare_slowdown()
	var old:=GDScript.new(); old.source_code=FileAccess.get_file_as_string("res://tests/fixtures/barrel_resistance_before/burning_barrel.gd.txt").replace("\r\n","\n").replace("class_name BurningBarrel\n","")
	check(old.reload()==OK,"preserved140kg implementation compiles")
	var config: HandlingConfig=load("res://resources/balanced.tres")
	var a:=VehicleState.new(); a.position=Vector2(-1.8,0); a.velocity=Vector2(12,0)
	var b:=VehicleState.new(); b.position=a.position; b.velocity=a.velocity
	var old_row: Array=old.initial(object()); var row: Array=BurningBarrel.initial(object())
	old.step(a,object(),old_row,clear,Vector2(-1.9,0),VehicleSimulation.STEP,config.mass,config.collision_radius)
	BurningBarrel.step(b,object(),row,clear,Vector2(-1.9,0),VehicleSimulation.STEP,config.mass,config.collision_radius)
	check(12-b.velocity.x>(12-a.velocity.x)*4,"tuned impact still takes over four times more speed than the old light barrel")
	check(row[2]<old_row[2] and b.position.distance_to(Vector2(row[0],row[1]))>=config.collision_radius+0.519,"barrel moves less while holding the car outside its body")
	metrics.append({"comparison":"single12mps_hit","old_mass":140,"new_mass":BurningBarrel.MASS,"old_car_loss_mps":12-a.velocity.x,"new_car_loss_mps":12-b.velocity.x,"old_barrel_speed_mps":old_row[2],"new_barrel_speed_mps":row[2]})
	var glancing:=VehicleState.new(); glancing.position=Vector2(-1.8,0); glancing.velocity=Vector2(8,6)
	BurningBarrel.step(glancing,object(),BurningBarrel.initial(object()),clear,Vector2(-1.9,0),VehicleSimulation.STEP,config.mass,config.collision_radius)
	check(glancing.velocity.y==6 and glancing.velocity.x<8,"contact removes normal speed and preserves tangential travel")
	var fast:=VehicleState.new(); fast.position=Vector2(4,0); fast.velocity=Vector2(40,0)
	BurningBarrel.step(fast,object(),BurningBarrel.initial(object()),clear,Vector2(-4,0),VehicleSimulation.STEP,config.mass,config.collision_radius)
	check(fast.position.x<0,"a swept hit cannot eject the car onto the far side of the barrel")
	var wall:=VehicleState.new(); wall.position=Vector2(-1.8,0); wall.velocity=Vector2(12,0)
	var guarded: Callable=func(p: Vector2,radius: float,_layer: bool) -> Vector3: return Vector3(1,0,1) if radius>1.0 and p.x>-2.5 else Vector3.ZERO
	BurningBarrel.step(wall,object(),BurningBarrel.initial(object()),guarded,Vector2(-3,0),VehicleSimulation.STEP,config.mass,config.collision_radius)
	check(wall.position==Vector2(-3,0),"car separation falls back to the clear previous point instead of entering a wall")
	for airborne: bool in [true,false]:
		var state:=VehicleState.new(); state.position=Vector2(-1.8,0); state.velocity=Vector2(12,0); state.jump_height=1 if airborne else 0; state.track_elevated=not airborne
		BurningBarrel.step(state,object(),BurningBarrel.initial(object()),clear,Vector2(-1.9,0),VehicleSimulation.STEP,config.mass,config.collision_radius)
		check(state.position==Vector2(-1.8,0) and state.velocity==Vector2(12,0),"ground barrel leaves airborne/bridge car unchanged")
	for car: String in VehicleCatalog.IDS:
		for speed: float in [12.0,24.0]: driving(car,speed)
	print("BARREL_RESISTANCE_METRICS: ",JSON.stringify(metrics))
	print("BARREL_RESISTANCE: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
func document(barrel: bool=true) -> Dictionary:
	var doc: Dictionary=TrackDocument.create_default(); doc.theme="night_city"; doc["automatic_scenery"]=false
	doc.paint=[{"surface":0,"width":40.0,"shape":"square","points":[[-20,0],[100,0]]}]; doc.objects=[object()] if barrel else []
	return doc
func driving(car: String,speed: float) -> void:
	var track: NativeTrack=TrackCompiler.compile(document()); var empty: NativeTrack=TrackCompiler.compile(document(false))
	check(track!=null and empty!=null,"driving/control documents compile: "+str(TrackDocument.validate(document())))
	if track==null or empty==null: return
	var sim:=VehicleSimulation.new(VehicleCatalog.config(car)); var control:=VehicleSimulation.new(VehicleCatalog.config(car)); var replay:=VehicleSimulation.new(VehicleCatalog.config(car))
	for run: VehicleSimulation in [sim,control,replay]: run.reset(Vector2(-6,0),PI*0.5); run.state.velocity=Vector2(speed,0)
	var input:=DriveFrame.new(); input.throttle=255
	var first_hit: int=-1; var loss: float=0.0; var speed_after_contact: float=0.0; var clearances: bool=true
	var mid: Dictionary; var branch: Array=[]; var packed: Array=[]
	for tick: int in range(360):
		var before_speed: float=sim.state.velocity.x
		sim.step(input,track); control.step(input,empty); packed.append(input.packed())
		var row: Array=sim.state.light_props[0]
		if first_hit<0 and float(row[10])>=0: first_hit=tick; loss=(before_speed-sim.state.velocity.x)/before_speed
		if first_hit>=0:
			var reach: float=sim.config.collision_radius+lerpf(0.52,0.76,sin(float(row[4])))
			clearances=clearances and sim.state.position.distance_to(Vector2(row[0],row[1]))>=reach-0.02
		if tick==first_hit+12 and first_hit>=0: speed_after_contact=sim.state.velocity.x
		if tick==180: mid=RewindHistory.properties(sim.state)
		if tick==240: branch=sim.state.snapshot()
	check(first_hit>=0 and loss>=0.095,car+" retains meaningful first-hit slowdown at "+str(speed))
	check(speed_after_contact<speed*0.55,car+" loses over45% speed within0.1s of continued contact")
	check(clearances,car+" never passes through the barrel during powered pushing")
	check(sim.state.velocity.x<3.0 and control.state.velocity.x>15,car+" pushing is limited to walking speed while the clear car reaches racing speed")
	for values: Array in JSON.parse_string(JSON.stringify(packed)):
		var frame:=DriveFrame.new(); frame.throttle=values[1]; replay.step(frame,track)
	check(sim.state.snapshot()==replay.state.snapshot(),car+" contact and fuel state replay exactly from JSON inputs")
	RewindHistory.restore(sim.state,mid)
	for tick: int in range(60): sim.step(input,track)
	check(sim.state.snapshot()==branch,car+" rewind restores the same continued pushing branch")
	metrics.append({"car":car,"incoming_mps":speed,"first_hit_loss_percent":loss*100,"speed_after0_1s_mps":speed_after_contact,"end_speed_mps":replay.state.velocity.x,"unobstructed_speed_mps":control.state.velocity.x,"car_x":replay.state.position.x,"barrel_x":replay.state.light_props[0][0]})

func compare_slowdown() -> void:
	var old:=GDScript.new(); old.source_code=FileAccess.get_file_as_string("res://tests/fixtures/barrel_slowdown_before/burning_barrel.gd.txt").replace("\r\n","\n").replace("class_name BurningBarrel\n","")
	check(old.reload()==OK,"preserved400kg implementation compiles")
	for car: String in VehicleCatalog.IDS:
		var config: HandlingConfig=VehicleCatalog.config(car)
		for scale: float in [0.5,1.0,2.5]:
			for speed: float in [3.0,12.0,24.0]:
				var prop: Dictionary=object(); prop.scale=scale
				var a:=VehicleState.new(); a.position=Vector2(-0.2,0); a.velocity=Vector2(speed,6)
				var b:=VehicleState.new(); b.position=a.position; b.velocity=a.velocity
				var previous: Vector2=a.position-Vector2(0.1,0)
				var old_row: Array=old.initial(prop); var row: Array=BurningBarrel.initial(prop)
				old.step(a,prop,old_row,clear,previous,VehicleSimulation.STEP,config.mass,config.collision_radius)
				BurningBarrel.step(b,prop,row,clear,previous,VehicleSimulation.STEP,config.mass,config.collision_radius)
				var old_loss: float=speed-a.velocity.x; var loss: float=speed-b.velocity.x
				check(absf(loss-old_loss*0.7)<0.00001,car+" slowdown reduced30% at scale "+str(scale)+" speed "+str(speed))
				check(b.velocity.y==6 and row==old_row and b.position==a.position,car+" retains tangent, drum motion, toppling, spill and separation")
				if scale==1.0 and speed==12.0: metrics.append({"comparison":"30_percent_reduction","car":car,"old_car_loss_mps":old_loss,"new_car_loss_mps":loss,"ratio":loss/old_loss})
