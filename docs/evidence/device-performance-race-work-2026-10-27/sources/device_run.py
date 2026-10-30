import pathlib,subprocess,json,time,hashlib,re,threading,queue,base64,sys
TASK=pathlib.Path(__file__).resolve().parent
ADB=r'C:\Users\ville\AppData\Local\Android\Sdk\platform-tools\adb.exe'
AAPT=r'C:\Users\ville\AppData\Local\Android\Sdk\build-tools\35.0.1\aapt.exe'
SERIAL='f0ba474a'
PACKAGE='org.beatmytrack.perf.r20261027a'
APK=TASK/'android-workspace/build/android/circuit01-debug.apk'
OUT=TASK/('device-'+(sys.argv[1] if len(sys.argv)>1 else 'first'))
OUT.mkdir(exist_ok=False)
commands=[]
def adb(*args,timeout=45,binary=False):
    cmd=[ADB,'-s',SERIAL,*args]
    p=subprocess.run(cmd,capture_output=True,timeout=timeout)
    if not binary: commands.append({'arguments':list(args),'exit':p.returncode,'stdout':p.stdout.decode('utf-8','replace'),'stderr':p.stderr.decode('utf-8','replace')})
    (OUT/'commands.json').write_text(json.dumps(commands,indent=2))
    if p.returncode: raise RuntimeError('ADB failed '+repr(args)+': '+p.stderr.decode('utf-8','replace'))
    return p.stdout if binary else p.stdout.decode('utf-8','replace').strip()
def metadata():
    result={}
    for key in ['ro.product.model','ro.build.version.sdk','ro.hardware']:
        result[key]=adb('shell','getprop',key)
    result['physical_display']=adb('shell','wm','size')
    result['battery_temperature']=adb('shell','dumpsys battery | grep temperature || true')
    result['thermal_status']=adb('shell','dumpsys thermalservice | grep -i "Thermal Status" || true')
    return result
badging=subprocess.run([AAPT,'dump','badging',str(APK)],capture_output=True,text=True,check=True).stdout
assert re.search(r"package: name='"+re.escape(PACKAGE)+r"'",badging), 'Wrong package identity'
assert 'application-debuggable' not in badging,'Unexpected debug build'
(OUT/'apk-badging.txt').write_text(badging)
receipt={'package':PACKAGE,'apk_sha256':hashlib.sha256(APK.read_bytes()).hexdigest(),'release_mode':True,'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'before':metadata()}
adb('shell','input','keyevent','KEYCODE_WAKEUP')
lock_state=adb('shell',"dumpsys window policy | grep 'showing=' || true")
if re.search(r'(?m)^\s*showing=true\s*$',lock_state):
    (OUT/'locked.json').write_text(json.dumps({'locked':True,'action':'no install/launch; owner must unlock'}))
    raise RuntimeError('Tablet is locked; unlock it before this performance run')
existing=adb('shell','pm path '+PACKAGE+' || true')
if existing:
    previous=list(TASK.glob('device-*/receipt.json'))
    assert any(json.loads(x.read_text()).get('installed_by_this_task') for x in previous),'Existing package has no task receipt'
install=adb('install','-r',str(APK),timeout=180)
assert 'Success' in install
receipt['installed_by_this_task']=True
(OUT/'receipt.json').write_text(json.dumps(receipt,indent=2))
print('Isolated release package installed.',flush=True)
if len(sys.argv)>4 and sys.argv[4]=='fresh':
    assert PACKAGE=='org.beatmytrack.perf.r20261027a' and receipt['installed_by_this_task']
    cleared=adb('shell','pm','clear',PACKAGE)
    assert 'Success' in cleared
    receipt['cleared_only_task_app_data']=True
    (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2))
if len(sys.argv)>3:
    mode=sys.argv[3]
    assert mode in ['full','garage']
    mode_file=OUT/'probe_mode.txt';mode_file.write_text(mode+'\n')
    remote='/sdcard/Android/data/'+PACKAGE+'/files'
    adb('shell','mkdir','-p',remote)
    adb('push',str(mode_file),remote+'/probe_mode.txt')
    receipt['requested_mode']=mode
launch=adb('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-p',PACKAGE)
pid=adb('shell','pidof '+PACKAGE+' || true').split()[0]
receipt['pid']=pid;receipt['launch']=launch
(OUT/'receipt.json').write_text(json.dumps(receipt,indent=2))
logerr=(OUT/'logcat-stderr.txt').open('w',encoding='utf-8')
logproc=subprocess.Popen([ADB,'-s',SERIAL,'logcat','--pid='+pid,'-v','raw','-T','1'],stdout=subprocess.PIPE,stderr=logerr,text=True,encoding='utf-8',errors='replace',bufsize=1)
lines=queue.Queue()
def reader():
    for line in logproc.stdout: lines.put(line)
threading.Thread(target=reader,daemon=True).start()
sf_layer='';sf_phase='';sf_frames=set();sf_reports=[];next_sf=0
def finish_sf():
    if len(sf_frames)<2:return
    stamps=sorted(sf_frames);deltas=sorted((b-a)/1e6 for a,b in zip(stamps,stamps[1:]))
    def pct(x):return deltas[min(len(deltas)-1,int((len(deltas)-1)*x))]
    sf_reports.append({'phase':sf_phase,'source':'SurfaceFlinger actual-present timestamps; first poll >=3s after phase begin; overlapping polls deduplicated','frames':len(deltas),'seconds':(stamps[-1]-stamps[0])/1e9,'p50_ms':pct(.5),'p95_ms':pct(.95),'p99_ms':pct(.99),'max_ms':max(deltas),'over34':sum(x>34 for x in deltas)})
    (OUT/'surface-presentation.json').write_text(json.dumps(sf_reports,indent=2))
