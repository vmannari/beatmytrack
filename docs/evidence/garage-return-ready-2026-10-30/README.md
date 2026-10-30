# Garage return readiness regression — 2026-10-30

The existing actual-App ready-pictures fixture was run on the current sources using isolated, synthetic records. It exercises first-frame exact pictures, a process restart, changed appearance and cancellation, memory-pressure recovery, and the owner fence. No owner profile was accessed.

Compatibility seed: **68 checks, 0 failures**, six captures, 37,929 ms startup and 277 ms first Garage construction dispatch. Reuse: **157 checks, 0 failures**, zero startup captures, 455 ms startup and 845 ms first Garage construction dispatch. All six restarted image hashes match the seed. These are cache-sensitive desktop observations, not mobile or warm-return timing claims. The fixture-generated reports are [seed.json](seed.json) and [reuse.json](reuse.json).

The standard `run_pair.py` attempt stopped before the fixture began: it logged `ERROR: Failed to read the root certificate store.` and `ERROR: Access denied`; [its log](standard-runner-failure.log) is retained. The retry below used the pinned console executable with dummy audio and the required process-tree crash-dialog wrapper. Both processes exited 0, and each still reported `ERROR: Failed to read the root certificate store.` at startup. The direct process stdout was observed in the tool session rather than saved to a separate log; the JSON files are the fixture's own output.

The two commands used the same isolated profile and separate output folders, from the workspace root in PowerShell:

```powershell
$env:APPDATA='C:\Codes\Godot\Beat my track\build\garage-ready-direct-user'
$env:LOCALAPPDATA='C:\Codes\Godot\Beat my track\build\garage-ready-direct-user\local'
$env:BMT_API_URL=''
$env:BMT_DEV_AUTH_KEY=''
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path game --audio-driver Dummy --position 10000,10000 --rendering-method gl_compatibility --script res://tests/test_garage_ready_pictures.gd -- '--output=C:\Codes\Godot\Beat my track\build\garage-ready-direct-seed' '--phase=seed' '--profile=C:\Codes\Godot\Beat my track\build\garage-ready-direct-profile'
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path game --audio-driver Dummy --position 10000,10000 --rendering-method gl_compatibility --script res://tests/test_garage_ready_pictures.gd -- '--output=C:\Codes\Godot\Beat my track\build\garage-ready-direct-reuse' '--phase=reuse' '--profile=C:\Codes\Godot\Beat my track\build\garage-ready-direct-profile'
```

The profile and output directories were created inside `build/` before launch. No device test or owner acceptance is implied.
