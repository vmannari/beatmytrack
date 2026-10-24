extends RefCounted
## The platform protects the key. No embedded key or plaintext fallback.
const HEADER: String = "BMT-SESSION-1\n"
var _encoding_pattern: RegEx = RegEx.create_from_string("^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$")
var adapter: Object

func _init() -> void:
	if Engine.has_singleton("BmtGoogleSignIn"):
		adapter = Engine.get_singleton("BmtGoogleSignIn")
	elif ClassDB.class_exists("BmtSecureSession"):
		adapter = ClassDB.instantiate("BmtSecureSession")

func available() -> bool:
	return is_instance_valid(adapter) and adapter.has_method("sealSession") and adapter.has_method("openSession")

func seal(text: String, context: String) -> String:
	if not available(): return ""
	var value: Variant = adapter.call("sealSession",text,context)
	if not value is PackedByteArray or value.is_empty(): return ""
	return HEADER+Marshalls.raw_to_base64(value)

func open(text: String, context: String) -> String:
	if not available() or not text.begins_with(HEADER) or text.length() > 90000: return ""
	var encoded: String = text.trim_prefix(HEADER)
	# Reject corrupt framing before calling a decoder that emits engine errors.
	if encoded.is_empty() or encoded.length() > 87384 or _encoding_pattern.search(encoded) == null: return ""
	var bytes: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if bytes.is_empty() or bytes.size() > 65536 or Marshalls.raw_to_base64(bytes) != encoded: return ""
	return str(adapter.call("openSession",bytes,context))
