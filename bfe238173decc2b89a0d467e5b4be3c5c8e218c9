import os,pathlib,subprocess,json,time,sys
root=pathlib.Path(__file__).resolve().parents[2]
task=pathlib.Path(__file__).resolve().parent
mirror=task/'android-workspace'
env=os.environ.copy()
env['APPDATA']=str(task/'android-appdata')
env['GODOT_ANDROID_KEYSTORE_RELEASE_PATH']=str(task/'perf-debug.keystore')
env['GODOT_ANDROID_KEYSTORE_RELEASE_USER']='androiddebugkey'
env['GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD']='android'
env['GIT_CONFIG_COUNT']='1'
env['GIT_CONFIG_KEY_0']='safe.directory'
env['GIT_CONFIG_VALUE_0']=mirror.as_posix()
env.pop('BMT_ANDROID_TEST_CA_SHA256',None)
cmd=['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',str(mirror/'scripts/dev.ps1'),'ExportAndroid','-GodotPath',r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe','-QuickValidation','-CommandTimeoutSeconds','900']
start=time.monotonic()
with (task/'android-release-export.log').open('w',encoding='utf-8') as log:
    p=subprocess.run(cmd,cwd=mirror,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=1500)
result={'command':cmd,'exit':p.returncode,'seconds':round(time.monotonic()-start,2),'log':str(task/'android-release-export.log'),'task_only_signing':True,'release_mode':True,'git_safe_directory':'process-scoped exact mirror only'}
(task/'android-release-export-result.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result),flush=True)
sys.exit(p.returncode)
