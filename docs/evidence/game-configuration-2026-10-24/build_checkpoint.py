"""Capture this task's source/evidence without staging unrelated workspace changes.

Existing files use selected task edits against retained snapshots, or explicit
reversal of task hooks from final sources. The synthetic base retains concurrent
work; it is a review/checkpoint base, not a claim of a pristine historical tree.
"""
import difflib
import hashlib
import json
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BEFORE = OUT / "before"

NEW = """
backend/bmt_backend/admin_ui/game_config.css
backend/bmt_backend/admin_ui/game_config.js
backend/bmt_backend/game_config.py
backend/bmt_backend/game_config_models.py
backend/bmt_backend/game_config_observations.py
backend/bmt_backend/game_config_policy.py
backend/bmt_backend/migrations/versions/0060_game_configuration.py
backend/schemas/game-configuration-v1.schema.json
backend/tests/test_game_config.py
backend/tests/test_game_config_postgres.py
scripts/test_game_configuration_console.py
scripts/test_game_configuration_postgres.py
game/backend/game_configuration.gd
game/backend/game_configuration.gd.uid
game/backend/game_config_policy.gd
game/backend/game_config_policy.gd.uid
game/tests/test_game_configuration.gd
game/tests/test_game_configuration_app.gd
game/tests/test_game_configuration_http.gd
game/tests/test_game_config_telemetry_original.gd
game/tests/fixtures/game_config_before/product_telemetry.gd
docs/GAME_CONFIGURATION_INTERFACE_SPEC_2026_10_24.md
docs/GAME_CONFIGURATION_IMPLEMENTATION_2026_10_24.md
""".split()

WHOLE = """
backend/bmt_backend/migrations/env.py
backend/bmt_backend/studio_experiments.py
backend/bmt_backend/studio_platform_models.py
backend/tests/test_auth_postgres.py
backend/tests/test_studio_platform.py
game/backend/product_telemetry.gd
game/platform/admob_test_ads.gd
game/platform/race_ad_breaks.gd
game/platform/resume_credits.gd
game/ui/store_page.gd
native/admob/src/org/beatmytrack/admob/BmtAdMob.java
""".split()


def read(name):
    return (ROOT / name).read_text(encoding="utf-8-sig")


def original(name):
    return (BEFORE / name.replace("/", "__")).read_text(encoding="utf-8-sig")


def replace_once(text, old, new=""):
    assert text.count(old) == 1, (old[:100], text.count(old))
    return text.replace(old, new, 1)


def selected(name, words):
    old, final = original(name).splitlines(True), read(name).splitlines(True)
    matcher = difflib.SequenceMatcher(None, old, final, autojunk=False)
    base = []
    for kind, i, j, a, b in matcher.get_opcodes():
        change = "".join(old[i:j] + final[a:b])
        base.extend(old[i:j] if kind != "equal" and any(w in change for w in words) else final[a:b])
    return "".join(base)


