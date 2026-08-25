class_name BuildingDamagePattern2D
extends Node2D

const CONTOUR_POINTS: int = 16
const BASE_CRACK_COUNT: int = 5
const EDGE_MARGIN: float = 8.0
const CRACK_SHADOW: Color = Color(0.015, 0.012, 0.012, 0.78)
const CRACK_HIGHLIGHT: Color = Color(0.34, 0.27, 0.22, 0.58)
const CABLE_DETAIL_BIT: int = 1
const PIPE_DETAIL_BIT: int = 2
const CABLE_DISPLAY_SIZE: Vector2 = Vector2(46.0, 68.0)
const PIPE_DISPLAY_SIZE: Vector2 = Vector2(31.5, 57.0)
const CABLE_TEXTURE: Texture2D = preload(
	"res://art/destruction/damage_details/dangling_cables.png"
)
const PIPE_TEXTURE: Texture2D = preload(
	"res://art/destruction/damage_details/broken_water_pipe.png"
)

var _texture: Texture2D
var _region_rect: Rect2
var _cell_size: Vector2
var _pattern_seed: int = 1
var _material_id: StringName = &"concrete"
var _contour: PackedVector2Array = PackedVector2Array()
var _cracks: Array[PackedVector2Array] = []
var _patch: Polygon2D
var _cable_detail: BuildingDamageAttachment2D
var _pipe_detail: BuildingDamageAttachment2D
var _detail_mask: int = 0


func configure(
	texture: Texture2D,
	region_rect: Rect2,
	cell_size: Vector2,
	pattern_seed: int,
	material_id: StringName,
	visual_tint: Color
) -> void:
	_texture = texture
	_region_rect = region_rect
	_cell_size = cell_size
	_pattern_seed = maxi(pattern_seed, 1)
	_material_id = material_id
	z_index = 2
	_patch = Polygon2D.new()
	_patch.name = "FractureTexture"
	_patch.texture = _texture
	_patch.color = visual_tint
	_patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_patch.z_index = -1
	add_child(_patch)
	_cable_detail = _create_detail_attachment(
		"DanglingCables",
		BuildingDamageAttachment2D.Kind.CABLE,
		CABLE_TEXTURE,
		CABLE_DISPLAY_SIZE
	)
	_pipe_detail = _create_detail_attachment(
		"BrokenWaterPipe",
		BuildingDamageAttachment2D.Kind.PIPE,
		PIPE_TEXTURE,
		PIPE_DISPLAY_SIZE
	)
	visible = false


func reconfigure(
	texture: Texture2D,
	region_rect: Rect2,
	cell_size: Vector2,
	pattern_seed: int,
	material_id: StringName,
	visual_tint: Color
) -> void:
	_texture = texture
	_region_rect = region_rect
	_cell_size = cell_size
	_pattern_seed = maxi(pattern_seed, 1)
	_material_id = material_id
	if _patch != null:
		_patch.texture = _texture
		_patch.color = visual_tint
	if _cable_detail != null:
		_cable_detail.configure_seed(_pattern_seed)
	if _pipe_detail != null:
		_pipe_detail.configure_seed(_pattern_seed)
	reset_pattern()
	visible = false


func record_damage(event: DamageEvent, health_ratio: float) -> void:
	if event == null or _patch == null:
		return
	var local_hit: Vector2 = to_local(event.hit_position)
	var half_size: Vector2 = _cell_size * 0.5
	local_hit.x = clampf(local_hit.x, -half_size.x + EDGE_MARGIN, half_size.x - EDGE_MARGIN)
	local_hit.y = clampf(local_hit.y, -half_size.y + EDGE_MARGIN, half_size.y - EDGE_MARGIN)
	var event_seed: int = (
		_pattern_seed
		^ int(event.attack_id * 1103515245)
		^ int(roundf(event.hit_position.x * 17.0))
		^ int(roundf(event.hit_position.y * 31.0))
	)
	var severity: float = clampf(1.0 - health_ratio, 0.0, 1.0)
	_generate(local_hit, severity, event_seed)
	_emit_attachment_effects(event, severity)
	queue_redraw()


func contour() -> PackedVector2Array:
	return _contour.duplicate()


func crack_count() -> int:
	return _cracks.size()


