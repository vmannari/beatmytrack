"""Offline loop preparation for the owner-selected menu recording; no generation.

Run using the existing WSL music Python environment after decoding the MP3 to
build/menu-exploration-source.wav with local FFmpeg at 44100 Hz, float PCM.
"""
from pathlib import Path
import hashlib
import json
import argparse
import numpy as np
import soundfile as sf
from scipy.signal import stft, correlate, find_peaks

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "archive/music/menu-exploration-2026-10-11/Exploration 3_take-3.mp3"
OUT = ROOT / "game/assets/audio/menu_exploration_v1"
EVIDENCE = ROOT / "docs/evidence/menu-exploration-2026-10-11"
parser = argparse.ArgumentParser()
parser.add_argument("--analyze", action="store_true")
parser.add_argument("--review-native", action="store_true")
args = parser.parse_args()
if args.review_native:
    report = {"captures": [], "listening": "Technical PCM analysis only"}
    for path in sorted(EVIDENCE.glob("godot-wrap-*.wav")):
        values, capture_rate = sf.read(path, always_2d=True)
        # Exclude recording activation edges, check every 50ms throughout wrap.
        body = values[round(.15*capture_rate):-round(.15*capture_rate)]
        window = round(.05*capture_rate)
        rms = np.array([np.sqrt(np.mean(body[i:i+window]**2))
                        for i in range(0, len(body)-window, window)])
        row = {"file": path.name, "seconds": len(values)/capture_rate,
               "peak": float(abs(values).max()), "minimum_50ms_rms_dbfs": float(20*np.log10(max(rms.min(), 1e-12))),
               "minimum_window_seconds": .15+float(np.argmin(rms))*.05,
               "maximum_sample_step": float(abs(np.diff(body, axis=0)).max())}
        print(json.dumps(row))
        assert row["minimum_50ms_rms_dbfs"] > -50 and row["peak"] < 1.0
        report["captures"].append(row)
    muted, _ = sf.read(EVIDENCE / "godot-muted.wav", always_2d=True)
    assert abs(muted).max() == 0 and len(report["captures"]) == 2
    report["muted_peak"] = float(abs(muted).max())
    (EVIDENCE / "native-audio-review.json").write_text(json.dumps(report, indent=2)+"\n")
    print(json.dumps(report, indent=2))
    raise SystemExit()
pcm, rate = sf.read(ROOT / "build/menu-exploration-source.wav", always_2d=True)
assert rate == 44100 and pcm.shape[1] == 2 and np.isfinite(pcm).all()
mono = pcm.mean(axis=1)
freq, times, spectrum = stft(mono, rate, nperseg=2048, noverlap=1536)
mag = abs(spectrum)
flux = np.maximum(np.diff(mag, axis=1), 0).sum(axis=0)
frame_rate = rate / 512
ac = correlate(flux - flux.mean(), flux - flux.mean(), mode="full", method="fft")[len(flux)-1:]
lo, hi = round(frame_rate * 60 / 180), round(frame_rate * 60 / 70)
peaks, _ = find_peaks(ac[lo:hi])
tempo_candidates = sorted([(float(ac[p+lo]), 60*frame_rate/(p+lo)) for p in peaks], reverse=True)[:5]
summary = {"rate": rate, "frames": len(pcm), "seconds": len(pcm)/rate,
           "peak": float(abs(pcm).max()), "rms": float(np.sqrt(np.mean(pcm**2))),
           "tempo_candidates_analysis_only": [round(v[1], 3) for v in tempo_candidates],
           "two_second_rms": [round(float(np.sqrt(np.mean(pcm[i:i+2*rate]**2))), 5)
                              for i in range(0, len(pcm), 2*rate)]}
if args.analyze:
    print(json.dumps(summary, indent=2))
    raise SystemExit()

# Remove the recorded fade-out, then choose an overlap near the ending whose
# spectral colour and onset envelope most closely match the opening. This is a
# technical alignment heuristic, not evidence of musical/listening acceptance.
overlap_seconds = 2.0
nominal = round(overlap_seconds * rate)
radius = round(.005 * rate)
nearby_steps = abs(pcm[nominal-radius:nominal+radius]-pcm[nominal-radius-1:nominal+radius-1]).max(axis=1)
overlap = nominal-radius+int(np.argmin(nearby_steps))
overlap_seconds = overlap/rate
head_mask = (times >= 0) & (times < overlap_seconds)
head_colour = np.sqrt(np.mean(mag[:, head_mask]**2, axis=1))
head_flux = flux[:round(overlap_seconds*frame_rate)]
candidates = []
for end in np.arange(112, 116, 1/frame_rate):
    mask = (times >= end-overlap_seconds) & (times < end)
    colour = np.sqrt(np.mean(mag[:, mask]**2, axis=1))
    similarity = float(np.dot(head_colour, colour)/(np.linalg.norm(head_colour)*np.linalg.norm(colour)))
    start_index = round((end-overlap_seconds)*frame_rate)
    tail_flux = flux[start_index:start_index+len(head_flux)]
    onset_match = float(np.corrcoef(head_flux, tail_flux)[0, 1])
    candidates.append((similarity+.5*onset_match, end, similarity, onset_match))
