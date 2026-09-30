shader_type sky;
// Static low-resolution overcast radiance, filtered once by the engine.
// No moving noise or painted highlights on the road itself.
void sky() {
 float elevation = smoothstep(-0.15,0.8,EYEDIR.y);
 float opening = pow(max(dot(EYEDIR,normalize(vec3(-0.4,0.8,0.3))),0.0),4.0);
 COLOR = mix(vec3(0.30,0.32,0.34),vec3(1.10,1.14,1.18),elevation);
 COLOR += vec3(0.65,0.66,0.67)*opening;
 COLOR *= 0.25;
}
