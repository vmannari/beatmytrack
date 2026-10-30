"""Reuse the reviewed metadata/aggregate-only reader; never access SQL or secrets."""
import importlib.util
from pathlib import Path

OUT = Path(__file__).resolve().parent
source = OUT.parent / "backend-performance-review-2026-10-24/inspect_cloud.py"
spec = importlib.util.spec_from_file_location("prior_aggregate_reader", source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.OUT = OUT
module.main()
