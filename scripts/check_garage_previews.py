"""Reject stale/missing packaged native Garage previews before export."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def check():
    folder = ROOT / 'game/assets/garage/previews_v1'
    provenance = json.loads((folder / 'provenance.json').read_text(encoding='utf-8'))
    catalog = (ROOT / 'game/vehicle/vehicle_catalog.gd').read_text(encoding='utf-8')
    match = re.search(r'const IDS: Array\[String\] = \[([^\]]+)\]', catalog)
    if not match:
        raise ValueError('Cannot read active vehicle IDs from VehicleCatalog')
    expected = set(re.findall(r'"([^"]+)"', match.group(1)))
    if set(provenance['hashes']) != expected:
        raise ValueError('Native default previews must match the active vehicle catalog')
    if not provenance['sources']:
        raise ValueError('Native preview source manifest is required')
    for file, digest in provenance['sources'].items():
        if hashlib.sha256((ROOT / file).read_bytes()).hexdigest() != digest:
            raise ValueError(f'Stale Garage preview: {file}; rerun scripts/bake_garage_previews.gd')
    for vehicle, digest in provenance['hashes'].items():
        if hashlib.sha256((folder / f'{vehicle}.png').read_bytes()).hexdigest() != digest:
            raise ValueError(f'Changed Garage preview: {vehicle}')
    print(f'GARAGE_PREVIEWS: {len(expected)} exact native images, {len(provenance["sources"])} current source hashes')


if __name__ == '__main__':
    check()
