"""Run only after compiler work stops: same-source live/cache Garage attribution."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

sys.dont_write_bytecode = True
from instrument_garage_tradeoff import install

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]


def main():
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument('--label',default='garage-tradeoff-'+str(time.time_ns()))
    parser.add_argument('--base',type=Path)
    parser.add_argument('--prepare-only',action='store_true')
    parser.add_argument('--project',type=Path,help='Reuse an already instrumented owned project')
    parser.add_argument('--pages',default='rivalry,daily,tracks,challenges,biome,drafts,profile,settings,store,garage')
    parser.add_argument('--renderer',default='gl_compatibility')
    args = parser.parse_args()
    if args.project:
        project = args.project.resolve()
        assert project.is_relative_to((ROOT/'build/loading-half-20261106').resolve())
    else:
        base = args.base or Path(json.loads((OUT.parent/'final-project.json').read_text())['project'])
        assert base.resolve().is_relative_to((ROOT/'build/loading-half-20261106').resolve())
        # Reuse the established copier; static/imported assets remain read-only
        # junctions and every mutable source/scene is a distinct owned copy.
        source = (OUT.parent/'freeze_project.py').read_text()
        source = source.replace('evidence = Path(__file__).resolve().parent','evidence = OUT')
        source = source.replace('root = evidence.parents[2]','root = ROOT')
        source = source.replace("evidence/'frozen-project.json'", "evidence/(LABEL+'-frozen.json')")
        for old,new in [("root/'game/.godot/imported'","BASE/'.godot/imported'"),
                        ("root/'game/.godot'","BASE/'.godot'"),
                        ("root/'game/assets'","BASE/'assets'"),("root/'game'","BASE")]:
            source = source.replace(old,new)
        namespace = {'__file__':str(OUT/'run_garage_tradeoff.py'),'OUT':OUT,'ROOT':ROOT,'BASE':base,'LABEL':args.label}
        exec(compile(source,str(OUT.parent/'freeze_project.py'),'exec'),namespace)
        project = namespace['game']
        manifest = install(project)
        (OUT/(args.label+'-project.json')).write_text(json.dumps({'project':str(project),'base':str(base),'instrumented':manifest},indent=2)+'\n')
    print('INSTRUMENTED_PROJECT '+str(project),flush=True)
    if args.prepare_only: return
    profile = args.label+'-shared'
    arms = [('seed',False),('live-a',True),('cached-a',False),('cached-b',False),('live-b',True)]
    combined = []
    for arm,live in arms:
        name = args.label+'-'+arm
        command = [sys.executable,str(OUT.parent/'run_case.py'),name,'profile_garage_tradeoff.gd',
                   '--project',str(project),'--native','--renderer',args.renderer,
                   '--profile',profile,'--timeout','240','--args','--pages='+args.pages]
        if live: command.append('--live-podium')
        subprocess.run(command,cwd=ROOT,check=True)
        receipt = json.loads((OUT.parent/name/'run.json').read_text())
        if receipt['exit_code'] != 0 or receipt['timeout'] or receipt['script_error'] or receipt['source_changes']:
            raise RuntimeError('Invalid instrumented arm '+name)
        events = []
        for line in (OUT.parent/name/'run.log').read_text().splitlines():
            if line.startswith('GARAGE_TRADEOFF_'):
                kind,payload = line.split(' ',1)
                events.append({'kind':kind,**json.loads(payload)})
        result = json.loads((OUT.parent/name/'result.json').read_text())
        combined.append({'name':name,'live_podium':live,'result':result,'events':events})
        (OUT/(args.label+'-summary.json')).write_text(json.dumps(combined,indent=2)+'\n')
    print('GARAGE_TRADEOFF_COMPLETE '+str(OUT/(args.label+'-summary.json')),flush=True)


if __name__ == '__main__': main()
