shader_type spatial;
render_mode diffuse_burley;
void fragment() {
	float thread = sin(UV.x*1800.0)*sin(UV.y*900.0);
	float fade = smoothstep(0.05,0.62,length(UV-vec2(0.5)));
	float aa = 1.0-smoothstep(0.3,1.0,max(fwidth(UV.x)*1800.0,fwidth(UV.y)*900.0));
	ALBEDO = mix(vec3(0.095,0.255,0.20),vec3(0.065,0.19,0.155),fade)* (1.0+thread*0.035*aa);
	ROUGHNESS = 0.96;
	SPECULAR = 0.12;
}
