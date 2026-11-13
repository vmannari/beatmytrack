"""Refresh Volt-only prepared models in dependency order, then validate."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
RUNNER = [sys.executable, "scripts/run_volt_rear.py"]
PREFIX = next((arg.split("=",1)[1] for arg in sys.argv if arg.startswith("--prefix=")), "")


def run(name, script, *args):
    subprocess.run([*RUNNER, PREFIX+name, script, *args], cwd=ROOT, check=True)


def identity():
    subprocess.run([
        "powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
        ". ./scripts/build_identity.ps1; "
        "Write-ClientBuildIdentity (Get-Location).Path "
        "(Join-Path (Get-Location).Path 'build/volt-rear-smoothing/identity') | Out-Null"
    ], cwd=ROOT, check=True)


def main():
    if "--resume-models" not in sys.argv:
        run("bake-source-final", "res://tests/bake_electric_reference.gd", "--headless")
        run("bake-shadows", "res://tests/bake_electric_design_shadows.gd", "--headless")
    identity()
    for name, script in [
        ("bake-bases", "bake_modular_car_bases.gd"),
        ("bake-kits", "bake_modular_car_kits.gd"),
        ("bake-garage", "bake_garage_cars.gd"),
    ]:
        run(name, "res://tests/"+script, "--headless", "--", "--vehicle=electric")
    identity()
    run("bake-pictures", "res://../scripts/bake_garage_previews.gd",
        "--rendering-method", "gl_compatibility")
    identity()
    run("prepared-check", "res://tests/check_prepared_assets.gd", "--headless")
    subprocess.run([sys.executable, "scripts/check_garage_previews.py"], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
