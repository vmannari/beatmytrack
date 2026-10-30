from pathlib import Path
import json,os,re,subprocess
work=Path(__file__).resolve().parent
evidence=work.parents[1]/'docs/evidence/desert-phone-performance-2026-10-25'
adb=Path(os.environ['LOCALAPPDATA'])/'Android/Sdk/platform-tools/adb.exe'
package='org.circuit01.handlinglab'
def run(*args):
    return subprocess.check_output([str(adb),'-s','PRQKU4U4PREQNRWG',*args],timeout=60)
build=json.loads((work/'verified-build.json').read_text(encoding='utf-8-sig'))
metadata=run('shell','dumpsys','package',package).decode()
assert re.search(r'versionName=(\S+)',metadata).group(1)==build['build_id']
remote=run('shell','pm','path',package).decode().strip().removeprefix('package:')
assert re.fullmatch(r'/data/app/[A-Za-z0-9_./+=~\-]+\.apk',remote)
assert run('shell','sha256sum',remote).decode().split()[0]==build['apk_sha256']
files=run('shell','run-as',package,'ls','files').decode().splitlines()
assert 'mobile_probe.json' not in files and 'mobile_probe_results.json' not in files
pid=run('shell','pidof',package).decode().strip().split()[0]
logs=run('logcat','-d','--pid='+pid,'-v','brief').decode(errors='replace')
(work/'final-startup-private.log').write_text(logs,encoding='utf-8')
errors=[line for line in logs.splitlines() if re.search(r'SCRIPT ERROR:|(^|\s)ERROR:|FATAL EXCEPTION|Unable to load GDExtension',line)]
assert 'APP_READY' in logs and not errors
result={'version_matches':True,'installed_sha256_matches':True,'diagnostic_markers_removed':True,'normal_app_ready':True,'matched_startup_errors':len(errors),'process_id':pid}
(evidence/'final-phone-state.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
