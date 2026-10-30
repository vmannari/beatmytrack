from pathlib import Path
import hashlib
import json
import zipfile

work = Path(__file__).resolve().parent
old = work.parent / 'phone-current-deployment-2026-10-25/current-game.apk'
candidate = work / 'current-game.apk'
def entries(path):
    with zipfile.ZipFile(path) as archive:
        return {name:hashlib.sha256(archive.read(name)).hexdigest() for name in archive.namelist() if not name.endswith('/')}
before = entries(old)
after = entries(candidate)
changed = sorted(name for name in before.keys() & after.keys() if before[name] != after[name])
scripts = [name for name in changed if name.endswith(('.gdc','.gd'))]
assert scripts and all(any(part in name for part in ('desert_sand_wind','desert_ambience','mobile_race_probe','build_identity')) for name in scripts), scripts
art = [name for name in before if name.endswith(('.ctex','.oggvorbisstr','.sample','.glb','.so','.res')) and name in after]
assert all(before[name] == after[name] for name in art), 'Unrelated packaged artwork/audio/native data changed'
report = {'base_build':'0.3.0-creator.2f8163c3a95d18ced951ffbe6194f742','changed':changed,'changed_scripts':scripts,'added':sorted(after.keys()-before.keys()),'removed':sorted(before.keys()-after.keys()),'unchanged_art_audio_native_entries':len(art)}
(work / 'apk-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'changed_scripts':scripts,'unchanged_art_audio_native_entries':len(art)}))
