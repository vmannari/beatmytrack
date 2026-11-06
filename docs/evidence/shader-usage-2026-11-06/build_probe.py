import hashlib,json,subprocess
from pathlib import Path
p=Path(__file__).resolve().parent;root=p.parents[2]
source=p/'harness/program_probe.cpp';dll=p/'harness/program_usage_v3.dll'
command=['C:/msys64/mingw64/bin/g++.exe',str(source),'-I',str(root/'.tools/godot-cpp-music/gdextension'),'-std=c++17','-O2','-shared','-static','-lopengl32','-lbcrypt','-lpsapi','-o',str(dll)]
result=subprocess.run(command,capture_output=True,text=True)
receipt={'command':command,'exit_code':result.returncode,'output':result.stdout+result.stderr}
assert result.returncode==0,receipt
receipt['sha256']={str(x.relative_to(p)):hashlib.sha256(x.read_bytes()).hexdigest() for x in (source,dll,p/'harness/shader_job.hpp')}
(p/'build-v3.json').write_text(json.dumps(receipt,indent=2)+'\n')
(p/'harness/program_probe.gdextension').write_text('[configuration]\nentry_symbol="program_probe_init"\ncompatibility_minimum="4.7"\n[libraries]\nwindows.debug.x86_64="'+dll.as_posix()+'"\nwindows.release.x86_64="'+dll.as_posix()+'"\n')
print(json.dumps(receipt))
