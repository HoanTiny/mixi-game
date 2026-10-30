shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color = vec4(0.3,0.22,0.15,1.0);
varying vec3 point;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex(){ point = VERTEX; }
void fragment(){
    float grain = sin(point.z*120.0 + sin(point.x*3.0)*2.0) * 0.025;
    float wear = hash(floor(point.xz*40.0))*0.055;
    float plank = hash(vec2(floor(point.x*2.5),0.0))*0.12;
    ALBEDO = base_color.rgb * (0.85+grain+wear+plank);
    ROUGHNESS = 0.91;
}
