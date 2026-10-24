extends "res://tests/test_medium_communication.gd"
## Run unchanged communication assertions with the task-original vault.
func make_client(url: String = "http://127.0.0.1:1") -> FakeClient:
	var client: FakeClient = super.make_client(url)
	client.session_vault = load("res://../docs/evidence/sign-in-startup-2026-10-23/before/game/backend/session_vault.gd").new()
	return client
