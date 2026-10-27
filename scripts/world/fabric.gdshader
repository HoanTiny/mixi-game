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
