extends RefCounted
## Fixed counters and selected failures. No URLs, bodies, credentials, IO or authority.
const CATEGORIES: Array[String] = ["bootstrap","authentication","profile","discovery","track_document","race_ticket","score_upload","run_status","resume","publication","competition","comparison","ghost","rating","commerce","other"]
const ERRORS: Array[String] = ["none","cancelled","dns","connect","tls","timeout","connection","body_limit","redirect","invalid_response","encoding","local","http_4xx","throttled","http_5xx","http_other"]
const METHODS: Array[String] = ["GET","POST","PATCH","DELETE","HEAD","PUT","OPTIONS","OTHER"]
const LIMITS: Array[int] = [25,50,100,250,500,1000,5000]
const AGE_LIMITS: Array[int] = [1,5,15,60,300,3600,86400]
const MAX_ATTEMPTS: int = 1000000
const MAX_MS: int = 86400000
const MAX_AGE: int = 7776000
const MAX_BYTES: int = 8388608
const MAX_SCOPES: int = 4
const MAX_OPERATIONS: int = 128
const MAX_FAILURES: int = 8
const INTERVAL_MSEC: int = 300000
const MAX_RAM_AGE_MSEC: int = 86400000
const ARRAYS: Dictionary = {"latency_buckets":8,"queue_buckets":8,"http_buckets":8,"status_buckets":7,"error_buckets":16,"method_buckets":8,"upload_age_buckets":8}
const COUNTERS: Array[String] = ["attempts","successes","cancelled","retries","throttled","upload_age_samples","dropped_observations","dropped_failures","request_body_bytes","response_body_bytes","total_ms","queue_ms","encode_ms","http_ms","decode_ms"]
const SUMMARY_FIELDS: Array[String] = ["schema_version","category","device_model","os_version","attempts","successes","cancelled","retries","throttled","upload_age_samples","dropped_observations","dropped_failures","request_body_bytes","response_body_bytes","total_ms","queue_ms","encode_ms","http_ms","decode_ms","latency_buckets","queue_buckets","http_buckets","status_buckets","error_buckets","method_buckets","upload_age_buckets"]
const FAILURE_FIELDS: Array[String] = ["schema_version","category","device_model","os_version","method","error_type","http_status","total_ms","queue_ms","encode_ms","http_ms","decode_ms","retry_index","upload_age_seconds"]
var _scopes: Dictionary = {}
var _device: String = bounded_text(OS.get_model_name())
var _os: String = bounded_text(OS.get_version())
static var _id_pattern: RegEx = RegEx.create_from_string("^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-4[a-fA-F0-9]{3}-[89aAbB][a-fA-F0-9]{3}-[a-fA-F0-9]{12}$")

static func bounded_text(value: String) -> String:
	var result: String = ""
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		if code >= 32 and code != 127: result += value.substr(index,1)
		if result.length() == 80: break
	return result if not result.is_empty() else "unknown"

static func category(path: String) -> String:
	var endpoint: String = path.get_slice("?",0)
	if endpoint == "/telemetry/batches": return ""
	if endpoint == "/bootstrap": return "bootstrap"
	if endpoint.begins_with("/auth/"): return "authentication"
	if endpoint.begins_with("/me/publications") or endpoint == "/publications": return "publication"
	if endpoint == "/me": return "profile"
	if endpoint.begins_with("/discovery/") or endpoint == "/tracks" or endpoint == "/me/tracks": return "discovery"
	if endpoint.ends_with("/document"): return "track_document"
	if endpoint == "/run-tickets" or endpoint.ends_with("/tickets"): return "race_ticket"
	if endpoint == "/runs": return "score_upload"
	if endpoint.begins_with("/runs/"): return "run_status"
	if endpoint.begins_with("/resume"): return "resume"
	if endpoint.contains("/ghost"): return "ghost"
	if endpoint.ends_with("/rating"): return "rating"
	if endpoint.contains("/results-comparison") or endpoint.contains("/leaderboard") or endpoint.begins_with("/boards/"): return "comparison"
	if endpoint.begins_with("/rivalry/") or endpoint.begins_with("/challenges") or endpoint.begins_with("/challenge-results/"): return "competition"
	if endpoint.begins_with("/store") or endpoint.begins_with("/purchase") or endpoint.begins_with("/entitlements"): return "commerce"
	return "other"

