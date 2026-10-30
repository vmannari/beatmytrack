from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
import localization as catalog

OLD = 'Instant rear-wheel power with responsive steering. Feed in the accelerator for a controlled slide; release to brake and stop. Select D or R while stopped. One pedal, no handbrake.'
NEW = 'Instant rear-wheel power with responsive steering. Feed in the accelerator for a controlled slide; release for regeneration. Use the brake pedal to slow down, then hold it while stopped to reverse. No handbrake.'
VALUES = [
    'Puissance arrière instantanée et direction réactive. Dosez l’accélérateur pour une glisse contrôlée ; relâchez pour récupérer de l’énergie. Freinez, puis maintenez la pédale à l’arrêt pour reculer. Sans frein à main.',
    'Potencia trasera inmediata y dirección ágil. Dosifica el acelerador para un derrape controlado; suéltalo para regenerar. Frena y mantén el pedal pisado estando parado para dar marcha atrás. Sin freno de mano.',
    'Sofortige Hinterradkraft und direkte Lenkung. Dosiere das Gas für kontrolliertes Driften; loslassen rekuperiert. Bremse und halte das Pedal im Stand gedrückt, um rückwärtszufahren. Keine Handbremse.',
    'Potência traseira instantânea e direção ágil. Dose o acelerador para deslizar com controle; solte para regenerar. Freie e mantenha o pedal pressionado ao parar para dar ré. Sem freio de mão.',
    '瞬時の後輪駆動と素直な操舵。アクセルを調節してドリフトを制御し、離すと回生減速します。ブレーキで減速し、停止後も踏み続けると後退します。ハンドブレーキはありません。',
    '즉각적인 후륜 구동과 민감한 조향. 가속을 조절해 드리프트를 제어하고, 페달을 놓으면 회생 제동합니다. 브레이크로 감속한 뒤 정지 상태에서 계속 밟으면 후진합니다. 핸드브레이크는 없습니다.',
    'Direct achterwielvermogen en responsieve besturing. Doseer het gas voor een beheerste drift; laat los voor regeneratie. Rem en houd het pedaal bij stilstand ingedrukt om achteruit te rijden. Geen handrem.',
    'Potenza posteriore immediata e sterzo reattivo. Dosa l’acceleratore per una derapata controllata; rilascialo per la rigenerazione. Frena e tieni premuto il pedale da fermo per andare in retromarcia. Nessun freno a mano.',
    'Välitön takaveto ja herkkä ohjaus. Annostele kaasua hallittuun luistoon; vapauta regenerointia varten. Jarruta ja pidä poljin painettuna pysähdyksissä peruuttaaksesi. Ei käsijarrua.',
    'Omedelbar bakhjulskraft och följsam styrning. Dosera gasen för kontrollerad sladd; släpp för regenerering. Bromsa och håll pedalen nedtryckt när bilen står stilla för att backa. Ingen handbroms.',
    'Umiddelbar bakhjulskraft og responsiv styring. Doser gassen for kontrollert sladd; slipp for regenerering. Brems og hold pedalen inne når bilen står stille for å rygge. Ingen håndbrekk.',
]
base = Path(__file__).resolve().parent / 'before'
for lang, value in zip(['fr','es','de','pt_BR','ja','ko','nl','it','fi','sv','nb'], VALUES):
    rel = Path('game/localization') / (lang + '.po')
    text = (ROOT / rel).read_text(encoding='utf-8')
    entries = text.split('\n\n')
    for index, entry in enumerate(entries):
        if 'msgid ' + catalog.quoted(NEW) in entry:
            entries[index] = entry[:entry.index('msgid ')] + 'msgid ' + catalog.quoted(NEW) + '\nmsgstr ' + catalog.quoted(value)
    (ROOT / rel).write_text('\n\n'.join(entries), encoding='utf-8')
for name in ['en.po', 'messages.pot']:
    rel = Path('game/localization') / name
    current = (ROOT / rel).read_text(encoding='utf-8')
    # Undo only our extraction, with an exact guard against concurrent edits.
    assert current == catalog.render(catalog.collect(), name == 'en.po'), name
    text = (base / rel).read_text(encoding='utf-8')
    assert OLD in text
    (ROOT / rel).write_text(text.replace(OLD, NEW), encoding='utf-8')
rel = Path('scripts/translations/vehicles.tsv')
text = (ROOT / rel).read_text(encoding='utf-8')
lines = text.splitlines()
for index, line in enumerate(lines):
    if line.startswith(NEW):
        lines[index] = '|'.join([NEW] + VALUES)
(ROOT / rel).write_text('\n'.join(lines) + '\n', encoding='utf-8')
print('Electric description updated in English and eleven authored translations.')
