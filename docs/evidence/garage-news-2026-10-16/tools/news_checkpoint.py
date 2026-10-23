"""Record only Garage News changes, retaining concurrent edits on both sides."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess

root = Path.cwd()
out = root / 'docs/evidence/garage-news-2026-10-16'
out.mkdir(parents=True, exist_ok=True)
new = [
    'backend/bmt_backend/news.py', 'backend/bmt_backend/news_models.py',
    'backend/bmt_backend/migrations/versions/0038_garage_news.py',
    'backend/tests/test_news.py', 'backend/tests/test_news_http.py',
    'game/backend/news_client.gd', 'game/backend/news_client.gd.uid',
    'game/ui/garage_news_menu.gd', 'game/ui/garage_news_menu.gd.uid',
    'game/tests/test_garage_news.gd', 'game/tests/test_garage_news_native.gd',
    'game/tests/test_garage_news_http.gd',
]
reverse = {
    'backend/bmt_backend/app.py': [
        ('        news,\n', ''),
        ('    app.include_router(news.router, prefix="/v1")\n', ''),
        ('            "garage_news_version": 1,\n', ''),
    ],
    'backend/bmt_backend/migrations/env.py': [('    news_models,\n', '')],
    'backend/bmt_backend/worker.py': [
        ('.where(Player.id == player_id).with_for_update(key_share=True)\n',
         '.where(Player.id == player_id).with_for_update()\n'),
        ('                from .news import process_requested\n                if process_requested(app):\n                    return True\n', ''),
        ('        if not creator_test:\n            from .news import capture_verified\n            capture_verified(session, run, board, version, track, player)\n', ''),
    ],
    'backend/bmt_backend/privacy.py': [
        ('    from .news import erase_private as erase_news\n', ''),
        ('    if not erase_news(session, job.player_id):\n        session.commit()\n        return True\n', ''),
        ('    from .news import cleanup_expired\n    pruned_news = 0\n    if getattr(app.state, "news_prune_at", 0) <= now():\n        pruned_news = cleanup_expired(session, now())\n        app.state.news_prune_at = now() + 60\n', ''),
        ('    return bool(rows or receipts or pruned_news)\n', '    return bool(rows or receipts)\n'),
    ],
    'backend/bmt_backend/community.py': [
        ('    from .news_models import Friendship\n    low, high = sorted((player.id, target_id))\n    session.execute(delete(Friendship).where(Friendship.low_id == low, Friendship.high_id == high))\n', ''),
    ],
    'game/backend/backend_client.gd': [
        ('var news: Node\n', ''),
        ('\tnews = preload("res://backend/news_client.gd").new()\n\tnews.client = self\n\tadd_child(news)\n\tidentity_changed.connect(news.identity_changed)\n\tnews.identity_changed()\n', ''),
        ('\tsafety.changed.connect(news.blocks_changed)\n', ''),
    ],
    'game/core/app.gd': [
        ('\tpage.news_client = online.client.news\n\tpage.account_requested.connect(_open_account)\n', ''),
    ],
    'game/ui/garage_mode_icons.gd': [
        ('\t\t"news":\n\t\t\tart = "<path fill-rule=\'evenodd\' d=\'M9 10h39v8h7v35H9Zm7 7v29h32V25h-7v-8Zm5 5h14v10H21Zm0 15h22v4H21Z\'/>"\n', ''),
    ],
    'game/ui/garage_page.gd': [
        ('signal account_requested\n', ''), ('var news_client: Node\n', ''),
        ('\tdestinations.append(["news","News"])\n\tif destinations.size() > 5: rail.add_theme_constant_override("separation",8)\n', ''),
        ('\t\tbutton.custom_minimum_size = Vector2(60,52 if destinations.size() > 5 else 60)\n', '\t\tbutton.custom_minimum_size = Vector2(60, 60)\n'),
        ('["cars", "customise", "care", "tuning", "trophies", "records", "news"]', '["cars", "customise", "care", "tuning", "trophies", "records"]'),
        ('_set_customise_layout(next in ["customise","tuning","records","news"])', '_set_customise_layout(next in ["customise","tuning","records"])'),
        ('elif next not in ["trophies","records","news"]:', 'elif next not in ["trophies","records"]:'),
        ('if section not in ["customise","tuning","records","news"]:', 'if section not in ["customise","tuning","records"]:'),
        ('\telif section == "news":\n\t\tvar news_menu := preload("res://ui/garage_news_menu.gd").new()\n\t\tnews_menu.page = self\n\t\tnews_menu.service = news_client\n\t\ttools.add_child(news_menu)\n', ''),
    ],
}
before = {}
for path, replacements in reverse.items():
    value = (root / path).read_text(encoding='utf-8')
    for after, original in replacements:
        assert value.count(after) == 1, (path, after)
        value = value.replace(after, original, 1)
    before[path] = value
readme = 'backend/README.md'
current = (root / readme).read_text(encoding='utf-8')
start = current.index('\n## Garage News\n')
end_marker = 'Phone touch/performance and production capacity remain unmeasured.\n'
end = current.index(end_marker, start) + len(end_marker)
before[readme] = current[:start] + current[end:]
patch = []
hashes = {}
for path in [*new, *before]:
    raw = (root / path).read_bytes()
    value = raw.decode('utf-8').replace('\r\n', '\n')
    original = before.get(path, '')
    hashes[path] = hashlib.sha256(raw).hexdigest()
    patch.append('diff --git a/' + path + ' b/' + path + '\n')
    if path in new:
        patch.append('new file mode 100644\n')
    patch.extend(difflib.unified_diff(original.splitlines(keepends=True), value.splitlines(keepends=True),
        fromfile='a/' + path if path in before else '/dev/null', tofile='b/' + path))
patch_file = out / 'task-only.patch'
patch_file.write_text(''.join(patch), encoding='utf-8', newline='\n')
checked = subprocess.run(['git', 'apply', '--reverse', '--check', str(patch_file)], capture_output=True, text=True)
assert checked.returncode == 0, checked.stderr
(out / 'checkpoint.json').write_text(json.dumps({
    'scope': 'Only Garage News additions; shared-file before images reconstruct the exact reversed task hunks. Concurrent changes remain identical on both sides. No main index or HEAD mutation.',
    'sha256': hashes, 'task_patch': 'task-only.patch', 'reverse_apply_check': 'passed',
}, indent=2) + '\n', encoding='utf-8')
print('Task-only checkpoint:', len(hashes), 'source files; reverse apply passed')
