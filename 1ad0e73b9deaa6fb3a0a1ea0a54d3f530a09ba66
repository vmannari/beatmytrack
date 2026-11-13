from pathlib import Path
old=Path(__file__).resolve().parent.parent/'challenger-panels-2026-11-12'
new=Path(__file__).resolve().parent
s=(old/'panel_geometry.gd').read_text().replace('FileAccess.open("res://../docs/evidence/challenger-panels-2026-11-12/panel-', 'FileAccess.open("res://../docs/evidence/challenger-surface-joins-2026-11-12/panel-')
(new/'panels.gd').write_text(s)
s=(old/'guarded_assets.py').read_text().replace('build/challenger-panels-assets','build/challenger-surface-joins-2026-11-12/assets')
(new/'guarded_assets.py').write_text(s)
