shader_type canvas_item;
render_mode unshaded;

const float SEAM_PIXELS = 48.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float edge_distance = min(UV.x, 1.0 - UV.x);
	float seam_width = TEXTURE_PIXEL_SIZE.x * SEAM_PIXELS;
	float seam_weight = 1.0 - smoothstep(0.0, seam_width, edge_distance);
	vec2 left_uv = vec2(edge_distance, UV.y);
	vec2 right_uv = vec2(1.0 - edge_distance, UV.y);
	vec4 matched_edge = mix(
		texture(TEXTURE, left_uv),
		texture(TEXTURE, right_uv),
		0.5
	);
	COLOR = mix(source, matched_edge, seam_weight) * COLOR;
}
