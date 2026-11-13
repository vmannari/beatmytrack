"""Extract sleeve/torso/leg authoring regions before the existing cloth union.

Uses the supplied CC-BY source and the established control-fitted pose. The
native baker uses these regions to keep the lap separate from nearby sleeves.
"""
from pathlib import Path
import sys
import numpy as np
import prepare_kart_driver as author

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "build/kart-driver-polish-2026-11-12"
UNION = author.union_cloth


class Captured(Exception):
    pass


def capture(parts, **_):
    # prepare_kart_driver emits sleeves 6/7/9/10, torso 11/13, then legs/belt.
    rows = [np.c_[vertices, np.full(len(vertices), 0 if index < 4 else 1)]
            for index, (vertices, _) in enumerate(parts)]
    assert len(parts) == 11
    points = np.concatenate(rows).astype("<f4")
    (WORK / "cloth-regions.bin").write_bytes(points.tobytes())
    vertices, faces = UNION(parts[4:])
    from kart_driver_geometry import normals
    (WORK / "body-vertices.bin").write_bytes(vertices.astype("<f4").tobytes())
    (WORK / "body-normals.bin").write_bytes(normals(vertices, faces).astype("<f4").tobytes())
    (WORK / "body-indices.bin").write_bytes(faces.astype("<i4").tobytes())
    print(f"Captured {len(points)} original garment samples in {len(parts)} regions")
    raise Captured()


if __name__ == "__main__":
    WORK.mkdir(parents=True, exist_ok=True)
    author.union_cloth = capture
    sys.argv = [sys.argv[0], str(ROOT / "docs/evidence/kart-tomkart-driver-2026-11-08/source/race_car_driver_-_low_poly.zip"),
                "--output", str(WORK / "binding-source/candidate")]
    try:
        author.main()
    except Captured:
        pass
