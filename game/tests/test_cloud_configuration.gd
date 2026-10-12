extends SceneTree
## Check the owner's actual PC backend configuration without loading player files.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func run() -> void:
	var account := preload("res://backend/account_controller.gd").new()
	root.add_child(account)
	check(account.configured, "actual app configuration loaded")
	check(account.client.base_url() == "https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app", "actual app targets the owned cloud API")
	check(account.client.session_path.is_empty(), "diagnostic does not load saved player sessions")
	await account.start_session()
	check(account.capabilities.get("service") == "beat-my-track", "actual account controller reaches cloud over verified TLS")
	check(not account.retry_available, "cloud bootstrap has no connection error")
	check(not account.show_development(), "cloud hides Development sign-in")
	check(account.google_available(), "cloud exposes Google sign-in")
	check(not account.client.signed_in(), "diagnostic never creates an authenticated account")
	print("Cloud app configuration: %d checks, %d failures" % [checks, failures])
	account.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
