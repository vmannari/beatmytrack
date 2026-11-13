"""Save pre-task assemblies, then rebuild only Rally-dependent templates."""
from pathlib import Path
import shutil
import subprocess
import sys

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
paths = list((root / "game/assets/vehicles/modular_car_bases_v1").glob("compact*.scn"))
paths += list((root / "game/assets/vehicles/modular_kits_v1/compact").rglob("*.scn"))
paths += [root / path for path in ("game/assets/garage/cars_v1/compact.scn", "game/assets/menu/header_car_templates_v1/compact.scn", "game/assets/garage/previews_v1/provenance.json")]
paths += list((root / "game/assets/garage/previews_v1").glob("*.png"))
for path in paths:
    backup = evidence / "before" / path.relative_to(root)
    if path.exists() and not backup.exists():
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, backup)
for label, script in (("bake-bases", "bake_modular_car_bases"), ("bake-kits", "bake_modular_car_kits"), ("bake-garage", "bake_garage_cars"), ("bake-header", "bake_header_simple_compact")):
    run_label = label + ("-" + sys.argv[1] if len(sys.argv) > 1 else "")
    command = [sys.executable, str(evidence / "run_check.py"), run_label, "res://tests/" + script + ".gd"]
    if label != "bake-header":
        command += ["--vehicle=compact"]
    subprocess.run(command, cwd=root, check=True)
