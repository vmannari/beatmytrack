from pathlib import Path
import os, sys, subprocess, time, json, re, hashlib

sys.stdout.reconfigure(encoding='utf-8')
ROOT = Path.cwd()
LAB = ROOT / 'build/re-audit-2026-10-27'
ENGINE = Path('C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe')
tests = [
    'test_script_parse', 'test_native_blend_memory', 'test_runtime_result_safety',
    'test_shared_resume_recovery', 'test_result_recording_limit',
    'test_pending_input_recovery', 'test_practice_save_recovery', 'test_app',
    'test_rewind', 'test_pause_menu', 'test_localization', 'test_client_quality',
    'test_graphics_settings', 'test_launch_start', 'test_garage_live_entry',
    'test_mobile_audit_fixes', 'test_statistics_request_reuse',
]
results = []
for name in tests:
    original = ROOT / 'game/tests' / (name + '.gd')
    source = original.read_text(encoding='utf-8')
    # Preserve all assertions and fixture reads. Redirect only known output roots.
    output = 'res://../build/re-audit-2026-10-27/outputs/' + name
    for old in [
        'res://../docs/evidence/runtime-correctness-2026-10-26',
        'res://../docs/evidence/storm-test-recovery-2026-10-26',
        'res://../docs/evidence/pause-menu',
        'res://../docs/evidence/graphics-settings-2026-10-22',
        'res://../docs/evidence/statistics-request-reuse-2026-10-26',
        'res://../build/studio-monitor-2026-10-12/client-test',
        'res://../build/garage-live-entry',
        'res://../build/mobile-audit-fixes-2026-10-26',
    ]:
        source = source.replace(old, output)
    setup = '''
	print("AUDIT_PID ",OS.get_process_id())
	var audit_config := ConfigFile.new()
	audit_config.set_value("backend","url","")
	assert(audit_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")
'''
    assert 'func run() -> void:' in source, name
    source = source.replace('func run() -> void:', 'func run() -> void:' + setup, 1)
    script = LAB / 'checks' / (name + '.gd')
    script.parent.mkdir(parents=True, exist_ok=True)
    script.write_text(source, encoding='utf-8', newline='\n')
    profile = LAB / 'profiles' / name
    profile.mkdir(parents=True, exist_ok=True)
    (LAB / 'outputs' / name).mkdir(parents=True, exist_ok=True)
    env = {k:v for k,v in os.environ.items() if not k.startswith('BMT_')}
    env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile), PYTHONIOENCODING='utf-8')
    command = [str(ENGINE), '--headless', '--audio-driver', 'Dummy', '--path', str(ROOT/'game'), '--script', str(script)]
    log = LAB / (name + '.log')
    began = time.monotonic()
    with log.open('wb') as output_log:
        process = subprocess.Popen(command, env=env, stdout=output_log, stderr=subprocess.STDOUT)
        try:
            code = process.wait(timeout=600)
            timeout = False
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            code, timeout = process.returncode, True
    text = log.read_text(encoding='utf-8', errors='replace')
    summary = [line for line in text.splitlines() if re.search(r'(RESULT|checks|SCRIPT_PARSE|failures|FAIL|ERROR:|WARNING:)', line)]
    row = dict(test=name, exit_code=code, timed_out=timeout, seconds=round(time.monotonic()-began,3),
               original_sha256=hashlib.sha256(original.read_bytes()).hexdigest(),
               probe_sha256=hashlib.sha256(script.read_bytes()).hexdigest(),
               errors=[x for x in summary if any(s in x for s in ['SCRIPT ERROR', 'FAIL', 'leaked', 'ERROR:'])],
               summary=summary[-10:])
    results.append(row)
    (LAB/'client-results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
    print(json.dumps({'test':name,'exit':code,'seconds':row['seconds'],'summary':summary[-3:]},ensure_ascii=False),flush=True)
