"""Bounded local tablet profiling, with private raw data kept under build/."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'build/tablet-phase-profile-20261107'
EVIDENCE = Path(__file__).resolve().parent
ADB = Path('C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe')
SERIAL = 'f0ba474a'
PACKAGE = 'org.circuit01.handlinglab'
MARKER = 'files/tablet_phase_profile.json'
REMOTE = 'files/tablet-phase-20261107'
commands = []


def adb(*args, binary=False, check=True, timeout=60, input_data=None):
    command = [str(ADB), '-s', SERIAL, *args]
    began = time.monotonic()
    result = subprocess.run(command, input=input_data, capture_output=True, timeout=timeout,
                            creationflags=subprocess.CREATE_NO_WINDOW, check=False)
    commands.append({'command':command, 'exit_code':result.returncode, 'seconds':time.monotonic()-began})
    (OUT/('commands-'+str(os.getpid())+'.json')).write_text(json.dumps(commands, indent=2)+'\n')
    if check and result.returncode:
        raise RuntimeError(str(args)+': '+result.stderr.decode(errors='replace'))
    return result.stdout if binary else result.stdout.decode('utf-8', errors='replace')


def unlocked():
    adb('shell','input','keyevent','KEYCODE_WAKEUP')
    policy = adb('shell','dumpsys','window','policy').split('KeyguardServiceDelegate')[-1]
    return not bool(re.search(r'^\s+showing=true', policy, re.M))


def manifest(label):
    value = adb('shell','run-as',PACKAGE,'sh','-c',"'find files -type f -exec sha256sum {} \\;'",timeout=180)
    result = {}
    for line in value.splitlines():
        match = re.fullmatch(r'([a-f0-9]{64})\s+(.+)',line)
        if not match:
            raise ValueError('Unrecognized private manifest row')
        result[match[2]] = match[1]
    (OUT/(label+'-private.json')).write_text(json.dumps(result,indent=2)+'\n')
    return result


def context():
    package = adb('shell','dumpsys','package',PACKAGE)
    battery = adb('shell','dumpsys','battery')
    thermal = adb('shell','dumpsys','thermalservice')
    status = re.search(r'Thermal Status:\s*(\d+)',thermal)
    return {'version':re.search(r'versionName=(\S+)',package).group(1),
            'first_install':re.search(r'firstInstallTime=([^\r\n]+)',package).group(1).strip(),
            'model':adb('shell','getprop','ro.product.model').strip(),
            'battery_temperature_c':int(re.search(r'temperature:\s*(\d+)',battery).group(1))/10,
            'battery_percent':int(re.search(r'level:\s*(\d+)',battery).group(1)),
            'thermal_status':int(status.group(1)) if status else None}


def launch(label):
    if not unlocked():
        raise RuntimeError('OWNER_UNLOCK_REQUIRED')
    before = context()
    clock_before = time.time()
    device_epoch = float(adb('shell','date','+%s.%N').strip())
    clock_after = time.time()
    offset = device_epoch-(clock_before+clock_after)/2
    adb('shell','am','force-stop',PACKAGE)
    old_pid = adb('shell','pidof',PACKAGE,check=False).strip()
    assert not old_pid, old_pid
    began = time.monotonic()
    log_start = time.time()
    output = adb('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',PACKAGE,timeout=90)
    (OUT/(label+'-launch.log')).write_text(output)
    deadline = time.monotonic()+180
    pid = ''
    selected = []
    while time.monotonic()<deadline:
        pid = adb('shell','pidof',PACKAGE,check=False).strip().split(' ')[0]
        if pid:
            text = adb('logcat','-d','-v','epoch','--pid='+pid)
            selected = [line for line in text.splitlines() if re.search(r'APP_READY|TABLET_PHASE_|SCRIPT ERROR|SHADER ERROR|Parse Error|FATAL EXCEPTION|Fatal signal|Invalid call|Invalid access',line)]
            if any('APP_READY' in line for line in selected):
                break
        time.sleep(0.25)
    errors = [line for line in selected if re.search(r'SCRIPT ERROR|SHADER ERROR|Parse Error|FATAL EXCEPTION|Fatal signal|Invalid call|Invalid access',line)]
    ready = next((line for line in selected if 'APP_READY' in line), None)
    if not ready or errors:
        raise RuntimeError('Startup did not qualify: '+str(errors))
    stamp = float(ready.split()[0])
    record = {'label':label,'pid':pid,'context':before,'host_to_observed_app_ready_ms':(time.monotonic()-began)*1000,
              'launch_request_to_app_ready_log_ms':(stamp-log_start-offset)*1000,'ready_log':ready,
              'clock_offset_seconds':offset,'clock_uncertainty_ms':(clock_after-clock_before)*500,
              'android_launch_ms':{key:int(value) for key,value in re.findall(r'^(ThisTime|TotalTime|WaitTime):\s*(\d+)',output,re.M)},
              'errors':errors,'cache_state':'existing app/driver caches preserved; process restarted'}
    (EVIDENCE/(label+'.json')).write_text(json.dumps(record,indent=2)+'\n')
    return record


def baseline():
    assert context()['version']=='0.3.0-creator.e14bec0e820302b39bbb8c16684bda60'
    adb('shell','run-as',PACKAGE,'test','-e',MARKER,check=False)
    assert commands[-1]['exit_code']==1, 'Pre-existing diagnostic marker; preserve it.'
    files = manifest('before')
    package_path = adb('shell','pm','path',PACKAGE).strip().removeprefix('package:')
    digest = adb('shell','sha256sum',package_path,timeout=180).split()[0]
    assert digest=='696bfd7a802ec91f8be916619fd29e7d229babc1b70619573c8eef93c2b83bdc'
    backup = OUT/'original-installed.apk'
    adb('pull',package_path,str(backup),timeout=180)
    assert hashlib.sha256(backup.read_bytes()).hexdigest()==digest
    (EVIDENCE/'original.json').write_text(json.dumps({'context':context(),'apk_sha256':digest,'saved_files':len(files)},indent=2)+'\n')
    for index,name in enumerate(name for name in files if name.endswith('/records.json') or name=='files/local_records.json'):
        records = adb('exec-out','run-as',PACKAGE,'cat',name,binary=True)
        (OUT/('before-records-'+str(index)+'-private.json')).write_bytes(records)
    (OUT/'record-paths-private.json').write_text(json.dumps([name for name in files if name.endswith('/records.json') or name=='files/local_records.json']))
    rows = []
    for label in ['stock-startup-a','stock-startup-b']:
        row = launch(label)
        print(json.dumps(row),flush=True)
        rows.append(row)
        # Let normal initial content finish before the next process restart.
        for _ in range(10):
            time.sleep(1)
            adb('shell','input','keyevent','KEYCODE_WAKEUP')
    print('BASELINE_COMPLETE',flush=True)


if __name__=='__main__':
    baseline()