func damage_detail_count() -> int:
	var total: int = 0
	if _cable_detail != null and _cable_detail.visible:
		total += 1
	if _pipe_detail != null and _pipe_detail.visible:
		total += 1
	return total


func damage_detail_mask() -> int:
	return _detail_mask


func damage_effect_activation_count() -> int:
	var total: int = 0
	if _cable_detail != null:
		total += _cable_detail.activation_count
	if _pipe_detail != null:
		total += _pipe_detail.activation_count
	return total


func active_damage_effect_count() -> int:
	var total: int = 0
	if _cable_detail != null:
		total += _cable_detail.active_effect_count()
	if _pipe_detail != null:
		total += _pipe_detail.active_effect_count()
	return total


func cable_sway_offset() -> float:
	return _cable_detail.sway_rotation_offset if _cable_detail != null else 0.0


func cull_damage_details() -> void:
	if _cable_detail != null:
		_cable_detail.set_attachment_visible(false)
	if _pipe_detail != null:
		_pipe_detail.set_attachment_visible(false)


func pattern_signature() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for point: Vector2 in _contour:
		parts.append("%d:%d" % [roundi(point.x), roundi(point.y)])
	return "|".join(parts)


func reset_pattern() -> void:
	_contour.clear()
	_cracks.clear()
	_detail_mask = 0
	if _patch != null:
		_patch.polygon = PackedVector2Array()
		_patch.uv = PackedVector2Array()
	cull_damage_details()
	queue_redraw()


func capture_stream_state() -> Dictionary:
	var cracks: Array[PackedVector2Array] = []
	for crack: PackedVector2Array in _cracks:
		cracks.append(crack.duplicate())
	return {
		"contour": _contour.duplicate(),
		"cracks": cracks,
		"detail_mask": _detail_mask,
	}


func restore_stream_state(state: Dictionary) -> void:
	reset_pattern()
	if state.is_empty() or _patch == null:
		return
	_contour = (state.get("contour", PackedVector2Array()) as PackedVector2Array).duplicate()
	var cracks: Array = state.get("cracks", []) as Array
	for crack_value: Variant in cracks:
		_cracks.append((crack_value as PackedVector2Array).duplicate())
	_patch.polygon = _contour
	_patch.uv = _texture_uvs(_contour)
	_apply_detail_mask(
		int(state.get("detail_mask", 0)),
		_contour_center()
	)
	queue_redraw()


