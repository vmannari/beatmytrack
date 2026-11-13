import hashlib,json,os,shutil,subprocess,concurrent.futures,difflib,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];WORK=Path(__file__).resolve().parent
EV=ROOT/'docs/evidence/asset-optimisation-2026-11-08'
FROZEN=WORK/'frozen';FROZEN.mkdir(exist_ok=True)
pins={} if '--current' in sys.argv else json.loads((EV/'baked-sources.json').read_text())
changed={p:h for p,h in pins.items() if not p.startswith('tree:') and (ROOT/p).exists() and hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=h}
recovered={}
paths=subprocess.run(['rg','--files','--hidden','--no-ignore','-g','*.gd','-g','!**/.godot/**','-g','!**/android/**'],cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True).stdout.splitlines()
for relative,wanted in changed.items():
    candidate=(ROOT/relative).read_bytes()
    # Recover only when the exact complete baked hash proves the source bytes.
    block='\t\tif vehicle_id == "super_rally":\n\t\t\tif side < 0.0: SuperRallyModel.night_lens(headlights,lens)\n\t\t\tcontinue\n'.encode()
    normal=candidate.replace(b'\r\n',b'\n').replace(block,b'')
    for variant in [candidate.replace(block,b''),candidate.replace(block.replace(b'\n',b'\r\n'),b''),normal,normal.replace(b'\n',b'\r\n')]:
        if hashlib.sha256(variant).hexdigest()==wanted:recovered[relative]=variant;break
    if relative not in recovered:
        for name in paths:
            if Path(name).name!=Path(relative).name:continue
            try:data=(ROOT/name).read_bytes()
            except OSError:continue
            if hashlib.sha256(data).hexdigest()==wanted:recovered[relative]=data;break
    baseline=WORK/'before'/relative
    if relative not in recovered and baseline.exists():
        left=baseline.read_text(encoding='utf-8').splitlines(True);right=(ROOT/relative).read_text(encoding='utf-8').splitlines(True)
        pieces=[];changes=0
        for tag,i,j,k,l in difflib.SequenceMatcher(a=left,b=right,autojunk=False).get_opcodes():
            if tag=='equal':pieces.append((''.join(left[i:j]),None))
            else:pieces.append((''.join(left[i:j]),''.join(right[k:l])));changes+=1
        print('Exact-source recovery candidates',relative,changes,flush=True)
        assert changes<=20
        for mask in range(1<<changes):
            strings=[];index=0
            for old,new in pieces:
                strings.append(old if new is None or not mask&(1<<index) else new)
                if new is not None:index+=1
            value=''.join(strings).encode()
            for variant in [value,value.replace(b'\n',b'\r\n')]:
                if hashlib.sha256(variant).hexdigest()==wanted:recovered[relative]=variant;break
            if relative in recovered:break
    assert relative in recovered,'Cannot recover exact baked source: '+relative
files=[]
for base,dirs,names in os.walk(ROOT/'game'):
    dirs[:]=[d for d in dirs if d not in ['android','__pycache__','.git']]
    rel=Path(base).relative_to(ROOT/'game')
    if rel.parts and rel.parts[0]=='.godot':
        dirs[:]=[d for d in dirs if d=='imported'] if len(rel.parts)==1 else dirs
        if len(rel.parts)==1:names=[n for n in names if n in ['global_script_class_cache.cfg','uid_cache.bin']]
    for name in names:files.append(Path(base)/name)
def copy(p):
    target=FROZEN/p.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:list(pool.map(copy,files))
for relative,data in recovered.items():(FROZEN/relative).write_bytes(data)
for name in ['godot-version.txt'] :shutil.copyfile(ROOT/name,FROZEN/name)
for p in WORK.glob('*.gd'):
    target=FROZEN/'build/asset-optimisation-2026-11-08'/p.name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
receipt_source={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.suffix in ['.gd','.gdshader','.gdshaderinc','.tres'] and '.godot' not in p.parts}
(EV/'frozen-all-source-pins.json').write_text(json.dumps(receipt_source,indent=2)+'\n')
receipt={'root':str(FROZEN),'files':len(files),'recovered_exact_baked_sources':{p:hashlib.sha256(data).hexdigest() for p,data in recovered.items()},'live_mismatches':changed,'no_live_source_replaced':True}
(EV/'frozen-source-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt))
