from pathlib import Path
import re
root=Path.cwd(); work=root/'build/runtime-stall-investigation-2026-10-26'

def method(source,name):
    start=source.index('func '+name+'(')
    match=re.search(r'(?m)^(?:static )?func ',source[start+1:])
    return source[start:start+1+match.start()] if match else source[start:]

def timed(source,line,label):
    pattern=re.compile(r'(?m)^'+re.escape(line)+r'$')
    assert len(pattern.findall(source))==1,(label,len(pattern.findall(source)))
    indent=line[:len(line)-len(line.lstrip('\t'))]
    replacement=indent+'var trace_cpu_'+label+': int = Time.get_ticks_usec()\n'+line+'\n'+indent+'(Engine.get_main_loop() as SceneTree).span("cpu_'+label+'",trace_cpu_'+label+')'
    return pattern.sub(lambda _:replacement,source,1)

detail=(root/'game/vehicle/compact_detail.gd').read_text(encoding='utf-8').replace('class_name CompactDetail\n','',1)
front=method(detail,'_front')
original_front=front
for line,label in [
 ('\tCompactCoachwork.build_nose(car,blue)','nose'),
 ('\t_nose_band(car,0.783,0.660,0.932,-0.009,trim)','nose_band'),
 ('\tCompactGrille.build(car)','grille'),
 ('\t_wrap_bumper(car,trim)','front_bumper'),
 ('\tCompactCoachwork.build_hood(car,blue,cream)','hood')]:
    front=timed(front,line,label)
detail=detail.replace(original_front,front)
detail=timed(detail,'\t_front(car, blue, cream, trim, alloy)','front_total')
marker='\tvar tool:=SurfaceTool.new()\n\ttool.begin(Mesh.PRIMITIVE_TRIANGLES)\n\tfor row: int in range(rows):'
assert detail.count(marker)==1
detail=detail.replace(marker,'''\tvar memo_grid: bool = "--memo-grid" in OS.get_cmdline_user_args()
\tvar grid_depth := PackedFloat64Array()
\tif memo_grid:
\t\tgrid_depth.resize((columns+1)*(rows+1))
\t\tfor grid_y: int in range(rows+1):
\t\t\tvar at_y: float = lerpf(bottom,top,grid_y/float(rows))
\t\t\tfor grid_x: int in range(columns+1):
\t\t\t\tvar at_x: float = lerpf(left,right,grid_x/float(columns))
\t\t\t\tgrid_depth[grid_y*(columns+1)+grid_x] = CompactCoachwork.front_skin(at_x,at_y)+offset
'''+marker)
for point,x,y,grid_y,grid_x in [('a','x0','y0','row','column'),('b','x1','y0','row','column+1'),('c','x1','y1','row+1','column+1'),('d','x0','y1','row+1','column')]:
    old=f'var {point}:=Vector3({x},{y},CompactCoachwork.front_skin({x},{y})+offset)'
    new=f'var {point}:=Vector3({x},{y},grid_depth[({grid_y})*(columns+1)+({grid_x})] if memo_grid else CompactCoachwork.front_skin({x},{y})+offset)'
    assert detail.count(old)==1,old
    detail=detail.replace(old,new)
(work/'cpu_detail.gd').write_text(detail,encoding='utf-8')
car=(root/'game/vehicle/car_visual.gd').read_text(encoding='utf-8')
ready=method(car,'_ready')
assert ready.count('await CompactDetail.build(')==1
ready=ready.replace('await CompactDetail.build(','await preload("res://../build/runtime-stall-investigation-2026-10-26/cpu_detail.gd").build(')
for line,label in [
 ('\tCompactCoachwork.build_body(self,blue)','main_body'),
 ('\t_hatchback(paint, glass, trim, blue)','cabin'),
 ('\t\t\tCompactDetail.tire(pivot, trim, simple_model)','tire')]:
    ready=timed(ready,line,label)
(work/'cpu_car.gd').write_text('extends "res://vehicle/car_visual.gd"\n'+ready.rstrip()+'\n',encoding='utf-8')
print('CPU probe copies original constructor/front math, adding timestamps only.')
