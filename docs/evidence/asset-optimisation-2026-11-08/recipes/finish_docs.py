import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];WORK=Path(__file__).resolve().parent;EV=ROOT/'docs/evidence/asset-optimisation-2026-11-08'
def log(label):return (WORK/(label+'.log')).read_text(encoding='utf-8',errors='replace')
total=0
for id in ['compact','kart','forklift','electric','hovercraft','super_rally']:
    text=log('final-matrix-'+id);match=re.search(r'MODULAR_CAR_ASSETS: (\d+) checks, 0 failures',text);assert match and 'SCRIPT ERROR' not in text
    total+=int(match[1])
doc=ROOT/'docs/ASSET_OPTIMISATION_2026_11_08.md';text=doc.read_text(encoding='utf-8')
text=text.replace('| Complete module matrix before fixture corrections | 8197 / 13 retained; see below |',f'| Complete six-vehicle module matrix, both tiers and all options | {total} / 0 |')
text=text.replace('| Six stock/fitted cars, close/race/paint/lights/moving, Compatibility | 328 / 0 |','| Six stock/fitted cars, close/race/paint/lights/moving, each renderer | 344 / 0 each |')
text=text.replace('| Six stock/fitted cars, close/race/paint/lights, desktop Mobile | 240 / 0 |\n| Six stock/fitted moving cars, desktop Mobile | 208 / 0 |','| Actual rebuilt prepared models versus procedural, each renderer | 362 / 0 each |\n| Live wheel/light bindings / exact-master LOD policy | 68 / 4294, all zero failures |')
start=text.index('During final qualification, a concurrent `car_visual.gd` edit')
end=text.index('\nRaw buffers, triangles and draws',start)
text=text[:start]+'''During qualification, concurrent Super Rally work briefly referenced a missing
`night_lens()` helper and then corrected a typed-array hood initializer. The
transient compile errors and script-error-bearing attempts are retained, even
when their wrapper exit code was zero. Their corrected source was copied into
the isolated project. All six final module matrices are clean, including those
hood options. The older sibling batching step also exposed four newly authored
brake-lamp references being merged away. Both batching stages now preserve live
handles, with in-tree checks and fresh native/prepared proofs.

The final rebuild regenerates every scene from source. Its task-only recipe
reuses approved LOD streams only when complete master buffers, material
appearance, local pose, render flags and requested bias match exactly; changed
masters use the original offline generator. The 4294-check policy pass preserves
all masters and enforces protected surfaces and original quality biases.
Complete live/isolated source maps and revisions matched before publication.
Only then were verified assets copied back; no frozen source replaced live work.
The final live preflight, six-picture provenance, App and parser pass. Failed
source matches and superseded owned bake attempts remain in the evidence.
''' + text[end:]
text=text.replace('the affected Garage wash check was rerun cleanly.','the affected Garage wash check was rerun cleanly.')
text=text.replace('the corrected full module matrix and whole-current-project readiness\nremain unqualified.','the corrected module matrix is recorded above.')
# Refresh the draw table from the final procedural native result.
rows=json.loads((EV/'cars-gl_compatibility-verified/report.json').read_text())['rows']
names={'compact':'Rally','kart':'Kart','forklift':'Forklift','electric':'Volt','hovercraft':'Hover','super_rally':'Super Rally'}
table=[]
for row in rows:
    if not row['case'].endswith('-stock-race'):continue
    id=row['case'].removesuffix('-stock-race');a=row['before_draws'];b=row['after_draws'];pct=(a-b)*100/a
    table.append(f'| {names[id]} | {a} | {b} | '+(f'{pct:.1f}%' if a!=b else 'unchanged')+' |')
start=text.index('| Rally |');end=text.index('\n\nThese are complete fixture',start)
text=text[:start]+'\n'.join(table)+text[end:]
doc.write_text(text,encoding='utf-8')
marker='ASSET-OPTIMISATION-20261108'
block=f'''<!-- {marker} -->
## Vehicle and track asset optimisation implemented (2026-11-08)
AOP01-AOP04: Raw GPU-vertex deduplication preserves ordered corners/encoded attributes; fixed car batching retains articulation, paint and live lights. Protected tree/tyre distance levels retain near/editor detail. Stock Volt draws91to43; four-biome shared raw buffers fall27-46%, Desert unchanged; distant trees/tyres about19-23% fewer triangles. Final native344/0 each renderer and actual prepared362/0 each, module{total}/0, live handles68/0, LOD policy4294/0, packing432/0, protected166/0 and retained scenery368/0 pass. Complete551-resource2267/0 and six-picture157-source provenance, App141/0, parser554/0, driving72/0 and washing1655/54 all pass. Material subresource aliases/full-quality rollback fixture corrected with exact native pixel-identity controls; initial13 matrix findings, missing helper, typed-array, stale-source, light-reference, renderer-restoration and timeout attempts retained. Isolated rebuild accepts byte-exact master LOD reuse, publishes only after full live source/revision equality; main index and concurrent code preserved. [Implementation, comparisons, commands, limits and source-only checkpoint](docs/ASSET_OPTIMISATION_2026_11_08.md). PC reload/owner and device performance acceptance remain; no device query/test, APK, owner-save/process change, live/backend request or deployment.
<!-- /{marker} -->

'''
for relative in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    path=ROOT/relative;current=path.read_text(encoding='utf-8')
    if '<!-- '+marker+' -->' not in current:
        local=block.replace('(docs/ASSET_OPTIMISATION_2026_11_08.md)','(ASSET_OPTIMISATION_2026_11_08.md)') if relative.startswith('docs/') else block
        path.write_text(local+current,encoding='utf-8')
print('Updated report/status documents; final module checks',total)
