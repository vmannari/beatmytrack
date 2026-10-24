extends SceneTree
## Android exposes Java capabilities separately; desktop uses native Object methods.
const Vault = preload("res://backend/session_vault.gd")
const Account = preload("res://backend/account_controller.gd")
var checks: int = 0
var failures: int = 0

class JavaVault extends RefCounted:
	var methods: Array[String] = ["sealSession","openSession"]
	var queried: Array[String] = []
	func has_java_method(method: String) -> bool:
		queried.append(method)
		return method in methods

class NativeVault extends RefCounted:
	func sealSession(_text: String, _context: String) -> PackedByteArray: return PackedByteArray()
	func openSession(_bytes: PackedByteArray, _context: String) -> String: return ""

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	var source: Script = Vault
	if "--original-vault" in OS.get_cmdline_user_args():
		source = load("res://../docs/evidence/sign-in-startup-2026-10-23/before/game/backend/session_vault.gd")
	var vault: RefCounted = source.new()
	var java := JavaVault.new()
	vault.adapter = java
	check(not java.has_method("sealSession") and not java.has_method("openSession"),"fixture matches Android's separate Java method registry")
	check(vault.available(),"Android Keystore remains available through Java methods")
	check(java.queried == ["sealSession","openSession"],"both Java vault operations are checked")
	java.methods = ["sealSession"]
	check(not vault.available(),"incomplete Android vault is unavailable")
	java.methods = ["openSession"]
	check(not vault.available(),"Android vault must also provide sealing")
	vault.adapter = NativeVault.new()
	check(vault.available(),"desktop native vault retains its ordinary method check")
	vault.adapter = RefCounted.new()
	check(not vault.available(),"unrelated adapter cannot persist credentials")
	vault.adapter = null
	check(not vault.available(),"missing platform adapter stays unavailable")
	check(vault.seal("fictional","context").is_empty(),"unavailable vault has no plaintext fallback")

	var account := Account.new()
	check(not account.profile_ready(),"guest profile cannot complete sign-in")
	account.client._access_token = "fictional-access"
	account.client.player = {"id":"fictional-player","needs_username":true,"country_code":"FI"}
	check(account.needs_username() and not account.profile_ready(),"existing country cannot bypass unfinished name selection")
	account.client.player.needs_username = false
	account.client.player.country_code = ""
	check(account.needs_country() and not account.profile_ready(),"missing country requires one setup step")
	account.client.player.country_code = "XX"
	check(account.needs_country() and not account.profile_ready(),"invalid country cannot complete setup")
	account.client.player.country_code = "FI"
	check(account.profile_ready() and not account.needs_country(),"saved country completes sign-in without another prompt")
	account.client.player.country_code = "jp"
	check(account.profile_ready(),"supported country is normalized by shared validation")
	account.client._access_token = ""
	check(not account.profile_ready() and not account.needs_country(),"stale player metadata never authenticates a guest")
	account.client.free()
	account.free()
	print("SIGN_IN_STARTUP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
