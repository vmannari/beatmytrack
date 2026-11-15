"""Blender BVH contact anchors, shared across instances of a source mesh."""
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import collections
import json

def collect_anchors(work, rows):
    data=json.loads((work/'contacts-input.json').read_text())
    frames=collections.defaultdict(list)
    for row in rows:
        if row['mode']=='stock' and row['vehicle'] in ('compact','kart','forklift','electric','hovercraft'):
            frames[(row['vehicle'],row['frame'])].append(row)
    anchors=collections.defaultdict(set)
    for group in frames.values():
        vertices=[];faces=[];owners=[];instances=[]
        for owner,row in enumerate(group):
            pose=[Vector(v) for v in row['pose']]
            source=[]
            for surface in data[row['key']]['surfaces']:
                transformed=[pose[3]+pose[0]*p[0]+pose[1]*p[1]+pose[2]*p[2] for p in surface['vertices']]
                offset=len(vertices);vertices.extend(transformed)
                for start in range(0,len(surface['indices']),3):faces.append([offset+i for i in surface['indices'][start:start+3]]);owners.append(owner)
                source.append(transformed)
            instances.append(source)
        tree=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
        for owner,(row,surfaces) in enumerate(zip(group,instances)):
            for surface,points in enumerate(surfaces):
                for at,point in enumerate(points):
                    if any(owners[hit[2]]!=owner for hit in tree.find_nearest_range(point,0.00002)):
                        anchors[(row['key'],surface)].add(at)
    return anchors
