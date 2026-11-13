from pathlib import Path
import sys
root=Path(__file__).resolve().parents[3]
script=root/'scripts/prepare_challenger.py'
sys.argv=['fit_only.py','--',str(root/'art_sources/challenger_hellcat_v1/source-panels.npz'),str(root/'art_sources/challenger_hellcat_v1/components.npz'),str(root/'build/challenger-surface-joins-2026-11-12/converted')]
exec(compile(script.read_text().split('for simple in [False,True]:')[0],str(script),'exec'),{'__file__':str(script)})