static func method_name(value: int) -> String:
	var values: Dictionary = {HTTPClient.METHOD_GET:"GET",HTTPClient.METHOD_POST:"POST",HTTPClient.METHOD_PATCH:"PATCH",HTTPClient.METHOD_DELETE:"DELETE",HTTPClient.METHOD_HEAD:"HEAD",HTTPClient.METHOD_PUT:"PUT",HTTPClient.METHOD_OPTIONS:"OPTIONS"}
	return values.get(value,"OTHER")

static func request_id(headers: PackedStringArray) -> String:
	for header: String in headers:
		if header.to_lower().begins_with("x-request-id:"):
			var value: String = header.substr(header.find(":")+1).strip_edges()
			return value.to_lower() if value.length() == 36 and _id_pattern.search(value) != null else ""
	return ""

static func error_type(response: Dictionary) -> String:
	if response.get("ok",false): return "none"
	var error: String = str(response.get("error",""))
	if error in ["CANCELLED","ACCOUNT_CHANGED"]: return "cancelled"
	if error == "INVALID_RESPONSE": return "invalid_response"
	if error in ["REQUEST_ENCODING_FAILED","REQUEST_TOO_LARGE","INVALID_REPLAY"]: return "encoding"
	var transport: int = int(response.get("transport_result",-1))
	if transport == HTTPRequest.RESULT_CANT_RESOLVE: return "dns"
	if transport == HTTPRequest.RESULT_CANT_CONNECT: return "connect"
	if transport == HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "tls"
	if transport == HTTPRequest.RESULT_TIMEOUT: return "timeout"
	if transport == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: return "body_limit"
	if transport == HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: return "redirect"
	if transport >= 0: return "connection"
	var status: int = int(response.get("status",0))
	if status == 429: return "throttled"
	if status >= 500 and status < 600: return "http_5xx"
	if status >= 400 and status < 500: return "http_4xx"
	return "local" if status == 0 else "http_other"

func _partition(scope: String) -> Dictionary:
	if not _scopes.has(scope):
		_scopes[scope] = {"rows":{},"failures":{},"operations":{},"born":Time.get_ticks_msec(),"due":Time.get_ticks_msec()+INTERVAL_MSEC}
		while _scopes.size() > MAX_SCOPES: _scopes.erase(_scopes.keys()[0])
	var partition: Dictionary = _scopes[scope]
	if Time.get_ticks_msec()-int(partition.born) > MAX_RAM_AGE_MSEC:
		partition.rows.clear(); partition.failures.clear(); partition.operations.clear()
		partition.born = Time.get_ticks_msec(); partition.due = Time.get_ticks_msec()+INTERVAL_MSEC
	return _scopes[scope]

func note_preparation(scope: String, key: String, usec: int, age: int = -2) -> void:
	var partition: Dictionary = _partition(scope)
	var identity: String = key.sha256_text()
	var operation: Dictionary = partition.operations.get(identity,{"attempts":0,"preparation_us":0,"age":-1})
	operation.preparation_us = mini(MAX_MS*1000,int(operation.preparation_us)+maxi(0,usec))
	if age >= -1: operation.age = clampi(age,-1,MAX_AGE)
	partition.operations.erase(identity); partition.operations[identity] = operation
	while partition.operations.size() > MAX_OPERATIONS: partition.operations.erase(partition.operations.keys()[0])

func begin(scope: String, key: String, retry_index: int = 0) -> Dictionary:
	var result: Dictionary = {"retry_index":retry_index,"extra_encode_us":0,"upload_age_seconds":-1}
	if key.is_empty(): return result
	note_preparation(scope,key,0)
	var operation: Dictionary = _partition(scope).operations[key.sha256_text()]
	result.retry_index = maxi(retry_index,int(operation.attempts))
	result.extra_encode_us = int(operation.preparation_us)
	result.upload_age_seconds = int(operation.age)
	operation.attempts = mini(1000,int(operation.attempts)+1); operation.preparation_us = 0
	return result

static func _bucket(value: int, limits: Array[int]) -> int:
	var index: int = 0
	while index < limits.size() and value > limits[index]: index += 1
	return index

