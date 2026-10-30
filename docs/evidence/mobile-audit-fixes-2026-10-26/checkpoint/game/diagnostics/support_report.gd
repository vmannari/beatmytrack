extends RefCounted
## Explicit local support export. Never called by telemetry or during startup.
const Build = preload("res://core/build_identity.gd")
const MAX_BYTES: int = 16384
const MAX_NATIVE_BYTES: int = 65536

static func capture(native: Object = null) -> String:
	var report: Dictionary = {"schema":"bmt-support-v1","build":Build.ID,"source_sha256":Build.SOURCE_SHA256,"engine":Engine.get_version_info().string,"platform":OS.get_name(),"model":_bounded(OS.get_model_name()),"os_version":_bounded(OS.get_version()),"renderer":RenderingServer.get_current_rendering_method(),"site":"settings.help","exits":[]}
	if native == null and OS.get_name() == "Android" and Engine.has_singleton("BmtGoogleSignIn"):
		native = Engine.get_singleton("BmtGoogleSignIn")
	if native != null and native.has_method("getSupportExits"):
		var raw: String = str(native.call("getSupportExits"))
		if raw.to_utf8_buffer().size() <= MAX_NATIVE_BYTES:
			var exits: Variant = JSON.parse_string(raw)
			if exits is Array:
				for exit: Variant in exits.slice(0,4):
					if not exit is Dictionary: continue
					var reason: Variant = exit.get("reason")
					if not (reason is int or reason is float) or not is_finite(float(reason)) or float(reason)!=floorf(float(reason)) or int(reason) not in [4,5,6]: continue
					var safe: Dictionary = {"reason":int(exit.reason),"frames":[]}
					if exit.get("at") is float or exit.get("at") is int: safe.at = int(exit.at)
					if exit.get("frames") is Array:
						for frame: Variant in exit.frames.slice(0,24):
							if frame is String and _safe_frame(frame): safe.frames.append(frame)
					report.exits.append(safe)
					# Prefer recent exits and keep as many safe frames as fit the budget.
					while JSON.stringify(report,"  ").to_utf8_buffer().size()>MAX_BYTES and not safe.frames.is_empty(): safe.frames.pop_back()
					if JSON.stringify(report,"  ").to_utf8_buffer().size()>MAX_BYTES:
						report.exits.pop_back()
						break
	var result: String = JSON.stringify(report,"  ")
	return result if result.to_utf8_buffer().size() <= MAX_BYTES else JSON.stringify({"schema":"bmt-support-v1","build":Build.ID,"site":"report.limit"})

static func _bounded(value: String) -> String:
	return value.replace("\n"," ").replace("\r"," ").substr(0,80)

static func _safe_frame(value: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^(lib(?:godot_android|bmt_track_geometry)[A-Za-z0-9_.-]*\\.so@0x[0-9a-f]{1,16}(?:#[0-9a-f]{1,64})?|org\\.beatmytrack\\.[A-Za-z0-9_.$]+\\([A-Za-z0-9_$]+\\.java:[0-9]{1,7}\\))$")
	return value.length() <= 220 and pattern.search(value) != null
