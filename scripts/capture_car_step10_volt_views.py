"""Add owner-marked door/handle close views to the retained native comparison."""
from pathlib import Path
p=Path(__file__).resolve().parents[1]/'game/tests/capture_car_step10.gd'
t=p.read_text()
t=t.replace('if id=="electric": views.append_array(', 'if id=="electric": views.append_array([["doors-left",0.0,0.3,1.0],["doors-right",0.0,0.3,1.0],["handle-front",0.0,0.3,1.0],["handle-rear",0.0,0.3,1.0]]);views.append_array(')
t=t.replace('match str(shot[0]):','''match str(shot[0]):
					"doors-left": camera_position=Vector3(3.5,1.22,0.1);target=Vector3(0,0.68,0.1)
					"doors-right": camera_position=Vector3(-3.5,1.22,0.1);target=Vector3(0,0.68,0.1)
					"handle-front": camera_position=Vector3(2.0,1.12,-0.16);target=Vector3(0,0.87,-0.16)
					"handle-rear": camera_position=Vector3(2.0,1.12,0.86);target=Vector3(0,0.87,0.86)''')
t=t.replace('ShowroomStudio._studio_glass(old,{})','ShowroomStudio._studio_glass(old,{})\n\t\t\tcheck(old.transform.is_equal_approx(view.car.transform),"matched root transform "+id+mode)')
p.write_text(t)