func record(scope: String, category_value: String, method: String, response: Dictionary, metrics: Dictionary) -> void:
	if category_value not in CATEGORIES: return
	var partition: Dictionary = _partition(scope)
	if not partition.rows.has(category_value):
		var row: Dictionary = {"schema_version":1,"category":category_value,"device_model":_device,"os_version":_os}
		for field: String in COUNTERS: row[field] = 0
		for field: String in ARRAYS:
			var values: Array = []; values.resize(int(ARRAYS[field])); values.fill(0); row[field] = values
		partition.rows[category_value] = row
	var row: Dictionary = partition.rows[category_value]
	if row.attempts >= MAX_ATTEMPTS: row.dropped_observations = mini(MAX_ATTEMPTS,int(row.dropped_observations)+1); return
	var error: String = error_type(response)
	row.attempts += 1; row.successes += int(error == "none"); row.cancelled += int(error == "cancelled")
	row.retries += int(int(metrics.get("retry_index",0)) > 0); row.throttled += int(int(metrics.get("http_status",0)) == 429)
	for field: String in ["total_ms","queue_ms","encode_ms","http_ms","decode_ms"]: row[field] += clampi(int(metrics.get(field,0)),0,MAX_MS)
	for field: String in ["request_body_bytes","response_body_bytes"]: row[field] += clampi(int(metrics.get(field,0)),0,MAX_BYTES)
	row.latency_buckets[_bucket(int(metrics.get("total_ms",0)),LIMITS)] += 1
	row.queue_buckets[_bucket(int(metrics.get("queue_ms",0)),LIMITS)] += 1
	row.http_buckets[_bucket(int(metrics.get("http_ms",0)),LIMITS)] += 1
	row.error_buckets[ERRORS.find(error)] += 1; row.method_buckets[METHODS.find(method)] += 1
	var status: int = int(metrics.get("http_status",0))
	var status_index: int = 0 if status == 0 else 1 if status >= 200 and status < 300 else 2 if status >= 300 and status < 400 else 4 if status == 429 else 3 if status >= 400 and status < 500 else 5 if status >= 500 and status < 600 else 6
	row.status_buckets[status_index] += 1
	var age: int = int(metrics.get("upload_age_seconds",-1))
	if category_value == "score_upload" and age >= 0:
		row.upload_age_samples += 1; row.upload_age_buckets[_bucket(age,AGE_LIMITS)] += 1
	if error in ["none","cancelled"]: return
	var failure: Dictionary = {"schema_version":1,"category":category_value,"device_model":_device,"os_version":_os,"method":method,"error_type":error,"http_status":clampi(status,0,999),"retry_index":clampi(int(metrics.get("retry_index",0)),0,1000),"upload_age_seconds":clampi(age,-1,MAX_AGE)}
	for field: String in ["total_ms","queue_ms","encode_ms","http_ms","decode_ms"]: failure[field] = clampi(int(metrics.get(field,0)),0,MAX_MS)
	var identifier: String = str(response.get("request_id",""))
	if identifier.length() == 36 and _id_pattern.search(identifier) != null: failure.request_id = identifier.to_lower()
	var sample_key: String = category_value+"/"+error
	if partition.failures.has(sample_key): row.dropped_failures = mini(MAX_ATTEMPTS,int(row.dropped_failures)+1)
	partition.failures.erase(sample_key); partition.failures[sample_key] = failure
	while partition.failures.size() > MAX_FAILURES:
		var oldest: String = str(partition.failures.keys()[0])
		var previous: Dictionary = partition.rows.get(partition.failures[oldest].category,{})
		if not previous.is_empty(): previous.dropped_failures = mini(MAX_ATTEMPTS,int(previous.dropped_failures)+1)
		partition.failures.erase(oldest)