def bases():
    base = {name: original(name) for name in WHOLE}
    name = "backend/bmt_backend/app.py"
    text = read(name)
    for line in ('        game_config,\n', '        app.include_router(game_config.router)\n',
                 '        app.include_router(game_config.public_router)\n',
                 '        app.include_router(studio_experiments.public_router)\n',
                 '            "game_configuration_version": 1,\n'):
        text = replace_once(text, line)
    base[name] = text
    name = "backend/bmt_backend/admin.py"
    base[name] = replace_once(read(name), ', "game_config.js", "game_config.css"')
    name = "backend/bmt_backend/admin_ui/index.html"
    text = read(name)
    for line in ('  <link rel="stylesheet" href="/admin/assets/game_config.css">\n',
                 '  <script src="/admin/assets/game_config.js" defer></script>\n'):
        text = replace_once(text, line)
    base[name] = text
    name = "backend/bmt_backend/admin_ui/app.js"
    base[name] = selected(name, ["error.desired_policy", "wireGameConfig"])
    name = "backend/bmt_backend/admin_ui/platform.js"
    text = read(name)
    text = replace_once(text, "['studio?tab=config','Game Configuration'],")
    text = replace_once(text, "['studio?tab=experiments','A/B testing']", "['studio?tab=experiments','Experiments']")
    text = replace_once(text, " if(tab==='config')return head+await gameConfigView(params);\n")
    text = replace_once(text, " if(tab==='experiments')return head+await gameConfigExperiments(params);\n")
    extra = "if(error.detail?.current_policy&&error.desired_policy&&typeof gcDiff==='function')$('#platform-command-error').insertAdjacentHTML('beforeend','<p>Current server values compared with your proposed values. Reload and reconcile before saving.</p>'+gcDiff(error.detail.current_policy,error.desired_policy));"
    base[name] = replace_once(text, extra)
    name = "game/backend/backend_client.gd"
    base[name] = selected(name, ["_configuration_epoch", "game_configuration", "request_configuration", "owner_id < 0", "/game-config"])
    name = "game/core/app.gd"
    base[name] = selected(name, ["game_configuration", "_remote_menu_notice", "_remote_config_changed"])
    name = "backend/bmt_backend/telemetry.py"
    text = read(name)
    text = replace_once(text, "game_config_observations, ")
    text = replace_once(text, "ALLOWED.update(game_config_observations.FIELDS)\n")
    start = text.index("    if name in game_config_observations.NAMES:\n")
    # The special config validation and ordinary-event extraction precede the
    # original name/property validators; keep the latter verbatim.
    tail = text.index("    if name in network_health.NAMES:", start)
    text = text[:start] + text[tail:]
    text = replace_once(text, "else {**result, **configuration}", "else result")
    base[name] = text
    name = "backend/bmt_backend/telemetry_projection.py"
    text = replace_once(read(name), "    from .game_config_observations import project as project_configuration\n    project_configuration(session, events)\n")
    base[name] = text
    name = "backend/bmt_backend/studio_erasure.py"
    text = replace_once(read(name), "from .game_config_models import GameConfigDelivery\n")
    base[name] = replace_once(text, ", GameConfigDelivery")
    name = "backend/bmt_backend/worker.py"
    text = replace_once(read(name), "    from .game_config import activate_schedules\n")
    text = replace_once(text, '    if time.monotonic() >= getattr(app.state, "config_schedule_check", 0):\n        app.state.config_schedule_check = time.monotonic() + 15\n        roles.append(lambda: activate_schedules(app.state.session_factory))\n')
    base[name] = text
    for name in ("backend/schemas/product-events-v1.schema.json", "native/admob/PROVENANCE.md"):
        base[name] = subprocess.check_output(["git", "show", "HEAD:" + name], cwd=ROOT).decode("utf-8-sig")
    for name in ("AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"):
        text = read(name)
        assert "RGC01-RGC11/R01/G01/Q01:" in text.split("\n\n", 1)[0]
        base[name] = text.split("\n\n", 1)[1]
    name = "backend/README.md"
    text = read(name)
    end = text.index("<!-- /GAME-CONFIGURATION-20261024 -->") + len("<!-- /GAME-CONFIGURATION-20261024 -->\n\n")
    text = text[end:]
    text = replace_once(text, "and [game-configuration implementation and verification](../docs/GAME_CONFIGURATION_IMPLEMENTATION_2026_10_24.md).",
        "and [game-configuration specification](../docs/GAME_CONFIGURATION_INTERFACE_SPEC_2026_10_24.md).")
    base[name] = text
    name = "docs/README.md"
    text = read(name)
    base[name] = text[:text.rindex("\nGame Configuration and required A/B testing:")]
    return base


def main():
    base = bases()
    patch = []
    manifest = []
    with zipfile.ZipFile(OUT / "checkpoint-base.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for name in sorted(base):
            content = base[name]
            if b"\r\n" in (ROOT / name).read_bytes():
                content = content.replace("\n", "\r\n")
            archive.writestr(name, content)
    for name in sorted([*base, *NEW]):
        final = (ROOT / name).read_bytes().decode("utf-8-sig")
        old = base.get(name, "")
        assert old != read(name), name
        if b"\r\n" in (ROOT / name).read_bytes():
            old = old.replace("\n", "\r\n")
        manifest.append({"path": name, "sha256": hashlib.sha256((ROOT / name).read_bytes()).hexdigest(),
                         "base": "synthetic task reversal preserving concurrent work" if name in base else "new task file"})
        patch.append("diff --git a/" + name + " b/" + name + "\n")
        if name not in base:
            patch.append("new file mode 100644\n")
        patch.extend(difflib.unified_diff(old.splitlines(True), final.splitlines(True),
            fromfile="a/"+name if name in base else "/dev/null", tofile="b/"+name))
    (OUT / "checkpoint.patch").write_bytes("".join(patch).encode("utf-8"))
    (OUT / "source-hashes.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"files": len(manifest), "patch_bytes": (OUT / "checkpoint.patch").stat().st_size}))


if __name__ == "__main__":
    main()
