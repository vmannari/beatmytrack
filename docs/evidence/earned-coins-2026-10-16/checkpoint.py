"""Build a review patch without including concurrent news/safety/clean-car work."""
import difflib
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent


def head(path):
    return subprocess.check_output(["git", "show", "HEAD:" + path], cwd=ROOT).decode().replace("\r\n", "\n")


def remove(text, value):
    assert text.count(value) == 1, value[:120]
    return text.replace(value, "", 1)


def section(text, start, end):
    a = text.index(start)
    b = text.index(end, a)
    return text[a:b]


def before(path, text):
    if path in {"game/ui/race_complete.gd", "game/ui/race_reward_preview.gd",
                "game/ui/garage_livery_menu.gd", "game/persistence/local_records.gd"}:
        return head(path)
    if path == "game/core/app.gd":
        text = remove(text, "var cosmetic_economy: Node\n")
        text = remove(text, '\tcosmetic_economy = preload("res://backend/cosmetic_economy.gd").new()\n\tcosmetic_economy.records = records\n\tcosmetic_economy.client = online.client\n\tadd_child(cosmetic_economy)\n')
        assert text.count("\tpage.economy = cosmetic_economy\n") == 2
        text = text.replace("\tpage.economy = cosmetic_economy\n", "")
        text = remove(text, '\tif cosmetic_economy != null and not cosmetic_economy.erase_account(origin,player_id):\n\t\t_notice("Account removed. Coin recovery files could not be erased; check writable storage.")\n')
        old = head(path)
        text = text.replace(section(text, "func _results() -> void:", "func _save_result_upload("),
                            section(old, "func _results() -> void:", "func _save_result_upload("), 1)
        text = remove(text, '\tpage.reward_ticket = str(results.get_meta("reward_ticket",""))\n\tpage.coin_receipt = results.get_meta("coin_receipt",{})\n')
        return text
    if path == "game/ui/garage_page.gd":
        text = remove(text, "var economy: Node\nvar _coin_balance: Label\nvar _coin_status: Label\nvar _purchase_dialog: ConfirmationDialog\n")
        text = text.replace(section(text, '\tif economy != null:\n\t\t_coin_balance = ', "func _new_menu_panels()"), "\n", 1)
        text = remove(text, '\t\t_shop_badge(card,"kit/compact/"+kit_category+"/"+str(option[0]))\n')
        text = text.replace('func _select_kit(category: String, option: String) -> void:\n\tif vehicle_id != "compact" or section != "tuning": return\n\tif not _require_clean_car(): return\n',
                            'func _select_kit(category: String, option: String) -> void:\n\tif vehicle_id != "compact" or section != "tuning": return\n', 1)
        text = text.replace(section(text, '\tvar title: String = option.capitalize()', '\t_save_kits(next)'), "", 1)
        text = remove(text, '\tvar value: Dictionary = _preset_value(index)\n\tvar title: String = LIVERY_NAMES[index] if index < LIVERY_NAMES.size() else str(LiveryCatalog.patterns[index-LIVERY_NAMES.size()].title)\n\tif not _require_owned("livery/"+str(value.pattern),title,_select_livery.bind(index)): return\n')
        text = remove(text, '\t\tif is_instance_valid(_purchase_dialog): _purchase_dialog.hide()\n')
        return remove(text, '\telif economy != null: economy.refresh()\n')
    if path == "game/backend/backend_client.gd":
        start = text.index('\tif endpoint == "/economy":')
        end = text.index('\t\treturn total == int(data.amount)\n', start) + len('\t\treturn total == int(data.amount)\n')
        return text[:start] + text[end:]
    if path == "backend/bmt_backend/app.py":
        text = remove(text, "        economy,\n")
        return remove(text, '    app.include_router(economy.router, prefix="/v1")\n')
    if path == "backend/bmt_backend/migrations/env.py":
        return remove(text, "    economy_models,\n")
    if path == "backend/bmt_backend/worker.py":
        text = remove(text, "        from .economy import accept_verified as award_coins, previous_bests\n        coin_previous = previous_bests(session, run) if not creator_test else (0, 0)\n")
        return remove(text, "            award_coins(session, run, coin_previous)\n")
    if path == "backend/bmt_backend/privacy.py":
        return text.replace(section(text, "    # Extend the final cleanup without changing the persisted v1 stage indices.", "    from .admin_models import AdminAudit"), "", 1)
    raise ValueError(path)


MODIFIED = ["backend/bmt_backend/app.py", "backend/bmt_backend/migrations/env.py",
            "backend/bmt_backend/worker.py", "backend/bmt_backend/privacy.py",
            "game/core/app.gd", "game/backend/backend_client.gd", "game/persistence/local_records.gd",
            "game/ui/garage_page.gd", "game/ui/garage_livery_menu.gd", "game/ui/race_complete.gd",
            "game/ui/race_reward_preview.gd"]
NEW = ["backend/bmt_backend/economy.py", "backend/bmt_backend/economy_models.py",
       "backend/bmt_backend/migrations/versions/0037_earned_coins.py", "backend/tests/test_earned_coins.py",
       "game/backend/cosmetic_economy.gd", "game/persistence/cosmetic_catalog.gd",
       "game/tests/test_earned_coins.gd", "game/tests/test_earned_coins_app.gd",
       "docs/schemas/earned-coins-v1.schema.json"]
NEW += [path + ".uid" for path in list(NEW) if path.endswith(".gd") and (ROOT / (path + ".uid")).exists()]
patches, manifest = [], []
for path in MODIFIED + NEW:
    current = (ROOT / path).read_text(encoding="utf-8").replace("\r\n", "\n")
    original = "" if path in NEW else before(path, current)
    patches.append("diff --git a/" + path + " b/" + path + "\n")
    if path in NEW:
        patches.append("new file mode 100644\n")
    patches.extend(difflib.unified_diff(original.splitlines(True), current.splitlines(True),
        fromfile="/dev/null" if path in NEW else "a/" + path, tofile="b/" + path))
    manifest.append({"path": path, "sha256": hashlib.sha256((ROOT / path).read_bytes()).hexdigest(),
                     "checkpoint_before_lf_sha256": hashlib.sha256(original.encode()).hexdigest()})
(OUT / "task.patch").write_text("".join(patches), encoding="utf-8", newline="\n")
(OUT / "source-manifest.json").write_text(json.dumps({"basis":"Current shared workspace minus this task's edits; unrelated work retained", "files":manifest}, indent=2) + "\n", encoding="utf-8")
print("Checkpoint:", len(manifest), "source/schema files")
