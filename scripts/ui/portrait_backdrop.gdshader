shader_type canvas_item;
void fragment() {
	float light = exp(-length((UV-vec2(0.5,0.35))*vec2(2.5,1.3))*2.0);
	vec3 tone = mix(vec3(0.07,0.09,0.085),vec3(0.32,0.29,0.22),light);
	float noise = fract(sin(dot(floor(FRAGCOORD.xy),vec2(12.9898,78.233)))*43758.5453);
	COLOR = vec4(tone+(noise-0.5)*0.012,0.98);
}
