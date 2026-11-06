"""Read-only runtime review; isolated offline profiles and bounded owned runs."""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
ENGINE = Path('C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe')
EXPECTED = (ROOT / 'godot-version.txt').read_text().strip()


def sources():
    result = {}
    for path in (ROOT / 'game').rglob('*'):
        relative = path.relative_to(ROOT).as_posix()
        if path.is_file() and '/.godot/' not in relative and '/assets/' not in relative:
            if path.suffix in {'.gd', '.gdshader', '.gdshaderinc', '.tscn', '.godot', '.cfg', '.gdextension'}:
                result[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def main():
    if os.name == 'nt':
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.SetErrorMode(kernel.GetErrorMode() | 0x0002)
    version = subprocess.check_output([str(ENGINE), '--version'], text=True).strip()
    assert version == EXPECTED, (version, EXPECTED)
    (OUT / 'sources-before.json').write_text(json.dumps(sources(), indent=2))
    cases = [
        ('graphics-settings', 'test_graphics_settings.gd', False, [], None),
        ('tablet-budget', 'test_tablet_render_budget.gd', False, [], None),
        ('native-blend-memory', 'test_native_blend_memory.gd', False, [], None),
        ('startup-stock', 'profile_startup_shell.gd', True, [], 'stock'),
        ('startup-custom-miss', 'profile_startup_shell.gd', True, ['--custom'], 'custom'),
        ('startup-custom-hit', 'profile_startup_shell.gd', True, ['--custom'], 'custom'),
        ('race-pine-winter', 'profile_first_use_graphics.gd', True, [], None),
    ]
    rows = []
    for name, script, native, arguments, shared_profile in cases:
        output = OUT / name
        output.mkdir(exist_ok=True)
        profile = ROOT / 'build' / 'mobile-performance-review-2026-11-05' / (shared_profile or name)
        env = os.environ.copy()
        for key in ['BMT_API_URL', 'BMT_DEV_AUTH_KEY', 'BMT_NATIVE_TRACE', 'BMT_NATIVE_EXTENSION']:
            env.pop(key, None)
        for key in ['APPDATA', 'LOCALAPPDATA']:
            destination = profile / key.lower()
            destination.mkdir(parents=True, exist_ok=True)
            env[key] = str(destination)
        user = Path(env['APPDATA']) / 'Circuit01Lab'
        user.mkdir(exist_ok=True)
        (user / 'backend.cfg').write_text('[backend]\nurl=""\n', encoding='utf-8')
        env['BMT_LOADING_OUTPUT'] = str(output / 'startup.json')
        env['BMT_GRAPHICS_OUTPUT'] = str(output)
        env['BMT_GRAPHICS_THEMES'] = 'pine,winter'
        command = [str(ENGINE), '--path', str(ROOT / 'game'), '--audio-driver', 'Dummy']
        command += ['--rendering-method', 'gl_compatibility', '--position', '10000,10000', '--resolution', '1280x720'] if native else ['--headless']
        command += ['--script', 'res://tests/' + script]
        if arguments:
            command += ['--'] + arguments
        before = sources()
        started = time.monotonic()
        timed_out = False
        with (output / 'run.log').open('w', encoding='utf-8') as log:
            try:
                completed = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240, creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
                code = completed.returncode
            except subprocess.TimeoutExpired:
                code = None
                timed_out = True
        after = sources()
        text = (output / 'run.log').read_text(encoding='utf-8', errors='replace')
        changes = [key for key in sorted(before.keys() | after.keys()) if before.get(key) != after.get(key)]
        row = {'name': name, 'command': command, 'engine': version, 'native_desktop': native,
               'profile': str(profile), 'offline_config': str(user / 'backend.cfg'), 'elapsed_seconds': time.monotonic() - started,
               'exit_code': code, 'timeout': timed_out, 'source_changes': changes,
               'script_or_shader_error': bool(re.search(r'SCRIPT ERROR|SHADER ERROR|Parse Error|Compile Error', text)),
               'result_lines': [line for line in text.splitlines() if re.search(r'checks|failures|SHELL_PROFILE|NATIVE_BLEND_MEMORY|FIRST_USE_ROW', line)],
               'diagnostics': [line for line in text.splitlines() if re.search(r'WARNING:|ERROR:|leaked|still in use', line)]}
        rows.append(row)
        (OUT / 'runs.json').write_text(json.dumps(rows, indent=2), encoding='utf-8')
        print(json.dumps(row), flush=True)
    (OUT / 'sources-after.json').write_text(json.dumps(sources(), indent=2))


if __name__ == '__main__':
    main()
