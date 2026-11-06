"""Read-only official pinned-source audit of all GLES3 draw entry points."""
import concurrent.futures,hashlib,json,re,urllib.request
from pathlib import Path
p=Path(__file__).resolve().parent
base='https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/'
def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'BMT-local-shader-usage-review'}),timeout=30).read()
tree=json.loads(fetch('https://api.github.com/repos/godotengine/godot/git/trees/4.7.2-stable?recursive=1'))
paths=[x['path'] for x in tree['tree'] if x['path'].startswith('drivers/gles3/') and x['path'].endswith(('.cpp','.h'))]
def audit(path):
    raw=fetch(base+path);text=raw.decode()
    calls=sorted(set(re.findall(r'\b(gl(?:Multi)?Draw\w*|glDispatchCompute\w*)\s*\(',text)))
    return {'path':path,'sha256':hashlib.sha256(raw).hexdigest(),'draw_calls':calls}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool: rows=list(pool.map(audit,paths))
result={'source':base,'files':rows,'entrypoints':sorted({x for r in rows for x in r['draw_calls']})}
(p/'engine-draw-audit.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'files':len(rows),'entrypoints':result['entrypoints']}))
