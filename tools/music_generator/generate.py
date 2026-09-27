#!/usr/bin/env python3
"""Offline MRT 2.0.3 adapter. Explicit outputs; no scanning or shared CLI output.

The public Python API allows one loaded model per batch and explicit Waveform.write.
Generation RNG is fixed internally by upstream; style_seed controls ONLY the text
mapper. Neither family labels nor equal seeds guarantee compatible arrangements.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.metadata as metadata
import json
import math
import os
from pathlib import Path
import re
import sys
import time
import uuid
import yaml

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build/music"

def safe_name(value):
    name = re.sub(r"[^a-z0-9]+", "_", str(value).lower()).strip("_")
    if not name:
        raise ValueError("Name needs at least one ASCII letter or digit")
    return name

def atomic_json(path, data):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, indent=2, allow_nan=False), encoding="utf-8")
    temporary.replace(path)

def prepare_jobs(cfg, command, limit=None, names=None):
    if not isinstance(cfg, dict):
        raise ValueError("Configuration must be a mapping")
    model = cfg.get("model", "mrt2_base")
    if model not in ("mrt2_base", "mrt2_small"):
        raise ValueError("Unsupported model")
    output = (ROOT / cfg.get("output_dir", "build/music/raw")).resolve()
    if not output.is_relative_to(BUILD.resolve()):
        raise ValueError("Generation output must be beneath build/music")
    if limit is not None and limit < 1:
        raise ValueError("--limit must be positive")
    variants = cfg.get("variants_per_state", 1) if command == "layers" else 1
    if not isinstance(variants, int) or not 1 <= variants <= 10:
        raise ValueError("variants_per_state must be 1..10")
    prefix = [cfg.get("identity", ""), *cfg.get("global_positive", [])]
    if cfg.get("global_negative"):
        prefix.append("Avoid: " + ", ".join(cfg["global_negative"]))
    jobs, used = [], set()
    items = cfg.get("states" if command == "layers" else "concepts", [])
    for index, item in enumerate(items):
        name = safe_name(item["name"])
        if name in used:
            raise ValueError("Duplicate normalized name: " + name)
        used.add(name)
        if names and name not in names:
            continue
        duration = float(item.get("duration", cfg.get("duration", 24)))
        if not math.isfinite(duration) or not 0.04 <= duration <= 120:
            raise ValueError("Duration must be finite and 0.04..120 seconds")
        if not isinstance(item.get("prompt"), str) or not item["prompt"].strip():
            raise ValueError("Non-empty prompt required")
        for variant in range(1, variants + 1):
            # MusicCoCa 2.0.3 keeps only 127 text tokens. Distinguishing musical
            # directions must precede the shared identity and palette.
            prompt = ". ".join(p.strip() for p in [item["prompt"], *prefix] if p.strip())
            jobs.append({"name": name, "variant": variant, "prompt": prompt,
                "duration_requested": duration, "frames": round(duration * 25),
                "style_seed": variant - 1, "state_index": index if command == "layers" else None,
                "family": cfg.get("composition_family", name), "kind": "arrangement",
                "alignment": "unverified", "model": model})
    if names and set(names) - used:
        raise ValueError("Unknown names: " + str(set(names) - used))
    if not jobs:
        raise ValueError("No generation jobs")
    return output, jobs[:limit] if limit else jobs

def audio_metrics(path):
    import numpy as np
    import soundfile as sf
    data, rate = sf.read(path, always_2d=True)
    if not data.size or not np.isfinite(data).all():
        raise ValueError("Empty/non-finite audio")
    peak = float(np.max(np.abs(data)))
    rms = float(np.sqrt(np.mean(data * data)))
    if rms < 1e-6:
        raise ValueError("Silent output")
    return {"sample_rate": rate, "channels": data.shape[1], "samples": len(data),
        "duration": len(data) / rate, "peak": peak, "rms": rms,
        "near_full_scale_samples": int(np.count_nonzero(np.abs(data) >= 0.999)),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

def condition_jobs(jobs):
    import sentencepiece
    from magenta_rt import musiccoca, paths
    vocabulary = sentencepiece.SentencePieceProcessor(model_file=str(paths.musiccoca_dir() / 'spm.model'))
    style = musiccoca.MusicCoCa()
    embeddings, seen = [], set()
    for job in jobs:
        full = job['prompt']
        tokens = vocabulary.encode(full.lower())
        # Decode/re-encode until the exact text we save also fits the encoder.
        effective = vocabulary.decode(tokens[:127])
        while len(vocabulary.encode(effective)) > 127:
            effective = vocabulary.decode(vocabulary.encode(effective)[:126])
        job.update(full_prompt=full, prompt=effective, full_prompt_tokens=len(tokens),
                   prompt_truncated=len(tokens) > 127)
        embedding = style.embed(effective, use_mapper=True, seed=job['style_seed'])
        codes = style.tokenize(embedding).tolist()
        if tuple(codes) in seen:
            raise ValueError('Duplicate MusicCoCa conditioning: revise prompt/variant seed before generating ' + job['name'])
        seen.add(tuple(codes))
        job['conditioning_tokens'] = codes
        embeddings.append(embedding)
    return style, embeddings

def generate(cfg, command, limit=None, names=None):
    output, jobs = prepare_jobs(cfg, command, limit, names)
    output.mkdir(parents=True, exist_ok=True)
    run = output / (time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8])
    run.mkdir()
    manifest = {"schema": "bmt-music-generation-1", "status": "starting", "jobs": jobs,
        "generation_seed": "Upstream internal fixed RNG; not configurable in 2.0.3",
        "approval": "unreviewed", "config": cfg}
    atomic_json(run / "manifest.json", manifest)
    try:
        if metadata.version("magenta-rt") != "2.0.3":
            raise RuntimeError("Adapter validated only for magenta-rt 2.0.3")
        import jax
        from magenta_rt import MagentaRT2Jax
        from magenta_rt.config import MUSICCOCA
        assert any(d.platform == "gpu" for d in jax.devices()), "CUDA GPU not detected"
        manifest["versions"] = {p: metadata.version(p) for p in ("magenta-rt", "jax", "jaxlib", "PyYAML")}
        manifest["devices"] = [str(d) for d in jax.devices()]
        manifest["parameters"] = {"temperature": 1.3, "top_k": 40,
            "cfg_musiccoca": 3.0, "cfg_notes": 1.0, "cfg_drums": 1.0}
        manifest["status"] = "loading_model"
        atomic_json(run / "manifest.json", manifest)
        print("RUN " + str(run), flush=True)
        style, embeddings = condition_jobs(jobs)
        atomic_json(run / "manifest.json", manifest)
        model = MagentaRT2Jax(size=jobs[0]["model"], style_model=style, temperature=1.3, top_k=40,
            cfg_scales={"musiccoca": 3.0, "notes": 1.0, "drums": 1.0})
        seen_audio = set()
        for job, embedding in zip(jobs, embeddings):
            job["status"] = "generating"
            manifest["status"] = "generating"
            atomic_json(run / "manifest.json", manifest)
            print("GENERATING " + job["name"], flush=True)
            started = time.monotonic()
            wav, _ = model.generate(conditioning={MUSICCOCA.key: embedding}, frames=job["frames"], state=None)
            path = run / f'{job["name"]}__v{job["variant"]:02d}.wav'
            wav.write(str(path))
            job["metrics"] = audio_metrics(path)
            if job['metrics']['sha256'] in seen_audio:
                raise ValueError('Duplicate generated audio: ' + job['name'])
            seen_audio.add(job['metrics']['sha256'])
            if abs(job["metrics"]["duration"] - job["frames"] / 25) > .001:
                raise ValueError("Generated duration mismatch")
            job.update(file=path.name, status="complete", elapsed_seconds=round(time.monotonic()-started, 2))
            atomic_json(run / "manifest.json", manifest)
            print("COMPLETE " + str(path), flush=True)
        manifest["status"] = "complete"
    except BaseException as error:
        manifest["status"] = "failed"
        manifest["error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        atomic_json(run / "manifest.json", manifest)
    return run

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["concepts", "layers"])
    parser.add_argument("--config", required=True)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--names", nargs="+")
    parser.add_argument("--variants", type=int, help="Override variants per state for a small audition batch")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    cfg = yaml.safe_load((ROOT / args.config).read_text(encoding="utf-8"))
    if args.variants is not None:
        cfg['variants_per_state'] = args.variants
    if args.dry_run:
        output, jobs = prepare_jobs(cfg, args.command, args.limit, args.names)
        print(json.dumps({"output": str(output), "jobs": jobs}, indent=2))
    else:
        generate(cfg, args.command, args.limit, args.names)

if __name__ == "__main__":
    main()