score, end_seconds, colour_match, onset_match = max(candidates)
end_frame = round(end_seconds*rate)
pcm = pcm[:end_frame]
# Begin after the overlap, play through the body, then blend into the opening.
# Constant-sum smooth weights avoid a +3 dB hump on correlated musical material.
t = np.linspace(0, 1, overlap, endpoint=True)
weight = (0.5 - 0.5*np.cos(np.pi*t))[:, None]
bridge = pcm[-overlap:]*(1-weight) + pcm[:overlap]*weight
loop = np.concatenate([pcm[overlap:-overlap], bridge])
# Retain dynamics/timbre; lower uniformly only if needed for 3 dB headroom.
gain = min(1.0, 10**(-3/20)/float(abs(loop).max()))
loop *= gain
OUT.mkdir(parents=True, exist_ok=True)
EVIDENCE.mkdir(parents=True, exist_ok=True)
export = OUT / "exploration_menu_loop.wav"
sf.write(export, loop, rate, subtype="PCM_16")
encoded, _ = sf.read(export, always_2d=True)
preview = np.concatenate([encoded[-4*rate:], encoded[:5*rate]])
sf.write(EVIDENCE / "loop-transition.wav", preview, rate, subtype="PCM_16")
sf.write(EVIDENCE / "two-loops.wav", np.tile(encoded, (2, 1)), rate, subtype="PCM_16")
seam = float(abs(encoded[0]-encoded[-1]).max())
local = np.concatenate([encoded[-rate:], encoded[:rate]])
steps = abs(np.diff(local, axis=0))
metrics = {"frames": len(encoded), "duration_seconds": len(encoded)/rate,
           "sample_rate_hz": rate, "channels": 2, "format": "PCM_16",
           "peak_dbfs": float(20*np.log10(abs(encoded).max())),
           "rms_dbfs": float(20*np.log10(np.sqrt(np.mean(encoded**2)))),
           "seam_delta": seam, "local_step_99_percentile": float(np.quantile(steps, .99)),
           "mono_rms_ratio": float(np.sqrt(np.mean(encoded.mean(axis=1)**2))/np.sqrt(np.mean(encoded**2))),
           "gain": gain, "overlap_seconds": overlap/rate,
           "source_end_seconds": end_frame/rate, "colour_match": colour_match,
           "onset_envelope_correlation": onset_match}
assert seam < .008 and abs(encoded).max() < .709
assert metrics["mono_rms_ratio"] > .5
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
manifest = {"schema_version": 1, "asset_id": "menu-exploration-v1",
            "status": "owner-selected source; loop listening pending", "created_at": "2026-10-11",
            "source_type": "edited",
            "generator": {"tool": "local FFmpeg decode; NumPy/SciPy/SoundFile loop export",
                          "tool_version": {"numpy": np.__version__, "soundfile": sf.__version__},
                          "model": None, "command_or_entrypoint": "scripts/prepare_menu_exploration.py"},
            "input_sources": [{"path_or_uri": str(SOURCE.relative_to(ROOT)), "role": "complete mix",
                               "origin": "MP3 supplied by owner", "sha256": digest(SOURCE),
                               "license_or_terms": "Owner authorizes local menu integration. Original creator/provider and distribution license were not supplied."}],
            "output": {"path": str(export.relative_to(ROOT)), "sha256": digest(export), **metrics},
            "modifications": ["Resample decoded stereo to 44100 Hz", "Trim recorded fade-out; select ending overlap using spectral/onset similarity", "Two-second constant-sum cosine cyclic overlap; playback starts at source 2s", "Uniform headroom reduction only when needed", "16-bit stereo PCM export; existing runtime cyclic interpolation guard"],
            "licensing": {"model_license": "No model used for this edit", "output_terms_reviewed": False,
                          "external_source_licenses": [], "commercial_use_status": "unverified owner-supplied recording"},
            "approval": {"user_approved": True, "scope": ["use supplied recording as menu background music", "prepare loop"],
                         "date": "2026-10-11", "edited_loop_listening_approved": False}}
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n")
(EVIDENCE / "audio-analysis.json").write_text(json.dumps({"source": summary, "loop": metrics,
    "listening": "Technical analysis only; no subjective listening claimed"}, indent=2)+"\n")
print(json.dumps(metrics, indent=2))
