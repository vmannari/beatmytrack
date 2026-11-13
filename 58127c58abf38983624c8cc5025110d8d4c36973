"""Read-only source inventory for the 26 October backend audit."""
from __future__ import annotations

import ast
import hashlib
import importlib.metadata
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent


def main():
    files, routes, tables, errors = [], [], [], []
    selected = set()
    for folder in ("backend", "game/backend", "game/platform", "game/persistence"):
        selected.update(p for p in (ROOT / folder).rglob("*") if p.is_file()
            and p.suffix in {".py", ".gd", ".json", ".toml", ".lock", ".yaml", ".sql", ".sh", ".md"}
            and not any(x in p.parts for x in ("__pycache__", ".pytest_cache", "vendor", ".ruff_cache", "build")))
    selected.update((ROOT / "scripts").glob("*backend*"))
    for path in sorted(selected):
        data = path.read_bytes()
        name = path.relative_to(ROOT).as_posix()
        source = data.decode("utf-8-sig", errors="replace")
        entry = {"path": name, "bytes": len(data), "lines": len(source.splitlines()),
                 "sha256": hashlib.sha256(data).hexdigest()}
        files.append(entry)
        if path.suffix != ".py":
            continue
        try:
            tree = ast.parse(source)
        except SyntaxError as exc:
            errors.append({"file": name, "line": exc.lineno, "message": exc.msg})
            continue
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef):
                for statement in node.body:
                    if isinstance(statement, ast.Assign) and any(isinstance(t, ast.Name)
                            and t.id == "__tablename__" for t in statement.targets):
                        try:
                            table = ast.literal_eval(statement.value)
                        except (ValueError, TypeError):
                            continue
                        tables.append({"table": table, "class": node.name, "file": name, "line": node.lineno})
            if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue
            for decorator in node.decorator_list:
                if not isinstance(decorator, ast.Call) or not isinstance(decorator.func, ast.Attribute):
                    continue
                method = decorator.func.attr
                if method not in ("get", "post", "put", "patch", "delete", "head", "options", "api_route"):
                    continue
                if not decorator.args or not isinstance(decorator.args[0], ast.Constant):
                    continue
                routes.append({"file": name, "line": node.lineno, "method": method.upper(),
                    "declared_path": decorator.args[0].value, "function": node.name,
                    "router": ast.unparse(decorator.func.value)})
    versions = {}
    locked = re.findall(r"^([A-Za-z0-9_-]+)==([^\s\\]+)", (ROOT / "backend/requirements.lock").read_text(), re.M)
    for package, pinned in locked:
        try:
            installed = importlib.metadata.version(package)
        except importlib.metadata.PackageNotFoundError:
            installed = None
        versions[package] = {"locked": pinned, "local_installed": installed}
    result = {"timestamp_utc": datetime.now(timezone.utc).isoformat(), "files": files,
              "route_declarations": routes, "model_tables": tables, "syntax_errors": errors,
              "dependency_versions": versions,
              "git_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "git_status": subprocess.check_output(["git", "status", "--short", "--", "backend", "game/backend",
                  "game/platform", "game/persistence"], cwd=ROOT, text=True).splitlines()}
    (OUT / "inventory.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"files": len(files), "source_lines": sum(x["lines"] for x in files),
        "route_declarations": len(routes), "model_tables": len(tables), "syntax_errors": errors,
        "largest_runtime_python": sorted((x for x in files if x["path"].startswith("backend/bmt_backend/")
            and x["path"].endswith(".py")), key=lambda x: -x["lines"])[:12]}, indent=2))


if __name__ == "__main__":
    main()
