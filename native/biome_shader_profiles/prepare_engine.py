"""Apply a checked, reproducible source patch only to the owned engine tree."""
from pathlib import Path
import difflib, hashlib, json, re, shutil
root=Path(__file__).resolve().parents[2]
engine=root/'build/biome-shader-profiles-20261106/godot-4.7.2-stable'
evidence=root/'docs/evidence/biome-shader-profiles-2026-11-06'
module=engine/'modules/biome_shader_profiles'
module.mkdir(exist_ok=True)
for name in ['config.py','SCsub','register_types.h','register_types.cpp','biome_shader_profiles.h','biome_shader_profiles.cpp','draw_calls.h']:
    src=Path(__file__).parent/name
    if not (module/name).exists() or (module/name).read_bytes() != src.read_bytes(): shutil.copyfile(src,module/name)
patch=[]; receipts=[]
def update(rel, fn):
    path=engine/rel
    before=evidence/'engine-before'/rel
    before.parent.mkdir(parents=True,exist_ok=True)
    if not before.exists(): shutil.copyfile(path,before)
    original=before.read_text(); result=fn(original)
    if path.read_text() != result: path.write_text(result,newline='\n')
    patch.extend(difflib.unified_diff(original.splitlines(True),result.splitlines(True),'a/'+rel,'b/'+rel))
    receipts.append({'path':rel,'before':hashlib.sha256(original.encode()).hexdigest(),'after':hashlib.sha256(result.encode()).hexdigest()})
def replace(s,a,b):
    assert s.count(a)==1, (a,s.count(a))
    return s.replace(a,b)
include='#include "modules/biome_shader_profiles/biome_shader_profiles.h"\n'
def header(s):
    s=replace(s,'#include <platform_gl.h>','#include <platform_gl.h>\n'+include)
    s=replace(s,'struct Version {','struct Version {\n\t\tString bmt_key;')
    s=replace(s,'glUseProgram(spec->id);','glUseProgram(spec->id);\n\t\tBMTShaderProfiles::bound(spec->id, version->bmt_key, p_variant, p_specialization);')
    return s
update('drivers/gles3/shader_gles3.h',header)
def source(s):
    s=replace(s,'#include "shader_gles3.h"','#include "shader_gles3.h"\n#include "core/os/os.h"')
    s=replace(s,'\tGLint status;','\tconst uint64_t bmt_began = OS::get_singleton()->get_ticks_usec();\n\tGLint status;')
    s=replace(s,'\tspec.ok = true;','\tspec.ok = true;\n\tBMTShaderProfiles::compiled(spec.id, p_version->bmt_key, p_variant, p_specialization, OS::get_singleton()->get_ticks_usec()-bmt_began);')
    s=replace(s,'\t\t\t\tglDeleteProgram(kv.value.id);','\t\t\t\tBMTShaderProfiles::removed(kv.value.id);\n\t\t\t\tglDeleteProgram(kv.value.id);')
    old='\t\tVersion::Specialization spec;\n\t\t_compile_specialization(spec, i, p_version, specialization_default_mask);\n\t\tp_version->variants[i].insert(specialization_default_mask, spec);'
    s=replace(s,old,'')
    anchor='\tp_version->variants.reserve(variant_count);'
    s=replace(s,anchor,'\tArray bmt_plan;\n\tconst bool bmt_selective = BMTShaderProfiles::plan(p_version->bmt_key, bmt_plan);\n'+anchor)
    anchor='\tif (use_cache) {\n\t\t_save_to_cache(p_version);'
    block='''\tif (bmt_selective) {
        for (int n = 0; n < bmt_plan.size(); ++n) {
            Dictionary entry = bmt_plan[n];
            int variant = entry["variant"];
            if (variant < 0 || variant >= variant_count) continue;
            uint64_t specialization = String(entry["specialization"]).hex_to_int();
            Version::Specialization spec;
            _compile_specialization(spec, variant, p_version, specialization);
            p_version->variants[variant].insert(specialization, spec);
        }
    } else {
        for (int i = 0; i < variant_count; ++i) {
            Version::Specialization spec;
            _compile_specialization(spec, i, p_version, specialization_default_mask);
            p_version->variants[i].insert(specialization_default_mask, spec);
        }
    }
'''
    s=replace(s,anchor,block+anchor)
    s=replace(s,'\tif (p_initialize) {','\tversion->bmt_key = (base_sha256 + String(general_defines.get_data()) + _version_get_sha1(version)).sha256_text();\n\tif (p_initialize || BMTShaderProfiles::known(version->bmt_key)) {')
    s=replace(s,'\tERR_FAIL_COND(p_version->variants.size() > 0);',
        '\tERR_FAIL_COND(p_version->variants.size() > 0);\n\tif (p_version->bmt_key.is_empty()) p_version->bmt_key = (base_sha256 + String(general_defines.get_data()) + _version_get_sha1(p_version)).sha256_text();')
    return s
update('drivers/gles3/shader_gles3.cpp',source)
# Instrument all actual draw APIs, preserving argument evaluation and branch scope.
for path in sorted((engine/'drivers/gles3').rglob('*.cpp')):
    original = evidence/'engine-before'/path.relative_to(engine)
    text = original.read_text() if original.exists() else path.read_text()
    if not re.search(r'\bglDraw(?:Arrays|Elements)(?:Instanced)?\(',text): continue
    def draws(s):
        s='#include "modules/biome_shader_profiles/draw_calls.h"\n'+s
        return re.sub(r'\b(glDraw(?:Arrays|Elements)(?:Instanced)?)\(',r'bmt_profile_\1(',s)
    update(path.relative_to(engine).as_posix(),draws)
(evidence/'engine.patch').write_text(''.join(patch),newline='\n')
(evidence/'engine-patch.json').write_text(json.dumps(receipts,indent=2)+'\n')
fingerprint=hashlib.sha256(''.join(patch).encode())
for path in sorted(Path(__file__).parent.glob('*')):
    if path.suffix in ('.cpp','.h'): fingerprint.update(path.name.encode()+path.read_bytes())
generated=module/'build_fingerprint.gen.h'
content='#define BMT_SHADER_PROFILE_SOURCE "'+fingerprint.hexdigest()+'"\n'
if not generated.exists() or generated.read_text()!=content: generated.write_text(content)
print('Patched',len(receipts),'engine files; original sources retained.')
