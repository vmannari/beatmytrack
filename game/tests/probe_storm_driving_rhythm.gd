extends SceneTree
## Development pace review. Ordinary inputs and actual checkpoint/lap rules.
const IDS: Array[String] = ["storm_freight","storm_switchyard","storm_timber","storm_quarry","storm_floodgate"]
const OUT: String = "res://../docs/evidence/storm-driving-variety-2026-10-26"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var rows: Array = []
	var before: bool = "--before" in OS.get_cmdline_user_args()
	for id: String in IDS:
		var source: String = ("res://../docs/evidence/storm-driving-variety-2026-10-26/before/game/resources/storm_tracks/" if before else "res://resources/storm_tracks/")+id+".json"
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
		var track: NativeTrack = TrackCompiler.compile(doc)
		var config: HandlingConfig = VehicleCatalog.config("compact")
		var candidates: Array = []
		for method: String in ["minimum_curvature","center"]:
			var trajectory := RacingTrajectory.new()
			trajectory.build(track,config,method)
			var driver := ProfiledRouteDriver.new({"seed":27,"skill":0.9,"consistency":1.0,"aggression":0.5,"learning":0.0,"strengths":{}},"storm",track.content_hash,0)
			driver.trajectory = trajectory
			var sim := VehicleSimulation.new(config)
			sim.reset(track.spawn,track.spawn_heading)
			sim.state.route_index = track.nearest_route(track.spawn)
			var session := TrackSession.new(120,3)
			var trace: Array = []
			var speeds := PackedFloat32Array()
			var brake_zones: Array = []
			var last_brake: int = -1000
			for tick: int in range(40000):
				var frame: DriveFrame = driver.sample(sim.state,track,config,session)
				var previous: Vector2 = sim.state.position
				sim.step(frame,track)
				session.advance(track,previous,sim.state.position,sim.state.route_index,sim.state.track_elevated)
				if session.completed_laps==1:
					if tick%12==0:
						speeds.append(sim.state.velocity.length()*3.6)
						trace.append([tick,sim.state.position.x,sim.state.position.y,sim.state.velocity.length()*3.6,frame.steer,frame.throttle,frame.brake])
					if frame.brake>30:
						if tick-last_brake>60: brake_zones.append(track.route_progress(sim.state.position,sim.state.route_index))
						last_brake=tick
				if session.finished or session.missed_checkpoint>=0: break
			var row: Dictionary = {"strategy":method,"finished":session.finished,"laps":session.lap_times,"contacts":sim.state.collision_count,"missed_checkpoint":session.missed_checkpoint,"braking_zones_flying_lap":brake_zones,"trace":trace,"speed_min_kmh":Array(speeds).min() if not speeds.is_empty() else 0,"speed_max_kmh":Array(speeds).max() if not speeds.is_empty() else 0}
			candidates.append(row)
			print("STORM_PACE ",id," ",method," finished=",row.finished," laps=",row.laps," contacts=",row.contacts," speeds=",row.speed_min_kmh,"..",row.speed_max_kmh," brake_zones=",brake_zones.size())
			if row.finished and row.contacts==0: break
		rows.append({"id":id,"source_sha256":FileAccess.get_sha256(source),"candidates":candidates})
		var file := FileAccess.open(OUT+("/pace-before.json" if before else "/pace-review.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"physics":VehicleSimulation.PHYSICS_VERSION,"driver":ProfiledRouteDriver.VERSION,"tracks":rows},"\t")); file.close()
	quit()
