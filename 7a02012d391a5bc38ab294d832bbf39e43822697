"""Resume startup checks after owner unlock; never repeats installation."""
import hashlib
import json
import os
import re
import subprocess
import time
import zipfile
from pathlib import Path

work=Path(__file__).resolve().parent
adb=Path(os.environ['LOCALAPPDATA'])/'Android/Sdk/platform-tools/adb.exe'
package='org.circuit01.handlinglab'
def call(*args,binary=False):
    result=subprocess.run([str(adb),'-s','f0ba474a',*args],capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
    assert result.returncode==0,'Tablet connection unavailable; installed data-preservation receipt is retained'
    return result.stdout if binary else result.stdout.decode('utf-8',errors='replace')
installed=json.loads((work/'install-preserved.json').read_text())
export=json.loads((work/'export-result.json').read_text())
text=call('shell','dumpsys','package',package)
assert re.search(r'versionName=(\S+)',text).group(1)==installed['installed_version']
apk_path=call('shell','pm','path',package).strip().removeprefix('package:')
assert call('shell','sha256sum',apk_path).split()[0]==installed['installed_apk_sha256']
deadline=time.monotonic()+600
while time.monotonic()<deadline:
    pids=call('shell','pidof',package).strip().split()
    if not pids:
        call('shell','monkey','-p',package,'-c','android.intent.category.LAUNCHER','1')
        time.sleep(2)
        continue
    pid=pids[0]
    logs=call('logcat','-d','-v','brief','--pid='+pid)
    selected=[line for line in logs.splitlines() if re.search(r'APP_READY|Godot Engine|OpenGL API|Vulkan|SCRIPT ERROR|Parse Error|FATAL EXCEPTION|Fatal signal|Unable to load|Invalid call|Invalid access',line)]
    failures=[line for line in selected if re.search(r'SCRIPT ERROR|Parse Error|FATAL EXCEPTION|Fatal signal|Unable to load|Invalid call|Invalid access',line)]
    assert not failures,'Startup errors require investigation; matching APK is installed'
    focus=call('shell','dumpsys','window')
    focus_lines=[line.strip() for line in focus.splitlines() if 'mCurrentFocus=' in line or 'mFocusedApp=' in line]
    visible=any('mCurrentFocus=' in line and package in line for line in focus_lines)
    ready=any('APP_READY' in line for line in selected)
    if visible and ready:
        (work/'tablet.png').write_bytes(call('exec-out','screencap','-p',binary=True))
        break
    time.sleep(2)
else:
    raise RuntimeError('Installed; owner unlock and visible game are still needed for startup acceptance')
(work/'startup-filtered.log').write_text('\n'.join(selected)+'\n')
with zipfile.ZipFile(export['apk']['path']) as archive:
    entries=archive.namelist()
report={**installed,'serial':'f0ba474a','model':'OPD2403','pid':pid,'app_ready':True,'startup_errors':[],
        'foreground':True,'focus':focus_lines,'apk':export['apk'],'zip_entries':len(entries),'abis':['arm64-v8a'],
        'startup_resumed_after_secure_unlock':True}
(work/'deployment.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report),flush=True)
