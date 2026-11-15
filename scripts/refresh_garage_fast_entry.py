"""Privately rebuild rejected prepared cars, then publish under source/output fences."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys

from refresh_car_coarse_models import sources as model_sources, consumed

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "build/garage-fast-entry-2026-11-14"
PROJECT = WORK / "bake/game"
for option in sys.argv[1:]:
    if option.startswith("--candidate="):
        PROJECT = Path(option.split("=", 1)[1]).resolve() / "game"
        assert PROJECT.is_relative_to(WORK) and PROJECT != ROOT / "game"
OUTPUTS = ("assets/vehicles/modular_car_bases_v1", "assets/vehicles/modular_kits_v1",
           "assets/garage/cars_v1", "assets/menu/header_car_templates_v1",
           "assets/garage/previews_v1")


def sources():
    result = model_sources()
    # New detail-frame recipes are JSON geometry inputs too.
    for path in (ROOT / "game/assets/vehicles").rglob("*.json"):
        relative = path.relative_to(ROOT).as_posix()
        if consumed(relative):
            result[relative] = digest(path)
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def files(game):
    result = {}
    for folder in OUTPUTS:
        for path in (game / folder).rglob("*"):
            relative = path.relative_to(game).as_posix()
            if (not path.is_file() or path.suffix not in (".scn", ".png", ".json")
                    or "/garage/cars_v1/" in relative or "_full_" in path.name
                    or "/modular_kits_v1/" in relative and "/full/" in relative):
                continue
            result[relative] = digest(path)
    return result


def prepare():
    PROJECT.mkdir(parents=True, exist_ok=True)
    links = []

    def link(target, source):
        if not target.exists():
            links.append(dict(link=str(target), target=str(source)))

    for source in (ROOT / "game").iterdir():
        if source.name in (".godot", "android", "build", "tmp", "docs", "assets") or source.name.startswith("recordings-"):
            continue
        target = PROJECT / source.name
        if source.name in ("ui", "core"):
            target.mkdir(exist_ok=True)
            for item in source.iterdir():
                if item.is_file():
                    shutil.copy2(item, target / item.name)
                else:
                    link(target / item.name, item)
        elif source.is_dir():
            link(target, source)
        else:
            shutil.copy2(source, target)
    assets = PROJECT / "assets"
    assets.mkdir(exist_ok=True)
    private = {"vehicles": {"modular_car_bases_v1", "modular_kits_v1"},
               "garage": {"cars_v1", "previews_v1"}, "menu": {"header_car_templates_v1"}}
    for source in (ROOT / "game/assets").iterdir():
        target = assets / source.name
        if source.name not in private:
            if source.is_dir():
                link(target, source)
            else:
                shutil.copy2(source, target)
            continue
        target.mkdir(exist_ok=True)
        for item in source.iterdir():
            if item.name in private[source.name]:
                if not (target / item.name).exists():
                    shutil.copytree(item, target / item.name)
            elif item.is_dir():
                link(target / item.name, item)
            else:
                shutil.copy2(item, target / item.name)
    cache = PROJECT / ".godot"
    cache.mkdir(exist_ok=True)
    for name in ("global_script_class_cache.cfg", "extension_list.cfg", "uid_cache.bin"):
        if (ROOT / "game/.godot" / name).exists():
            shutil.copy2(ROOT / "game/.godot" / name, cache / name)
    link(cache / "imported", ROOT / "game/.godot/imported")
    for name in ("docs", "native", "scripts"):
        link(PROJECT.parent / name, ROOT / name)
    shutil.copy2(ROOT / "godot-version.txt", PROJECT.parent / "godot-version.txt")
    if links:
        subprocess.run(["powershell", "-NoProfile", "-Command",
                        "$ErrorActionPreference='Stop'; $items=ConvertFrom-Json $env:BMT_FAST_LINKS; foreach($item in $items) { New-Item -ItemType Junction -Path $item.link -Target $item.target | Out-Null }"],
                       env=dict(os.environ, BMT_FAST_LINKS=json.dumps(links)), check=True)
    for folder in OUTPUTS:
        path = PROJECT / folder
        assert path.is_dir() and not (getattr(path.lstat(), "st_file_attributes", 0)
                                    & stat.FILE_ATTRIBUTE_REPARSE_POINT), path


def run(label, script, *options):
    command = [sys.executable, str(ROOT / "scripts/run_garage_fast_entry.py"), label,
               "--project", str(PROJECT), "--script", script, *options]
    subprocess.run(command, cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    errors = [line for line in (WORK / label / "run.log").read_text().splitlines()
              if line.startswith("ERROR:") and "root certificate store" not in line]
    assert not errors, errors[:5]
    print(label, "passed", flush=True)


def freeze_inputs(before):
    """Copy consumed junctions so another producer cannot change a running bake."""
    for relative in sorted(before):
        target = PROJECT.parent / relative
        for parent in list(target.parents)[::-1]:
            if parent == PROJECT or not parent.is_relative_to(PROJECT):
                continue
            if parent.exists() and getattr(parent.lstat(), "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT:
                source = ROOT / parent.relative_to(PROJECT.parent)
                assert source.is_dir() and parent.absolute().is_relative_to(PROJECT.absolute())
                parent.rmdir() # Remove only this verified private junction, never its target.
                shutil.copytree(source, parent)
        shutil.copy2(ROOT / relative, target)
    assert all(digest(PROJECT.parent / p) == h for p,h in before.items()), "Snapshot changed while copying"


def identity(label):
    destination = WORK / (label + "-identity")
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
               ". (Join-Path $env:BMT_FAST_REPO 'scripts/build_identity.ps1'); Write-ClientBuildIdentity $env:BMT_FAST_REPO $env:BMT_FAST_IDOUT $env:BMT_FAST_DEST"]
    with (WORK / (label + "-identity.log")).open("w", encoding="utf-8") as log:
        subprocess.run(command, cwd=ROOT, env=dict(os.environ, BMT_FAST_REPO=str(ROOT),
                       BMT_FAST_IDOUT=str(destination), BMT_FAST_DEST=str(PROJECT.parent)), stdout=log, stderr=subprocess.STDOUT, check=True)
    return json.loads((destination / "client-build-identity.json").read_text(encoding="utf-8-sig"))


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    publish_only = "--publish-qualified" in sys.argv
    rebase = "--rebase-qualified" in sys.argv
    if "--resume-after-bases" in sys.argv or publish_only or rebase:
        before = json.loads((WORK / "refresh-inputs.json").read_text())
        accepted = json.loads((WORK / "accepted-outputs.json").read_text())
        first = json.loads((WORK / "fast-before-identity/client-build-identity.json").read_text(encoding="utf-8-sig"))
        assert before == sources(), "Source fence changed; restart the private bake"
        if rebase:
            # Preserve a concurrent producer's current base/module bytes.
            # Strict validation below qualifies that complete combined set.
            accepted = files(ROOT / "game")
            for path in accepted:
                if "/modular_car_bases_v1/" in path or "/modular_kits_v1/" in path:
                    shutil.copy2(ROOT / "game" / path, PROJECT / path)
            first = identity("fast-before")
            (WORK / "accepted-outputs.json").write_text(json.dumps(accepted, indent=2))
        elif publish_only:
            assert (WORK / "private-snapshot.json").is_file()
        else:
            base_receipt = json.loads((WORK / "bake-bases-native/run.json").read_text())
            assert base_receipt["exit_code"] == 0 and base_receipt.get("stop_reason") is None
            assert not any(line.startswith(("ERROR:", "SCRIPT ERROR:")) for line in (WORK / "bake-bases-native/run.log").read_text().splitlines())
    else:
        before = sources()
        accepted = files(ROOT / "game")
        prepare()
        freeze_inputs(before)
        first = identity("fast-before")
        assert before == sources(), "Sources changed while preparing snapshot"
        (WORK / "refresh-inputs.json").write_text(json.dumps(before, indent=2))
        (WORK / "accepted-outputs.json").write_text(json.dumps(accepted, indent=2))
        run("bake-bases-native", "res://tests/bake_modular_car_bases.gd", "--quality=simple")
    if not publish_only and not rebase:
        with ThreadPoolExecutor(max_workers=3) as executor:
            futures = [executor.submit(run, "bake-kits-" + car,
                       "res://tests/bake_modular_car_kits.gd", *([] if car == "forklift" else ["--headless"]), "--vehicle=" + car, "--quality=simple")
                       for car in ("compact", "kart", "forklift", "electric", "hovercraft", "super_rally")]
            for future in futures:
                future.result()
        run("bake-header", "res://tests/bake_header_simple_compact.gd", "--headless")
        run("bake-pictures", "res://../scripts/bake_garage_previews.gd", "--output=" + str(PROJECT / "assets/garage/previews_v1"))
    if rebase:
        run("bake-header", "res://tests/bake_header_simple_compact.gd", "--headless")
        run("bake-pictures", "res://../scripts/bake_garage_previews.gd", "--output=" + str(PROJECT / "assets/garage/previews_v1"))
    run("private-preflight", "res://tests/check_prepared_assets.gd", "--headless", "--simple-only")
    import check_garage_previews as preview_validation
    preview_validation.ROOT = PROJECT.parent
    preview_validation.check()
    print("Private catalogue provenance passed", flush=True)
    assert all(digest(PROJECT.parent / p) == h for p,h in before.items()), "Private input snapshot changed"
    if "--private-only" in sys.argv:
        (WORK / "private-snapshot.json").write_text(json.dumps(dict(input_count=len(before),
            source_fence=True, geometry_keys=first["modular_car_sha256"]), indent=2))
        print("Private snapshot qualified; live assets untouched", flush=True)
        return
    assert before == sources(), "Consumed sources changed; accepted output remains untouched"
    final = identity("fast-after")
    assert first["modular_car_sha256"] == final["modular_car_sha256"], "Geometry identity changed"
    assert accepted == files(ROOT / "game"), "Another producer changed accepted output"
    assert before == sources(), "Consumed sources changed before publication"
    photo_sources = json.loads((PROJECT / "assets/garage/previews_v1/provenance.json").read_text())["sources"]
    assert all(digest(ROOT / p) == h for p,h in photo_sources.items()), "Catalogue sources changed before publication"
    candidate = files(PROJECT)
    # Publish generated identity with its qualified assets; preserve every
    # authored project setting even if another session edited the project.
    def normalized_project(path):
        return "\n".join(line for line in path.read_text().splitlines()
                         if not line.startswith('config/version='))
    assert normalized_project(PROJECT / "project.godot") == normalized_project(ROOT / "game/project.godot")
    for path in ("core/build_identity.gd", "project.godot"):
        accepted[path] = digest(ROOT / "game" / path)
        candidate[path] = digest(PROJECT / path)
    changed = [path for path, value in candidate.items() if accepted.get(path) != value]
    for path in changed:
        target = ROOT / "game" / path
        previous = WORK / "publication-before" / path
        if target.exists():
            previous.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, previous)
    written = []
    try:
        for path in sorted(changed, key=lambda p: p.endswith("provenance.json")):
            target = ROOT / "game" / path
            assert digest(target) == accepted[path] if path in accepted else not target.exists()
            target.parent.mkdir(parents=True, exist_ok=True)
            temporary = target.with_name(target.name + ".fast-publish")
            shutil.copy2(PROJECT / path, temporary)
            os.replace(temporary, target)
            written.append(path)
        assert before == sources(), "Consumed sources changed during publication"
        assert all(digest(ROOT / p) == h for p,h in photo_sources.items()), "Catalogue sources changed during publication"
        assert all(digest(ROOT / "game" / p) == candidate[p] for p in written)
    except BaseException:
        for path in reversed(written):
            target = ROOT / "game" / path
            if digest(target) == candidate[path] and path in accepted:
                shutil.copy2(WORK / "publication-before" / path, target)
        raise
    receipt = dict(input_count=len(before), changed=changed, source_fence=True,
                   geometry_keys=final["modular_car_sha256"], published_hashes={p:candidate[p] for p in changed})
    (WORK / "refresh-publication.json").write_text(json.dumps(receipt, indent=2))
    print("Published", len(changed), "qualified generated assets", flush=True)


if __name__ == "__main__":
    main()
