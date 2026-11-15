"""VSR02: publish qualified local skin repair and exact frame migrations."""
import hashlib,json,os
from run_volt_smooth import ROOT,WORK,OUT
digest=lambda data:hashlib.sha256(data).hexdigest()
def main():
    assert json.loads((OUT/'geometry-proof.json').read_text())['failures']==0
    for label in ('stage-final','candidate-native-field'):
        value=json.loads((OUT/(label+'-receipt.json')).read_text())
        assert value['exit_code']==0 and not value['errors'],label
    staged=json.loads((OUT/'staged.json').read_text());files={}
    for name,relative in sorted(staged['files'].items(),key=lambda row:row[0].endswith('.json')):
        assert relative.startswith(('game/assets/vehicles/car_detail_v1/electric_','game/assets/vehicles/car_surface_v1/electric_','game/assets/vehicles/electric_rear_lamp_gaps_v1/'))
        target=ROOT/relative;old=target.read_bytes() if target.exists() else None
        if old is not None:
            backup=WORK/'before'/relative;backup.parent.mkdir(parents=True,exist_ok=True);assert not backup.exists();backup.write_bytes(old)
        data=(WORK/'staged'/name).read_bytes();temporary=target.with_name(target.name+'.tmp');temporary.write_bytes(data);os.replace(temporary,target)
        files[relative]=dict(before=digest(old) if old is not None else None,after=digest(data))
    (OUT/'publication.json').write_text(json.dumps(dict(files=files,migration=staged['migration'],replacements=staged['replacements']),indent=2)+'\n',encoding='utf-8')
    print('VOLT_CORNER_PUBLICATION',len(files),'Electric source files')
if __name__=='__main__':main()
