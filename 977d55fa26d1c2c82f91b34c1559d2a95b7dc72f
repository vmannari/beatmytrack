import bpy,numpy as np
for mode in ['none','border','interior']:
    points=[];faces=[]
    for i in range(24):
        for j in range(24):points.append([i/23,j/23,.08*np.sin(i*.55)+.03*np.cos(j*.7)])
    for i in range(23):
        for j in range(23):
            a=i*24+j;faces.extend([(a,a+1,a+25),(a,a+25,a+24)])
    data=bpy.data.meshes.new('BoundaryProbe');data.from_pydata(points,[],faces)
    obj=bpy.data.objects.new('BoundaryProbe',data);bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    boundary=[i*24+j for i in range(24) for j in range(24) if i in [0,23] or j in [0,23]]
    mod=obj.modifiers.new('Probe','DECIMATE');mod.ratio=.16;mod.use_collapse_triangulate=True
    if mode!='none':
        group=obj.vertex_groups.new(name='Influence')
        group.add(boundary if mode=='border' else [i for i in range(576) if i not in boundary],1.0,'REPLACE')
        mod.vertex_group=group.name;mod.vertex_group_factor=1000
    bpy.ops.object.modifier_apply(modifier=mod.name)
    after=np.asarray([v.co[:] for v in obj.data.vertices]);before=np.asarray(points)[boundary]
    distance=np.min(np.linalg.norm(after[:,None,:]-before[None,:,:],axis=2),axis=0)
    print('DECIMATION_BOUNDARY',mode,'exact',np.sum(distance<1e-6),'/',len(boundary),'maxgap',distance.max(),flush=True)
    obj.select_set(False)
