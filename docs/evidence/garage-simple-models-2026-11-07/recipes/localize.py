import json
from pathlib import Path
import re
import sys

ROOT=Path(__file__).resolve().parents[2]
EV=ROOT/'docs/evidence/garage-simple-models-2026-11-07'
ENTRIES={
 'en':'Use much lighter cars in races and Garage. Small details and curves are less accurate.',
 'fi':'Käytä kilpailuissa ja tallissa kevyempiä automalleja. Pienet yksityiskohdat ja kaaret ovat epätarkempia.',
 'sv':'Använd enklare bilmodeller i lopp och garaget. Små detaljer och kurvor blir mindre exakta.',
 'de':'Verwende in Rennen und Garage deutlich einfachere Automodelle. Kleine Details und Rundungen sind weniger genau.',
 'es':'Usa modelos de coches mucho más ligeros en las carreras y el garaje. Los pequeños detalles y las curvas son menos precisos.',
 'fr':'Utilisez des voitures plus légères à afficher en course et au garage. Les petits détails et les courbes sont moins précis.',
 'it':'Usa modelli di auto molto più leggeri in gara e nel garage. I piccoli dettagli e le curve sono meno precisi.',
 'ja':'レースとガレージで大幅に軽量化した車のモデルを使用します。細部や曲面の精度が下がります。',
 'ko':'레이스와 차고에서 훨씬 가벼운 자동차 모델을 사용합니다. 작은 디테일과 곡면의 정밀도가 낮아집니다.',
 'nb':'Bruk mye enklere bilmodeller i løp og garasjen. Små detaljer og kurver blir mindre nøyaktige.',
 'nl':'Gebruik veel lichtere automodellen tijdens races en in de garage. Kleine details en rondingen zijn minder nauwkeurig.',
 'pt_BR':'Use modelos de carros bem mais leves nas corridas e na garagem. Pequenos detalhes e curvas ficam menos precisos.',
}
OLD='Use much lighter cars while racing. Small details and curves are less accurate.'
for path in list((ROOT/'game/localization').glob('*.po'))+[ROOT/'game/localization/messages.pot']:
    source=path.read_text(encoding='utf-8')
    text=ENTRIES[path.stem] if path.suffix=='.po' else ''
    assert '?' not in text
    if path.stem in ['fi','sv','es','fr','it','ja','ko','nb']:assert any(ord(c)>127 for c in text)
    pattern=r'\nmsgid '+re.escape(json.dumps(OLD))+r'\nmsgstr "[^"\n]*"'
    changed,count=re.subn(pattern,lambda _: '\nmsgid '+json.dumps(ENTRIES['en'])+'\nmsgstr '+json.dumps(text,ensure_ascii=False),source)
    assert count==1,path
    path.write_bytes(changed.encode())
(EV/'translation-expectations.json').write_bytes((json.dumps(ENTRIES,indent=2,ensure_ascii=False)+'\n').encode())
sys.path.insert(0,str(ROOT/'scripts'))
import localization as loc
messages=loc.collect();key=('',ENTRIES['en']);errors=[]
for language,expected in ENTRIES.items():
    parsed=loc.parse_po((ROOT/'game/localization'/f'{language}.po').read_text(encoding='utf-8'))
    assert parsed[key]['msgstr']==expected
    errors+=loc.validate({k:v for k,v in parsed.items() if k in [key,('','')]},{key:messages[key]},language)
assert not errors
(EV/'localization.json').write_bytes((json.dumps({'languages':sorted(ENTRIES),'checks':12,'failures':errors,'utf8_round_trip':True},indent=2)+'\n').encode())
print('GARAGE_SIMPLE_LOCALIZATION 12 checks, 0 failures; UTF-8 exact')
