@tool
extends EditorPlugin
var exporter: EditorExportPlugin

func _enter_tree() -> void:
	exporter = AdMobExport.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null

class AdMobExport extends EditorExportPlugin:
	func _get_name() -> String: return "BMTAdMobDevelopment"
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid
	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, debug: bool) -> String:
		if not debug: return ""
		return '<meta-data android:name="org.godotengine.plugin.v2.BmtAdMob" android:value="org.beatmytrack.admob.BmtAdMob"/><meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="ca-app-pub-3940256099942544~3347511713"/>'
