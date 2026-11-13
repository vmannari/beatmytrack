"""Audit declared car consumers against actual builder references. No writes."""

import json
import re
from fnmatch import fnmatchcase
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = json.loads(
    (ROOT / "game/vehicle/prepared_asset_dependencies.json").read_text(encoding="utf-8")
)


def consumers(path):
    if any(fnmatchcase(path, pattern) for pattern in SPEC["excluded"]):
        return set()
    for rule in SPEC["rules"]:
        if fnmatchcase(path, rule["pattern"]):
            return set(rule["vehicles"])
    return set(SPEC["vehicles"])


def audit():
    classes = {}
    for path in (ROOT / "game/vehicle").glob("*.gd"):
        match = re.search(
            r"^class_name\s+(\w+)", path.read_text(encoding="utf-8-sig"), re.MULTILINE
        )
        if match:
            classes[match[1]] = path.relative_to(ROOT).as_posix()
    errors, checked = [], 0
    families = ("compact", "electric", "kart", "forklift", "hovercraft")
    for path in (ROOT / "game/vehicle").iterdir():
        if path.suffix not in (".gd", ".gdshader", ".gdshaderinc"):
            continue
        # The shared CarVisual/VehicleModels/RacingCarModels dispatchers have
        # explicit vehicle branches; their complete source remains shared.
        if not any(path.name.startswith(family + "_") for family in families):
            continue
        relative = path.relative_to(ROOT).as_posix()
        owners = consumers(relative)
        source = path.read_text(encoding="utf-8-sig")
        sections = [(source, owners)]
        if path.name == "compact_detail.gd":
            # Electric/Forklift call only tire(). Compact body/detail builders
            # are reached by CompactDetail.build(), which belongs to Compact.
            # The file hash remains conservative for all three consumers.
            begin = source.index("static func tire(")
            end = source.index("static func build(")
            sections = [
                (source[:begin] + source[end:], {"compact", "super_rally"}),
                (source[begin:end], owners),
            ]
        for section, section_owners in sections:
            dependencies = {
                target
                for name, target in classes.items()
                if re.search(r"\b" + name + r"\b", section)
            }
            for reference in re.findall(r'res://([^"\n]+)', section):
                target = "game/" + reference
                if (ROOT / target).is_file():
                    dependencies.add(target)
                elif (
                    reference.startswith("assets/vehicles/")
                    and (ROOT / target).is_dir()
                ):
                    matched = any(
                        rule["pattern"].startswith(target + "/")
                        for rule in SPEC["rules"]
                    )
                    if not matched:
                        errors.append(f"{relative}: undeclared mesh root {target}")
                    dependencies.add(target + "/probe.res")
            for target in dependencies:
                checked += 1
                missing = section_owners - consumers(target)
                if missing:
                    errors.append(
                        f"{relative} -> {target}: missing consumers {sorted(missing)}"
                    )
    if errors:
        raise SystemExit("\n".join(errors))
    print(
        f"PREPARED_DEPENDENCIES: {checked} builder/reference edges cover their consumers; unknown inputs stay shared."
    )


if __name__ == "__main__":
    audit()
