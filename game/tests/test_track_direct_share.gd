extends SceneTree
const Bridge = preload("res://platform/challenge_links.gd")
const VERSION: String = "11111111-2222-4333-8444-555555555555"
const LINK: String = "https://example.invalid/t/"+VERSION
const PAYLOAD: String = "Mountain Run\n"+LINK
var checks: int = 0
var failures: int = 0

class IsolatedBridge extends Bridge:
	var clipboard: String = ""
	func _copy_track_text(value: String) -> void: clipboard = value

class WindowsShare extends RefCounted:
	var calls: Array[Dictionary] = []
	var accepted: bool = true
	func share_text(window: int, text: String, title: String, url: String) -> bool:
		calls.append({"window":window,"text":text,"title":title,"url":url})
		return accepted

class AndroidShare extends RefCounted:
	var calls: Array[String] = []
	var accepted: bool = true
	func shareTrack(value: String) -> bool:
		calls.append(value)
		return accepted

class OlderAndroidShare extends RefCounted:
	var text: String = ""
	func shareTrack(value: String) -> void: text = value

func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	root.size = Vector2i(1280,720)
	root.title = "Beat my track - share validation"
	var bridge := IsolatedBridge.new()
	root.add_child(bridge)
	if "--native-share" in OS.get_cmdline_user_args() or "--native-share-click" in OS.get_cmdline_user_args():
		if "--native-share-click" in OS.get_cmdline_user_args():
			root.always_on_top = true
			var button := Button.new()
			button.text = "Share track"
			button.size = Vector2(400,120)
			button.position = (Vector2(root.size)-button.size)*0.5
			root.add_child(button)
			print("WINDOWS_SHARE_CLICK_READY")
			var pending_button: WeakRef = weakref(button)
			create_timer(25).timeout.connect(func() -> void:
				if pending_button.get_ref() != null: print("FAIL: native share click deadline"); quit(1))
			await button.pressed
			button.queue_free()
			root.always_on_top = false
		await process_frame
		await process_frame
		root.grab_focus()
		await process_frame
		check(bridge._windows_share != null,"Windows share extension is available in the actual graphical client")
		if bridge._windows_share != null:
			check(bridge.share_track(PAYLOAD),"actual Windows system share sheet opens for this window")
		print("WINDOWS_NATIVE_SHARE_OPEN: ",failures == 0)
		await create_timer(2).timeout
		check(bridge._windows_share.call("data_requests") > 0,"Windows actually requests the share payload after opening the chooser")
		print("WINDOWS_NATIVE_DATA_REQUESTS: ",bridge._windows_share.call("data_requests"))
		await create_timer(8).timeout
	else:
		var original: RefCounted = bridge._windows_share
		bridge._windows_share = null
		var android := AndroidShare.new()
		bridge._native = android
		check(bridge.share_track(PAYLOAD) and android.calls == [PAYLOAD],"Android chooser gets the complete exact title and immutable track URL")
		android.accepted = false
		check(not bridge.share_track(PAYLOAD),"Android immediate launch refusal uses the clipboard fallback")
		var older := OlderAndroidShare.new()
		bridge._native = older
		check(bridge.share_track(PAYLOAD) and older.text == PAYLOAD,"previously installed void-returning Android bridges still open sharing once")
		bridge._native = null
		var windows := WindowsShare.new()
		bridge._windows_share = windows
		if DisplayServer.get_name() != "headless":
			bridge.clipboard = "clipboard-before-share"
			check(bridge.share_track(PAYLOAD),"Windows native handoff is reported as opened")
			check(windows.calls.size() == 1 and windows.calls[0].window != 0,"Windows chooser is attached to the actual Godot window")
			check(windows.calls[0].text == PAYLOAD and windows.calls[0].title == "Mountain Run" and windows.calls[0].url == LINK,"Windows apps receive exact text and a separate clickable web link")
			check(bridge.clipboard == "clipboard-before-share","successful native sharing does not replace the clipboard")
			windows.accepted = false
			check(not bridge.share_track(PAYLOAD),"Windows native refusal exposes fallback")
			check(bridge.clipboard == PAYLOAD,"native refusal hands the complete exact share text to the clipboard")
		bridge._windows_share = null
		check(not bridge.share_track(PAYLOAD),"unsupported platforms retain clipboard fallback")
		var errors: Array[String] = []
		bridge.track_share_failed.connect(func(value: String) -> void: errors.append(value))
		bridge._pending_track_share = PAYLOAD+"?new"
		bridge._track_share_failed(PAYLOAD)
		check(errors.is_empty(),"late failure for a previous track cannot replace the newer sharing action")
		bridge._pending_track_share = PAYLOAD
		bridge._track_share_failed(PAYLOAD)
		check(errors == [PAYLOAD],"asynchronous Android failure exposes one retryable clipboard fallback")
		bridge._track_share_failed(PAYLOAD)
		check(errors.size() == 1,"duplicate native failures do not repeat the fallback notice")
		if OS.get_name() == "Windows":
			check(ClassDB.class_exists("BmtWindowsShare"),"Windows native adapter is registered")
			var native: RefCounted = ClassDB.instantiate("BmtWindowsShare")
			check(not native.call("share_text",0,PAYLOAD,"Mountain Run",LINK),"actual DLL refuses an absent owner window without opening UI")
			check(not native.call("share_text",0,"x".repeat(4097),"Mountain Run",LINK),"actual DLL refuses oversized payloads")
		bridge._windows_share = original
	bridge.queue_free()
	await process_frame
	print("TRACK_DIRECT_SHARE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
