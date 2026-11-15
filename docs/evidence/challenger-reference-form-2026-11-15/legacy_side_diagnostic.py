from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
source=(ROOT/'docs/evidence/challenger-continuous-side-2026-11-15/check_side.py').read_text()
(OUT/'legacy_side_checks.py').write_text(source.replace('challenger-continuous-side-2026-11-15',OUT.name))
