from pathlib import Path
import os, subprocess, sys
root = Path.cwd()
out = root / 'docs/evidence/results-home-2026-11-02'
out.mkdir(parents=True, exist_ok=True)
profile = root / 'build/results-home-2026-11-02/profile'
profile.mkdir(parents=True, exist_ok=True)
source = (root / 'game/tests/test_results_footer_fit.gd').read_text(encoding='utf-8')
source = source.replace('Vector2i(1600,720)]', 'Vector2i(1600,720),Vector2i(1280,1400)]')
source = source.replace('res://../docs/evidence/results-footer-2026-11-02', 'res://../docs/evidence/results-home-2026-11-02')
source = source.replace('\t\tvar footer_before:', '''\t\tvar home := page.find_child("MainMenu",true,false) as Button
\t\tvar content := scroll.get_child(0) as Control
\t\tprint("HOME_GEOMETRY ",dimensions," button=",home.size," right=",home.get_global_rect().end.x," card_right=",content.get_global_rect().end.x," scrollbar=",scroll.get_v_scroll_bar().visible)
\t\tawait RenderingServer.frame_post_draw
\t\troot.get_texture().get_image().save_png("res://../docs/evidence/results-home-2026-11-02/home-%dx%d.png" % [dimensions.x,dimensions.y])
\t\tvar footer_before:''')
probe = root / 'build/results-home-2026-11-02/capture.gd'
source = source.replace('\t\tvar footer_before:', '\t\tcontent.custom_minimum_size.y = 1100\n\t\tawait settle()\n\t\tprint("HOME_SCROLLBAR ",dimensions," button=",home.size," right=",home.get_global_rect().end.x," card_right=",content.get_global_rect().end.x," scrollbar=",scroll.get_v_scroll_bar().visible)\n\t\tawait RenderingServer.frame_post_draw\n\t\troot.get_texture().get_image().save_png("res://../docs/evidence/results-home-2026-11-02/scrollbar-%dx%d.png" % [dimensions.x,dimensions.y])\n\t\tcontent.custom_minimum_size.y = 0\n\t\tawait settle()\n\t\tvar footer_before:')
probe.write_text(source, encoding='utf-8')
env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile), BMT_API_URL='')
cmd = [sys.executable, str(root/'scripts/run_no_crash_dialog.py'),'--',r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe','--path',str(root/'game'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--quit-after','900','--script',str(probe),'--','--capture']
result = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=150)
(out/'native.log').write_text(result.stdout+result.stderr,encoding='utf-8')
print(result.stdout+result.stderr)
raise SystemExit(result.returncode)
