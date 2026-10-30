from pathlib import Path
import re
import sys

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'godot-version.txt').exists())
FILES=['ui/garage_floor','ui/garage_deck','ui/garage_surface_finish','ui/garage_audio_wood','ui/garage_display_stone','ui/garage_plant_leaf','ui/garage_vinyl','vehicle/vehicle_weathering','vehicle/livery_finish']
room_only='--room-only' in sys.argv
if room_only:FILES=FILES[:7]
globals=[];entries={'vertex':[],'fragment':[]};uniforms=set()
for file in FILES:
    code=(ROOT/'game'/f'{file}.gdshader').read_text()
    code=re.sub(r'^shader_type .*?;|^render_mode .*?;','',code,flags=re.M)
    for stage in entries:
        match=re.search(r'void\s+'+stage+r'\(\)\s*\{',code)
        body=''
        if match:
            start=match.end();end=start;depth=1
            while depth:
                if code[end]=='{':depth+=1
                if code[end]=='}':depth-=1
                end+=1
            body=code[start:end-1]
            code=code[:match.start()]+code[end:]
        entries[stage].append(body)
    for line in code.splitlines():
        if line.strip().startswith('uniform '):
            name=re.search(r'uniform\s+\w+\s+(\w+)',line).group(1)
            if name in uniforms:continue
            uniforms.add(name)
        if line.strip().startswith(('varying ','#include ')) and line in globals:continue
        globals.append(line)
result='shader_type spatial;\nrender_mode diffuse_burley, specular_schlick_ggx;\nuniform int garage_finish_family=0;\nuniform vec4 shared_albedo : source_color;\nuniform vec4 shared_emission : source_color;\nuniform float shared_roughness=1.0;\nuniform float shared_metallic=0.0;\nuniform float shared_specular=0.5;\nuniform float shared_clearcoat=0.0;\nuniform float shared_clearcoat_roughness=0.5;\n'+'\n'.join(globals)+'\n'
for stage,functions in entries.items():
    result+='void '+stage+'() {\n'
    if stage=='fragment':result+='ALBEDO=vec3(1.0); ROUGHNESS=1.0; METALLIC=0.0; SPECULAR=0.5; EMISSION=vec3(0.0);\n'
    for index,body in enumerate(functions):
        result+=('if' if index==0 else 'else if')+' (garage_finish_family=='+str(index)+') {\n'+body+'\n}\n'
    if stage=='fragment' and not room_only:result+='else { ALBEDO=shared_albedo.rgb; ROUGHNESS=shared_roughness; METALLIC=shared_metallic; SPECULAR=shared_specular; EMISSION=shared_emission.rgb; CLEARCOAT=shared_clearcoat; CLEARCOAT_ROUGHNESS=shared_clearcoat_roughness; }\n'
    result+='}\n'
(Path(__file__).resolve().parent/('room_program.gdshader' if room_only else 'finish_program.gdshader')).write_text(result)
print(len(result),FILES)
