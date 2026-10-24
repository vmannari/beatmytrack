extends Node
## Presentation-side sign-in. No credentials in records, exports, URLs or logs.
signal changed
signal account_removed(origin: String, player_id: String)
const Client = preload("res://backend/backend_client.gd")
var client := Client.new()
var busy: bool = false
var waiting_for_google: bool = false
var message: String = "Choose how to sign in."
var retry_available: bool = false
var capabilities: Dictionary = {}
var configured: bool = false
var _development_key: String = ""
var _cancelled: bool = false
var open_browser: Callable = OS.shell_open
var _signing_out: bool = false

func _ready() -> void:
	add_child(client)
	client.identity_changed.connect(_identity_changed)
	_load_configuration()

func _identity_changed() -> void:
	# Explicit sign-in batches its clear/remember transition until it finishes.
	# Expiry and local sign-out update storage/UI immediately, before callers resume.
	if busy and not _signing_out: return
	if not client.signed_in(): message = "Session ended. Sign in again or continue as Guest."
	changed.emit()

func _load_configuration() -> void:
	var config := ConfigFile.new()
	config.load("user://backend.cfg")
	var url: String = str(config.get_value("backend", "url", "http://127.0.0.1:18181" if OS.is_debug_build() else ""))
	if OS.has_environment("BMT_API_URL"): url = OS.get_environment("BMT_API_URL")
	if OS.is_debug_build():
		_development_key = OS.get_environment("BMT_DEV_AUTH_KEY")
		if _development_key.is_empty(): _development_key = str(config.get_value("backend", "development_key", ""))
	if url != client.base_url():
		capabilities = {}
		var error: Error = client.configure(url)
		configured = not url.is_empty() and error == OK
	if not configured: message = "Online sign-in is not configured yet."

func start_session() -> void:
	client.discard_signed_out_session()
	if not configured: return
	busy = true
	message = "Checking saved sign-in?"
	changed.emit()
	var result: Dictionary = await _check_service()
	if result.ok and client.has_saved_session():
		result = await client.restore_session()
	if result.get("account_removed",false): account_removed.emit(str(result.removed_origin),str(result.removed_player_id))
	message = _signed_in_message() if client.signed_in() else ("" if result.ok else _error_text(result))
	if result.get("account_removed",false): message = "Account removed. Tracks and historical standings remain under Removed account."
	retry_available = not result.ok
	busy = false
	changed.emit()

func player_name() -> String:
	return str(client.player.get("display_name", ""))

func show_development() -> bool:
	return OS.is_debug_build() and bool(capabilities.get("development_auth", true))

func google_available() -> bool:
	return bool(capabilities.get("google_browser_configured", false))

func needs_username() -> bool:
	return client.signed_in() and bool(client.player.get("needs_username", false))

func _signed_in_message() -> String:
	return "Choose the name other racers will see." if needs_username() else "Signed in as " + player_name() + "."

func _check_service() -> Dictionary:
	var result: Dictionary = await client.request_api("/bootstrap")
	if result.ok and (result.data.get("service", "") != "beat-my-track" or result.data.get("api_version", "") != "v1"):
		capabilities = {}
		return {"ok":false,"error":"WRONG_SERVICE"}
	if result.ok: capabilities = result.data
	else: capabilities = {}
	return result

func refresh_options() -> void:
	if busy: return
	_load_configuration()
	if not configured:
		changed.emit()
		return
	busy = true
	retry_available = false
	message = "Connecting to sign-in…"
	changed.emit()
	var result: Dictionary = await _check_service()
	if result.ok:
		capabilities = result.data
		if not client.signed_in() and client.has_saved_session():
			await client.restore_session()
		if client.signed_in():
			var profile: Dictionary = await client.request_api("/me", HTTPClient.METHOD_GET, {}, "", true)
			if profile.ok: client.player = profile.data
		message = "" if not client.signed_in() else _signed_in_message()
	else:
		message = _error_text(result)
		retry_available = true
	busy = false
	changed.emit()

func sign_in_developer() -> void:
	if busy: return
	if not configured:
		message = "Online sign-in is not configured yet."
	elif not show_development() or _development_key.is_empty():
		message = "Development sign-in is not configured on this device."
	else:
		busy = true
		message = "Signing in as developer…"
		changed.emit()
		var result: Dictionary = await _check_service()
		if result.ok: result = await client.developer_login(_development_key)
		message = _signed_in_message() if result.ok else _error_text(result)
		busy = false
	changed.emit()

