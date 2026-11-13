import concurrent.futures,hashlib,json,os,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent;TARGET=OUT/'snapshot'
assert not TARGET.exists(),'Preserve the existing snapshot.'
TARGET.mkdir()
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
files=[]
for folder in ['game','native','scripts']:
 for base,dirs,names in os.walk(ROOT/folder):
  rel=Path(base).relative_to(ROOT)
  dirs[:]=[d for d in dirs if d not in ['__pycache__','.git','.gradle','.cxx']]
  if rel==Path('game/android'):dirs[:]=[];names=[]
  if rel==Path('game/.godot'):
   dirs[:]=[d for d in dirs if d=='imported'];names=[n for n in names if n in ['global_script_class_cache.cfg','uid_cache.bin','extension_list.cfg']]
  for name in names:files.append(Path(base)/name)
for name in ['.gitignore','.gitattributes','godot-version.txt']:files.append(ROOT/name)
files.append(ROOT/'.tools/admob/android_source.zip')
fixture=ROOT/'backend/tests/fixtures/verified_oval.json';files.append(fixture)
def copy(p):
 target=TARGET/p.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:list(pool.map(copy,files))
env={**os.environ,'GIT_OPTIONAL_LOCKS':'0'}
subprocess.run(['git','init','--quiet',str(TARGET)],check=True,env=env)
tracked=subprocess.check_output(['git','-C',str(ROOT),'ls-files','-z','--','game','native','godot-version.txt','scripts/build_identity.ps1','scripts/garage_preview_identity.ps1','scripts/prepared_asset_identity.ps1'])
kept=[p for p in tracked.split(b'\0') if p and (TARGET/os.fsdecode(p)).is_file()]
listing=OUT/'tracked-paths.nul';listing.write_bytes(b'\0'.join(kept)+b'\0')
subprocess.run(['git','-C',str(TARGET),'add','-f','--pathspec-from-file='+str(listing),'--pathspec-file-nul'],check=True,env=env)
pins={p.relative_to(ROOT).as_posix():digest(TARGET/p.relative_to(ROOT)) for p in files if '.godot' not in p.parts}
(OUT/'snapshot.json').write_text(json.dumps({'root':str(TARGET),'copied_files':len(files),'hashes':pins},indent=2)+'\n')
print('Frozen current source and assets:',len(files),'files.')
