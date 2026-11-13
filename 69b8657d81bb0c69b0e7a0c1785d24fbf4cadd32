from pathlib import Path
p=Path(__file__).resolve().parent
old=p.parent/'shader-usage-2026-11-06'
(p/'freeze_project.py').write_text((old/'freeze_project.py').read_text().replace('shader-usage-20261106','biome-shader-profiles-20261106'))
s=(old/'run_check.py').read_text().replace('shader-usage-20261106','biome-shader-profiles-20261106')
s=s.replace("p.add_argument('--native', action='store_true')", "p.add_argument('--native', action='store_true')\np.add_argument('--engine', default='C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe')")
s=s.replace("'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe', '--path'", "args.engine, '--path'")
s=s.replace("receipt = dict(command=command, profile=str(profile), before=hashes())", "receipt = dict(command=command, engine_sha256=hashlib.sha256(Path(args.engine).read_bytes()).hexdigest(), profile=str(profile), before=hashes())")
s=s.replace("paths.append(project/'project.godot')", "paths.append(project/'project.godot')\n    paths.append(project/'rendering/biome_shader_profiles.json')")
(p/'run_check.py').write_text(s)
