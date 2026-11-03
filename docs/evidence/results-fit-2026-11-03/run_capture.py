from pathlib import Path
import os, subprocess, sys
root=Path.cwd(); work=root/'build/results-fit-2026-11-03'; out=root/'docs/evidence/results-fit-2026-11-03';out.mkdir(parents=True,exist_ok=True)
work.mkdir(parents=True,exist_ok=True)
if not (work/'race_complete.before.gd').exists():
    (work/'race_complete.before.gd').write_bytes((out/'race_complete.before.gd.txt').read_bytes())
s=(root/'game/tests/test_results_footer_fit.gd').read_text(encoding='utf-8')
if '--before' in sys.argv:
    control=work/'before_control.gd'
    control.write_text((work/'race_complete.before.gd').read_text(encoding='utf-8').replace('class_name RaceComplete\n',''),encoding='utf-8')
    s=s.replace('RaceComplete.new()', 'preload("'+control.as_posix()+'").new()')
a=s.index('\troot.add_child(page)');b=s.index('\tvar scroll :=',a)
s=s[:a]+'''\tvar parent := MarginContainer.new()
\troot.add_child(parent)
\tMenuStyle.fill(parent)
\tfor side: String in ["left","right"]: parent.add_theme_constant_override("margin_"+side,32)
\tfor side: String in ["top","bottom"]: parent.add_theme_constant_override("margin_"+side,16)
\tparent.add_child(page)
\tpage.global_rank.text = "POSITION 1"
\tpage.lap_population.text = "POSITION 1"
\tpage.race_best_caption.text = "PB 01:30.142"
\tpage.lap_best_caption.text = "PB 00:16.097"
\t# Explicit offline fixture data, only for reviewing chart legibility.
\tfor chart: TrackDistribution in [page.race_chart,page.lap_chart]:
\t\tvar current: float = float(chart.snapshot.markers[0].value_ms)
\t\tchart.snapshot.bins = [1,2,4,6,8,6,5,3,2,1,1,0,1,0,0,1]
\t\tchart.snapshot.min_ms = current*0.9
\t\tchart.snapshot.max_ms = current*1.4
\t\tchart.queue_redraw()
'''+s[b:]
s=s.replace('"flying":16.097','"complete":true,"flying":16.097')
s=s.replace('\t\tawait settle()\n\t\t# Canvas-items', '\t\tfor side: String in ["top","bottom"]: parent.add_theme_constant_override("margin_"+side,32 if dimensions.x != 1920 else 80)\n\t\tawait settle()\n\t\t# Canvas-items')
s=s.replace('\t\tvar footer_before:', '''\t\tvar home := page.find_child("MainMenu",true,false) as Button
\t\tvar content := scroll.get_child(0) as Control
\t\tprint("LAYOUT ",dimensions," canvas=",root.get_visible_rect()," scroll=",scroll.size," content_min=",content.get_combined_minimum_size()," main_min=",content.get_child(0).get_combined_minimum_size()," home=",home.size," right=",home.get_global_rect().end.x," card_right=",content.get_global_rect().end.x," scrollbar=",scroll.get_v_scroll_bar().visible)
\t\tvar footer_before:''')
s=s.replace('res://../docs/evidence/results-footer-2026-11-02','res://../docs/evidence/results-fit-2026-11-03')
(work/'capture.gd').write_text(s,encoding='utf-8')
profile=work/'profile';profile.mkdir(exist_ok=True)
env=dict(os.environ,APPDATA=str(profile),LOCALAPPDATA=str(profile),BMT_API_URL='')
cmd=[sys.executable,str(root/'scripts/run_no_crash_dialog.py'),'--',r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe','--path',str(root/'game'),'--audio-driver','Dummy','--quit-after','900','--script',str(work/'capture.gd')]
if '--capture' not in sys.argv: cmd+=['--headless']
else: cmd+=['--','--capture']
r=subprocess.run(cmd,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
(out/('before-constrained.log' if '--before' in sys.argv else 'native.log' if '--capture' in sys.argv else 'after-headless.log')).write_text(r.stdout+r.stderr,encoding='utf-8');print(r.stdout+r.stderr);sys.exit(r.returncode)
