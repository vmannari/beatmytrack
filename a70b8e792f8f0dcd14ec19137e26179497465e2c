"""Read only local tool/resource metadata; no service/container mutations."""
import json
import os
import shutil
import subprocess


def run(args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=10)
    return {"returncode": result.returncode, "stdout": result.stdout.strip()}


def main():
    result = {"cpu_count": os.cpu_count(), "tools": {k: shutil.which(k) for k in ("docker", "psql", "python3")}}
    if os.path.isfile("/proc/meminfo"):
        rows = dict(line.split(":", 1) for line in open("/proc/meminfo"))
        result["memory_kib"] = {k: int(rows[k].strip().split()[0]) for k in ("MemTotal", "MemAvailable")}
    if result["tools"]["docker"]:
        result["docker_version"] = run(["docker", "info", "--format", "{{.ServerVersion}}"])
        result["cached_postgres_images"] = run(["docker", "image", "ls", "postgres", "--format", "{{.Repository}}:{{.Tag}}"])
        active = run(["docker", "ps", "--format", "{{.ID}}"])
        result["existing_running_containers"] = len(active["stdout"].splitlines()) if active["returncode"] == 0 else None
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
