from pathlib import Path
from PIL import Image,ImageChops
import json,sys
p=Path(__file__).resolve().parent
left,right=sys.argv[1:3]
rows=[]
for path in sorted((p/left).glob('*-ready.png')):
    other=p/right/path.name
    if not other.exists():continue
    a,b=Image.open(path).convert('RGB'),Image.open(other).convert('RGB')
    if a.size!=b.size:raise ValueError('image sizes differ')
    diff=ImageChops.difference(a,b)
    rows.append({'image':path.name,'changed_pixels':sum(any(v) for v in diff.getdata()),
                 'max_channel_delta':max(v[1] for v in diff.getextrema()),'pixels':a.width*a.height})
(p/(left+'-vs-'+right+'-images.json')).write_text(json.dumps(rows,indent=2)+'\n')
print(rows)
