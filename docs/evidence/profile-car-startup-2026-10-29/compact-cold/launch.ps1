$ErrorActionPreference = 'Stop'
& 'C:\Codes\Godot\Beat my track\scripts\dev.ps1' -Action 'TestScript' -ScriptPath 'res://tests/test_profile_car_startup.gd' -TestArgument @('--output=C:\Codes\Godot\Beat my track\docs\evidence\profile-car-startup-2026-10-29\compact-cold','--profile=user://profile-startup-compact','--phase=seed') -Graphical -RenderingMethod 'gl_compatibility'
