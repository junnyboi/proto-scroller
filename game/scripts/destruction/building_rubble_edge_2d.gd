class_name BuildingRubbleEdge2D
extends Node2D

enum Edge {
	TOP,
	RIGHT,
	BOTTOM,
	LEFT,
}

const EDGE_COUNT: int = 4
const HOLE_HALF_EXTENTS: Vector2 = Vector2(0.34, 0.38)
const HOLLOW_SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded;

uniform vec4 atlas_region_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 hole_center = vec2(0.5, 0.48);
uniform vec2 hole_half_extents = vec2(0.34, 0.38);
uniform float pattern_seed = 1.0;
uniform float ground_open = 1.0;
uniform vec4 exposed_edges = vec4(0.0);

void fragment() {
	vec2 local_uv = (UV - atlas_region_uv.xy) / atlas_region_uv.zw;
	vec4 facade = texture(TEXTURE, UV) * COLOR;
	if (facade.a <= 0.04) {
		discard;
	}
	float horizontal_noise = sin(local_uv.x * 31.0 + pattern_seed * 1.37) * 0.018;
	float vertical_noise = sin(local_uv.y * 29.0 - pattern_seed * 1.11) * 0.018;
	float top_shell = exposed_edges.x * (1.0 - step(0.12 + horizontal_noise, local_uv.y));
	float right_shell = exposed_edges.y * step(0.88 - vertical_noise, local_uv.x);
	float bottom_shell = exposed_edges.z * step(0.88 - horizontal_noise, local_uv.y);
	float left_shell = exposed_edges.w * (1.0 - step(0.12 + vertical_noise, local_uv.x));
	if (max(max(top_shell, right_shell), max(bottom_shell, left_shell)) <= 0.0) {
		discard;
	}
	vec2 from_hole = local_uv - hole_center;
	float angle = atan(from_hole.y, from_hole.x);
	float irregularity = (
		sin(angle * 5.0 + pattern_seed * 1.73) * 0.035
		+ sin(angle * 9.0 - pattern_seed * 0.91) * 0.018
		+ sin(angle * 13.0 + pattern_seed * 0.37) * 0.010
	);
	vec2 effective_half = hole_half_extents + vec2(irregularity, irregularity * 0.72);
	float hollow_distance = length(vec2(
		from_hole.x / max(effective_half.x, 0.01),
		from_hole.y / max(effective_half.y, 0.01)
	));
	float inside_hollow = 1.0 - step(1.0, hollow_distance);
	float vertical_band = floor(local_uv.y * 9.0);
	float left_width = clamp(
		0.075
		+ sin(vertical_band * 2.17 + pattern_seed * 1.31) * 0.020
		+ sin(vertical_band * 4.63 - pattern_seed * 0.47) * 0.010,
		0.045,
		0.10
	);
	float right_width = clamp(
		0.075
		+ sin(vertical_band * 1.83 - pattern_seed * 1.07) * 0.020
		+ sin(vertical_band * 5.11 + pattern_seed * 0.39) * 0.010,
		0.045,
		0.10
	);
	float ground_center_shift = (
		sin(vertical_band * 1.37 + pattern_seed * 0.73) * 0.010
	);
	float ground_x = from_hole.x - ground_center_shift;
	float below_hole_center = step(hole_center.y, local_uv.y);
	float inside_ground_opening = (
		step(-left_width, ground_x) * (1.0 - step(right_width, ground_x))
	);
	float cutout = max(
		inside_hollow,
		ground_open * below_hole_center * inside_ground_opening
	);
	if (cutout > 0.5) {
		discard;
	}
	float hollow_rim = 1.0 - smoothstep(1.0, 1.14, hollow_distance);
	float ground_edge_distance = min(
		abs(ground_x + left_width),
		abs(ground_x - right_width)
	);
	float ground_rim = (
		ground_open * below_hole_center
		* (1.0 - smoothstep(0.0, 0.038, ground_edge_distance))
	);
	float scorched_rim = max(hollow_rim, ground_rim);
	facade.rgb *= mix(1.0, 0.54, scorched_rim);
	COLOR = facade;
}
"""

static var _shared_hollow_shader: Shader

var _cell_size: Vector2 = Vector2.ZERO
var _facade_texture: Texture2D
var _facade_region: Rect2 = Rect2()
var _edge_visible: Array[bool] = [false, false, false, false]
var _shell_sprite: Sprite2D
var _cutout_material: ShaderMaterial


func configure(
	cell_size: Vector2,
	pattern_seed: int,
	facade_texture: Texture2D,
	facade_region: Rect2,
	visual_tint: Color
) -> void:
	_cell_size = cell_size
	_facade_texture = facade_texture
	_facade_region = facade_region
	_shell_sprite = Sprite2D.new()
	_shell_sprite.name = "HollowFacade"
	_shell_sprite.z_index = 0
	_shell_sprite.texture = _facade_texture
	_shell_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shell_sprite.region_enabled = true
	_shell_sprite.region_filter_clip_enabled = true
	_shell_sprite.region_rect = _facade_region
	_shell_sprite.scale = _cell_size / _facade_region.size
	_shell_sprite.modulate = visual_tint
	_cutout_material = ShaderMaterial.new()
	_cutout_material.shader = _get_shared_hollow_shader()
	var texture_size: Vector2 = _facade_texture.get_size()
	_cutout_material.set_shader_parameter(
		"atlas_region_uv",
		Vector4(
			_facade_region.position.x / texture_size.x,
			_facade_region.position.y / texture_size.y,
			_facade_region.size.x / texture_size.x,
			_facade_region.size.y / texture_size.y
		)
	)
	var seed_fraction: float = fmod(float(pattern_seed) * 0.173, 1.0)
	_cutout_material.set_shader_parameter(
		"hole_center",
		Vector2(0.5 + (seed_fraction - 0.5) * 0.045, 0.48)
	)
	_cutout_material.set_shader_parameter("hole_half_extents", HOLE_HALF_EXTENTS)
	_cutout_material.set_shader_parameter("pattern_seed", float(pattern_seed))
	_cutout_material.set_shader_parameter("ground_open", 1.0)
	_cutout_material.set_shader_parameter("exposed_edges", Vector4.ZERO)
	_shell_sprite.material = _cutout_material
	add_child(_shell_sprite)
	visible = false


func reconfigure(
	cell_size: Vector2,
	pattern_seed: int,
	facade_texture: Texture2D,
	facade_region: Rect2,
	visual_tint: Color
) -> void:
	_cell_size = cell_size
	_facade_texture = facade_texture
	_facade_region = facade_region
	if _shell_sprite == null or _cutout_material == null:
		return
	_shell_sprite.texture = _facade_texture
	_shell_sprite.region_rect = _facade_region
	_shell_sprite.scale = _cell_size / _facade_region.size
	_shell_sprite.modulate = visual_tint
	var texture_size: Vector2 = _facade_texture.get_size()
	_cutout_material.set_shader_parameter(
		"atlas_region_uv",
		Vector4(
			_facade_region.position.x / texture_size.x,
			_facade_region.position.y / texture_size.y,
			_facade_region.size.x / texture_size.x,
			_facade_region.size.y / texture_size.y
		)
	)
	var seed_fraction: float = fmod(float(pattern_seed) * 0.173, 1.0)
	_cutout_material.set_shader_parameter(
		"hole_center",
		Vector2(0.5 + (seed_fraction - 0.5) * 0.045, 0.48)
	)
	_cutout_material.set_shader_parameter("pattern_seed", float(pattern_seed))
	set_exposed_edges(false, false, false, false)


static func _get_shared_hollow_shader() -> Shader:
	if _shared_hollow_shader == null:
		_shared_hollow_shader = Shader.new()
		_shared_hollow_shader.code = HOLLOW_SHADER_CODE
	return _shared_hollow_shader


func set_exposed_edges(top: bool, right: bool, bottom: bool, left: bool) -> void:
	_edge_visible[Edge.TOP] = top
	_edge_visible[Edge.RIGHT] = right
	_edge_visible[Edge.BOTTOM] = bottom
	_edge_visible[Edge.LEFT] = left
	if _cutout_material != null:
		_cutout_material.set_shader_parameter(
			"exposed_edges",
			Vector4(float(top), float(right), float(bottom), float(left))
		)
	visible = top or right or bottom or left


func exposed_edge_count() -> int:
	var total: int = 0
	for edge_is_visible: bool in _edge_visible:
		total += 1 if edge_is_visible else 0
	return total


func exposed_edge_mask() -> Vector4:
	return Vector4(
		float(_edge_visible[Edge.TOP]),
		float(_edge_visible[Edge.RIGHT]),
		float(_edge_visible[Edge.BOTTOM]),
		float(_edge_visible[Edge.LEFT])
	)


func active_shell_count() -> int:
	return 1 if visible and _shell_sprite != null else 0


func is_edge_exposed(edge: Edge) -> bool:
	return edge >= 0 and edge < _edge_visible.size() and _edge_visible[edge]


func source_texture() -> Texture2D:
	return _facade_texture


func source_region() -> Rect2:
	return _facade_region


func facade_sprite() -> Sprite2D:
	return _shell_sprite


func cutout_parameter(parameter_name: StringName) -> Variant:
	if _cutout_material == null:
		return null
	return _cutout_material.get_shader_parameter(parameter_name)
