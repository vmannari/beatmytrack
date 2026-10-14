shader_type spatial;
// Continuous light across shallow sand deposits; same shared surface logic.
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
#include "res://track/creator_road.gdshaderinc"
