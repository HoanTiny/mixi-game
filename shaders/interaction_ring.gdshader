shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.94,0.78,0.40,1.0);
uniform float active = 0.0;
void fragment() {
	float radius = length(UV - vec2(0.5));
	float rim = smoothstep(0.34,0.39,radius) * (1.0-smoothstep(0.42,0.48,radius));
	float pulse = 0.65 + 0.20 * sin(TIME * 2.5);
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * (0.25 + active * 0.55);
	ALPHA = rim * pulse * (0.48 + active * 0.48);
}
