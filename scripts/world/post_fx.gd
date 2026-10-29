extends CanvasLayer
## Lớp hậu kỳ toàn màn hình kiểu "Nobody" (Gritty Urban), nằm trên cảnh 3D, dưới HUD (layer 0 < hud layer 1):
## giảm bão hòa (saturation 0,8), tăng tương phản (contrast 1,15), ám vàng bụi ấm (tint), tối góc (vignette), hạt
## nhiễu nhẹ như bụi phim. Ban đêm bớt ám vàng để đèn đường, neon giữ màu. world.gd đặt night mỗi khung.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float saturation = 0.8;
uniform float contrast = 1.15;
uniform vec3 tint : source_color = vec3(1.0, 0.9, 0.72);
uniform float tint_amount = 0.22;
uniform float vignette = 0.42;
uniform float grain = 0.035;
uniform float night = 0.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	// Đêm: bớt tương phản, nâng vùng tối một chút cho phố vẫn đọc được dưới đèn đường.
	c = (c - 0.5) * mix(contrast, 1.02, night * 0.8) + 0.5 + night * 0.03;
	// Ám vàng bụi: nhân vào vùng trung và sáng nhiều hơn vùng tối (bóng vẫn đen sạch).
	float amt = tint_amount * mix(1.0, 0.35, night) * smoothstep(0.05, 0.6, luma);
	c = mix(c, c * tint * 1.08, amt);
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.85);
	float v = smoothstep(0.32, 0.82, length(d));
	c *= 1.0 - vignette * mix(1.0, 0.65, night) * v;
	c += (hash(floor(FRAGCOORD.xy * 0.5) + fract(TIME * 7.0) * 61.0) - 0.5) * grain;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""

var rect: ColorRect
var mat: ShaderMaterial


func _ready() -> void:
	layer = 0
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	add_child(rect)


func set_night(nf: float) -> void:
	if mat != null:
		mat.set_shader_parameter("night", nf)
