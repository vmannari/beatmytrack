"""Bind inert intrinsic materials without changing any recipe geometry."""
import hashlib
import json
import os
import sys
from run_car_detail_reduction import ROOT, OUT, WORK, run

def main():
    if '--publish-only' not in sys.argv and run('material-finalise','res://tests/finalize_car_detail_materials.gd','--headless'):
        raise RuntimeError('Material staging failed')
    rows=json.loads((OUT/'material-finalisation.json').read_text())
    destination=(ROOT/'game/assets/vehicles/car_detail_v1').resolve()
    staged=(WORK/'material-stage').resolve()
    for row in rows:
        target=(destination/row['file']).resolve();candidate=(staged/row['file']).resolve()
        assert target.parent==destination and candidate.parent==staged and row['exact_geometry']
        assert hashlib.sha256(target.read_bytes()).hexdigest()==row['source_sha256']
        assert hashlib.sha256(candidate.read_bytes()).hexdigest()==row['staged_sha256']
    for row in rows:
        # Same-volume rename publishes a whole resource, never partial bytes.
        os.replace(staged/row['file'],destination/row['file'])
    receipt={'resource_count':len(rows),'exact_geometry':True,'all_source_outputs_verified_before_publication':True,
             'publication':'atomic resource replacement; frame manifests unchanged',
             'missing_intrinsic_materials':sum(row['missing_intrinsic_materials'] for row in rows)}
    (OUT/'material-publication.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(receipt)

if __name__=='__main__':main()
