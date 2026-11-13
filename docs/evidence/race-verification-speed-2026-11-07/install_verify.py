"""Install a newly verified ARM64 export on the named tablet; preserve app data."""
import hashlib,json,os,re,shlex,subprocess,time,zipfile
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT/'frozen'
PACKAGE='org.circuit01.handlinglab';SERIAL='f0ba474a'
SDK=Path(os.environ['LOCALAPPDATA'])/'Android/Sdk';ADB=SDK/'platform-tools/adb.exe'
commands=[]
def adb(*args,binary=False,timeout=60):
    command=[str(ADB),'-s',SERIAL,*args];started=time.monotonic()
    result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=timeout,creationflags=subprocess.CREATE_NO_WINDOW)
    commands.append({'command':command,'exit_code':result.returncode,'seconds':time.monotonic()-started})
    (OUT/'device-commands.json').write_text(json.dumps(commands,indent=2)+'\n')
    assert result.returncode==0,(args,result.stderr.decode(errors='replace'))
    return result.stdout if binary else result.stdout.decode('utf-8',errors='replace')
def package_info():
    text=adb('shell','dumpsys','package',PACKAGE)
    return {'version':re.search(r'versionName=(\S+)',text).group(1),'first_install':re.search(r'firstInstallTime=([^\r\n]+)',text).group(1).strip()}
def file_manifest():
    command=r'find files -type f -exec sha256sum {} \;'
    text=adb('shell','run-as',PACKAGE,'sh','-c',shlex.quote(command),timeout=180)
    result={}
    for line in text.splitlines():
        match=re.fullmatch(r'([a-f0-9]{64})[ \t]+(.+)',line);assert match,line
        result[match[2]]=match[1]
    return result
export=json.loads((OUT/'export-result.json').read_text());assert export['exit_code']==0
assert set(export['source_changes'])<={'game/core/build_identity.gd','game/project.godot'},export['source_changes']
apk=Path(export['apk']['path']);digest=hashlib.sha256(apk.read_bytes()).hexdigest();assert digest==export['apk']['sha256']
version=export['build_id']
with zipfile.ZipFile(apk) as archive:
    assert archive.testzip() is None
    entries=archive.namelist();abis={name.split('/')[1] for name in entries if name.startswith('lib/') and name.endswith('.so')};assert abis=={'arm64-v8a'},abis
badging=subprocess.check_output([str(SDK/'build-tools/36.1.0/aapt2.exe'),'dump','badging',str(apk)],text=True,encoding='utf-8')
assert "name='"+PACKAGE+"'" in badging.splitlines()[0] and "versionName='"+version+"'" in badging.splitlines()[0]
(OUT/'apk-badging.txt').write_text(badging)
assert adb('shell','getprop','ro.product.model').strip()=='OPD2403'
assert adb('shell','getprop','ro.product.cpu.abilist').strip()=='arm64-v8a'
before=package_info();assert before['version']=='0.3.0-creator.769446573963ee2e0b51fc5a5c783fe7',before;old_path=adb('shell','pm','path',PACKAGE).strip();assert old_path.startswith('package:') and '\n' not in old_path
old_path=old_path.removeprefix('package:');old_digest=adb('shell','sha256sum',old_path,timeout=180).split()[0]
previous=OUT/'previous-installed.apk'
if not previous.exists() or hashlib.sha256(previous.read_bytes()).hexdigest()!=old_digest:
    previous=OUT/'previous-installed.apk';adb('pull',old_path,str(previous),timeout=180);assert hashlib.sha256(previous.read_bytes()).hexdigest()==old_digest
print('APK, device and rollback package verified: '+version,flush=True)
# Installation already stops the app. Quiesce before hashing to distinguish
# package replacement from ordinary background application writes.
adb('shell','input','keyevent','KEYCODE_WAKEUP')
adb('shell','am','force-stop',PACKAGE)
files_before=file_manifest();(OUT/'files-before-private.json').write_text(json.dumps(files_before,indent=2)+'\n')
result=adb('install','-r',str(apk),timeout=360)
assert 'Success' in result,result
after=package_info();assert after['version']==version and after['first_install']==before['first_install']
files_after=file_manifest();(OUT/'files-after-install-private.json').write_text(json.dumps(files_after,indent=2)+'\n');assert files_after==files_before,'Installation changed app files before first launch'
installed_path=adb('shell','pm','path',PACKAGE).strip().removeprefix('package:');installed_digest=adb('shell','sha256sum',installed_path,timeout=180).split()[0];assert installed_digest==digest
print('Installed APK hash matched; '+str(len(files_before))+' existing app files unchanged.',flush=True)
(OUT/'install-preserved.json').write_text(json.dumps({'previous_version':before['version'],'installed_version':version,'first_install_time_preserved':True,'install_replace':True,'data_cleared':False,'prelaunch_files_preserved':len(files_before),'prelaunch_manifest_exact':True,'previous_apk_sha256':old_digest,'installed_apk_sha256':installed_digest},indent=2)+'\n')
adb('shell','input','keyevent','KEYCODE_WAKEUP');adb('shell','wm','dismiss-keyguard')
adb('shell','monkey','-p',PACKAGE,'-c','android.intent.category.LAUNCHER','1')
deadline=time.monotonic()+120;ready=False;pid='';selected=[]
while time.monotonic()<deadline:
    values=adb('shell','pidof',PACKAGE).strip().split()
    if values:
        pid=values[0];log=adb('logcat','-d','-v','brief','--pid='+pid)
        selected=[line for line in log.splitlines() if re.search(r'APP_READY|Godot Engine|OpenGL API|Vulkan|SCRIPT ERROR|Parse Error|FATAL EXCEPTION|Fatal signal|Unable to load|Invalid call|Invalid access',line)]
        ready=any('APP_READY' in line for line in selected)
        if ready:break
    time.sleep(2)
(OUT/'startup-filtered.log').write_text('\n'.join(selected)+'\n')
failures=[line for line in selected if re.search(r'SCRIPT ERROR|Parse Error|FATAL EXCEPTION|Fatal signal|Unable to load|Invalid call|Invalid access',line)]
focus=adb('shell','dumpsys','window');focus_lines=[line.strip() for line in focus.splitlines() if 'mCurrentFocus=' in line or 'mFocusedApp=' in line];visible=any('mCurrentFocus=' in line and PACKAGE in line for line in focus_lines)
if visible:(OUT/'tablet.png').write_bytes(adb('exec-out','screencap','-p',binary=True))
report={'serial':SERIAL,'model':'OPD2403','previous_version':before['version'],'installed_version':version,'first_install_time_preserved':True,'install_replace':True,'data_cleared':False,'prelaunch_files_preserved':len(files_before),'prelaunch_manifest_exact':True,'previous_apk':str(previous),'previous_apk_sha256':old_digest,'installed_apk_sha256':installed_digest,'pid':pid,'app_ready':ready,'startup_errors':failures,'foreground':visible,'focus':focus_lines,'apk':export['apk'],'zip_entries':len(entries),'abis':sorted(abis)}
(OUT/'deployment.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report),flush=True)
assert ready and not failures and visible,'Installed, but startup/foreground needs investigation.'
