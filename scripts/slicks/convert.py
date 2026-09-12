"""Development-only SS -> native surface-grid-v2. No screenshots are traced.

Ordered DAT masks define geometry only. Native meshes use flat project materials.
All compatibility assumptions live here/config.json; runtime needs neither source.
"""
import argparse
import hashlib
import json
import math
import heapq
from pathlib import Path
from slicks_ss_parser import parse_ss
from slicks_track_renderer_corrected import parse_dat

W, H = 320, 200


def rotated(resource, turns):
    w, h, pixels = resource['w'], resource['h'], resource['pix']
    for _ in range(turns):
        pixels = bytes(pixels[(h-1-x)*w+y] for y in range(w) for x in range(h))
        w, h = h, w
    return w, h, pixels


def runs(grid):
    """Merge equal horizontal runs vertically into native rectangles."""
    result, active = [], {}
    for y, row in enumerate(grid):
        current = {}
        x = 0
        while x < W:
            end = x+1
            while end < W and row[end] == row[x]:
                end += 1
            key = (x, end, row[x])
            if key in active:
                r = active.pop(key); r[3] += 1
            else:
                r = [x, y, end-x, 1, row[x]]
            current[key] = r
            x = end
        result.extend(active.values()); active = current
    result.extend(active.values())
    return result


