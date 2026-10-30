from pathlib import Path

EVIDENCE = Path(__file__).resolve().parent
ROOT = next(p for p in EVIDENCE.parents if (p / "godot-version.txt").exists())
test = (EVIDENCE / "test_garage_clean_customisation.before.gd.txt").read_text(encoding="utf-8-sig")
test = test.replace("\tMenuStyle.fill(page)\n\tpage.open_car(0)", "\tMenuStyle.fill(page)\n\tawait settle()\n\tpage.showroom.pick_body_surface(page.showroom.size*0.5)\n\tpage.open_car(0)", 1)
test = test.replace('\tawait capture("wash-required-kits")', '\tawait settle()\n\tawait capture("wash-required-kits")', 1)
(ROOT / "game/tests/_garage_workshop_clean_before.gd").write_text(test, encoding="utf-8")
