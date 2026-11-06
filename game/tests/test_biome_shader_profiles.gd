extends SceneTree
const Profile = preload("res://rendering/biome_shader_profile.gd")
const Wire = preload("res://backend/shader_profile_telemetry.gd")
var checks: int = 0
var failures: int = 0
class Client extends Node:
	var player: Dictionary = {"id":"fixture-player"}
	var supported: bool = true
	func base_url() -> String: return "https://offline.invalid"
	func shader_profiles_supported() -> bool: return supported
func check(value: bool, description: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var context: Dictionary = {"biome":"pine","renderer":"gl_compatibility","settings":{"msaa":0,"detail":"full"}}
	var entry: Dictionary = {"shader":"a".repeat(64),"variant":0,"specialization":"000000000000001f"}
	var manifest: Dictionary = {"schema_version":1,"revision":Profile.REVISION,"profiles":{Profile.identity(context):{"context":context.duplicate(true),"entries":[entry]}}}
	check(not Profile.select_profile(manifest,context).is_empty(),"exact biome/settings selects profile")
	check(not Profile.select_profile(JSON.parse_string(JSON.stringify(manifest)),context).is_empty(),"profile JSON round trip matches live context")
	for field: String in ["biome","renderer","settings"]:
		var changed: Dictionary = context.duplicate(true)
		changed[field] = "different"
		check(Profile.select_profile(manifest,changed).is_empty(),"changed "+field+" retains conservative fallback")
	var stale: Dictionary = manifest.duplicate(true); stale.revision = "old"
	check(Profile.select_profile(stale,context).is_empty(),"engine revision invalidates profile")
	check(Profile.identity({"a":1,"b":2}) == Profile.identity({"b":2,"a":1}),"stable dictionary-order identity")
	for broken: Variant in [null,{},[{}],[entry,entry],[{"shader":"bad","variant":0,"specialization":"0000000000000000"}],[{"shader":"a".repeat(64),"variant":0.5,"specialization":"0000000000000000"}]]:
		check(not Profile.valid_entries(broken),"malformed entries rejected")
	var observations: Array = []
	for n: int in range(22):
		observations.append({"key":str(n).sha256_text(),"shader":"a".repeat(64),"variant":n,"specialization":"0000000000000000","missing":true,"phase":"driving","compile_phase":"loading" if n == 0 else "driving","compile_us":1000})
	var data: Dictionary = {"context":"b".repeat(64),"profile_context":{"biome":"pine","renderer":"gl_compatibility"},"status":"matched","observations":observations,"dropped":0}
	var report: Dictionary = Profile.summary(data)
	check(report.missing == 22 and report.misses.size() == 16,"miss count survives bounded details")
	check(report.late_compile_us == 21000,"loading cost is not attributed to driving")
	var recreated: Dictionary = data.duplicate(true)
	recreated.observations = [{"key":"c".repeat(64),"shader":"a".repeat(64),"variant":0,"specialization":"0000000000000000","missing":false,"listed":true,"phase":"loading","compile_phase":"cached","compile_us":0}]
	var later: Dictionary = recreated.observations[0].duplicate()
	later.merge({"missing":true,"phase":"driving","compile_phase":"driving","compile_us":2000},true)
	recreated.observations.append(later)
	check(Profile.summary(recreated).missing == 1 and Profile.summary(recreated).misses[0].reason == "late_compile","recreated known variant retains its later preparation miss")
	check(report.misses[0].compile_phase == "driving","late misses take detail priority")
	check(not Wire.normalize(report).is_empty(),"bounded summary validates")
	var restored: Dictionary = Wire.normalize(JSON.parse_string(JSON.stringify(report)))
	check(restored.observed is int and restored.misses[0].variant is int and restored.misses[0].compile_us is int,"persisted JSON restores integer wire types")
	for field: String in ["context","biome","renderer","status","observed","misses"]:
		var broken: Dictionary = report.duplicate(true); broken[field] = null
		check(Wire.normalize(broken).is_empty(),"invalid summary "+field+" rejected")
	var extra: Dictionary = report.duplicate(true); extra["driver_serial"] = "not-allowed"
	check(Wire.normalize(extra).is_empty(),"unapproved telemetry properties rejected")
	var duplicate: Dictionary = report.duplicate(true); duplicate.misses[1] = duplicate.misses[0].duplicate()
	check(Wire.normalize(duplicate).is_empty(),"duplicate details rejected")
	var client := Client.new()
	var telemetry := preload("res://backend/product_telemetry.gd").new()
	telemetry.client = client
	telemetry._scope = (client.base_url()+"/"+str(client.player.id)).sha256_text()
	telemetry._allowed = false
	check(telemetry.observe_shader_profile(report,telemetry._scope),"negotiated scoped telemetry enqueues")
	check(telemetry.queue.size() == 1 and telemetry._thread == null,"capture does not start race-time IO")
	check(not telemetry.observe_shader_profile(report,"stale-account"),"old account cannot own diagnostics")
	telemetry.enabled = false
	check(not telemetry.observe_shader_profile(report,telemetry._scope),"analytics opt-out suppresses telemetry")
	telemetry.enabled = true; client.supported = false
	check(not telemetry.observe_shader_profile(report,telemetry._scope),"old backend does not receive unknown event")
	telemetry._persisted_ids[telemetry.queue[0].event.id] = true
	check(telemetry.batch_payload().events.is_empty(),"persisted diagnostics wait through capability rollback")
	telemetry.free(); client.free()
	if Engine.has_singleton("BMTShaderProfiles"):
		var native: Object = Engine.get_singleton("BMTShaderProfiles")
		check(native.begin("bad",[],false) == 0,"native rejects invalid scope")
		var token: int = native.begin("a".repeat(64),[entry],true)
		check(token > 0,"native accepts validated profile")
		check(native.begin("b".repeat(64),[],false) == 0,"second owner cannot replace active scope")
		native.end(token+1)
		check(not native.snapshot(token).is_empty(),"stale owner cannot terminate active scope")
		check(not native.finish(token).is_empty(),"owner atomically takes final report")
		check(native.snapshot(token).is_empty(),"owner releases its telemetry scope")
	print("BIOME_SHADER_PROFILES_COMPLETE %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
