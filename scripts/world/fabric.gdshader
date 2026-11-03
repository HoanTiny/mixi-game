shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.4,0.4,0.35,1.0);
varying vec3 pos;
float hash(vec3 p) { return fract(sin(dot(p,vec3(12.9898,78.233,45.164)))*43758.5453); }
float noise(vec3 p) {
    vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { pos=VERTEX; }
void fragment() {
    float wear=noise(pos*22.0)*0.12+noise(pos*70.0)*0.05;
    float folds=sin(pos.y*95.0+noise(pos*12.0)*7.0);
    ALBEDO=base_color.rgb*(0.85+wear+folds*0.035);
    ROUGHNESS=0.96;
}

// Đổ bóng bậc thang 3 cấp kiểu Nobody (scripts/world/ink.gd, CEL_LIGHT): sáng, nửa tối, tối; ranh giới mềm vài phần
// trăm. Phần bóng đổ (ATTENUATION) cũng rơi vào bậc tối.
void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band = mix(0.22, 0.55, smoothstep(0.08, 0.12, lit));
	band = mix(band, 1.0, smoothstep(0.48, 0.52, lit));
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
	SPECULAR_LIGHT += LIGHT_COLOR * smoothstep(0.93, 0.96, clamp(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0, 1.0)) * ATTENUATION * 0.06;
}
