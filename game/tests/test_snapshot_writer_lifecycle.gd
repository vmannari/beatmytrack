extends SceneTree
## Reproduce root-busy creation from the first App child's _ready.
const Writer = preload("res://backend/menu_snapshot_writer.gd")
var checks: int = 0
var failures: int = 0
var folder: String = "user://snapshot-writer-lifecycle"

class FirstApp extends Node:
	var path: String
	var allow_work: bool = false
	func _ready() -> void:
		Writer.shared().background_allowed = func() -> bool: return allow_work
		Writer.queue(path,{"scope":"owner-a","value":1})
		Writer.queue(path,{"scope":"owner-a","value":2})
		Writer.queue(path,{"scope":"owner-a","value":3})

func _initialize() -> void:
	var app := FirstApp.new()
	app.path = folder.path_join("snapshot.json")
	root.add_child(app)
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func run() -> void:
	for frame: int in range(4): await process_frame
	var writer: Node = Writer.shared()
	check(writer.is_inside_tree(),"writer attaches after root-busy App readiness")
	check(writer.pending.size()==1 and writer.active==null,"early queues coalesce while background work is gated")
	check(Writer.peek(folder.path_join("snapshot.json"),"owner-a").get("value")==3,"latest early value remains readable")
	check(Writer.peek(folder.path_join("snapshot.json"),"owner-b").is_empty(),"RAM snapshot retains the account fence")
	writer.background_allowed = func() -> bool: return true
	Writer.resume()
	var deadline: int = Time.get_ticks_msec()+3000
	while not Writer.idle() and Time.get_ticks_msec()<deadline: await process_frame
	check(Writer.idle() and writer.completed_writes==1,"deferred attachment retains and writes the queued batch")
	check(Writer.IO.read(folder.path_join("snapshot.json")).get("value")==3,"atomic file contains the newest queued value")
	Writer.queue(folder.path_join("snapshot.json"),{"scope":"owner-b","value":4})
	deadline = Time.get_ticks_msec()+3000
	while not Writer.idle() and Time.get_ticks_msec()<deadline: await process_frame
	check(Writer.idle() and writer.completed_writes==2,"attached idle writer wakes for a later account")
	check(Writer.IO.read(folder.path_join("snapshot.json")).get("scope")=="owner-b","later snapshot persists the new scope")
	check(not writer.is_processing(),"idle writer stops processing")
	writer.background_allowed = func() -> bool: return false
	for index: int in range(24): Writer.queue(folder.path_join(str(index)+".json"),{"scope":"bounded"})
	await process_frame
	check(writer.pending.size()==Writer.MAX_PENDING_PATHS,"pending paths stay bounded")
	writer.pending.clear()
	if writer.get_parent()!=null: writer.get_parent().remove_child(writer)
	writer.free()
	var immediate := FirstApp.new()
	immediate.path = folder.path_join("early-ready.json"); immediate.allow_work = true
	root.add_child(immediate)
	deadline = Time.get_ticks_msec()+3000
	while not Writer.idle() and Time.get_ticks_msec()<deadline: await process_frame
	check(Writer.idle() and Writer.instance.completed_writes==1,"allowed pre-ready queue writes without a later resume call")
	check(Writer.IO.read(immediate.path).get("value")==3,"early-ready atomic snapshot has the coalesced value")
	print("SNAPSHOT_WRITER_LIFECYCLE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
