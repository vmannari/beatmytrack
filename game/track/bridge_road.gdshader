shader_type spatial;
// Continuous, non-wrapped diffuse lighting is essential here: toon lighting
// admitted headlight energy from below and its layer workaround split the crest.
render_mode diffuse_lambert, specular_schlick_ggx, cull_disabled;
#include "res://track/bridge_road.gdshaderinc"
