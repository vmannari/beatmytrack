"""Build the task-owned engine; does not replace installed engines/templates."""
from pathlib import Path
import hashlib,json,subprocess,sys,time
root=Path(__file__).resolve().parents[2]
engine=root/'build/biome-shader-profiles-20261106/godot-4.7.2-stable'
evidence=root/'docs/evidence/biome-shader-profiles-2026-11-06'
subprocess.run([sys.executable,str(Path(__file__).with_name('prepare_engine.py'))],check=True)
command=[sys.executable,str(root/'.tools/scons-music/scripts/scons.py'),'-C',str(engine),
 'platform=windows','target=template_debug','use_mingw=yes','vulkan=no','d3d12=no',
 'debug_symbols=no','optimize=speed','lto=none','disable_path_overrides=no','-j12']
began=time.monotonic()
with (evidence/'engine-final-build.log').open('w') as log:
    result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
receipt={'command':command,'exit_code':result.returncode,'seconds':time.monotonic()-began,
 'source_fingerprint':(engine/'modules/biome_shader_profiles/build_fingerprint.gen.h').read_text()}
if result.returncode==0:
    receipt['binaries']={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (engine/'bin').glob('*.exe')}
(evidence/'engine-build.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt))
sys.exit(result.returncode)
