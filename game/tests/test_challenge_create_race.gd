extends SceneTree
## Explicit create-and-race survives its folder read and cancels on lost ownership.
var checks: int = 0
var failures: int = 0

class StubClient extends Node:
	var player: Dictionary = {"id":"race-intent"}
	func base_url() -> String: return "http://race-intent"

class RaceProbe extends "res://core/app.gd":
	var starts: int = 0
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _notification(_what: int) -> void: pass
	func _exit_tree() -> void: pass
	func _start_challenge_race() -> void: starts += 1

func _initialize() -> void: run.call_deferred()
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+detail)

func frames() -> void:
	for frame: int in range(4): await process_frame

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	var client := StubClient.new()
	root.add_child(client)
	var adapter := ChallengesClient.new()
	adapter.client = client
	var probe := RaceProbe.new()
	probe.challenges = adapter
	probe.screen = "challenges"
	root.add_child(probe)
	for cancel: String in ["none","account","selection","navigation"]:
		client.player.id = "race-intent"
		adapter.selected = {"code":"AB12CD34EF56AB78"}
		adapter.busy = true
		probe.screen = "challenges"
		var prior: int = probe.starts
		probe._race_created_challenge.call_deferred(str(adapter.selected.code),adapter.scope())
		await frames()
		check(probe.starts == prior,"waits for the Created folder read")
		match cancel:
			"account": client.player.id = "other-account"
			"selection": adapter.selected.code = "BA12CD34EF56AB78"
			"navigation": probe._navigation_generation += 1
		adapter.busy = false
		await frames()
		check(probe.starts == prior+(1 if cancel == "none" else 0),"race intent is fenced by "+cancel)
	probe.queue_free()
	adapter.queue_free()
	client.queue_free()
	await frames()
	print("CHALLENGE_CREATE_RACE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