reconnects=0
chunks={};count=0;finished=False;phase='startup';capture_due=0;captured=set();start=time.monotonic();next_memory=start+30
instrumented=(len(sys.argv)<3 or sys.argv[2]!='timing-only')
with (OUT/'probe-logcat.txt').open('w',encoding='utf-8') as log:
    try:
        while time.monotonic()-start<780:
            try: line=lines.get(timeout=0.25)
            except queue.Empty: line=''
            if line:
                log.write(line);log.flush()
                if 'BMT_PERF_BEGIN ' in line:
                    finish_sf();sf_frames.clear()
                    phase=line.split('BMT_PERF_BEGIN ',1)[1].strip();sf_phase=phase;next_sf=time.monotonic()+3
                    print('Device: '+phase,flush=True)
                    if instrumented and phase.startswith('garage'): next_memory=time.monotonic()+1
                    if instrumented and (phase.startswith('drive_') or phase.endswith('_orbit') or phase=='garage_first_visit'): capture_due=time.monotonic()+2
                if 'BMT_PERF_CASE ' in line:
                    finish_sf();sf_frames.clear();sf_phase=''
                    raw=line.split('BMT_PERF_CASE ',1)[1].strip()
                    try:
                        case=json.loads(raw)
                        with (OUT/'cases.jsonl').open('a') as f:f.write(json.dumps(case)+'\n')
                        print('  '+case['phase']+': '+str(round(case['wall_ms'],1))+'ms, p95 '+str(case['p95_ms'])+'ms, max '+str(case['max_ms'])+'ms',flush=True)
                    except json.JSONDecodeError: pass
                match=re.search(r'BMT_PERF_CHUNK (\d+)/(\d+) (\S+)',line)
                if match: chunks[int(match[1])]=match[3];count=int(match[2])
                if 'BMT_PERF_FINISHED ' in line:finished=True;break
            now=time.monotonic()
            if capture_due and now>=capture_due and phase not in captured:
                focus=adb('shell','dumpsys window | grep mCurrentFocus || true')
                if PACKAGE in focus:
                    (OUT/(phase+'.png')).write_bytes(adb('exec-out','screencap','-p',binary=True))
                    captured.add(phase)
                capture_due=0
            if not instrumented and sf_phase and (sf_phase.startswith('drive_') or sf_phase.endswith('_orbit')) and now>=next_sf:
                if not sf_layer:
                    layer_text=adb('shell',"dumpsys SurfaceFlinger --list | grep '"+PACKAGE+"' || true")
                    candidates=[x for x in layer_text.splitlines() if PACKAGE in x and 'SurfaceView' in x and 'BLAST' in x]
                    if candidates:
                        sf_layer=candidates[-1]
                        decorated=re.match(r'RequestedLayerState\{(.+?) parentId=',sf_layer)
                        if decorated:sf_layer=decorated[1]
                if sf_layer:
                    latency=adb('shell',"dumpsys SurfaceFlinger --latency '"+sf_layer+"'")
                    with (OUT/'surface-raw.jsonl').open('a') as f:f.write(json.dumps({'phase':sf_phase,'raw':latency})+'\n')
                    for row in latency.splitlines():
                        cols=row.split()
                        if len(cols)==3 and all(x.isdigit() for x in cols):
                            stamp=int(cols[1])
                            if 0<stamp<9000000000000000000:sf_frames.add(stamp)
                next_sf=now+.9
            if instrumented and now>=next_memory:
                text=adb('shell','dumpsys','meminfo',PACKAGE)
                with (OUT/'android-memory.txt').open('a') as f:f.write('\nPHASE '+phase+'\n'+text+'\n')
                next_memory=now+30
            if logproc.poll() is not None and lines.empty():
                if reconnects>=3 or not adb('shell','pidof '+PACKAGE+' || true'):break
                reconnects+=1
                print('Reconnecting own-process log stream: '+str(reconnects),flush=True)
                logproc=subprocess.Popen([ADB,'-s',SERIAL,'logcat','--pid='+pid,'-v','raw','-T','1000'],stdout=subprocess.PIPE,stderr=logerr,text=True,encoding='utf-8',errors='replace',bufsize=1)
                threading.Thread(target=reader,daemon=True).start()
    finally:
        logproc.terminate()
        try:logproc.wait(timeout=5)
        except subprocess.TimeoutExpired:logproc.kill()
receipt['logcat_reconnects']=reconnects
receipt['instrumented_screenshots_and_memory']=instrumented
receipt['finished_marker']=finished;receipt['elapsed_seconds']=round(time.monotonic()-start,2);receipt['chunks']=len(chunks);receipt['expected_chunks']=count
receipt['after']=metadata()
decoded=False
if finished and count and len(chunks)==count:
    try:
        report=json.loads(base64.b64decode(''.join(chunks[x] for x in range(count))))
        (OUT/'report.json').write_text(json.dumps(report,indent=2))
        receipt['errors']=report['errors']
        decoded=True
        print('Device report complete: '+str(len(report['cases']))+' cases; errors '+repr(report['errors']),flush=True)
    except Exception as error:
        receipt['error']='report transport: '+str(error)
else:
    receipt['error']='probe ended before complete report'
    if adb('shell','pidof '+PACKAGE+' || true'):adb('shell','am','force-stop',PACKAGE)
receipt['decoded_report']=decoded
(OUT/'receipt.json').write_text(json.dumps(receipt,indent=2))
print(json.dumps(receipt,indent=2),flush=True)
sys.exit(0 if decoded and not receipt.get('errors') else 1)
