"""Attribute native link time by weathering family within each measured trial."""
import json,re,struct,sys
from pathlib import Path
p=Path(__file__).resolve().parent
label=sys.argv[1]
rows=[]; current=None
def family(key):
    path=p/label/'jobs'/(key+'.job')
    if not path.exists():return 'unknown'
    data=path.read_bytes();offset=4;strings=[]
    for _ in range(3):
        size=struct.unpack_from('<I',data,offset)[0];offset+=4;strings.append(data[offset:offset+size].decode());offset+=size
    code=strings[1]+strings[2]
    if 'weather_hash' not in code:return 'other'
    return 'toon' if '#define DIFFUSE_TOON' in code else 'burley'
for line in (p/(label+'.log')).read_text(errors='replace').splitlines():
    if line.startswith('WEATHERING_BEGIN '):
        current={'policy':line.split()[1],'links_us':{},'programs':{}}
    elif line.startswith('NATIVE_CALL ') and current is not None:
        fields=dict(re.findall(r'(\w+)=([^ ]+)',line))
        if fields['api']!='glLinkProgram':continue
        kind=family(fields['key'])
        current['links_us'][kind]=current['links_us'].get(kind,0)+int(fields['us'])
        current['programs'][kind]=current['programs'].get(kind,0)+1
    elif line.startswith('WEATHERING_CANDIDATE ') and current is not None:
        current.update(json.loads(line[len('WEATHERING_CANDIDATE '):]))
    elif line.startswith('WEATHERING_END '):
        rows.append(current);current=None
(p/(label+'-analysis.json')).write_text(json.dumps(rows,indent=2)+'\n')
for row in rows:print(json.dumps(row))
