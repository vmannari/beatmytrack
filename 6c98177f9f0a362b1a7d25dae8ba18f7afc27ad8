"""Public EUR catalogue reads using the existing metadata-only reader."""
import importlib.util
from pathlib import Path

OUT = Path(__file__).resolve().parent
source = OUT.parent / "backend-performance-review-2026-10-24/prices.py"
spec = importlib.util.spec_from_file_location("prior_price_reader", source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.OUT = OUT
module.main()
