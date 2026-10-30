"""Build a task-only review patch by reversing this task's known shared edits.

The reconstructed baseline is NOT an archived task-start source snapshot. Shared
files contain concurrent work; the inverse patch check verifies the scoped edits
against the current tree without staging or committing any of that other work.
"""
import difflib
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))
import localization as catalog  # noqa: E402


def remove(text, value):
    assert value in text, value[:100]
    return text.replace(value, "")


def prior(name, text):
    if name == "backend/bmt_backend/app.py":
        for line in ('        track_of_day,\n', '        app.include_router(track_of_day.router)\n',
                     '            "track_of_day_version": 1,\n'):
            text = remove(text, line)
    elif name == "backend/bmt_backend/discovery_models.py":
        start = text.index('class TrackOfDayState(')
        end = text.index('class DiscoveryPartition(', start)
        text = text[:start] + text[end:]
    elif name == "backend/bmt_backend/discovery_worker.py":
        text = remove(text, 'from .track_of_day import step as track_of_day_step\n')
        text = remove(text, '                    daily_work = track_of_day_step(factory) or daily_work\n')
    elif name == "backend/bmt_backend/database_privileges.py":
        for table in ("track_of_day_state", "track_of_day_history", "track_of_days"):
            text = remove(text, f'        "{table}",\n')
        text = remove(text, '    for table in ("track_of_days", "track_of_day_history", "track_of_day_state"):\n'
            '        policy[table] = dict.fromkeys(("SELECT", "INSERT", "UPDATE") if workload == "worker" else ("SELECT",))\n')
    elif name == "game/core/app.gd":
        start = text.index('func _open_track_of_day()')
        end = text.index('func _keep_race_mode_rail_fixed(', start)
        text = text[:start] + text[end:]
        for line in ('\telif mode == "daily": _open_track_of_day()\n',
                     '\t\t"daily": _track_of_day()\n',
                     '\t\t\t"daily": _track_of_day(column, true)\n',
                     '\t\telif next == "tracks" and race_area_mode == "daily": next = "daily"\n',
                     '\tbrowser.daily_requested.connect(_open_track_of_day)\n',
                     '\tpage.daily_requested.connect(_open_track_of_day)\n',
                     '\telif race_area_mode == "daily": _open_track_of_day()\n'):
            text = remove(text, line)
        text = remove(text, '\telif destination == "daily":\n'
            '\t\tvar daily: Node = column.find_child("TrackOfDayPage",true,false)\n'
            '\t\tif daily != null: daily.activate()\n')
        text = remove(text, '\tif screen == "daily":\n'
            '\t\tvar daily: Node = menu_body.find_child("TrackOfDayPage",true,false)\n'
            '\t\tif daily != null: daily.activate()\n')
        text = text.replace(' else "daily" if race_area_mode == "daily"', '')
        # Only the explicit menu-destination arrays changed in this task.
        text = text.replace(', "daily", "challenges"]', ', "challenges"]')
        text = text.replace(',"daily",', ',').replace(', "daily",', ',')
        text = text.replace(',"daily"]', ']').replace(', "daily"]', ']')
    elif name == "game/ui/race_mode_rail.gd":
        text = text.replace(',["sun","Track of the day","daily"]', '')
        text = text.replace(',"daily",', ',')
    elif name == "game/ui/race_mode_icons.gd":
        text = re.sub(r'\t\t"sun":\n\t\t\tart = .*\n', '', text)
    elif name in ("game/ui/track_browser.gd", "game/ui/weekly_rivalry_page.gd"):
        text = remove(text, 'signal daily_requested\n')
        text = remove(text, '\t\telif mode == "daily": daily_requested.emit())\n')
        text = text.replace('\t\telif mode == "challenges": challenges_requested.emit()\n',
            '\t\telif mode == "challenges": challenges_requested.emit())\n')
    elif name.startswith("game/localization/"):
        sources = {row.split('|')[0] for row in (ROOT / "scripts/translations/track_of_day.tsv")
            .read_text(encoding="utf-8").splitlines()}
        sources.add("TrackOfDayPage")
        needles = {'msgid ' + catalog.quoted(source) + '\n' for source in sources}
        text = '\n\n'.join(block for block in text.split('\n\n')
            if not any(needle in block + '\n' for needle in needles))
    elif name in ("AGENTS.md", "DEVELOPMENT_STATUS.md"):
        text = re.sub(r'<!-- TRACK-OF-DAY-20261025 -->.*?<!-- /TRACK-OF-DAY-20261025 -->\n\n',
            '', text, flags=re.S)
    elif name == "backend/README.md":
        text = text[:text.index('\n## Track of the Day\n')] + text[text.index('\n## Track of the Day\n'):].split(
            'migration chain. See [policy, tests and release limits](../docs/TRACK_OF_DAY_2026_10_25.md).\n', 1)[1]
    elif name == "docs/README.md":
        text = remove(text, '\n- [Track of the Day: permanent novelty, shared UTC selection and Race menu](TRACK_OF_DAY_2026_10_25.md).\n')
    else:
        raise AssertionError(name)
    return text


new = ["backend/bmt_backend/track_of_day.py", "backend/bmt_backend/migrations/versions/0068_track_of_day.py",
    "backend/schemas/track-of-day-v1.schema.json", "backend/tests/test_track_of_day.py",
    "backend/tests/test_track_of_day_native.py", "game/ui/track_of_day_page.gd", "game/ui/track_of_day_page.gd.uid",
    "game/tests/test_track_of_day.gd", "game/tests/test_track_of_day.gd.uid", "scripts/translations/track_of_day.tsv",
    "docs/TRACK_OF_DAY_2026_10_25.md"]
shared = ["backend/bmt_backend/app.py", "backend/bmt_backend/discovery_models.py",
    "backend/bmt_backend/discovery_worker.py", "backend/bmt_backend/database_privileges.py",
    "game/core/app.gd", "game/ui/race_mode_rail.gd", "game/ui/race_mode_icons.gd", "game/ui/track_browser.gd",
    "game/ui/weekly_rivalry_page.gd", "AGENTS.md", "DEVELOPMENT_STATUS.md", "backend/README.md", "docs/README.md"]
shared += [p.relative_to(ROOT).as_posix() for p in sorted((ROOT / 'game/localization').glob('*.po'))]
shared += ['game/localization/messages.pot']
patch = []
hashes = {}
for name in new + shared:
    path = ROOT / name
    if not path.exists():
        continue
    current = path.read_text(encoding='utf-8')
    before = '' if name in new else prior(name, current)
    assert before != current, name
    patch.extend(difflib.unified_diff(before.splitlines(True), current.splitlines(True),
        fromfile='/dev/null' if name in new else 'a/' + name, tofile='b/' + name))
    hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
(OUTPUT / 'task-only.patch').write_text(''.join(patch), encoding='utf-8', newline='\n')
checked = subprocess.run(['git', 'apply', '--reverse', '--check', str(OUTPUT / 'task-only.patch')],
    cwd=ROOT, text=True, capture_output=True, check=False)
(OUTPUT / 'checkpoint-check.log').write_text(checked.stdout + checked.stderr, encoding='utf-8')
assert checked.returncode == 0, checked.stdout + checked.stderr
(OUTPUT / 'source-hashes.json').write_text(json.dumps(hashes, indent=2) + '\n', encoding='utf-8')
print(f'Task-only review patch reverse-check passes: {len(hashes)} files. No index or commit mutation.')
