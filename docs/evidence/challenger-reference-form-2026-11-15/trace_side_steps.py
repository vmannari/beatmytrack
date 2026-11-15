from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
source=(OUT/'legacy_side_checks.py').read_text()
source=source.replace("track_metrics.append(","\n        if angles.max()>18:print('STEP_LOCATIONS',tier,offset,np.asarray(locations)[1:][step][angles>18].tolist(),flush=True)\n        track_metrics.append(")
(OUT/'trace_side_checks.py').write_text(source)
