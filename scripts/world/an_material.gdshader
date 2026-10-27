shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap;
uniform vec4 hair_color : source_color = vec4(0.14,0.12,0.10,1.0);
uniform vec4 shirt_color : source_color = vec4(0.46,0.44,0.40,1.0);
uniform vec4 pants_color : source_color = vec4(0.28,0.35,0.40,1.0);
void fragment() {
	vec3 base = texture(albedo_map, UV).rgb;
	float lum = dot(base, vec3(0.2126,0.7152,0.0722));
	vec3 cloth = mix(vec3(lum), base, 0.55);
	float detail = clamp(pow(max(lum,0.001) / 0.28, 0.55), 0.45, 1.65);
	vec3 adjusted = mix(base, cloth, 0.25);
	adjusted = mix(adjusted, hair_color.rgb * clamp(lum / 0.045,0.5,1.6), COLOR.r);
	adjusted = mix(adjusted, shirt_color.rgb * detail, COLOR.g);
	adjusted = mix(adjusted, pants_color.rgb * detail, COLOR.b);
	ALBEDO = adjusted;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.72,0.94,clamp(COLOR.r+COLOR.g+COLOR.b,0.0,1.0));
	SPECULAR = 0.22;
	NORMAL_MAP = texture(normal_map, UV).rgb;
	NORMAL_MAP_DEPTH = 0.3;
}