func _generate(center: Vector2, severity: float, event_seed: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = event_seed
	var base_radius: float = minf(_cell_size.x, _cell_size.y) * 0.28
	var radius_scale: Vector2 = Vector2(1.18, 0.88)
	var crack_total: int = BASE_CRACK_COUNT
	if _material_id == &"glass":
		base_radius *= 0.90
		radius_scale = Vector2(1.02, 1.20)
		crack_total += 2
	elif _material_id == &"steel":
		base_radius *= 0.82
		radius_scale = Vector2(1.42, 0.66)
		crack_total -= 1
	base_radius *= lerpf(0.82, 1.18, severity)
	_contour = PackedVector2Array()
	for point_index: int in range(CONTOUR_POINTS):
		var angle: float = TAU * float(point_index) / float(CONTOUR_POINTS)
		angle += rng.randf_range(-0.12, 0.12)
		var notch: float = 0.72 if point_index % 5 == 2 else 1.0
		var radial: float = base_radius * notch * rng.randf_range(0.72, 1.14)
		var point: Vector2 = center + Vector2(
			cos(angle) * radial * radius_scale.x,
			sin(angle) * radial * radius_scale.y
		)
		point.x = clampf(
			point.x,
			-_cell_size.x * 0.5 + EDGE_MARGIN,
			_cell_size.x * 0.5 - EDGE_MARGIN
		)
		point.y = clampf(
			point.y,
			-_cell_size.y * 0.5 + EDGE_MARGIN,
			_cell_size.y * 0.5 - EDGE_MARGIN
		)
		_contour.append(point)
	_patch.polygon = _contour
	_patch.uv = _texture_uvs(_contour)
	_cracks.clear()
	for crack_index: int in range(crack_total):
		var contour_index: int = wrapi(
			roundi(float(crack_index) * float(CONTOUR_POINTS) / float(crack_total))
			+ rng.randi_range(-1, 1),
			0,
			CONTOUR_POINTS
		)
		var edge: Vector2 = _contour[contour_index]
		var direction: Vector2 = center.direction_to(edge)
		var normal: Vector2 = direction.orthogonal()
		var middle: Vector2 = center.lerp(edge, rng.randf_range(0.38, 0.62))
		middle += normal * rng.randf_range(-10.0, 10.0)
		var crack: PackedVector2Array = PackedVector2Array([
			center + normal * rng.randf_range(-3.0, 3.0),
			middle,
			edge,
		])
		_cracks.append(crack)
	_apply_detail_mask(_detail_mask_for_severity(severity), center)


func _detail_mask_for_severity(severity: float) -> int:
	if severity < 0.28:
		return 0
	if severity >= 0.62:
		return CABLE_DETAIL_BIT | PIPE_DETAIL_BIT
	if _material_id == &"steel":
		return PIPE_DETAIL_BIT
	if _material_id == &"glass":
		return CABLE_DETAIL_BIT
	return CABLE_DETAIL_BIT if _pattern_seed % 2 == 0 else PIPE_DETAIL_BIT


func _apply_detail_mask(mask: int, center: Vector2) -> void:
	_detail_mask = mask
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _pattern_seed * 32452843 + mask * 49979687
	_position_detail(
		_cable_detail,
		center,
		Vector2(rng.randf_range(-28.0, 16.0), 30.0),
		rng
	)
	_position_detail(
		_pipe_detail,
		center,
		Vector2(rng.randf_range(-12.0, 28.0), 34.0),
		rng
	)
	if _cable_detail != null:
		_cable_detail.set_attachment_visible((mask & CABLE_DETAIL_BIT) != 0)
	if _pipe_detail != null:
		_pipe_detail.set_attachment_visible((mask & PIPE_DETAIL_BIT) != 0)


func _position_detail(
	attachment: BuildingDamageAttachment2D,
	center: Vector2,
	offset: Vector2,
	rng: RandomNumberGenerator
) -> void:
	if attachment == null:
		return
	var half_size: Vector2 = _cell_size * 0.5
	var visual_center: Vector2 = center + offset
	visual_center.x = clampf(visual_center.x, -half_size.x + 26.0, half_size.x - 26.0)
	visual_center.y = clampf(visual_center.y, -half_size.y + 34.0, half_size.y - 34.0)
	attachment.configure_transform(
		visual_center,
		rng.randf_range(-0.11, 0.11),
		rng.randi_range(0, 1) == 1
	)


func _create_detail_attachment(
	attachment_name: String,
	kind: BuildingDamageAttachment2D.Kind,
	texture: Texture2D,
	display_size: Vector2
) -> BuildingDamageAttachment2D:
	var attachment: BuildingDamageAttachment2D = BuildingDamageAttachment2D.new()
	attachment.name = attachment_name
	attachment.setup(kind, texture, display_size, _pattern_seed)
	add_child(attachment)
	return attachment


func _emit_attachment_effects(event: DamageEvent, severity: float) -> void:
	if _cable_detail != null and _cable_detail.visible:
		_cable_detail.emit_damage_effect(event.direction, severity)
	if _pipe_detail != null and _pipe_detail.visible:
		_pipe_detail.emit_damage_effect(event.direction, severity)


func _contour_center() -> Vector2:
	if _contour.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in _contour:
		center += point
	return center / float(_contour.size())


func _texture_uvs(points: PackedVector2Array) -> PackedVector2Array:
	var uvs: PackedVector2Array = PackedVector2Array()
	var half_size: Vector2 = _cell_size * 0.5
	for point: Vector2 in points:
		var normalized: Vector2 = (point + half_size) / _cell_size
		uvs.append(_region_rect.position + normalized * _region_rect.size)
	return uvs


func _draw() -> void:
	if _contour.is_empty():
		return
	var closed_contour: PackedVector2Array = _contour.duplicate()
	closed_contour.append(_contour[0])
	draw_colored_polygon(_contour, Color(0.06, 0.045, 0.04, 0.24))
	draw_polyline(closed_contour, CRACK_SHADOW, 3.5, true)
	for crack: PackedVector2Array in _cracks:
		draw_polyline(crack, CRACK_SHADOW, 4.0, true)
		draw_polyline(crack, CRACK_HIGHLIGHT, 1.25, true)
