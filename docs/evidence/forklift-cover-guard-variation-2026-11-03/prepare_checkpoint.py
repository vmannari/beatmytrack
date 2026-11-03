from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
text=(ROOT/'docs/evidence/forklift-cabin-variation-2026-11-03/checkpoint.py').read_text(encoding='utf-8')
start=text.index("    test='game/tests/test_forklift_kit_construction.gd'")
end=text.index('    # Documentation includes',start)
block='''    candidates=set(json.loads((OUT/'before-hashes.json').read_text()))
    candidates.update(['game/tests/capture_forklift_kit_refinement.gd',
        'game/tests/test_forklift_cover_decks.gd','scripts/run_forklift_cover_guard.ps1',
        'docs/FORKLIFT_COVER_GUARD_VARIATION_2026_11_03.md','AGENTS.md','DEVELOPMENT_STATUS.md',
        'docs/evidence/forklift-cover-guard-variation-2026-11-03/before/game/vehicle/forklift_kit_surface.gd'])
'''
text=text[:start]+block+text[end:]
text=text.replace('FORKLIFT-CABIN-VARIATION-20261103','FORKLIFT-COVER-GUARD-VARIATION-20261103')
text=text.replace('tmp/forklift-cabin-variation-checkpoint','tmp/forklift-cover-guard-variation-checkpoint')
text=text.replace('Cabin variation task-start baseline','Cover and guard task-start baseline')
(OUT/'checkpoint.py').write_text(text,encoding='utf-8',newline='\n')
print('Prepared self-contained task checkpoint utility')