func sign_in_google() -> void:
	if busy: return
	if OS.get_name() == "Android":
		await _sign_in_google_native()
		return
	busy = true
	_cancelled = false
	message = "Opening Google sign-in…"
	changed.emit()
	var result: Dictionary = await _check_service()
	if result.ok and not google_available(): result = {"ok":false,"error":"GOOGLE_SIGN_IN_NOT_CONFIGURED"}
	if result.ok: result = await client.request_api("/auth/google/browser/start", HTTPClient.METHOD_POST)
	if not result.ok:
		message = _error_text(result)
		busy = false
		changed.emit()
		return
	var poll_token: String = str(result.data.get("poll_token", ""))
	var browser_url: String = str(result.data.get("browser_url", ""))
	# Only open this configured backend's browser endpoint, never arbitrary server URLs.
	if not browser_url.begins_with(client.base_url() + "/v1/auth/google/browser#") or poll_token.is_empty():
		message = "The sign-in service returned an invalid response."
		busy = false
		changed.emit()
		return
	if open_browser.call(browser_url) != OK:
		await client.request_api("/auth/google/browser/cancel", HTTPClient.METHOD_POST, {"token":poll_token})
		message = "Your browser could not be opened. Please try again."
		busy = false
		changed.emit()
		return
	waiting_for_google = true
	message = "Finish signing in with Google in your browser, then return here."
	changed.emit()
	var deadline: int = Time.get_ticks_msec() + 300000
	var poll_delay: float = 5.0
	while not _cancelled and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(poll_delay).timeout
		if _cancelled: break
		result = await client.poll_google(poll_token)
		if not result.ok:
			if int(result.get("status",0)) == 429:
				poll_delay = maxf(5.0,float(result.get("retry_after",60)))
				continue
			message = _error_text(result)
			break
		poll_delay = 5.0
		if client.signed_in():
			message = _signed_in_message()
			break
	if _cancelled or not client.signed_in():
		if client.signed_in(): await client.logout()
		await client.request_api("/auth/google/browser/cancel", HTTPClient.METHOD_POST, {"token":poll_token})
		if _cancelled: message = "Sign-in cancelled."
		elif Time.get_ticks_msec() >= deadline: message = "Sign-in expired. Please try again."
	waiting_for_google = false
	busy = false
	changed.emit()

func _google_native_plugin() -> Object:
	return Engine.get_singleton("BmtGoogleSignIn") if Engine.has_singleton("BmtGoogleSignIn") else null

func _sign_in_google_native() -> void:
	busy = true
	_cancelled = false
	message = "Connecting to Google…"
	changed.emit()
	var result: Dictionary = await _check_service()
	if result.ok and not _cancelled: result = await client.google_challenge()
	var native: Object = _google_native_plugin()
	if result.ok and not _cancelled and (native == null or str(result.data.get("client_id", "")).is_empty()):
		result = {"ok":false,"error":"GOOGLE_SIGN_IN_NOT_CONFIGURED"}
	if result.ok and not _cancelled:
		var challenge_id: String = str(result.data.challenge_id)
		native.startSignIn(str(result.data.client_id), str(result.data.nonce))
		waiting_for_google = true
		message = "Choose your Google account."
		changed.emit()
		var deadline: int = Time.get_ticks_msec() + 300000
		var credential: String = ""
		while not _cancelled and Time.get_ticks_msec() < deadline:
			credential = str(native.takeResult())
			if not credential.is_empty(): break
			await get_tree().create_timer(0.1).timeout
		if not _cancelled and credential.begins_with("token:"):
			message = "Signing in…"
			changed.emit()
			result = await client.google_login(credential.trim_prefix("token:"), challenge_id, "")
			if _cancelled and client.signed_in(): await client.logout()
			message = _signed_in_message() if result.ok else _error_text(result)
		elif credential == "error:cancelled":
			_cancelled = true
		else:
			message = "Google sign-in could not complete. Please try again."
		native.cancelSignIn()
	else:
		message = _error_text(result)
	if _cancelled: message = "Sign-in cancelled."
	waiting_for_google = false
	busy = false
	changed.emit()

