"""Fresh-process font costs with exact imported assets in a private minimal project."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
PROJECT = ROOT / 'build/loading-half-20261106/font-component'
ENGINE = Path('C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe')
SOURCE = ROOT / 'game/localization/game_fonts.gd'
TEXT = SOURCE.read_text(encoding='utf-8')
PATHS = re.findall(r'preload\("(res://[^"]+)"\)', TEXT)
PROBE = '''extends SceneTree
func _initialize() -> void:
    var rows: Array = []
    var retained: Array = []
    if "--individual" in OS.get_cmdline_user_args():
        for path: String in %s:
            var began: int = Time.get_ticks_usec()
            retained.append(load(path))
            rows.append({"font":path,"load_ms":(Time.get_ticks_usec()-began)/1000.0})
    var began: int = Time.get_ticks_usec()
    var fonts: Script = load("res://localization/game_fonts.gd")
    var loaded: int = Time.get_ticks_usec()
    fonts.configure("en")
    var configured: int = Time.get_ticks_usec()
    var latin_size: Vector2 = fonts.LATIN[0].get_string_size("Beat my track: Racing, Garage, Settings",HORIZONTAL_ALIGNMENT_LEFT,-1,24)
    var latin_shaped: int = Time.get_ticks_usec()
    var mixed_size: Vector2 = fonts.LATIN[0].get_string_size("Alice 日本語 한국어",HORIZONTAL_ALIGNMENT_LEFT,-1,24)
    var mixed_shaped: int = Time.get_ticks_usec()
    var result: Dictionary = {"individual":rows,"script_load_ms":(loaded-began)/1000.0,"configure_ms":(configured-loaded)/1000.0,"first_latin_shape_ms":(latin_shaped-configured)/1000.0,"first_mixed_shape_ms":(mixed_shaped-latin_shaped)/1000.0,"total_ms":(mixed_shaped-began)/1000.0,"latin_size":str(latin_size),"mixed_size":str(mixed_size),"engine_elapsed_ms":mixed_shaped/1000.0}
    print("FONT_COMPONENT ",JSON.stringify(result))
    quit()
'''


def main():
    assert subprocess.check_output([str(ENGINE), '--version'], text=True).strip() == (ROOT / 'godot-version.txt').read_text().strip()
    PROJECT.mkdir(parents=True, exist_ok=False)
    (PROJECT / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="BMTFontComponent"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
    (PROJECT / 'localization').mkdir()
    shutil.copy2(SOURCE, PROJECT / 'localization/game_fonts.gd')
    receipts = {}
    for path in PATHS:
        relative = path.removeprefix('res://')
        imported = (ROOT / 'game' / (relative + '.import')).read_text(encoding='utf-8')
        generated = re.search(r'^path="res://([^"]+)"', imported, re.MULTILINE).group(1)
        for item in [relative, relative + '.import', generated]:
            source = ROOT / 'game' / item
            target = PROJECT / item
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            receipts[item] = hashlib.sha256(source.read_bytes()).hexdigest()
    (PROJECT / 'probe.gd').write_text(PROBE % json.dumps(PATHS, ensure_ascii=False), encoding='utf-8')
    env = os.environ.copy()
    for key in ('APPDATA', 'LOCALAPPDATA'):
        target = PROJECT / 'profile' / key.lower()
        target.mkdir(parents=True)
        env[key] = str(target)
    results = []
    for index, mode in enumerate(['script', 'individual', 'script', 'individual']):
        command = [str(ENGINE), '--headless', '--path', str(PROJECT), '--script', 'res://probe.gd']
        if mode == 'individual':
            command += ['--', '--individual']
        run = subprocess.run(command, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60,
                             creationflags=subprocess.CREATE_NO_WINDOW)
        (OUT / f'component-{index}-{mode}.log').write_text(run.stdout + run.stderr, encoding='utf-8')
        result = {'command': command, 'exit_code': run.returncode}
        result['measurements'] = [json.loads(line.removeprefix('FONT_COMPONENT ')) for line in run.stdout.splitlines()
                                  if line.startswith('FONT_COMPONENT ')]
        results.append(result)
        print(json.dumps(result), flush=True)
        assert run.returncode == 0 and len(result['measurements']) == 1, run.stdout + run.stderr
    (OUT / 'component-results.json').write_text(json.dumps({'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'assets': receipts, 'runs': results}, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
