"""CST04: exact authored-source publication, including the Volt repair."""
import hashlib,json
from run_car_step10 import ROOT,OUT,WORK
digest=lambda data:hashlib.sha256(data).hexdigest()
def main():
    pub=json.loads((OUT/'publication.json').read_text())
    pub['files'].update(json.loads((OUT/'volt-publication.json').read_text())['files'])
    for receipt in ('volt-recipe-migration.json','volt-clearance-migration.json'):
        for path in json.loads((OUT/receipt).read_text()):
            relative='game/'+path.removeprefix('res://')
            pub['files'][relative]=dict(before=None,after=digest((ROOT/relative).read_bytes()))
    for name in ('game/vehicle/visual_geometry.gd','game/vehicle/car_detail_reduction.gd','game/vehicle/prepared_asset_dependencies.json','game/ui/header_icon_renderer.gd'):
        original=(WORK/'before'/name).read_bytes()
        pub['files'][name]=dict(before=digest(original),after=digest((ROOT/name).read_bytes()))
    for name in ('game/vehicle/car_surface_reduction.gd','game/vehicle/car_surface_shader_allowlist.gd'):
        pub['files'][name]=dict(before=None,after=digest((ROOT/name).read_bytes()))
        uid=ROOT/(name+'.uid')
        if uid.exists():pub['files'][name+'.uid']=dict(before=None,after=digest(uid.read_bytes()))
    assert not any('super_rally' in name or 'challenger' in name for name in pub['files'])
    for name,row in pub['files'].items():assert digest((ROOT/name).read_bytes())==row['after'],name
    pub['scope']='CST01-CST04: five racing models, Volt seam/handle repair, protected batching and exact offline surface recipes. Challenger model source is excluded; shared derived consumers are rebuilt.'
    (OUT/'authored-publication.json').write_text(json.dumps(pub,indent=2)+'\n')
    print('STEP10_SOURCE_BINDINGS',len(pub['files']))
if __name__=='__main__':main()
