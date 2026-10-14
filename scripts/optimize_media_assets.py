"""Offline, reproducible media audit/encoding. Never used by the game.

Audit with Windows Python; encode/review with the existing WSL music Python.
Original PCM and PNG masters remain intact. Only derived files are compressed.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import struct
import subprocess
import wave
import zlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/media-compression-2026-10-12"
FFMPEG = "/home/ville/.local/share/bmt-music-tools/ffmpeg"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit():
    OUT.mkdir(parents=True, exist_ok=True)
    if (OUT / "before-assets.json").exists():
        raise RuntimeError("Pre-task audit already exists; do not replace its baseline")
    records = []
    texts = {p.relative_to(ROOT).as_posix(): p.read_text(errors="replace")
             for p in (ROOT / "game").rglob("*")
             if p.suffix in (".gd", ".tscn", ".tres", ".gdshader", ".cfg")
             and ".godot" not in p.parts and "android" not in p.parts}
    for p in (ROOT / "game/assets").rglob("*"):
        if p.suffix not in (".png", ".wav", ".ogg"):
            continue
        row = {"path": p.relative_to(ROOT).as_posix(), "bytes": p.stat().st_size, "sha256": sha(p)}
        if p.suffix == ".png":
            row["dimensions"] = struct.unpack(">II", p.read_bytes()[16:24])
            # Stem matching also catches concatenated paths in VehicleCatalog.
            row["references"] = [name for name, text in texts.items() if p.stem in text]
        elif p.suffix == ".wav":
            with wave.open(str(p)) as w:
                row.update(frames=w.getnframes(), rate=w.getframerate(), channels=w.getnchannels(),
                           seconds=w.getnframes()/w.getframerate())
        imp = Path(str(p) + ".import")
        if imp.exists():
            row["imported"] = []
            for target in re.findall(r'"(res://\.godot/imported/[^\"]+)"', imp.read_text()):
                dest = ROOT / "game" / target.removeprefix("res://")
                if dest.exists() and not any(x["path"] == target for x in row["imported"]):
                    row["imported"].append({"path": target, "bytes": dest.stat().st_size,
                                            "deflated_bytes": len(zlib.compress(dest.read_bytes(), 6))})
        records.append(row)
    (OUT / "before-assets.json").write_text(json.dumps(records, indent=2) + "\n")
    for p in (ROOT / "game").rglob("*"):
        if p.suffix in (".gd", ".import", ".cfg") and ".godot" not in p.parts and "android" not in p.parts:
            dest = ROOT / "build/media-compression/before" / p.relative_to(ROOT)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, dest)
    print("Audited", len(records), "assets; saved pre-task source/import checkpoint")
    for r in records:
        if r["path"].endswith(".png"):
            print(r["path"], r["dimensions"], [s for s in r["references"] if "/tests/" not in s])


def encode():
    import numpy as np
    import soundfile as sf
    spec = json.loads((OUT / "audio-plan.json").read_text())
    reports = []
    for item in spec:
        source = ROOT / item["master"]
        target = ROOT / item["encoded"]
        x, rate = sf.read(source, always_2d=True)
        chosen = None
        attempts = []
        for quality in (8, 9, 10):
            subprocess.run([FFMPEG, "-v", "error", "-y", "-i", str(source), "-map_metadata", "-1",
                            "-c:a", "libvorbis", "-flags:a", "+bitexact", "-q:a", str(quality),
                            "-fflags", "+bitexact", str(target)], check=True)
            y, decoded_rate = sf.read(target, always_2d=True)
            n = len(x)
            assert decoded_rate == rate and y.shape == x.shape
            error = x-y
            snr = float(10*np.log10(np.mean(x*x)/max(np.mean(error*error), 1e-20)))
            rms_db = float(20*np.log10(np.sqrt(np.mean(y*y))/np.sqrt(np.mean(x*x))))
            seam = float(np.max(abs(y[0]-y[-1])))
            reference_step = float(np.quantile(abs(np.diff(x, axis=0)), .9995))
            # Measure broad spectral balance and short-time envelopes as well
            # as full-waveform error, so noisy beds are not judged by SNR alone.
            from scipy.signal import welch
            f, px = welch(x, rate, axis=0, nperseg=4096)
            _, py = welch(y, rate, axis=0, nperseg=4096)
            bands = []
            for lo, hi in [(0,200),(200,1000),(1000,4000),(4000,10000),(10000,20000)]:
                mask = (f>=lo)&(f<hi)
                a, b = px[mask].sum(), py[mask].sum()
                if a > px.sum()*1e-4:
                    bands.append(float(10*np.log10(max(b,1e-20)/a)))
            width = round(.05*rate)
            xa = x[:n//width*width].reshape(-1,width,x.shape[1])
            ya = y[:n//width*width].reshape(-1,width,x.shape[1])
            ex, ey = np.sqrt(np.mean(xa*xa,axis=(1,2))), np.sqrt(np.mean(ya*ya,axis=(1,2)))
            envelope_error = float(np.max(abs(20*np.log10(np.maximum(ey,1e-9)/np.maximum(ex,1e-9)))))
            stats = {"quality":quality,"snr_db":snr,"rms_change_db":rms_db,
                     "band_changes_db":bands,"envelope_max_change_db":envelope_error,
                     "peak":float(abs(y).max()),"seam_step":seam,
                     "seam_reference_step":reference_step,"frames":n,"rate":rate,
                     "channels":x.shape[1]}
            attempts.append(stats)
            if (snr >= 30 and abs(rms_db) < .15 and max(map(abs,bands)) < .75
                    and envelope_error < 1 and stats["peak"] < 1
                    and seam <= max(.008, reference_step*1.5)):
                chosen = dict(stats)
                break
        if chosen is None:
            raise RuntimeError(f"Compression quality gate failed: {source}: {attempts}")
        duration = len(x)/rate
        chosen.update(item, master_sha256=sha(source), encoded_sha256=sha(target),
                      master_bytes=source.stat().st_size, encoded_bytes=target.stat().st_size,
                      duration_seconds=duration, attempts=attempts)
        reports.append(chosen)
        (OUT / "audio-quality.json").write_text(json.dumps(reports, indent=2)+"\n")
        print(source.name, "q", chosen["quality"], "SNR", round(chosen["snr_db"],2),
              "MB", round(source.stat().st_size/1e6,2), "->", round(target.stat().st_size/1e6,2), flush=True)
    print("Compressed", len(reports), "loop masters with independent decode quality checks")
    manifest = ROOT / "game/assets/audio/compressed/manifest.json"
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps({"schema_version":1,"codec":"Ogg Vorbis",
                                   "entrypoint":"scripts/optimize_media_assets.py encode",
                                   "outputs":reports},indent=2)+"\n")


def review_textures():
    import numpy as np
    from scipy.ndimage import uniform_filter
    base = ROOT / "build/media-compression/textures"
    results = []
    changed = set(json.loads((OUT / "texture-plan.json").read_text()))
    for file in sorted((base / "after").glob("*.png")):
        folder, name = file.name.split("--", 1)
        source = base / "before" / file.name
        width, height = struct.unpack(">II", source.read_bytes()[16:24])
        assert struct.unpack(">II", file.read_bytes()[16:24]) == (width,height)
        def pixels(path):
            raw = subprocess.check_output([FFMPEG,"-v","error","-i",str(path),"-f","rawvideo",
                                           "-pix_fmt","rgba","-"])
            return np.frombuffer(raw,np.uint8).reshape(height,width,4).astype(float)
        a,b = pixels(source),pixels(file)
        visible = a[:,:,3]>0
        mse = float(np.mean((a[:,:,:3][visible]-b[:,:,:3][visible])**2))
        psnr = float(10*np.log10(255**2/max(mse,1e-20)))
        # Standard 11x11 luminance structural similarity, without extra deps.
        x = a[:,:,:3] @ np.array([.2126,.7152,.0722])
        y = b[:,:,:3] @ np.array([.2126,.7152,.0722])
        mx,my = uniform_filter(x,11),uniform_filter(y,11)
        vx,vy = uniform_filter(x*x,11)-mx*mx,uniform_filter(y*y,11)-my*my
        cov = uniform_filter(x*y,11)-mx*my
        sim=((2*mx*my+6.5025)*(2*cov+58.5225))/((mx*mx+my*my+6.5025)*(vx+vy+58.5225))
        path = f"game/assets/{folder}/{name}"
        row={"path":path,"psnr_db":psnr,"ssim":float(sim[visible].mean()),
             "dimensions":[width,height],"alpha_exact":bool(np.array_equal(a[:,:,3],b[:,:,3])),
             "pixels_exact":bool(np.array_equal(a,b)),"compressed":path in changed}
        row["passes"] = (psnr>=38 and row["ssim"]>=.98 and row["alpha_exact"]
                         if row["compressed"] else row["pixels_exact"])
        results.append(row)
        if row["compressed"]: print(name, "PSNR",round(psnr,2),"SSIM",round(row["ssim"],5),"PASS" if row["passes"] else "FAIL",flush=True)
    (OUT / "texture-quality.json").write_text(json.dumps(results,indent=2)+"\n")
    assert all(r["passes"] for r in results), "Inspect failed textures and raise quality before accepting"
    print("TEXTURE_REVIEW:",len(results),"images; dimensions/alpha preserved, data textures exact")


def verify_rebuild():
    records = json.loads((OUT / "audio-quality.json").read_text())
    scratch = ROOT / "build/media-compression/rebuild"
    scratch.mkdir(parents=True,exist_ok=True)
    for row in records:
        target = scratch / Path(row["encoded"]).name
        subprocess.run([FFMPEG,"-v","error","-y","-i",str(ROOT/row["master"]),
                        "-map_metadata","-1","-c:a","libvorbis","-flags:a","+bitexact",
                        "-q:a",str(row["quality"]),"-fflags","+bitexact",str(target)],check=True)
        assert sha(target)==row["encoded_sha256"], f"Non-repeatable encode: {target}"
    for row in json.loads((OUT / "before-assets.json").read_text()):
        path=ROOT/row["path"]
        if not path.exists():
            path=ROOT / "archive/artwork/retired-2026-10-12" / Path(row["path"]).relative_to("game/assets")
        assert sha(path)==row["sha256"], f"Master changed: {path}"
    print("REBUILD_VERIFICATION:",len(records),"encoded hashes exact; all original audio/art masters preserved")


def review_native():
    import numpy as np
    import soundfile as sf
    report=[]
    for file in sorted((OUT / "menu-native").glob("godot-wrap-*.wav")):
        x,rate=sf.read(file,always_2d=True)
        width=round(.05*rate)
        body=x[round(.15*rate):-round(.15*rate)]
        levels=np.array([np.sqrt(np.mean(body[i:i+width]**2)) for i in range(0,len(body)-width,width)])
        row={"file":file.name,"seconds":len(x)/rate,"peak":float(abs(x).max()),
             "minimum_50ms_rms_dbfs":float(20*np.log10(max(levels.min(),1e-12))),
             "maximum_step":float(abs(np.diff(body,axis=0)).max())}
        assert row["peak"]<1 and row["minimum_50ms_rms_dbfs"]>-50 and len(x)/rate>=6
        report.append(row)
    muted,_=sf.read(OUT/"menu-native/godot-muted.wav",always_2d=True)
    assert len(report)==2 and abs(muted).max()==0
    (OUT/"menu-native-quality.json").write_text(json.dumps({"wraps":report,"muted_peak":0,
        "review":"Technical native-output analysis; subjective owner/device listening remains pending"},indent=2)+"\n")
    print("NATIVE_MENU_REVIEW:",json.dumps(report),"mute exact zero")


def audit_package():
    package = ROOT / "build/android/circuit01-debug.apk"
    deployed = ROOT / "build/media-compression/deployed-before.apk"
    before = {r["path"]:r for r in json.loads((OUT/"before-assets.json").read_text())}
    plan = json.loads((OUT/"audio-plan.json").read_text())
    textures = json.loads((OUT/"texture-plan.json").read_text())
    retired = json.loads((OUT/"retired-artwork.json").read_text())
    inactive = json.loads((OUT/"excluded-inactive-audio.json").read_text())
    with zipfile.ZipFile(package) as archive:
        entries = {i.filename:i for i in archive.infolist()}
        excluded = [r["master"] for r in plan]+inactive+[r["removed_from_runtime"] for r in retired]
        for path in excluded:
            assert "assets/"+path.removeprefix("game/")+".remap" not in entries, f"Excluded source remap shipped: {path}"
            for i in before[path].get("imported",[]):
                assert "assets/"+i["path"].removeprefix("res://") not in entries, f"Excluded imported data shipped: {path}"
        def packed(path):
            imp=ROOT / (path+".import")
            targets=set(re.findall(r'"(res://\.godot/imported/[^\"]+)"',imp.read_text()))
            return sum(entries["assets/"+t.removeprefix("res://")].compress_size for t in targets)
        for row in plan:
            assert packed(row["encoded"])>0
        assert "assets/assets/audio/compressed/manifest.json" in entries
        assert "assets/assets/audio/compressed/NOTICE.txt" in entries
        with zipfile.ZipFile(deployed) as old:
            native_exact = all(old.read(k)==archive.read(k) for k in entries if k.startswith("lib/"))
        assert native_exact, "Engine/architecture libraries changed outside media scope"
        stats={"apk_bytes":package.stat().st_size,"apk_sha256":sha(package),
               "deployed_apk_bytes":deployed.stat().st_size,"deployed_apk_sha256":sha(deployed),
               "native_libraries_byte_identical":native_exact,
               "excluded_asset_count":len(excluded),"compressed_loop_count":len(plan),
               "texture_count":len(textures),"imported_audio_bytes":sum(packed(r["encoded"]) for r in plan),
               "imported_texture_bytes":sum(packed(p) for p in textures),
               "before_audio_deflated_bytes":sum(sum(i["deflated_bytes"] for i in before[r["master"]]["imported"]) for r in plan),
               "before_texture_deflated_bytes":sum(sum(i["deflated_bytes"] for i in before[p]["imported"]) for p in textures),
               "retired_art_deflated_bytes":sum(sum(i["deflated_bytes"] for i in before[r["removed_from_runtime"]]["imported"]) for r in retired),
               "inactive_audio_deflated_bytes":sum(sum(i["deflated_bytes"] for i in before[p]["imported"]) for p in inactive)}
        stats["estimated_same_source_media_savings_bytes"] = (stats["before_audio_deflated_bytes"]+stats["before_texture_deflated_bytes"]+
            stats["retired_art_deflated_bytes"]+stats["inactive_audio_deflated_bytes"]-
            stats["imported_audio_bytes"]-stats["imported_texture_bytes"])
        stats["deployed_to_local_build_reduction_bytes"]=stats["deployed_apk_bytes"]-stats["apk_bytes"]
        (OUT/"package-audit.json").write_text(json.dumps(stats,indent=2)+"\n")
        print("PACKAGE_AUDIT:",json.dumps(stats))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("audit", "encode", "review-textures", "verify-rebuild", "review-native", "audit-package"))
    args = parser.parse_args()
    {"audit":audit,"encode":encode,"review-textures":review_textures,
     "verify-rebuild":verify_rebuild,"review-native":review_native,"audit-package":audit_package}[args.action]()
