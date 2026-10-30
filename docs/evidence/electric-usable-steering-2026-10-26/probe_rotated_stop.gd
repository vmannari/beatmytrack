extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var old: HandlingConfig=load("res://../docs/evidence/electric-usable-steering-2026-10-26/before/game__resources__cars__electric.tres") as HandlingConfig
	var current: HandlingConfig=VehicleCatalog.config("electric")
	var a:=VehicleSimulation.new(old)
	var b:=VehicleSimulation.new(current)
	for sim: VehicleSimulation in [a,b]:
		sim.reset(Vector2.ZERO,PI*0.5-deg_to_rad(0.289567684131689))
		sim.state.velocity=sim.state.forward()*-7.0
	var exact: bool=true
	for tick: int in range(40):
		a.step(DriveFrame.sample(0,0,1))
		b.step(DriveFrame.sample(0,0,1))
		exact=exact and a.state.snapshot()==b.state.snapshot()
	var result: Dictionary={"old_velocity":[a.state.velocity.x,a.state.velocity.y],"new_velocity":[b.state.velocity.x,b.state.velocity.y],"snapshots_exact":exact}
	var file:=FileAccess.open("res://../docs/evidence/electric-usable-steering-2026-10-26/rotated-stop.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("ROTATED_STOP ",JSON.stringify(result))
	quit()
