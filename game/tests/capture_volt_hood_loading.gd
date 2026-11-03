extends "res://tests/capture_volt_hood_quality.gd"
## Render exact same source with the mesh bank disabled/enabled for comparison.
func _initialize() -> void:
	settle_frames=32
	if "--raw-hoods" in OS.get_cmdline_user_args():
		preload("res://vehicle/electric_kits.gd")._hood_mesh_bank_checked=true
		preload("res://vehicle/electric_kits.gd")._hood_mesh_bank_valid=false
	super._initialize()
