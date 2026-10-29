shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap;
uniform sampler2D orm_map : filter_linear_mipmap;
uniform bool has_normal = false;
uniform bool has_orm = false;
uniform vec4 hair_color : source_color = vec4(0.14,0.12,0.10,1.0);
uniform vec4 shirt_color : source_color = vec4(0.46,0.44,0.40,1.0);
uniform vec4 pants_color : source_color = vec4(0.28,0.35,0.40,1.0);
void fragment() {
	vec3 base = texture(albedo_map, UV).rgb;
	float lum = dot(base, vec3(0.2126,0.7152,0.0722));
	vec3 cloth = mix(vec3(lum), base, 0.55);
	// Reduce baked plaid/grit contrast while retaining the source folds and seams.
	// Shader colour uniforms are already converted by source_color; their values
	// must be supplied as sRGB from script, never converted a second time.
	float broad = dot(textureLod(albedo_map, UV, 2.0).rgb, vec3(0.2126, 0.7152, 0.0722));
	float reference = OUTPUT_IS_SRGB ? 0.44 : 0.17;
	float detail = clamp(pow(max(mix(lum, broad, 0.40), 0.001) / reference, 0.42), 0.62, 1.38);
	vec3 adjusted = mix(base, cloth, 0.12) * 0.97;
	float exposed = 1.0-clamp(COLOR.r+COLOR.g+COLOR.b,0.0,1.0);
	// Slightly warmer, less chalky exposed skin; preserve the existing face UVs.
	adjusted *= mix(vec3(1.0),OUTPUT_IS_SRGB ? vec3(0.97,0.94,0.91) : vec3(0.94,0.88,0.83),exposed);
	float hair_reference = OUTPUT_IS_SRGB ? 0.16 : 0.023;
	adjusted = mix(adjusted, hair_color.rgb * clamp(lum / hair_reference, 0.70, 1.25), COLOR.r);
	// Wardrobe swatches describe the dye, not a lit fabric highlight. The source
	// scan already contains broad illumination; compensate before scene lighting.
	float dye_scale = OUTPUT_IS_SRGB ? 0.68 : 0.42;
	adjusted = mix(adjusted, shirt_color.rgb * dye_scale * detail, COLOR.g);
	adjusted = mix(adjusted, pants_color.rgb * dye_scale * detail, COLOR.b);
	ALBEDO = adjusted;
	METALLIC = 0.0;
	float clothing = clamp(COLOR.g + COLOR.b, 0.0, 1.0);
	ROUGHNESS = mix(mix(0.68, 0.82, COLOR.r), 0.92, clothing);
	SPECULAR = mix(0.24, 0.16, clothing);
	if (has_normal) {
		NORMAL_MAP = texture(normal_map, UV).rgb;
		NORMAL_MAP_DEPTH = mix(0.16, 0.32, clothing);
	}
	if (has_orm) {
		vec3 orm = texture(orm_map, UV).rgb;
		AO = mix(0.78, 1.0, orm.r);
		ROUGHNESS = mix(ROUGHNESS, max(orm.g, 0.58), 0.22);
	}
}
