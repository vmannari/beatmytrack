# Player profile person icon — 2026-10-25

PPI01: The public Player profile header uses the existing `MenuIcon` person glyph instead of the pencil. The shared popup title selector now recognizes `profile`, retaining the current yellow tint, size and positioning.

Changed files: `game/ui/popup_style.gd` (one runtime line), `game/tests/capture_profile_icon.gd` and its UID (offline screenshot helper), this record and `docs/evidence/profile-icon-2026-10-25/` (native screenshot, logs and runtime patch). Existing concurrent changes are outside this checkpoint.

Actual validation used pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`:

```powershell
$profileIconData = Join-Path (Get-Location).Path 'build/profile-icon-2026-10-25/userdata'
New-Item -ItemType Directory -Path $profileIconData -Force | Out-Null
$env:APPDATA = $profileIconData
$env:LOCALAPPDATA = $profileIconData
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_player_profile.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_profile_icon.gd -Graphical -RenderingMethod gl_compatibility
git diff --check -- game/ui/popup_style.gd game/tests/capture_profile_icon.gd
git diff --binary --output=docs/evidence/profile-icon-2026-10-25/runtime.patch -- game/ui/popup_style.gd
git apply --reverse --check docs/evidence/profile-icon-2026-10-25/runtime.patch
```

Results: existing profile suite **3,080 checks, zero failures**, exit 0. Native Compatibility capture exited 0 and reported `person=true`, yellow `(1.0, 0.8275, 0.2824, 1.0)` and `PROFILE_ICON_CAPTURE: OK`. Visually inspected the [actual profile screenshot](evidence/profile-icon-2026-10-25/player-profile-person.png); the header shows the person silhouette. Scoped diff and reverse-apply checkpoint checks passed.

Initial attempts encountered host PowerShell execution policy, then denied default user-log access, then denied Windows certificate-store access. Explicit PowerShell execution policy, isolated workspace test data and approved test execution resolved these environment restrictions; no certificate settings changed.

The screenshot uses an offline fixture and does not access a real player account. Owner appearance acceptance after client reload remains. No physical-device test or attachment check, APK, deployment or owner-process restart was performed.
