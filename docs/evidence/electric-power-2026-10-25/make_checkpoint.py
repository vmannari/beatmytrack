"""Build and byte-check the task-only patch against the shared-workspace baseline."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
REL = OUT.relative_to(ROOT)
MARKER = "ELECTRIC-POWER-20261025"
METADATA = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
COMMON = [
    "game/resources/cars/electric.tres", "game/vehicle/handling_config.gd",
    "game/vehicle/vehicle_catalog.gd", "game/tests/test_electric_car.gd",
    "game/tests/test_electric_one_pedal.gd", "backend/tests/fixtures/verified_oval.json",
]
NEW = ["docs/ELECTRIC_POWER_2026_10_25.md"]
for name in ["test_electric_power", "test_electric_turning", "test_electric_power_laps", "export_electric_power_replay"]:
    NEW.extend([f"game/tests/{name}.gd", f"game/tests/{name}.gd.uid"])


def write(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


def run(args: list[str], cwd: Path, expected: int = 0) -> bytes:
    result = subprocess.run(args, cwd=cwd, capture_output=True)
    if result.returncode != expected:
        raise RuntimeError(result.stderr.decode(errors="replace") + result.stdout.decode(errors="replace"))
    return result.stdout


def main() -> None:
    logs = OUT / "logs"
    logs.mkdir(exist_ok=True)
    cutoff = (OUT / "before/game__resources__cars__electric.tres.txt").stat().st_mtime
    for source in (ROOT / "build/logs").glob("TestScript-*/test-script.log"):
        text = source.read_text(errors="replace")
        own = any(key in text for key in ["ELECTRIC_", "ONE_PEDAL:"])
        own |= '"values"' in text and '"turn36"' in text
        own |= source.parent.name in ["TestScript-13084", "TestScript-38088", "TestScript-32088"]
        if own and source.stat().st_mtime >= cutoff:
            shutil.copyfile(source, logs / (source.parent.name + ".log"))
    for name in ["Import-39836", "Import-30556"]:
        shutil.copyfile(ROOT / "build/logs" / name / "import.log", logs / (name + ".log"))
    write(OUT / "initial/font-and-manifest-failures.txt", (
        "Final-regression attempt before font import: 27 failed, 45 passed, 2 deselected, 6 warnings in 63.18s.\n"
        "The 27 failures report VerifierUnavailable: Canonical verifier reported an engine error.\n"
        "Concurrent language.gd first could not resolve GameFonts; after class discovery the three new\n"
        "font preloads had no resource loaders. See retained TestScript-38088 and Import-39836 logs.\n"
        "Diagnostic direct pinned --headless --editor --path game --import --recovery-mode populated\n"
        "font caches but retained preload errors and a relative log-file path error (exit 0 is not a pass).\n"
        "Normal pinned import then passed. No localization source was edited.\n"
        "The initial manifest isolation assertion found concurrent forklift-2 -> forklift-3; only the\n"
        "electric fixture entry was refreshed, preserving the current forklift-3 entry.\n"
        "A probe invocation outside res://tests/ was rejected by scripts/dev.ps1; rerun inside tests.\n"
    ).encode())

    statement = (
        "2026-10-25 EP01-EP04/R01/Q01: Electric-3 retains the stronger rear-wheel launch "
        "(0-100 1.892s to 1.017s), tightens actual high-speed path radii at least20% and "
        "calms rejected exaggerated breakaway (same-corner full-pedal slip44.23 to17.58deg; "
        "gentle5.35deg). One pedal/no handbrake, saved brake-position D/R, 11m/s2 regeneration "
        "and exact72km/h stop1.8s/17.842m remain. Native power19/turn61/retained60/one-pedal63/"
        "laps6/Compatibility59/desktopMobile59, backend72pass/2explicit deselections, "
        "real five-lap reader13115inputs and parser1153/import pass. Initial gentle-corner, "
        "concurrent-font/import/backend and manifest-isolation failures remain recorded; "
        "the owner's calmer-slide correction supersedes the initial >25deg proposal. "
        "Simulation arithmetic/physics0.68 and other car integrator states remain; "
        "concurrent forklift-3 is preserved. Commands, native evidence, hashes and task-only "
        "Git-checked checkpoint: docs/ELECTRIC_POWER_2026_10_25.md and "
        "docs/evidence/electric-power-2026-10-25/report.json. Client reload, matching online "
        "configuration/verifier rollout and owner/device feel acceptance remain. No device "
        "attachment check/test, APK, live mutation, purchase, deployment or owner-process "
        "restart; concurrent work preserved."
    )
    block = f"<!-- {MARKER} -->\n## Electric launch, tighter turning and calmer grip override (2026-10-25)\n{statement}\n<!-- /{MARKER} -->\n\n"
    for name in METADATA:
        current = (ROOT / name).read_bytes()
        # Preserve concurrent sections; remove only this task's marker on reruns.
        plain = re.sub(rb"<!-- ELECTRIC-POWER-20261025 -->.*?<!-- /ELECTRIC-POWER-20261025 -->\r?\n\r?\n", b"", current, flags=re.S)
        write(OUT / "checkpoint-base" / name, plain)
        write(ROOT / name, block.encode() + plain)
    for name in COMMON:
        if name.endswith("verified_oval.json"):
            # The current fixture includes independent forklift-3 work. Baseline
            # keeps that work and removes only our electric-3 entry.
            current = (ROOT / name).read_bytes()
            old = json.loads((OUT / "before/backend__tests__fixtures__verified_oval.json.txt").read_text())
            parsed = json.loads(current)
            new_entry = parsed["expected_manifest"]["vehicles"]["electric"]
            old_entry = old["expected_manifest"]["vehicles"]["electric"]
            base = current.replace(new_entry["config_hash"].encode(), old_entry["config_hash"].encode()).replace(b'"handling_version": "electric-3"', b'"handling_version": "electric-2"')
        else:
            base = (OUT / "before" / (name.replace("/", "__") + ".txt")).read_bytes()
        write(OUT / "checkpoint-base" / name, base)

    assert (ROOT / "game/vehicle/vehicle_simulation.gd").read_bytes() == (OUT / "before/game__vehicle__vehicle_simulation.gd.txt").read_bytes()
    manifest = json.loads((OUT / "manifest.json").read_text())
    baseline = json.loads((OUT / "before/backend__tests__fixtures__verified_oval.json.txt").read_text())["expected_manifest"]
    unchanged = [k for k, v in manifest["vehicles"].items() if k != "electric" and v == baseline["vehicles"].get(k)]
    assert len(unchanged) == 5
    backend_bytes = (OUT / "backend-final.log").read_bytes()
    backend_log = backend_bytes.decode("utf-16" if backend_bytes.startswith(b"\xff\xfe") else "utf-8-sig")
    write(OUT / "backend-final.log", backend_log.encode())
    assert "72 passed, 2 deselected" in backend_log
    report = {
        "date": "2026-10-25", "recorded_utc": datetime.now(timezone.utc).isoformat(),
        "requirements": {"EP01": "faster RWD acceleration", "EP02": "owner-corrected moderate rear slip", "EP03": "strict one pedal, stop/hold, no handbrake, D/R", "EP04": "tighter actual high-speed turn paths"},
        "version": {"handling": "electric-3", "physics": "arcade-planar-0.68", "config_hash": manifest["vehicles"]["electric"]["config_hash"]},
        "results": {"power":19,"turning":61,"electric":60,"one_pedal":63,"laps":6,"native_compatibility":59,"native_desktop_mobile":59,"backend_pass":72,"backend_deselected":2,"parser_scripts":1153,"failures":0,"normal_import":"pass"},
        "measurements": {name:json.loads((OUT/(name+".json")).read_text()) for name in ["power","turning","one-pedal","canonical-verification"]},
        "initial_outcomes": {"overaggressive_steering":"19 power checks / 1 gentle-corner failure; retained initial/exaggerated-steering-power.json", "changed_owner_target":"explicit calmer sliding request replaces >25deg target with bounded 12-24deg, gentle bound tightens to8deg", "unimported_concurrent_fonts":"27 failed /45 passed /2 deselected; recovered by import, no source/assertion edits", "manifest_isolation":"concurrent forklift-3 detected and preserved", "exploratory_probes":"0 assertions; not acceptance passes"},
        "unchanged_task_start_config_hashes": unchanged,
        "concurrent_forklift": manifest["vehicles"]["forklift"],
        "commands_document": "docs/ELECTRIC_POWER_2026_10_25.md",
        "changed_files": COMMON + NEW + METADATA,
        "limits": ["Owner/device driving feel pending", "Client reload and matching verifier/config rollout needed", "No phone/tablet attachment check or physical-device test", "No APK, live mutation, purchase, deployment or owner-process restart", "Native hitch diagnostics are not a performance benchmark", "PostgreSQL and known archived physics-050 ghost defect explicitly deselected"],
        "checkpoint": {"path":str(REL / "checkpoint.patch").replace("\\","/"), "baseline":"task-start sources plus preserved concurrent metadata/forklift-3", "git_apply_check":False, "byte_exact":False},
    }
    report["initial_outcomes"]["checkpoint_tool"] = "First log read needed UTF-16 decoding; first byte comparison caught prefix replacement inside this helper's source. Normalize patch headers only and repeat exact comparison."
    paths = COMMON + NEW + METADATA + ["game/vehicle/vehicle_simulation.gd"]
    paths += [str(p.relative_to(ROOT)).replace("\\","/") for p in OUT.rglob("*") if p.is_file() and p.name not in ["checkpoint.patch", "report.json"] and "__pycache__" not in p.parts]
    report["sha256"] = {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sorted(set(paths))}
    write(OUT / "report.json", (json.dumps(report,indent=2)+"\n").encode())

    number = 1
    while (ROOT / f"build/electric-power-checkpoint-{number}").exists(): number += 1
    stage = ROOT / f"build/electric-power-checkpoint-{number}"
    before, after = stage / "before", stage / "after"
    for name in COMMON + METADATA:
        write(before / name, (OUT / "checkpoint-base" / name).read_bytes())
    changed = sorted(set(COMMON + NEW + METADATA + [str(p.relative_to(ROOT)).replace("\\","/") for p in OUT.rglob("*") if p.is_file() and p.name != "checkpoint.patch" and "__pycache__" not in p.parts]))
    for name in changed: write(after / name, (ROOT / name).read_bytes())
    patch = OUT / "checkpoint.patch"
    def make_patch() -> None:
        diff = run(["git","-c","core.autocrlf=false","diff","--no-index","--no-renames","--binary","--","before","after"],stage,1)
        lines = []
        for line in diff.splitlines(keepends=True):
            if line.startswith((b"diff --git ", b"--- ", b"+++ ")):
                for a,b in [(b"a/before/",b"a/"),(b"b/after/",b"b/"),(b"a/after/",b"a/"),(b"b/before/",b"b/")]: line=line.replace(a,b)
            lines.append(line)
        patch.write_bytes(b"".join(lines))
    def verify(label: str) -> None:
        target = stage / label
        shutil.copytree(before,target)
        run(["git","init","-q"],target)
        run(["git","config","core.autocrlf","false"],target)
        run(["git","apply","--check",str(patch)],target)
        run(["git","apply",str(patch)],target)
        for name in changed:
            assert (target/name).read_bytes() == (after/name).read_bytes(), name
    make_patch()
    verify("verify1")
    report["checkpoint"].update(git_apply_check=True,byte_exact=True,changed_paths=len(changed))
    write(OUT / "report.json", (json.dumps(report,indent=2)+"\n").encode())
    shutil.copyfile(OUT/"report.json",after/REL/"report.json")
    make_patch()
    verify("verify2")
    for name, expected in report["sha256"].items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == expected, name
    print(json.dumps({"checkpoint":report["checkpoint"],"hashes_verified":len(report["sha256"]),"patch_bytes":patch.stat().st_size}))


if __name__ == "__main__":
    main()
