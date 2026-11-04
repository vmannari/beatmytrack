"""Time public daily GETs without sign-in; retain timings and counts, never player rows."""
import argparse
import json
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlencode, urlsplit


def fetch(origin, path):
    with tempfile.TemporaryDirectory(prefix="bmt-daily-read-") as folder:
        body = Path(folder) / "body.json"
        headers = Path(folder) / "headers.txt"
        result = subprocess.run([
            "curl.exe", "--silent", "--show-error", "--max-time", "35",
            "--output", str(body), "--dump-header", str(headers),
            "--write-out", "%{json}", origin + "/v1" + path,
        ], capture_output=True, text=True, timeout=40, check=False)
        timing = json.loads(result.stdout) if result.stdout.strip() else {}
        try:
            data = json.loads(body.read_text(encoding="utf-8"))
        except (ValueError, FileNotFoundError):
            data = {}
        retained = {name: round(float(timing.get(name, 0)) * 1000, 3) for name in (
            "time_namelookup", "time_connect", "time_appconnect", "time_starttransfer", "time_total")}
        retained.update(status=timing.get("http_code", 0), bytes=timing.get("size_download", 0),
                        curl_exit=result.returncode, utc=datetime.now(timezone.utc).isoformat())
        for line in headers.read_text(encoding="utf-8").splitlines() if headers.exists() else []:
            name, _, value = line.partition(":")
            if name.lower() in ("retry-after", "x-request-id", "server-timing"):
                retained[name.lower()] = value.strip()
        for key in ("detail", "population", "generation", "limits_generation", "vehicle_id", "server_now"):
            if key in data:
                retained[key] = data[key]
        retained["items"] = len(data["items"]) if isinstance(data.get("items"), list) else None
        return retained, data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--rounds", type=int, default=3, choices=range(1, 6))
    args = parser.parse_args()
    origin = args.url.rstrip("/")
    parsed = urlsplit(origin)
    if parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path:
        parser.error("Use a bare origin without credentials, path, query or fragment")
    if parsed.scheme != "https" and not (parsed.scheme == "http" and parsed.hostname in ("localhost", "127.0.0.1")):
        parser.error("HTTPS or loopback HTTP required")
    report = {"origin": origin, "mode": "unauthenticated public GET only", "requests": []}

    def record(label, path):
        measurement, data = fetch(origin, path)
        row = {"label": label, **measurement}
        report["requests"].append(row)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(row), flush=True)
        return measurement, data

    measurement, daily = record("daily", "/track-of-the-day")
    if measurement["status"] != 200 or not isinstance(daily.get("track"), dict):
        raise SystemExit("Daily metadata unavailable; see recorded timings")
    report["day"] = daily["day"]
    report["version_id"] = daily["track"]["version_id"]
    for attempt in range(args.rounds):
        for car in ("compact", "electric", "forklift", "hovercraft", "kart"):
            params = {"day": daily["day"], "version_id": report["version_id"], "vehicle_id": car}
            _, limits = record(f"limits/{car}/{attempt}", "/track-of-the-day/limits?" + urlencode(params))
            record(f"standings/{car}/{attempt}", "/track-of-the-day/lap-standings?" + urlencode(
                {**params, "limit": 6, "around": "true"}))
            cutoffs = limits.get("cutoffs", [])
            if cutoffs:
                record(f"nearby/{car}/{attempt}", "/track-of-the-day/lap-standings?" + urlencode(
                    {**params, "limit": 7, "around": "true", "lap_ticks": cutoffs[0]["lap_ticks"]}))


if __name__ == "__main__":
    main()
