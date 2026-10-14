shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 backing_color : source_color = vec4(0.16,0.205,0.225,1.0);
varying vec3 backing_position;
void vertex() { backing_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 // Smooth charcoal upholstery: no periodic weave or subpixel normal perturbation.
 float broad=sin(backing_position.z*1.4+sin(backing_position.y*1.1))*0.5+0.5;
 ALBEDO=backing_color.rgb*(0.975+broad*0.025);
 ROUGHNESS=0.88;
 METALLIC=0.0;
 SPECULAR=0.24;
}