func save_username(username: String, country_code: String = "") -> void:
	if busy or not needs_username(): return
	username = username.strip_edges()
	if username.is_empty() or username.length() > 40:
		message = "Choose a name between 1 and 40 characters."
		changed.emit()
		return
	busy = true
	message = "Saving your name…"
	changed.emit()
	var payload: Dictionary = {"display_name":username}
	if not country_code.is_empty(): payload.country_code = country_code
	var result: Dictionary = await client.request_api("/me", HTTPClient.METHOD_PATCH, payload, "", true)
	if result.ok: client.player = result.data
	message = _signed_in_message() if result.ok else _error_text(result)
	busy = false
	changed.emit()

func save_country(country_code: String) -> void:
	if busy or not client.signed_in() or needs_username(): return
	if PlayerCountry.valid_code(country_code).is_empty():
		message = "Choose your country from the list."
		changed.emit()
		return
	busy = true
	message = "Saving your country…"
	changed.emit()
	var result: Dictionary = await client.request_api("/me",HTTPClient.METHOD_PATCH,{"country_code":country_code},"",true)
	if result.ok: client.player = result.data
	message = "Country saved." if result.ok else "Could not save your country. Check your connection and try again."
	busy = false
	changed.emit()

func cancel_google() -> void:
	_cancelled = true
	if Engine.has_singleton("BmtGoogleSignIn"):
		Engine.get_singleton("BmtGoogleSignIn").cancelSignIn()
	message = "Cancelling sign-in…"
	changed.emit()

func sign_out() -> void:
	if busy: return
	if Engine.has_singleton("BmtGoogleSignIn"):
		Engine.get_singleton("BmtGoogleSignIn").clearSignIn()
	busy = true
	_signing_out = true
	changed.emit()
	var result: Dictionary = await client.logout()
	message = "Signed out." if result.ok else "Signed out on this device. Server revocation was not confirmed."
	if result.get("error") == "SESSION_STORAGE_ERROR": message = "Session ended, but saved credentials could not be removed. Check writable storage before restarting."
	_signing_out = false
	busy = false
	changed.emit()

func delete_account(expected_player: String = "", expected_origin: String = "") -> void:
	if busy or not client.signed_in(): return
	if (not expected_player.is_empty() and str(client.player.get("id","")) != expected_player) or (not expected_origin.is_empty() and client.base_url() != expected_origin):
		message = "Your account changed. Review the current account before deleting it."
		changed.emit()
		return
	busy = true
	message = "Removing your account…"
	changed.emit()
	var result: Dictionary = await client.delete_account()
	if result.ok:
		if Engine.has_singleton("BmtGoogleSignIn"): Engine.get_singleton("BmtGoogleSignIn").clearSignIn()
		account_removed.emit(str(result.removed_origin),str(result.removed_player_id))
		message = "Account removed. Tracks and historical standings remain under Removed account."
		if client.persistence_error: message += " Saved sign-in could not be erased; the account is already inaccessible. Check writable storage."
	else:
		message = "Deletion could not be confirmed. Check your connection and retry; the same request will be used."
		if result.get("error") == "ACCOUNT_CHANGED": message = "Your account changed in another game instance. Its saved sign-in has been preserved."
	busy = false
	changed.emit()

func _error_text(result: Dictionary) -> String:
	match str(result.get("error", "")):
		"USERNAME_TAKEN": return "That racing name is already taken. Choose another name."
		"USERNAME_REQUIRED": return "Choose your racing name before sharing tracks."
		"GOOGLE_SIGN_IN_NOT_CONFIGURED", "GOOGLE_PUBLIC_URL_NOT_CONFIGURED": return "Google sign-in is not configured yet."
		"INVALID_DEVELOPMENT_KEY": return "Development sign-in is not configured correctly on this device."
		"INVALID_INPUT": return "Choose a visible username between 1 and 40 characters."
		"LOGIN_EXPIRED": return "Sign-in expired. Please try again."
		"RATE_LIMITED": return "Too many sign-in attempts. Please wait a minute and try again."
		"ACCOUNT_DISABLED": return "This account is disabled."
		"NOT_CONFIGURED": return "Online sign-in is not configured yet."
		"WRONG_SERVICE", "INVALID_RESPONSE": return "The sign-in address points to another service. Check the PC backend setup."
		"NETWORK_ERROR", "REQUEST_START_FAILED": return "The game service could not be reached. Reconnect and retry, or continue as Guest."
		_: return "Could not sign in. Check your connection and try again."
