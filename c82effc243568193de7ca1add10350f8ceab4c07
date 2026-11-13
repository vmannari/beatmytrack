"""Make labelled contact sheets and a local gallery from unaltered native views."""
from pathlib import Path
import html

ROOT = Path(__file__).resolve().parent


def main():
    cards = []
    for folder in sorted(ROOT.glob('capture-*')):
        for category in ('hood', 'aero', 'rims', 'body'):
            for path in sorted((folder / category).glob('*.png')):
                relative = path.relative_to(ROOT).as_posix()
                label = f'{folder.name} / {category} / {path.stem}'
                cards.append(f'<a href="{relative}"><figure><img loading="lazy" src="{relative}"><figcaption>{html.escape(label)}</figcaption></figure></a>')
    diagnostics = []
    for folder in sorted(ROOT.glob('diagnostic-*')):
        if not folder.is_dir():
            continue
        for path in sorted(folder.glob('*.png')):
            relative = path.relative_to(ROOT).as_posix()
            label = f'{folder.name} / {path.stem}'
            diagnostics.append(f'<a href="{relative}"><figure><img loading="lazy" src="{relative}"><figcaption>{html.escape(label)}</figcaption></figure></a>')
    (ROOT / 'review.html').write_text('''<!doctype html><meta charset="utf-8"><title>Compact kit review, 2026-10-25</title>
<style>body{background:#18212a;color:#edf1f3;font:16px system-ui;margin:24px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(380px,1fr));gap:16px}figure{margin:0}img{width:100%}a{color:inherit}select,input{font:inherit;padding:8px;margin:8px}</style>
<h1>Compact custom kits: native review</h1><p>Current prepared geometry. Open any image at full size. Desktop renderers; no device acceptance claim.</p>
<p>Findings: floating Roof lip; detached arch extensions on six body kits; simplified Power dome and Vented dome accent inserts intersect their hoods. See <a href="../../COMPACT_KIT_REVIEW_2026_10_25.md">review report</a> and <a href="report.json">measurements and checks</a>.</p>
<label>Filter <input id="filter" placeholder="e.g. hood / scoop"></label><main>''' + ''.join(diagnostics + cards) + '''</main><script>document.querySelector('#filter').addEventListener('input',e=>{for(const card of document.querySelectorAll('main>a'))card.hidden=!card.textContent.toLowerCase().includes(e.target.value.toLowerCase())})</script>''', encoding='utf-8')


if __name__ == '__main__':
    main()
