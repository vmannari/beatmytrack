"""Copy only canonical verification inputs into a standalone Godot project.

Run from any working directory. No presentation assets/native music extension are
included; canonical game scripts are copied without modification.
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

SCRIPTS = {
    "editor": (
        "creator_catalog",
        "creator_objects",
        "creator_scenery",
        "road_pieces",
        "spline_road",
        "start_line",
        "surface_paint",
        "track_compiler",
        "track_document",
    ),
    "input": ("drive_frame", "route_driver", "profiled_route_driver"),
    "persistence": ("track_library",),
    "race": ("race_rules", "track_session", "rewind_history", "lap_telemetry", "personal_ghost_run"),
    "track": (
        "builtin_tracks",
        "bridge_elevation",
        "creator_bridges",
        "native_track",
        "playground_data",
        "road_edges",
        "road_kerbs",
        "snow_banks",
        "track_theme",
    ),
    "ui": ("handling_selection",),
    "vehicle": (
        "handling_config",
        "rally_handbrake",
        "launch_start",
        "light_props",
        "loose_tyres",
        "track_hazards",
        "vehicle_catalog",
        "vehicle_simulation",
        "vehicle_state",
    ),
}
PROFILES = (
    "stable",
    "balanced",
    "loose",
    "baseline",
    "original_slide",
    "compact_fun",
)


def stage(repo: Path, destination: Path) -> None:
    source = repo / "game"
    if destination.exists() and any(destination.iterdir()):
        raise ValueError("Destination must be absent or empty; existing files are never removed")
    files = [source / folder / (name + ".gd") for folder, names in SCRIPTS.items() for name in names]
    runners = [source / "backend" / name for name in ("runner.gd", "generate_fixture.gd", "generate_test_driver.gd")]
    files.extend(runners)
    # TrackTheme preloads this resource even in the headless canonical project.
    files.extend(source / "track" / name for name in ("storm_sky.tres", "storm_sky.gdshader"))
    files.extend(source / "resources" / (name + ".tres") for name in PROFILES)
    files.extend(sorted((source / "resources" / "cars").glob("*.tres")))
    files.extend(
        source / "resources" / name
        for name in (
            "builtin_tracks.json",
            "tracks/starter_circuit.json",
        )
    )
    for file in files:
        if not file.is_file():
            raise ValueError(f"Missing canonical source: {file}")
    destination.mkdir(parents=True, exist_ok=True)
    for file in files:
        output = destination / file.relative_to(source)
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(file, output)
        uid = Path(str(file) + ".uid")
        if uid.is_file():
            shutil.copyfile(uid, Path(str(output) + ".uid"))
    (destination / "project.godot").write_text(
        'config_version=5\n\n[application]\nconfig/name="Beat my track verifier"\n'
        '\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',
        encoding="utf-8",
    )
    shutil.copyfile(repo / "godot-version.txt", destination.parent / "godot-version.txt")
    print(f"Staged {len(files)} canonical inputs into {destination}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--destination", type=Path, required=True)
    arguments = parser.parse_args()
    stage(arguments.repo.resolve(), arguments.destination.resolve())
