@tool
extends EditorPlugin
var exporter: EditorExportPlugin
func _enter_tree() -> void:
	exporter = GoogleExport.new()
	add_export_plugin(exporter)
func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null
class GoogleExport extends EditorExportPlugin:
	func _get_name() -> String: return "BMTGoogleSignIn"
	func _supports_platform(platform: EditorExportPlatform) -> bool: return platform is EditorExportPlatformAndroid
	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return '<meta-data android:name="org.godotengine.plugin.v2.BmtGoogleSignIn" android:value="org.beatmytrack.signin.BmtGoogleSignIn"/>'
