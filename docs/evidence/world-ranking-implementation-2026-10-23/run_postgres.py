"""Own disposable PostgreSQL and frozen-source Linux tests; no existing services."""
import json
import os
import secrets
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent


def linux(path):
    absolute = path.resolve().as_posix()
    assert absolute.startswith("C:/")
    return "/mnt/c/"+absolute[3:]


def main():
    docker = json.loads((ROOT / ".tools/gcp-staging/config.json").read_text())["docker"]
    token = secrets.token_hex(8)
    if (OUT / "postgres.log").exists() and not (OUT / "postgres-initial.log").exists():
        shutil.copyfile(OUT / "postgres.log", OUT / "postgres-initial.log")
        shutil.copyfile(OUT / "postgres-source.json", OUT / "postgres-initial-source.json")
    name, label = "bmt-ranking-pg-"+token, "world-ranking-"+token
    frozen = ROOT / "build" / ("world-ranking-frozen-"+token)
    shutil.copytree(ROOT / "backend", frozen / "backend", ignore=shutil.ignore_patterns(
        "__pycache__", ".pytest_cache", "var", "*.sqlite", "*.db", "*.egg-info"))

    shutil.copytree(ROOT / "docs/schemas", frozen / "docs/schemas")

    def call(*args, check=True, timeout=60):
        result = subprocess.run([*docker, *args], capture_output=True, text=True,
                                timeout=timeout, check=False)
        if check and result.returncode:
            raise RuntimeError(result.stderr[-3000:]+result.stdout[-3000:])
        return result

    image = next((tag for tag in ("bmt-backend:local", "303c521ef446", "c126c96c")
                  if call("image", "inspect", tag, check=False).returncode == 0), None)
    assert image, "An existing backend test image is required; nothing pulled"
    call("run", "--rm", "--network", "none", "--label", "bmt.task="+label,
         "--entrypoint", "python", image, "-c", "import pytest, sqlalchemy; print(pytest.__version__)")
    call("run", "-d", "--rm", "--name", name, "--label", "bmt.task="+label,
         "--network", "none", "--cpus", "1", "--memory", "2g", "--shm-size", "256m",
         "-e", "POSTGRES_HOST_AUTH_METHOD=trust", "postgres:17",
         "-c", "shared_buffers=128MB", "-c", "work_mem=16MB", "-c", "max_connections=20")
    result = None
    try:
        for _ in range(60):
            if call("exec", name, "pg_isready", "-U", "postgres", check=False).returncode == 0:
                break
            time.sleep(.25)
        else:
            raise RuntimeError("Owned PostgreSQL startup failed")
        selection = sys.argv[1:] or ["tests/test_world_ranking.py", "-k", "postgres"]
        command = ["run", "--rm", "--label", "bmt.task="+label,
            "--network", "container:"+name, "--entrypoint", "python", "--workdir", "/workspace/backend",
            "-e", "BMT_RANKING_SCALE_PLAYERS="+str(int(os.environ.get("BMT_RANKING_SCALE_PLAYERS", "0"))),
            "-e", "PYTHONPATH=/workspace/backend", "-e", "PYTHONDONTWRITEBYTECODE=1",
            "-e", "BMT_TEST_DATABASE_URL=postgresql+psycopg://postgres@127.0.0.1:5432/postgres",
            "--mount", "type=bind,source="+linux(frozen / "backend")+",target=/workspace/backend,readonly",
            "--mount", "type=bind,source="+linux(ROOT / "game")+",target=/workspace/game,readonly",
            "--mount", "type=bind,source="+linux(frozen / "docs")+",target=/workspace/docs,readonly",
            "--mount", "type=bind,source="+linux(OUT)+",target=/evidence", image,
            "-m", "pytest", *selection, "-q", "--tb=short", "-p", "no:cacheprovider", "--junitxml=/evidence/postgres-"+token+".xml"]
        result = call(*command, timeout=3600, check=False)
        (OUT / "postgres.log").write_text(result.stdout+result.stderr, encoding="utf-8")
        (OUT / ("postgres-"+token+".log")).write_text(result.stdout+result.stderr, encoding="utf-8")
        (OUT / ("postgres-"+token+"-source.json")).write_text(json.dumps({"image":image,
            "frozen_backend":str(frozen / "backend"),"selection":selection,"exit_code":result.returncode},indent=2))
        shutil.copyfile(OUT / ("postgres-"+token+"-source.json"), OUT / "postgres-source.json")
        print((result.stdout+result.stderr)[-12000:])
    finally:
        identity = call("inspect", name, "--format", "{{json .Config.Labels}}", check=False)
        if identity.returncode == 0 and json.loads(identity.stdout).get("bmt.task") == label:
            call("stop", "--time", "5", name)
            print("Owned PostgreSQL removed")
        else:
            raise RuntimeError("Owned container label not verified; no cleanup attempted")
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
