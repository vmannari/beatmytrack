from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
finding=OUT/'opaque-initial-mobile-finding';finding.mkdir(exist_ok=True)
for name in ['full-front.png','full-front-probe.png','acceptance.json']:
    shutil.copy2(OUT/'opaque/mobile'/name,finding/name)
for name in ['opaque-mobile.log','opaque-mobile-command.json']:
    shutil.copy2(OUT/name,finding/name)
s=(ROOT/'game/tests/test_challenger_hellcat.gd').read_text().replace('range(8)','range(32)')
(OUT/'opaque.gd').write_text(s)
