extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var vault = load("res://backend/session_vault.gd").new()
	var available: bool = vault.available()
	var sealed: String = vault.seal("fictional-review-value","security-review-isolated-context")
	var roundtrip: bool = vault.open(sealed,"security-review-isolated-context") == "fictional-review-value" if not sealed.is_empty() else false
	print("REVIEW_VAULT: "+JSON.stringify({"registered":ClassDB.class_exists("BmtSecureSession"),"available":available,"sealed_bytes":sealed.length(),"roundtrip":roundtrip}))
	quit(0)
