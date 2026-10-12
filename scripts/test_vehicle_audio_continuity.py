"""Check the decoded bank and actual Godot captures for dropouts, including loop seams."""
from pathlib import Path
import argparse
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    with wave.open(str(path)) as handle:
        rate = handle.getframerate()
        channels = handle.getnchannels()
        assert handle.getsampwidth()==2, path.name+": expected 16-bit master"
        values = np.frombuffer(handle.readframes(handle.getnframes()),dtype="<i2").astype(np.float64)/32768.0
    return values.reshape(-1,channels),rate


def measure(values, rate):
    width = round(rate*.02)
    hop = round(rate*.01)
    rms = np.array([np.sqrt(np.mean(values[i:i+width]**2)) for i in range(0,len(values)-width+1,hop)])
    floor = max(.0003,float(np.median(rms))*.04)
    low = rms<floor
    longest = count = 0
    for flag in low:
        count = count+1 if flag else 0
        longest = max(count,longest)
    return {"rms_min":float(rms.min()),"rms_median":float(np.median(rms)),"floor":floor,"dropout_windows":int(low.sum()),"maximum_dropout_ms":longest*10,"peak":float(np.max(np.abs(values)))}


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument("--captures",type=Path)
    parser.add_argument("--report",type=Path)
    args = parser.parse_args()
    manifest = json.loads((ROOT/"game/assets/audio/vehicles/manifest.json").read_text(encoding="utf-8"))
    report = {"bank":[],"captures":[],"failures":[]}
    for clip in manifest["outputs"]:
        if not clip["loop"]: continue
        values,rate = read(ROOT/"game/assets/audio/vehicles"/clip["file"])
        # Three repetitions include both wrap boundaries, not only the original clip.
        stats = measure(np.tile(values,(3,1)),rate)
        steps = np.abs(np.diff(values,axis=0))
        seam_step = float(np.max(np.abs(values[0]-values[-1])))
        reference_step = float(np.quantile(steps,.9995))
        stats.update(seam_step=seam_step,reference_step=reference_step)
        report["bank"].append({"file":clip["file"],**stats})
        if stats["dropout_windows"]: report["failures"].append(clip["file"]+": embedded gap or loop dropout")
        if seam_step>reference_step*1.5+2/32768:
            report["failures"].append(clip["file"]+": discontinuous wrap boundary")
    if args.captures:
        captures = sorted(args.captures.glob("*-continuous.wav"))
        assert len(captures)==5, "Expected all five continuous Godot engine captures"
        for path in captures:
            values,rate = read(path)
            for label,start,end in [("idle",.5,2.9),("steady revs",4.5,9.9),("lift-off",10.2,10.8)]:
                stats = measure(values[round(start*rate):round(end*rate)],rate)
                report["captures"].append({"file":path.name,"segment":label,**stats})
                if stats["dropout_windows"]: report["failures"].append(path.name+": "+label+" dropout")
            if np.max(np.abs(values))>=.95: report["failures"].append(path.name+": clipped capture")
            if np.max(np.abs(values[-rate//2:]))!=0: report["failures"].append(path.name+": pause tail is not silent")
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print("AUDIO_CONTINUITY:",len(report["bank"]),"looped assets;",len(report["captures"]),"captured segments;",len(report["failures"]),"failures")
    for failure in report["failures"]: print("FAIL:",failure)
    return 1 if report["failures"] else 0


if __name__=="__main__": raise SystemExit(run())
