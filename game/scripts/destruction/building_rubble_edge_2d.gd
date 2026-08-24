class_name BuildingRubbleEdge2D
extends Node2D

enum Edge {
	TOP,
	RIGHT,
	BOTTOM,
	LEFT,
}

const EDGE_COUNT: int = 4
const HOLLOW_STEPS: int = 11
const MIN_RETAINED_DEPTH: float = 24.0
const MAX_RETAINED_DEPTH: float = 54.0
const CHARRED_OUTLINE: Color = Color(0.018, 0.016, 0.015, 0.86)
const EXPOSED_FACET: Color = Color(0.34, 0.32, 0.285, 0.66)

var _cell_size: Vector2 = Vector2.ZERO
var _facade_texture: Texture2D
var _facade_region: Rect2 = Rect2()
var _shell_polygons: Array[PackedVector2Array] = []
var _shell_uvs: Array[PackedVector2Array] = []
var _edge_visible: Array[bool] = [false, false, false, false]
var _visual_tint: Color = Color.WHITE


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
	_visual_tint = visual_tint
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_build_shells(pattern_seed)
	visible = false
	queue_redraw()


func set_exposed_edges(top: bool, right: bool, bottom: bool, left: bool) -> void:
	_edge_visible[Edge.TOP] = top
	_edge_visible[Edge.RIGHT] = right
	_edge_visible[Edge.BOTTOM] = bottom
	_edge_visible[Edge.LEFT] = left
	visible = top or right or bottom or left
	queue_redraw()


func exposed_edge_count() -> int:
	var total: int = 0
	for edge_is_visible: bool in _edge_visible:
		total += 1 if edge_is_visible else 0
	return total


func active_shell_count() -> int:
	return exposed_edge_count()


func is_edge_exposed(edge: Edge) -> bool:
	return edge >= 0 and edge < _edge_visible.size() and _edge_visible[edge]


func source_texture() -> Texture2D:
	return _facade_texture


func source_region() -> Rect2:
	return _facade_region


func shell_polygon(edge: Edge) -> PackedVector2Array:
	if edge < 0 or edge >= _shell_polygons.size():
		return PackedVector2Array()
	return _shell_polygons[edge].duplicate()


func shell_uv(edge: Edge) -> PackedVector2Array:
	if edge < 0 or edge >= _shell_uvs.size():
		return PackedVector2Array()
	return _shell_uvs[edge].duplicate()


func _build_shells(pattern_seed: int) -> void:
	_shell_polygons.clear()
	_shell_uvs.clear()
	for edge: int in range(EDGE_COUNT):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = pattern_seed * 104729 + edge * 15485863
		var polygon: PackedVector2Array = _shell_polygon(edge, rng)
		_shell_polygons.append(polygon)
		_shell_uvs.append(_texture_uvs(polygon))


func _shell_polygon(edge: int, rng: RandomNumberGenerator) -> PackedVector2Array:
	var half_size: Vector2 = _cell_size * 0.5
	var points: PackedVector2Array = PackedVector2Array()
	if edge == Edge.TOP or edge == Edge.BOTTOM:
		var outer_y: float = -half_size.y if edge == Edge.TOP else half_size.y
		points.append(Vector2(-half_size.x, outer_y))
		points.append(Vector2(half_size.x, outer_y))
		for step: int in range(HOLLOW_STEPS, -1, -1):
			var ratio: float = float(step) / float(HOLLOW_STEPS)
			var x: float = lerpf(-half_size.x, half_size.x, ratio)
			var depth: float = rng.randf_range(
				MIN_RETAINED_DEPTH + 4.0,
				MAX_RETAINED_DEPTH
			)
			if step % 4 == 1:
				depth *= rng.randf_range(0.62, 0.78)
			elif step % 5 == 3:
				depth *= rng.randf_range(1.05, 1.18)
			var y: float = outer_y + depth if edge == Edge.TOP else outer_y - depth
			points.append(Vector2(x, y))
		return points
	var outer_x: float = -half_size.x if edge == Edge.LEFT else half_size.x
	points.append(Vector2(outer_x, -half_size.y))
	points.append(Vector2(outer_x, half_size.y))
	for step: int in range(HOLLOW_STEPS, -1, -1):
		var ratio: float = float(step) / float(HOLLOW_STEPS)
		var y: float = lerpf(-half_size.y, half_size.y, ratio)
		var depth: float = rng.randf_range(
			MIN_RETAINED_DEPTH,
			MAX_RETAINED_DEPTH - 8.0
		)
		if step % 4 == 2:
			depth *= rng.randf_range(0.62, 0.78)
		elif step % 5 == 4:
			depth *= rng.randf_range(1.05, 1.18)
		var x: float = outer_x + depth if edge == Edge.LEFT else outer_x - depth
		points.append(Vector2(x, y))
	return points


func _texture_uvs(points: PackedVector2Array) -> PackedVector2Array:
	var uvs: PackedVector2Array = PackedVector2Array()
	var half_size: Vector2 = _cell_size * 0.5
	for point: Vector2 in points:
		var normalized: Vector2 = (point + half_size) / _cell_size
		uvs.append(_facade_region.position + normalized * _facade_region.size)
	return uvs


func _draw() -> void:
	if _facade_texture == null:
		return
	for edge: int in range(mini(_shell_polygons.size(), EDGE_COUNT)):
		if not _edge_visible[edge]:
			continue
		var polygon: PackedVector2Array = _shell_polygons[edge]
		if polygon.size() < 3:
			continue
		draw_polygon(
			polygon,
			PackedColorArray([_visual_tint]),
			_shell_uvs[edge],
			_facade_texture
		)
		var hollow_edge: PackedVector2Array = PackedVector2Array()
		for point_index: int in range(2, polygon.size()):
			hollow_edge.append(polygon[point_index])
		draw_polyline(hollow_edge, CHARRED_OUTLINE, 2.5, true)
		draw_polyline(hollow_edge, EXPOSED_FACET, 0.9, true)
