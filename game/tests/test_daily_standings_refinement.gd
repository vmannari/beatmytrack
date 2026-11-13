extends SceneTree
const Board = preload("res://ui/daily_standings.gd")
const Progress = preload("res://persistence/daily_progress.gd")
const DAY: int = 20764
var checks: int = 0
var failures: int = 0
var service: Service
var board: Node
var output: String

class Service extends Node:
 signal identity_changed
 signal released
 var player: Dictionary = {"id":"owner","country_code":"FI"}
 var authenticated: bool = true
 var pending: bool = false
 var response: Dictionary = {}
 var calls: Array[String] = []
 func signed_in() -> bool: return authenticated
 func base_url() -> String: return "http://standings-refinement.invalid"
 func cancel_public_reads(_owner: int) -> void: pass
 func request_public(path: String, _owner: int) -> Dictionary: return await request_api(path,0,{},"",false)
 func request_api(path: String, _method: int, _body: Dictionary, _key: String, _auth: bool) -> Dictionary:
  calls.append(path)
  var captured: Dictionary = response.duplicate(true)
  if pending: await released
  return captured

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func settle() -> void:
 for frame: int in range(12): await process_frame
func fixture(ticks: int = 1483, car: String = "electric") -> Dictionary:
 return {"ok":true,"data":{"day":DAY,"version_id":"refinement","vehicle_id":car,"ends_at":(DAY+1)*86400,"server_now":DAY*86400+3600,"tick_rate":120,"population":2,
  "items":[{"player_id":"rival","display_name":"Nova Wren T1071-001","country_code":"SE","rank":1,"time_ticks":1757,"gap_ticks":0}],
  "comparison":{"position":1,"population":2,"candidate_ticks":ticks},"player":null,"next_cursor":null}}
func make_board(seconds: float = 12.358) -> Node:
 var dialog := Board.new()
 dialog.client = service
 dialog.day = DAY
 dialog.version = "refinement"
 dialog.vehicle = "electric"
 dialog.track_name = "Underpass"
 dialog.ends_at = (DAY+1)*86400
 dialog.server_now = DAY*86400+3600
 dialog.flying_laps = true
 dialog.best_seconds = seconds
 return dialog
func capture(id: String) -> void:
 if output.is_empty() or DisplayServer.get_name() == "headless": return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output.path_join(id+".png")) == OK,"capture "+id)
func run() -> void:
 create_timer(90).timeout.connect(func() -> void: push_error("Refinement deadline"); quit(1))
 root.gui_embed_subwindows = true
 root.size = Vector2i(1280,720)
 output = OS.get_environment("BMT_DAILY_REFINEMENT_OUTPUT")
 if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
 service = Service.new()
 root.add_child(service)
 service.response = fixture()
 board = make_board()
 root.add_child(board)
 board.popup_centered()
 await settle()
 check(board._rows.get_child_count() == 2,"reported missing-player case includes local lap and rival")
 check(board._rows.get_child(0).name == "DailySelfRow","faster player appears first")
 check(board._rows.get_child(1).get_child(0).get_child(0).text == "2","rival shifts to second")
 check(board._rows.get_child(1).get_child(0).get_child(3).text == "+2.284","gap matches the displayed leading attempt")
 check(board._rows.get_child(0).get_child(0).get_child(2).text == "0:12.358","display keeps exact completed milliseconds")
 check(board._own.find_child("DailyComparisonPosition",true,false).text == "#1 / 2","summary matches result card")
 for extent: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(844,390)]:
  root.size = extent
  await settle()
  check(root.get_visible_rect().encloses(Rect2(Vector2(board.position),Vector2(board.size))),"window fits "+str(extent))
  check(board._refresh.get_global_rect().end.y <= board.size.y,"Refresh stays within dialog "+str(extent))
  await capture("underpass-%dx%d" % [extent.x,extent.y])
 root.size = Vector2i(1280,720)
 # Server response must describe this exact candidate.
 service.response = fixture(1500)
 board._restart()
 await settle()
 check(board._rows.get_child_count() == 0 and board._own.get_child_count() == 0,"wrong candidate cannot create a player row")
 # A stored daily result is restored through the same real dialog as the Daily page.
 board.queue_free()
 await settle()
 var records := LocalRecords.new("user://refinement-"+TrackLibrary.unique_id()+".json")
 var entries := {Progress.identity(DAY,"refinement","electric"):{"day":DAY,"version":"refinement","vehicle":"electric","passed":4,"best_ms":12358}}
 check(preload("res://backend/atomic_json.gd").write(records.path+".daily.json",{"schema":1,"entries":entries},Progress.MAX_BYTES),"save isolated daily fixture")
 service.response = fixture()
 board = make_board(0.0)
 board.records = records
 root.add_child(board)
 board.popup_centered()
 await settle()
 check(board._candidate == 12.358 and board._rows.get_child_count() == 2,"saved daily best appears on reopening")
 service.response = fixture(1483,"kart")
 board._select_vehicle(VehicleCatalog.IDS.find("kart"))
 await settle()
 check(board._candidate == 0.0 and "lap_ticks=" not in service.calls.back(),"saved best is isolated by car")
 service.response = fixture()
 board._select_vehicle(VehicleCatalog.IDS.find("electric"))
 await settle()
 check(board._candidate == 12.358,"returning car restores saved best")
 service.pending = true
 board._restart()
 await settle()
 check(board.busy and board._own.get_child_count() == 0,"in-flight refresh clears private summary")
 service.player = {"id":"other"}
 service.identity_changed.emit()
 service.pending = false
 service.released.emit()
 await settle()
 check(board._candidate == 0.0 and board._own.find_child("DailyComparisonPosition",true,false) == null,"late previous-account reply cannot restore local lap")
 board.server_now = board.ends_at
 board._process(0.0)
 check(board._expired and board._rows.get_child_count() == 0 and board._own.get_child_count() == 0,"midnight clears comparison and rows")
 board.queue_free()
 service.queue_free()
 await settle()
 print("DAILY_STANDINGS_REFINEMENT: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
