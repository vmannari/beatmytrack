from pathlib import Path
script=Path(__file__).with_name('guarded_assets.py')
exec(compile(script.read_text(encoding='utf-8-sig').split('\nbefore = sources()')[0],str(script),'exec'))
before=json.loads((OUT/'source-receipt.json').read_text())['after'];after=sources()
changed=sorted(p for p in before.keys()|after.keys() if before.get(p)!=after.get(p))
(OUT/'changed-now.json').write_text(json.dumps(changed))
print(json.dumps(changed,indent=2))
