from pathlib import Path
import hashlib,json,subprocess
root=Path.cwd(); out=root/'build/mobile-audit-fixes-2026-10-26'; tools=Path('C:/msys64/mingw64/bin')
source=out/'symbol_fixture.cpp'; binary=out/'symbol_fixture.dll'
source.write_text('extern "C" __declspec(dllexport) int bmt_symbol_fixture(int value) {\n    return value + 7;\n}\n',encoding='utf-8')
commands=[]
def run(args):
    p=subprocess.run([str(a) for a in args],capture_output=True,text=True,check=False)
    commands.append({'command':[str(a) for a in args],'exit_code':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
    assert p.returncode==0, commands[-1]
    return p.stdout
run([tools/'g++.exe','-g','-O0','-shared',source,'-o',binary])
run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',root/'scripts/retain_native_symbols.ps1','-Compiled',binary,'-Objcopy',tools/'objcopy.exe','-Strip',tools/'strip.exe','-Source',source])
digest=hashlib.sha256(binary.read_bytes()).hexdigest(); archive=root/'build/symbols'/digest
mapping=json.loads((archive/'mapping.json').read_text(encoding='utf-8-sig')); debug=archive/mapping['symbols']
assert mapping['binary_sha256']==digest and mapping['symbols_sha256']==hashlib.sha256(debug.read_bytes()).hexdigest()
symbols=run([tools/'nm.exe',debug]); address=next(line.split()[0] for line in symbols.splitlines() if line.endswith(' T bmt_symbol_fixture'))
site=run([tools/'addr2line.exe','-f','-e',debug,address])
assert 'bmt_symbol_fixture' in site and 'symbol_fixture.cpp:1' in site,site
(out/'native-symbol-test.json').write_text(json.dumps({'checks':'stripped binary hash, separate debug hash, source hash and actual address-to-source resolution','mapping':mapping,'resolved':site,'commands':commands},indent=2),encoding='utf-8')
print('NATIVE_SYMBOLS: extracted, stripped, mapped and resolved fixture address to source line')
