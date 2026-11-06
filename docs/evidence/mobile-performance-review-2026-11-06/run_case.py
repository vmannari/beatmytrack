"""Bounded, offline desktop test in an isolated profile; never touches owner saves."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
ENGINE = Path('C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe')

def sources(project):
    return {p.relative_to(project).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in project.rglob('*') if p.is_file() and '/.godot/' not in p.as_posix()
            and '/assets/' not in p.as_posix() and p.suffix in {'.gd','.gdshader','.gdshaderinc','.tscn','.godot','.cfg','.gdextension'}}

def main():
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument('name')
    parser.add_argument('script')
    parser.add_argument('--project', type=Path, default=ROOT/'game')
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--verbose', action='store_true')
    parser.add_argument('--renderer', default='gl_compatibility')
    parser.add_argument('--profile')
    parser.add_argument('--timeout', type=int, default=240)
    parser.add_argument('--args', nargs=argparse.REMAINDER, default=[])
    args = parser.parse_args()
    if os.name == 'nt':
        kernel = ctypes.WinDLL('kernel32',use_last_error=True)
        kernel.SetErrorMode(kernel.GetErrorMode() | 0x0002)
    version = subprocess.check_output([str(ENGINE),'--version'],text=True).strip()
    assert version == (ROOT/'godot-version.txt').read_text().strip()
    output = OUT/args.name
    output.mkdir(exist_ok=False)
    profile = ROOT/'build/mobile-performance-review-20261106/profiles'/(args.profile or args.name)
    env = os.environ.copy()
    for key in ['BMT_API_URL','BMT_DEV_AUTH_KEY','BMT_NATIVE_TRACE','BMT_NATIVE_EXTENSION']:
        env.pop(key,None)
    for key in ['APPDATA','LOCALAPPDATA']:
        destination = profile/key.lower()
        destination.mkdir(parents=True,exist_ok=True)
        env[key] = str(destination)
    user = Path(env['APPDATA'])/'Circuit01Lab'
    user.mkdir(exist_ok=True)
    (user/'backend.cfg').write_text('[backend]\nurl=""\n',encoding='utf-8')
    env['BMT_LOADING_OUTPUT'] = str(output/'result.json')
    env['BMT_GRAPHICS_EVIDENCE'] = str(output)
    env['BMT_GRAPHICS_OUTPUT'] = str(output)
    env['BMT_GRAPHICS_THEMES'] = 'pine,winter,desert,night_city,storm'
    command = [str(ENGINE),'--path',str(args.project),'--audio-driver','Dummy']
    command += ['--rendering-method',args.renderer,'--position','10000,10000','--resolution','1280x720'] if args.native else ['--headless']
    command += ['--script','res://tests/'+args.script]
    if args.verbose: command += ['--verbose']
    if args.args: command += ['--']+args.args
    before = sources(args.project)
    started = time.monotonic()
    timeout = False
    with (output/'run.log').open('w',encoding='utf-8') as log:
        try:
            result = subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=args.timeout,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = None
            timeout = True
    after = sources(args.project)
    log = (output/'run.log').read_text(encoding='utf-8',errors='replace')
    row = dict(name=args.name,command=command,version=version,profile=str(profile),elapsed_seconds=time.monotonic()-started,exit_code=code,timeout=timeout,
               source_changes=[p for p in sorted(before.keys()|after.keys()) if before.get(p)!=after.get(p)],
               script_error=bool(re.search(r'SCRIPT ERROR|SHADER ERROR|Parse Error|Compile Error',log)),
               results=[line for line in log.splitlines() if re.search(r'checks|failures|SHELL_PROFILE|FIRST_USE_ROW|GARAGE_SAMPLE|TRACK_EDITOR_HISTORY|NATIVE_BLEND_MEMORY|FAIL|TIMEOUT',line)],
               diagnostics=[line for line in log.splitlines() if re.search(r'WARNING:|ERROR:|leaked|still in use',line)])
    (output/'run.json').write_text(json.dumps(row,indent=2)+'\n',encoding='utf-8')
    (output/'sources.json').write_text(json.dumps(before,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(row),flush=True)

if __name__=='__main__': main()
