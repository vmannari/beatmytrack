@tool
extends EditorPlugin
var exporter: EditorExportPlugin

func _enter_tree() -> void:
	exporter = ChallengeExport.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null

class ChallengeExport extends EditorExportPlugin:
	func _get_name() -> String: return "BMTChallengeLinks"
	func _supports_platform(platform: EditorExportPlatform) -> bool: return platform is EditorExportPlatformAndroid
	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return '<meta-data android:name="org.godotengine.plugin.v2.BmtChallenges" android:value="org.beatmytrack.challenges.BmtChallenges"/>'
	func _get_android_manifest_activity_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		var filter: String = '<intent-filter><action android:name="android.intent.action.VIEW"/><category android:name="android.intent.category.DEFAULT"/><category android:name="android.intent.category.BROWSABLE"/><data android:scheme="beatmytrack" android:host="challenge"/></intent-filter>'
		var host: String = OS.get_environment("BMT_CHALLENGE_LINK_HOST")
		var pattern := RegEx.new()
		pattern.compile("^[a-zA-Z0-9][a-zA-Z0-9.-]{0,251}[a-zA-Z0-9]$")
		if not host.is_empty() and pattern.search(host) != null:
			filter += '<intent-filter android:autoVerify="true"><action android:name="android.intent.action.VIEW"/><category android:name="android.intent.category.DEFAULT"/><category android:name="android.intent.category.BROWSABLE"/><data android:scheme="https" android:host="'+host+'" android:pathPrefix="/c/"/></intent-filter>'
		return filter
