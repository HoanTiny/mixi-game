shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D felt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
void fragment() {
	// Dense fibres repeat at a small scale; mipmaps keep them stable at distance.
	vec3 fibres = texture(felt_albedo, UV * vec2(7.0, 5.0)).rgb;
	ALBEDO = mix(vec3(0.055,0.16,0.12), fibres, 0.72);
	ROUGHNESS = 0.96;
	SPECULAR = 0.12;
}
