from pathlib import Path
import html

root=Path(__file__).resolve().parent
cards=[]
for path in sorted((root/'attachments-gl_compatibility').glob('*.png')):
    name=path.name
    label=html.escape(path.stem.replace('-',' '))
    cards.append(f'<article><h2>{label}</h2><div class="pair"><figure><img loading="lazy" src="baseline-gl_compatibility/{name}"><figcaption>Before · Compatibility</figcaption></figure><figure><a class="after-link" href="attachments-gl_compatibility/{name}"><img class="after" loading="lazy" data-name="{name}" src="attachments-gl_compatibility/{name}"></a><figcaption>After · <span class="renderer">Compatibility</span></figcaption></figure></div></article>')
(root/'review.html').write_text('''<!doctype html><meta charset="utf-8"><title>Compact kit construction fixes</title>
<style>body{margin:24px;background:#18212a;color:#edf1f3;font:16px system-ui}h1{font-size:28px}h2{font-size:19px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{width:100%}article{margin:28px 0}select{font:inherit;padding:8px}a{color:#e9cc71}@media(max-width:700px){.pair{grid-template-columns:1fr}}</style>
<h1>Compact kit construction fixes · 2026-10-25</h1><p>Fitted roof-lip root and arch backing, plus hood accents following the actual hood triangles. Native models at both detail levels. These are desktop views.</p>
<p><a href="../../COMPACT_KIT_FIXES_2026_10_25.md">Report</a> · <a href="report.json">Checks and measurements</a></p>
<label>After renderer <select id="choice"><option value="gl_compatibility">Compatibility</option><option value="mobile">Mobile (desktop Vulkan)</option></select></label>
<p>The before images are from the unchanged task-start assets in Compatibility. The after selector shows final prepared assets in either renderer.</p>''' + ''.join(cards) + '''<script>document.querySelector('#choice').addEventListener('change',e=>{for(const image of document.querySelectorAll('.after')){image.src='attachments-'+e.target.value+'/'+image.dataset.name;image.closest('a').href=image.src}for(const label of document.querySelectorAll('.renderer'))label.textContent=e.target.value==='mobile'?'Mobile (desktop Vulkan)':'Compatibility'})</script>''',encoding='utf-8')
print(f'Gallery: {len(cards)} before/after comparisons, two final renderers')
