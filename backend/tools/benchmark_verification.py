"""Compare real pinned-engine replay/proof costs without an API or player data."""
import argparse
import ctypes
import json
import os
import statistics
import sys
import time
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from bmt_backend.loadtest import rss_bytes
from bmt_backend.verifier import GodotVerifier


def cpu_seconds(pid):
    if os.name == "nt":
        from ctypes import wintypes
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = kernel.OpenProcess(0x1000, False, pid)
        if not handle:
            raise OSError(ctypes.get_last_error())
        try:
            values = [wintypes.FILETIME() for _ in range(4)]
            if not kernel.GetProcessTimes(handle, *[ctypes.byref(value) for value in values]):
                raise OSError(ctypes.get_last_error())
            return sum((value.dwHighDateTime << 32) + value.dwLowDateTime for value in values[2:]) / 10_000_000
        finally:
            kernel.CloseHandle(handle)
    fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
    return (int(fields[11]) + int(fields[12])) / os.sysconf("SC_CLK_TCK")


def measure(binary, project, fixture, proof, repeats):
    verifier = GodotVerifier(SimpleNamespace(godot_bin=binary, game_project=project,
        verifier_timeout_seconds=90, persistent_verifier=True, verifier_recycle_jobs=100))
    result = {}
    try:
        for mode in ["canonical", "movement-proof"]:
            replay = fixture["replay"] if mode == "canonical" else {**fixture["replay"], "race_proof": proof}
            started = time.perf_counter()
            verifier.verify_run(fixture["document"], replay, fixture["vehicle_id"])
            warmup = time.perf_counter() - started
            samples = []
            for _ in range(repeats):
                cpu = cpu_seconds(verifier.engine_pid)
                python_cpu = time.process_time()
                started = time.perf_counter()
                response = verifier.verify_run(fixture["document"], replay, fixture["vehicle_id"])
                elapsed = time.perf_counter() - started
                assert response["time_ticks"] == fixture["time_ticks"]
                assert response["lap_ticks"] == [2634, 2532, 2531, 2530, 2530]
                assert response["manifest"] == fixture["expected_manifest"]
                samples.append({"wall_seconds": elapsed, "engine_cpu_seconds": cpu_seconds(verifier.engine_pid)-cpu,
                    "python_cpu_seconds": time.process_time()-python_cpu, "engine_rss_bytes": rss_bytes(verifier.engine_pid),
                    "method": response.get("verification_method", "canonical-replay")})
            result[mode] = {"warmup_seconds": warmup, "samples": samples,
                "median_wall_seconds": statistics.median(row["wall_seconds"] for row in samples),
                "median_engine_cpu_seconds": statistics.median(row["engine_cpu_seconds"] for row in samples)}
    finally:
        verifier.close()
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--proof", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--repeats", type=int, default=5)
    args = parser.parse_args()
    if not 1 <= args.repeats <= 50:
        parser.error("Use 1 to 50 repeats")
    report = measure(args.godot, args.project, json.loads(args.fixture.read_text()),
                     json.loads(args.proof.read_text()), args.repeats)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2))
    for mode, data in report.items():
        print(f"{mode}: wall {data['median_wall_seconds']:.4f}s, engine CPU {data['median_engine_cpu_seconds']:.4f}s")
