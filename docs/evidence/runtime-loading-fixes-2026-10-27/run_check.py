from pathlib import Path
import hashlib,json,os,re,subprocess,sys,time

ROOT=Path.cwd()
LAB=ROOT/'build/runtime-loading-fixes-2026-10-27'
label,script,mode=sys.argv[1:4]
extra_args=sys.argv[4:]
project=ROOT/'game'
for value in extra_args:
    if value.startswith('--project='): project=ROOT/value.split('=',1)[1]
extra_args=[value for value in extra_args if not value.startswith('--project=')]
source=ROOT/script
text=source.read_text(encoding='utf-8')
if mode=='headless' and 'await RenderingServer.frame_post_draw' in text and 'DisplayServer.get_name()' not in text:
    raise ValueError(label+': graphical fixture requires a native renderer')
output='res://../build/runtime-loading-fixes-2026-10-27/outputs/'+label
lines=[]
for line in text.splitlines(keepends=True):
    if re.search(r'\b(output|out|OUTPUT|OUT|evidence|capture)\s*(?::[^=]+)?=',line):
        if 'res://../docs/evidence/' in line:
            line=re.sub(r'res://\.\./docs/evidence/[^"\n]+',lambda match: output+'/' if match.group().endswith('/') else output,line)
        elif 'res://../build/' in line:
            is_file='.json' in line or '.png' in line
            line=re.sub(r'res://\.\./build/[^"\n]+',lambda match: output+'/'+match.group().rsplit('/',1)[-1] if is_file else output,line)
    if 'var folder:' in line and 'res://../build/' in line:
        line=re.sub(r'res://\.\./build/[^"\n]+',output+'/fixture-',line)
    lines.append(line)
text=''.join(lines)
setup='\n\tvar task_config:=ConfigFile.new()\n\ttask_config.set_value("backend","url","")\n\tassert(task_config.save("user://backend.cfg")==OK)\n\tOS.unset_environment("BMT_API_URL")\n'
if '--task-start' in sys.argv:
    setup+='''
	var task_paths: Array[String]=["vehicle/skid_trails.gd","vehicle/compact_grille.gd","vehicle/compact_detail.gd","vehicle/effect_render_preparation.gd","editor/editor_memory.gd","core/app.gd"]
	var task_scripts: Array[Script]=[]
	for task_path: String in task_paths: task_scripts.append(load("res://"+task_path))
	for task_index: int in range(task_paths.size()): task_scripts[task_index].source_code=FileAccess.get_file_as_string("res://../build/runtime-loading-fixes-2026-10-27/before/game/"+task_paths[task_index]+".txt")
	for task_script: Script in task_scripts: assert(task_script.reload(true)==OK)
'''
entry=re.search(r'func _?run\(\)\s*->\s*void\s*:',text)
assert entry is not None,(label,'missing test entrypoint')
text=text[:entry.end()]+setup+text[entry.end():]
probe=LAB/'checks'/(label+'.gd');probe.parent.mkdir(parents=True,exist_ok=True)
probe.write_text(text,encoding='utf-8',newline='\n')
profile=LAB/'profiles'/label;profile.mkdir(parents=True,exist_ok=True)
(LAB/'outputs'/label).mkdir(parents=True,exist_ok=True)
env={key:value for key,value in os.environ.items() if not key.startswith('BMT_')}
env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile),PYTHONIOENCODING='utf-8')
cmd=['C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe','--audio-driver','Dummy','--path',str(project),'--script',str(probe)]
cmd+=['--headless'] if mode=='headless' else ['--rendering-method',mode]
if extra_args:cmd+=['--',*extra_args]
started=time.monotonic()
with (LAB/(label+'.log')).open('wb') as log:
    process=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,env=env)
    (LAB/(label+'-started.json')).write_text(json.dumps(dict(label=label,pid=process.pid,command=cmd),indent=2),encoding='utf-8')
    try:code=process.wait(timeout=600)
    except subprocess.TimeoutExpired:process.kill();process.wait();code='timeout'
record=dict(label=label,command=cmd,pid=process.pid,exit=code,seconds=round(time.monotonic()-started,3),
            original_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),probe_sha256=hashlib.sha256(probe.read_bytes()).hexdigest())
log_text=(LAB/(label+'.log')).read_text(encoding='utf-8',errors='replace')
record['runtime_errors']=[line for line in log_text.splitlines() if ('SCRIPT ERROR:' in line or 'ERROR:' in line or 'leaked at exit' in line) and 'Failed to read the root certificate store.' not in line]
(LAB/(label+'-execution.json')).write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps(record),flush=True)
sys.stdout.reconfigure(encoding='utf-8')
print((LAB/(label+'.log')).read_text(encoding='utf-8',errors='replace')[-4500:])
sys.exit(0 if code==0 and not record['runtime_errors'] else 1)
