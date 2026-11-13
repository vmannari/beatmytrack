"""Add a scoped implementation receipt without replacing concurrent notes."""
from pathlib import Path

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
marker = 'DAILY-CARD-REDESIGN-20261103'
receipt = '''DCR01-DCR04: Approved Chase the podium title, one target line, four always-visible medal silhouettes until earned, calmer standings spacing and six real competitors plus self. Native237/0 each desktop renderer, retained headless758/0, backend5pass/5PostgreSQLdeselected and scoped Ruff pass;32 final native views. Bounded backend nearby selection now honors the requested size in both snapshot forms; twelve locales retain fit. Initial row clipping, obsolete request assertion and environment/entry failures retained. Sources, commands, captures and checked task-only checkpoint: [docs/DAILY_CARD_REDESIGN_2026_11_03.md](docs/DAILY_CARD_REDESIGN_2026_11_03.md). Reload/owner appearance/touch and matching backend rollout remain. No device query/test, APK, owner-save/process change, live access/mutation, deployment or main-index write; concurrent work preserved.'''
for name in ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']:
    path = root / name
    text = path.read_text(encoding='utf-8')
    old = out / 'docs-before' / name
    old.parent.mkdir(parents=True, exist_ok=True)
    if not old.exists():
        old.write_text(text, encoding='utf-8', newline='\n')
    body = receipt.replace('docs/DAILY_CARD_REDESIGN_2026_11_03.md', 'DAILY_CARD_REDESIGN_2026_11_03.md') if name.startswith('docs/') else receipt
    block = '<!-- '+marker+' -->\n## Daily card follows the approved podium draft (2026-11-03)\n'+body+'\n<!-- /'+marker+' -->\n\n'
    if marker not in text:
        path.write_text(block+text, encoding='utf-8', newline='\n')
