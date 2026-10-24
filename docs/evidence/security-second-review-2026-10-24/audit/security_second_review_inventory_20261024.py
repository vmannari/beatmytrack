"""Reuse the value-redacting inventory against this review's evidence directory."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT/'docs/evidence/security-review-2026-10-24/inventory.py').read_text(encoding='utf-8')
source = source.replace('Path(__file__).resolve().parents[3]', 'Path(__file__).resolve().parents[1]')
source = source.replace('OUT = Path(__file__).resolve().parent', "OUT = ROOT / 'docs/evidence/security-second-review-2026-10-24'")
source = source.replace('build/security-review-20261024/inventory-objects', 'build/security-second-review-2026-10-24/inventory-objects')
source = source.replace("    candidates, scanned, scan_bytes = [], 0, 0", "    names = sorted(set(names) | {p.relative_to(ROOT).as_posix() for p in sources})\n    candidates, scanned, scan_bytes = [], 0, 0")
source = source.replace('current Git-tracked text files <=2MB', 'current Git-tracked and selected untracked source text files <=2MB')
exec(compile(source, __file__, 'exec'))
