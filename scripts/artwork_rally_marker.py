"""Refresh catalogue and header pictures after the prepared model rebuild."""
import subprocess
import sys
import run_rally_marker as task
import refresh_car_10k_assets as refresh

refresh.OUT, refresh.WORK, refresh.run = task.OUT, task.WORK, task.runner.run
refresh.checked('pictures', 'res://../scripts/bake_garage_previews.gd', '--rendering-method', 'gl_compatibility', '--',
                *['--exclude-vehicle='+car for car in ('kart','forklift','electric','hovercraft')])
subprocess.run([sys.executable, 'scripts/check_garage_previews.py', '--vehicles=compact,super_rally'], cwd=task.ROOT, check=True)
refresh.checked('header-picture', 'res://tests/bake_rally_lamp_style_header.gd', '--rendering-method', 'gl_compatibility', '--',
                '--evidence-root=res://../docs/evidence/rally-marker-2026-11-15')
subprocess.run([sys.executable, 'scripts/import_rally_marker_images.py'], cwd=task.ROOT, check=True)
refresh.identity('identity-final')
refresh.checked('prepared-final', 'res://tests/check_prepared_assets.gd', '--headless', '--',
                *['--exclude-vehicle='+car for car in ('kart','forklift','electric','hovercraft')])
