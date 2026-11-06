"""Merge measured native first-draw coverage into a reviewed biome manifest.

Explicit input files and destination; never guesses coverage for another device.
Do not feed deliberately injected-miss runs to this command.
"""
import argparse,json,re
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('reports',nargs='+',type=Path)
p.add_argument('--output',required=True,type=Path)
args=p.parse_args()
manifest={'schema_version':1,'revision':'bmt-biome-gles3-1','profiles':{}}
for path in args.reports:
    for run in json.loads(path.read_text()):
        data=run['final'];context=data['profile_context'];key=data['context']
        assert data['dropped']==0 and context['revision']==manifest['revision']
        assert context['biome'] in ('pine','winter','desert','storm','night_city')
        profile=manifest['profiles'].setdefault(key,{'context':context,'entries':[]})
        assert profile['context']==context
        entries={(e['shader'],int(e['variant']),e['specialization']):e for e in profile['entries']}
        for event in data['observations']:
            entry={field:event[field] for field in ('shader','variant','specialization')}
            assert re.fullmatch('[a-f0-9]{64}',entry['shader']), 'Incomplete shader attribution; do not promote this run'
            entries[(entry['shader'],int(entry['variant']),entry['specialization'])]=entry
        assert len(entries)<=4096
        profile['entries']=[entries[k] for k in sorted(entries)]
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(manifest,indent=2)+'\n')
print({p['context']['biome']:len(p['entries']) for p in manifest['profiles'].values()})
