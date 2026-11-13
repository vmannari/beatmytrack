"""Construct routers and model metadata locally, without opening a database."""
import inspect
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend"))
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.db import Base
from fastapi.routing import iter_route_contexts

OUT = Path(__file__).resolve().parent
result = {}
for role in ("api", "admin"):
    app = create_app(Settings(environment="test", workload_role=role, database_url="sqlite://",
        object_dir=str(ROOT / "build/backend-comprehensive-audit-2026-10-26/inventory-objects")))
    routes = []
    for context in iter_route_contexts(app.routes):
        route = context.route
        endpoint = getattr(route, "endpoint", None)
        path = getattr(context, "path", getattr(route, "path", ""))
        if not path:
            path = str(context)
        try:
            source = str(Path(inspect.getsourcefile(endpoint)).resolve().relative_to(ROOT)).replace("\\", "/")
            line = inspect.getsourcelines(endpoint)[1]
        except (TypeError, ValueError, OSError):
            source, line = None, None
        routes.append({"path": path, "methods": sorted(getattr(route, "methods", [])),
            "function": getattr(endpoint, "__name__", None), "source": source, "line": line})
    result[role] = routes
    app.state.engine.dispose()
result["tables"] = [{"name": table.name, "columns": [c.name for c in table.columns],
    "indexes": [{"name": i.name, "columns": [str(e) for e in i.expressions]} for i in table.indexes]}
    for table in Base.metadata.sorted_tables]
(OUT / "runtime-inventory.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"api_routes": len(result["api"]), "admin_routes": len(result["admin"]),
    "model_tables": len(result["tables"]), "billing": {role: [r for r in result[role] if "/billing/" in r["path"]]
        for role in ("api", "admin")}}, indent=2))