func pending(scope: String, now: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _scopes.has(scope): return result
	var partition: Dictionary = _partition(scope)
	if (Time.get_ticks_msec() if now < 0 else now) < int(partition.due): return result
	for row: Dictionary in partition.rows.values(): result.append({"name":"network_summary","properties":row.duplicate(true)})
	for failure: Dictionary in partition.failures.values(): result.append({"name":"network_failure","properties":failure.duplicate(true)})
	return result

func acknowledge(scope: String, name: String, properties: Dictionary) -> void:
	if not _scopes.has(scope): return
	var partition: Dictionary = _scopes[scope]
	if name == "network_summary": partition.rows.erase(properties.category)
	else: partition.failures.erase(str(properties.category)+"/"+str(properties.error_type))
	if partition.rows.is_empty() and partition.failures.is_empty():
		partition.born = Time.get_ticks_msec(); partition.due = Time.get_ticks_msec()+INTERVAL_MSEC

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == float(int(value)) and value >= low and value <= high

static func normalize(name: String, value: Variant) -> Dictionary:
	if not value is Dictionary or not _integer(value.get("schema_version"),1,1) or value.get("category") not in CATEGORIES: return {}
	var result: Dictionary = value.duplicate(true)
	for field: String in ["device_model","os_version"]:
		if not value.get(field) is String or value[field].is_empty() or value[field].length() > 80 or value[field] != bounded_text(value[field]): return {}
	if name == "network_failure":
		if value.size() != FAILURE_FIELDS.size()+int(value.has("request_id")) or not value.has_all(FAILURE_FIELDS): return {}
		if value.method not in METHODS or value.error_type not in ERRORS or value.error_type in ["none","cancelled"]: return {}
		for field: String in ["schema_version","http_status","total_ms","queue_ms","encode_ms","http_ms","decode_ms","retry_index","upload_age_seconds"]:
			var low: int = -1 if field == "upload_age_seconds" else 0
			var high: int = MAX_AGE if field == "upload_age_seconds" else 999 if field == "http_status" else 1000 if field == "retry_index" else MAX_MS
			if not _integer(value[field],low,high): return {}
			result[field] = int(value[field])
		if value.has("request_id") and (not value.request_id is String or value.request_id.length() != 36 or _id_pattern.search(value.request_id) == null): return {}
		for field: String in ["queue_ms","encode_ms","http_ms","decode_ms"]:
			if result[field] > result.total_ms: return {}
		return result
	if name != "network_summary" or value.size() != SUMMARY_FIELDS.size() or not value.has_all(SUMMARY_FIELDS): return {}
	for field: String in ["device_model","os_version"]:
		if not value[field] is String or value[field].is_empty() or value[field].length() > 80 or value[field] != bounded_text(value[field]): return {}
	for field: String in COUNTERS:
		var high: int = MAX_ATTEMPTS*(MAX_BYTES if field.ends_with("_bytes") else MAX_MS) if field.ends_with("_bytes") or field.ends_with("_ms") else MAX_ATTEMPTS
		if not _integer(value[field],0,high): return {}
		result[field] = int(value[field])
	if result.attempts < 1: return {}
	for field: String in COUNTERS:
		if field.ends_with("_bytes") or field.ends_with("_ms"):
			if result[field] > int(result.attempts)*(MAX_BYTES if field.ends_with("_bytes") else MAX_MS): return {}
	for field: String in ARRAYS:
		if not value[field] is Array or value[field].size() != int(ARRAYS[field]): return {}
		var values: Array = []; var total: int = 0
		for count: Variant in value[field]:
			if not _integer(count,0,MAX_ATTEMPTS): return {}
			values.append(int(count)); total += int(count)
		if total != (result.upload_age_samples if field == "upload_age_buckets" else result.attempts): return {}
		result[field] = values
	if result.successes != result.error_buckets[0] or result.cancelled != result.error_buckets[1] or result.throttled != result.status_buckets[4]: return {}
	for field: String in ["queue_ms","encode_ms","http_ms","decode_ms"]:
		if result[field] > result.total_ms: return {}
	if result.retries > result.attempts or result.upload_age_samples > result.attempts or (result.category != "score_upload" and result.upload_age_samples != 0): return {}
	for pair: Array in [["total_ms","latency_buckets"],["queue_ms","queue_buckets"],["http_ms","http_buckets"]]:
		var minimum: int = 0; var maximum: int = 0
		for index: int in range(8):
			minimum += int(result[pair[1]][index])*(0 if index == 0 else LIMITS[index-1]+1)
			maximum += int(result[pair[1]][index])*(MAX_MS if index == 7 else LIMITS[index])
		if result[pair[0]] < minimum or result[pair[0]] > maximum: return {}
	result.schema_version = 1
	return result
