extends "res://tests/test_achievement_notification.gd"
## Real App lifecycle methods with isolated authority and no startup/network work.

class LifecycleApp extends "res://core/app.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _notification(_what: int) -> void: pass
	func _exit_tree() -> void: pass

class Race extends Node:
	var track_session: TrackSession = TrackSession.new()

func run() -> void:
	create_timer(20).timeout.connect(func() -> void: print("FAIL: achievement timing deadline"); quit(1))
	var app := LifecycleApp.new()
	root.add_child(app)
	app.root_ui = Control.new()
	app.add_child(app.root_ui)
	app.game = Race.new()
	app.add_child(app.game)
	var backend := Backend.new()
	backend.enabled = true
	app.add_child(backend)
	var service := Service.new()
	service.client = backend
	service.directory = "user://timing/cache"
	service.refresh_allowed = app._background_work_allowed
	app.achievements = service
	app.add_child(service)
	service.unlocked.connect(func(item: Dictionary) -> void: grants.append(item))
	app.game.track_session.finished = true
	await service.refresh()
	check(backend.calls == 1 and grants.is_empty(),"account baseline seeds without historical notifications")
	var desert: Dictionary = {}
	for family: Dictionary in AchievementProgress.catalog().families:
		if family.metric == "race_desert": desert = family; break
	check(not desert.is_empty(),"fixture uses the actual desert completion achievement")
	backend.data.states.race = state(str(desert.id),1)
	app.game.track_session.finished = false
	app._race_menu_visible(false)
	service.refresh_after_activity()
	await create_timer(1.2).timeout
	check(backend.calls == 1 and service._activity_pending and service._activity_timer == null,"verified desert award remains pending while driving forbids collection reads")
	app._wake_optional_work()
	await create_timer(0.4).timeout
	check(backend.calls == 1 and service._activity_pending,"race-time lifecycle wake keeps optional HTTP asleep")
	app.game.track_session.finished = true
	app._race_menu_visible(true) # Used by ordinary and Daily results, without _show_screen.
	await create_timer(1.2).timeout
	check(backend.calls == 2 and not service._activity_pending,"results resume the pending read without another race receipt or navigation")
	check(grants.size() == 1 and grants[0].family == desert.id and grants[0].tier == 1,"results announce the authoritative desert award immediately after deferred work resumes")
	app._race_menu_visible(true)
	app._wake_optional_work()
	await create_timer(0.4).timeout
	check(backend.calls == 2 and grants.size() == 1,"repeated lifecycle wakes neither poll nor repeat the grant")
	# A receipt can also be deferred behind race loading; its completion setter
	# must wake the same pending activity without dispatching during loading.
	backend.data.states.race = state(str(desert.id),2)
	app.cloud_starting = true
	service.refresh_after_activity()
	await create_timer(1.2).timeout
	check(backend.calls == 2 and service._activity_pending,"loading retains a later verified milestone")
	app.cloud_starting = false
	await create_timer(1.2).timeout
	check(backend.calls == 3 and grants.size() == 2 and grants.back().tier == 2,"loading completion wakes the retained milestone once")
	app.free()
	print("ACHIEVEMENT_TIMING: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
