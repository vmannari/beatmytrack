from pathlib import Path
import importlib.util
import sys

EVIDENCE=Path(__file__).resolve().parent
ROOT=EVIDENCE.parents[3]
spec=importlib.util.spec_from_file_location('case',ROOT/'docs/evidence/mobile-performance-review-2026-11-06/run_case.py')
case=importlib.util.module_from_spec(spec)
spec.loader.exec_module(case)
case.OUT=EVIDENCE
case.ROOT=ROOT
case.main()