def convert(path, resources, config):
    source = parse_ss(path)
    if source['format_version'] != 2:
        raise ValueError('Only fully segmented v2 tracks supported')
    scale = config['car_width_m']*config['target_car_widths']/config['representative_road_width_px']
    roles = {i:role for role,ids in config['semantic_blocks'].items() for i in ids}
    grid = [[0]*W for _ in range(H)] # asphalt, grass, dirt, water, solid, curb
    deck = [[-1]*W for _ in range(H)]
    # Opposing 41/42 ramps with matching rows bound a short east-west deck.
    # OFFROAD uses these plus separate block-49 rails instead of 39/40 deck art.
    ramps=[b for b in source['blocks'] if b['block_id'] in (41,42)]
    for left in ramps:
        for right in ramps:
            if left['rotation']==0 and right['rotation']==2 and left['y']==right['y'] and 17<right['x']-left['x']<80:
                for y in range(left['y'],min(H,left['y']+16)):
                    for x in range(left['x']+17,right['x']):
                        deck[y][x]=0
    blocks = []
    water_bounds=[]
    correction=config.get('track_corrections',{}).get(path.stem,{})
    for original in source['blocks']:
        b=original.copy()
        if b['block_id']==53 and correction.get('post_pair_spread_px'):
            peers=[p['x'] for p in source['blocks'] if p['block_id']==53 and p['y']==b['y']]
            if len(peers)==2:
                b['x']+=correction['post_pair_spread_px']*(-1 if b['x']==min(peers) else 1)
        rid=b['block_id']
        if rid not in roles or b['flags']:
            raise ValueError(f'Unreviewed block/flags: {b}')
        role=roles[rid]; w,h,pix=rotated(resources[rid],b['rotation'])
        if role=='water': water_bounds.append((b['x'],b['y'],b['x']+w,b['y']+h))
        blocks.append([original['x'],original['y'],w,h,rid,b['rotation']])
        for y in range(h):
            for x in range(w):
                p=pix[y*w+x]; xx=b['x']+x; yy=b['y']+y
                if not p or not (0<=xx<W and 0<=yy<H): continue
                if role=='deck':
                    # Purple/green edge bands are bridge rails, greys are deck.
                    deck[yy][xx]=4 if p in (26,219) else 0
                elif role=='rail':
                    deck[yy][xx]=4
                elif role!='decoration':
                    value={'finish':0,'grass':1,'dirt':2,'water':3,'solid':4,'wall':4,'curb':5,'ramp':2,'rough':7}[role]
                    grid[yy][xx]=value
    targets=[(q['target']['x'],q['target']['y']) for q in source['computer_points']]
    # Drop disconnected deck-shaped decorative signs when no route seed or
    # seed segment crosses the component. Retain source bounds in debug metadata.
    visited=set()
    seed_samples=[]
    for i,a in enumerate(targets):
        b=targets[(i+1)%len(targets)]; n=max(1,math.ceil(math.dist(a,b)))
        seed_samples.extend((round(a[0]+(b[0]-a[0])*j/n),round(a[1]+(b[1]-a[1])*j/n)) for j in range(n+1))
    samples=set(seed_samples)
    for y in range(H):
        for x in range(W):
            if deck[y][x]<0 or (x,y) in visited:continue
            component=[];pending=[(x,y)];visited.add((x,y))
            while pending:
                xx,yy=pending.pop();component.append((xx,yy))
                for nx,ny in [(xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)]:
                    if 0<=nx<W and 0<=ny<H and deck[ny][nx]>=0 and (nx,ny) not in visited:
                        visited.add((nx,ny));pending.append((nx,ny))
            if not samples.intersection(component):
                for xx,yy in component:deck[yy][xx]=-1
    # Transparent pixels can split one water patch into disconnected mask islands.
    # Group touching source water block bounds before deciding ford versus lake.
    while water_bounds:
        group=[water_bounds.pop()]
        changed=True
        while changed:
            changed=False
            for r in water_bounds[:]:
                if any(r[0]<=b[2]+2 and r[2]>=b[0]-2 and r[1]<=b[3]+2 and r[3]>=b[1]-2 for b in group):
                    water_bounds.remove(r);group.append(r);changed=True
        if any(a<=x<=c and b<=y<=d for a,b,c,d in group for x,y in targets):
            for a,b,c,d in group:
                for y in range(max(0,b),min(H,d)):
                    for x in range(max(0,a),min(W,c)):
                        if grid[y][x]==3:grid[y][x]=6
    # A water patch containing a route target is a required water crossing, not
    # an impassable lake. Flood just that connected patch into native shallow ford.
    for x,y in targets:
        if grid[y][x] == 3:
            pending=[(x,y)]; grid[y][x]=6
            while pending:
                xx,yy=pending.pop()
                for nx,ny in [(xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)]:
                    if 0<=nx<W and 0<=ny<H and grid[ny][nx]==3:
                        grid[ny][nx]=6;pending.append((nx,ny))
    # Conservative 1.55 m planning envelope (physical car radius is now 1.364 m).
    # Rough ground is an AI avoidance hint, not a runtime collision surface.
    # Keep this clearance configurable alongside mesh-width-derived scale.
    def distance_field():
        dist=[[999.0]*W for _ in range(H)]; heap=[]
        for y in range(H):
            for x in range(W):
                if grid[y][x] in (3,4,7) or x in (0,W-1) or y in (0,H-1):
                    dist[y][x]=0;heap.append((0,x,y))
        heapq.heapify(heap)
        while heap:
            d,x,y=heapq.heappop(heap)
            if d != dist[y][x]:continue
            for dx,dy in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)]:
                nx=x+dx;ny=y+dy;nd=d+math.hypot(dx,dy)
                if 0<=nx<W and 0<=ny<H and nd<dist[ny][nx]:
                    dist[ny][nx]=nd;heapq.heappush(heap,(nd,nx,ny))
        return dist
    distances=distance_field()
    margin=config.get('collision_radius_m',1.55)/scale+2
    # Match source target order, but move seeds towards local usable road clearance.
    # This is an intentionally conservative route, not an optimal racing line.
    def clearance(x,y):
        best=15.0
        for dy in range(-14,15):
            for dx in range(-14,15):
                xx=x+dx; yy=y+dy
                if not (0<=xx<W and 0<=yy<H) or grid[yy][xx] in (1,3,4):
                    best=min(best,math.hypot(dx,dy))
        return best
    seeds=[]
    for x,y in targets:
        candidates=[]
        for dy in range(-20,21,2):
            for dx in range(-20,21,2):
                xx=x+dx; yy=y+dy
                if 0<=xx<W and 0<=yy<H and grid[yy][xx] in (0,2,5,6) and distances[yy][xx]>=margin:
                    candidates.append((clearance(xx,yy)-0.6*math.hypot(dx,dy),xx,yy))
        _,xx,yy=max(candidates) if candidates else (0,x,y)
        seeds.append((xx,yy))
    def safe(p):
        x,y=round(p[0]),round(p[1])
        return 0<=x<W and 0<=y<H and distances[y][x]>=margin
    def line_safe(a,b):
        n=max(1,math.ceil(math.dist(a,b)))
        return all(safe((a[0]+(b[0]-a[0])*i/n,a[1]+(b[1]-a[1])*i/n)) for i in range(n+1))
    def connect(a,b):
        if line_safe(a,b):return [a]
        heap=[(math.dist(a,b),0,a)]; costs={a:0}; parent={}
        while heap:
            _,g,p=heapq.heappop(heap)
            if g!=costs[p]:continue
            if p==b:
                path=[p]
                while p!=a:p=parent[p];path.append(p)
                path.reverse()
                simple=[path[0]]; i=0
                while i<len(path)-1:
                    j=len(path)-1
                    while j>i+1 and not line_safe(path[i],path[j]):j-=1
                    simple.append(path[j]);i=j
                return simple[:-1]
            for dx,dy in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)]:
                q=(p[0]+dx,p[1]+dy)
                if not safe(q):continue
                ng=g+math.hypot(dx,dy)*(1+(3 if grid[q[1]][q[0]]==1 else 0))
                if ng<costs.get(q,math.inf):
                    costs[q]=ng;parent[q]=p;heapq.heappush(heap,(ng+math.dist(q,b),ng,q))
        raise ValueError(f'No car-clear route between {a} and {b}')
    seeds=[p for i,a in enumerate(seeds) for p in connect(a,seeds[(i+1)%len(seeds)])]
    # Chaikin subdivision softens sharp seed corners without imposing a racing line.
    smooth=[]
    for i,a in enumerate(seeds):
        b=seeds[(i+1)%len(seeds)]
        smooth.extend([(a[0]*.8+b[0]*.2,a[1]*.8+b[1]*.2),(a[0]*.2+b[0]*.8,a[1]*.2+b[1]*.8)])
    points=[]
    for i,a in enumerate(smooth):
        b=smooth[(i+1)%len(smooth)]; n=max(1,math.ceil(math.dist(a,b)/4))
        points.extend([(a[0]+(b[0]-a[0])*j/n,a[1]+(b[1]-a[1])*j/n) for j in range(n)])
    def world(p): return [round((p[0]-160)*scale,5),round((100-p[1])*scale,5)]
    def coord(p): return world((p['x'],p['y']))
    # Deck direction is inferred from its aggregate principal axis. OFFROAD's
    # small 39/40 group spells a sign, not a traversed bridge: route never uses it.
    covered=[(x,y) for y in range(H) for x in range(W) if deck[y][x]>=0]
    bridges=[]
    if covered:
        cx=sum(p[0] for p in covered)/len(covered); cy=sum(p[1] for p in covered)/len(covered)
        xx=sum((x-cx)**2 for x,y in covered); yy=sum((y-cy)**2 for x,y in covered); xy=sum((x-cx)*(y-cy) for x,y in covered)
        angle=.5*math.atan2(2*xy,xx-yy); axis=(math.cos(angle),math.sin(angle))
        # Opposing east-west ramp pairs state deck orientation more reliably
        # than the principal axis of several parallel short bridges together.
        if any(left['rotation']==0 and right['rotation']==2 and left['y']==right['y'] and 17<right['x']-left['x']<80 for left in ramps for right in ramps):
            axis=(1.0,0.0)
        used=[]
        for i,p in enumerate(points):
            q=points[(i+1)%len(points)]; length=math.dist(p,q)
            x,y=round(p[0]),round(p[1])
            used.append(0<=x<W and 0<=y<H and deck[y][x]>=0 and length>0 and abs(((q[0]-p[0])*axis[0]+(q[1]-p[1])*axis[1])/length)>.75)
        if any(used):
            bridges=[{'axis':[axis[0],-axis[1]],'height':3.2}]
        else:
            deck=[[-1]*W for _ in range(H)]
    gates=[]
    for q in source['checkpoints']:
        a,b=coord(q['a']),coord(q['b'])
        gates.append([min(a[0],b[0]),min(a[1],b[1]),abs(a[0]-b[0]),abs(a[1]-b[1])])
    markers=[b for b in source['blocks'] if b['block_id']==0]
    if markers:
        marker_points=[]
        for b in markers:
            w,h,_=rotated(resources[0],b['rotation'])
            marker_points.append((b['x']+w/2,b['y']+h/2))
        finish=world((sum(p[0] for p in marker_points)/len(marker_points),sum(p[1] for p in marker_points)/len(marker_points)))
        finish_note='Centre of stored block-0 start/finish markings'
    else:
        finish=coord(source['start']);finish_note='No block-0 line: inferred transverse gate through stored start'
    result = {'schema':'surface-grid-v2','identity':'slicks_'+path.stem.lower()+'_test',
            'version':'2','corrections':correction,'cell_size':scale,'grid_size':[W,H],'origin':world((0,0)),
            'car_width_m':config['car_width_m'],'representative_width_m':config['representative_road_width_px']*scale,
            'surfaces':runs(grid),'deck':runs(deck) if bridges else [],'bridges':bridges,
            'spawn':coord(source['start']),'spawn_heading':math.pi/2+source['start']['direction']*math.tau/160,
            'finish':{'center':finish,'half_width':36*scale,'heading':math.pi/2+source['start']['direction']*math.tau/160,'basis':finish_note},
            'route':[world(p) for p in points],'checkpoints':gates,
            'debug':{'blocks':blocks,'computer_points':source['computer_points'],'checkpoints':source['checkpoints'],'start':source['start']},
            'provenance':{'source':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'use':'owner supplied handling test reference; redistribution clearance unverified'}}
    # Presentation metadata is opt-in; original fixture bytes remain unchanged.
    metadata = config.get('track_metadata', {}).get(path.stem, {})
    for key in ('title', 'description', 'theme'):
        if key in metadata:
            result[key] = metadata[key]
    return result


def main():
    ap=argparse.ArgumentParser(); ap.add_argument('source',type=Path); ap.add_argument('--output',type=Path,default=Path('game/resources/tracks')); ap.add_argument('--config',type=Path,default=Path(__file__).with_name('config.json')); ap.add_argument('--track',action='append')
    args=ap.parse_args(); config=json.loads(args.config.read_text()); resources,_=parse_dat(args.source/'SLICKS.DAT')
    args.output.mkdir(parents=True,exist_ok=True)
    for name in args.track or ['FREEWAY','1WAY','66','OFFROAD']:
        result=convert(args.source/'original_tracks'/f'{name}.SS',resources,config)
        (args.output/(result['identity']+'.json')).write_bytes((json.dumps(result,separators=(',',':'))+'\n').encode('utf-8'))
        print(result['identity'],len(result['route']),'route points;',result['representative_width_m'],'m representative road')


if __name__=='__main__': main()
