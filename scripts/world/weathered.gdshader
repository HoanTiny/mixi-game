shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
varying vec3 world_pos;
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898,78.233,37.719))) * 43758.5453); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float grain = hash(floor(world_pos * 65.0));
    float stain = hash(floor(world_pos * 2.5));
    float damp = 1.0 - 0.18 * (1.0 - smoothstep(0.0, 1.1, world_pos.y));
    ALBEDO = base_color.rgb * (0.9 + grain * 0.08 + stain * 0.07) * damp;
    ROUGHNESS = 0.94;
}
