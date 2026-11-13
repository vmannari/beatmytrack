from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
doc=ROOT/'docs/CHALLENGER_SURFACE_JOINS_2026_11_12.md'
s=doc.read_text()
s=s.replace('49,804','49,540').replace('84,090','83,935')
s=s.replace('1,432 checks / 0 failures; original control 1,432 / 16','2,624 checks / 0 failures; original control 2,624 / 21')
s=s.replace('434 stable source inputs, 15 successful commands','434 stable source inputs, 10 final successful commands')
s=s.replace('Front and rear corner triangles are clipped at the repair boundary','Front corner, upper rear shoulder and rear corner triangles are clipped at the repair boundary')
s=s.replace('regenerates `game/assets/news/vehicles/forklift.png`, whose bytes differ. No\nForklift source edit was authored, and pixel identity for that news image is\nnot claimed.','observes a concurrent update to `game/assets/news/vehicles/forklift.png`. This\nupdate is preserved. The photography commands here write only the Super rally\nnews image; no Forklift source edit was authored.')
s=s.replace('the shared baker also\nobserves','the controls also\nobserve')
s=s.replace('`prepared_checks.py`, and `checkpoint.py`.','`prepared_checks.py`, and `checkpoint.py`. The initial complete refresh\nused 15 commands. After the final upper-shoulder refinement,\n`guarded_assets_final.py` refreshes the affected vehicle with 10 commands and\nretains the other catalogue pictures. Both refreshes use the full input fence\nand strict shared preflights.')
s=s.replace('A conversion whose inputs changed while running was rejected','The final Vulkan review exposed a remaining upper shoulder kink; the narrow\nupper strip was retopologised and added to the surface scan. Its interior edges\nare paired exactly. An exact-edge ray miss is resolved by a 10 micrometre\nlongitudinal probe, with the independent edge-pairing audit rejecting real\nopenings. The scan excludes the separate rear-quarter window opening.\nA conversion whose inputs changed while running was rejected')
doc.write_text(s)
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
    path=ROOT/name;data=path.read_bytes()
    start=data.index(b'<!-- CHALLENGER-JOINS-20261112 -->');end=data.index(b'<!-- /CHALLENGER-JOINS-20261112 -->')
    block=data[start:end].replace(b'49804',b'49540').replace(b'84090',b'83935').replace(b'1432/0',b'2624/0').replace(b'1432/16',b'2624/21').replace(b'15-command',b'10-command').replace(b'regenerated Forklift news image differs',b'concurrent Forklift news update preserved')
    path.write_bytes(data[:start]+block+data[end:])
