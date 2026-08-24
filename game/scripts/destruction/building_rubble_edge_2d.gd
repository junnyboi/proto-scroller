class_name BuildingRubbleEdge2D
extends Node2D

enum Edge {
	TOP,
	RIGHT,
	BOTTOM,
	LEFT,
}

const EDGE_COUNT: int = 4
const JAGGED_STEPS: int = 11
const WEATHER_PATCH_COUNT: int = 8
const POCKMARK_COUNT: int = 12
const OUTLINE_COLOR: Color = Color(0.018, 0.016, 0.015, 0.96)
const SOOT_COLOR: Color = Color(0.025, 0.028, 0.028, 0.82)
const ASH_COLOR: Color = Color(0.26, 0.255, 0.235, 0.46)

var _cell_size: Vector2 = Vector2.ZERO
var _edge_polygons: Array[PackedVector2Array] = []
var _weather_patches: Array[Array] = []
var _pockmarks: Array[PackedVector2Array] = []
var _edge_visible: Array[bool] = [false, false, false, false]
var _fill_color: Color = Color("171918")
var _facet_color: Color = Color("4c4a43")


func configure(
	cell_size: Vector2,
	pattern_seed: int,
	material_id: StringName,
	visual_tint: Color
) -> void:
	_cell_size = cell_size
	_apply_material_palette(material_id, visual_tint)
	_build_polygons(pattern_seed)
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


func is_edge_exposed(edge: Edge) -> bool:
	return edge >= 0 and edge < _edge_visible.size() and _edge_visible[edge]


func weather_mark_count() -> int:
	var total: int = 0
	for patches: Array in _weather_patches:
		total += patches.size()
	for marks: PackedVector2Array in _pockmarks:
		total += marks.size()
	return total


func surface_fill_color() -> Color:
	return _fill_color


func _build_polygons(pattern_seed: int) -> void:
	_edge_polygons.clear()
	_weather_patches.clear()
	_pockmarks.clear()
	for edge: int in range(EDGE_COUNT):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = pattern_seed * 104729 + edge * 15485863
		_edge_polygons.append(_edge_polygon(edge, rng))
		_weather_patches.append(_build_weather_patches(edge, rng))
		_pockmarks.append(_build_pockmarks(edge, rng))


func _edge_polygon(edge: int, rng: RandomNumberGenerator) -> PackedVector2Array:
	var half_size: Vector2 = _cell_size * 0.5
	var points: PackedVector2Array = PackedVector2Array()
	if edge == Edge.TOP or edge == Edge.BOTTOM:
		var outer_y: float = -half_size.y if edge == Edge.TOP else half_size.y
		points.append(Vector2(-half_size.x, outer_y))
		points.append(Vector2(half_size.x, outer_y))
		for step: int in range(JAGGED_STEPS, -1, -1):
			var ratio: float = float(step) / float(JAGGED_STEPS)
			var x: float = lerpf(-half_size.x, half_size.x, ratio)
			var depth: float = rng.randf_range(6.0, 18.0)
			if step % 4 == 1:
				depth *= rng.randf_range(0.38, 0.62)
			elif step % 5 == 3:
				depth *= rng.randf_range(1.20, 1.52)
			var y: float = outer_y + depth if edge == Edge.TOP else outer_y - depth
			points.append(Vector2(x, y))
		return points
	var outer_x: float = -half_size.x if edge == Edge.LEFT else half_size.x
	points.append(Vector2(outer_x, -half_size.y))
	points.append(Vector2(outer_x, half_size.y))
	for step: int in range(JAGGED_STEPS, -1, -1):
		var ratio: float = float(step) / float(JAGGED_STEPS)
		var y: float = lerpf(-half_size.y, half_size.y, ratio)
		var depth: float = rng.randf_range(6.0, 17.0)
		if step % 4 == 2:
			depth *= rng.randf_range(0.38, 0.62)
		elif step % 5 == 4:
			depth *= rng.randf_range(1.20, 1.48)
		var x: float = outer_x + depth if edge == Edge.LEFT else outer_x - depth
		points.append(Vector2(x, y))
	return points


func _build_weather_patches(edge: int, rng: RandomNumberGenerator) -> Array:
	var patches: Array[PackedVector2Array] = []
	for _index: int in range(WEATHER_PATCH_COUNT):
		var center: Vector2 = _edge_interior_point(
			edge,
			rng.randf_range(0.05, 0.95),
			rng.randf_range(3.0, 13.0)
		)
		var radius: Vector2 = Vector2(
			rng.randf_range(4.0, 12.0),
			rng.randf_range(2.2, 6.5)
		)
		if edge == Edge.LEFT or edge == Edge.RIGHT:
			radius = Vector2(radius.y, radius.x)
		var patch: PackedVector2Array = PackedVector2Array()
		for point_index: int in range(7):
			var angle: float = TAU * float(point_index) / 7.0
			var wobble: float = rng.randf_range(0.68, 1.18)
			patch.append(center + Vector2(
				cos(angle) * radius.x * wobble,
				sin(angle) * radius.y * wobble
			))
		patches.append(patch)
	return patches


func _build_pockmarks(edge: int, rng: RandomNumberGenerator) -> PackedVector2Array:
	var marks: PackedVector2Array = PackedVector2Array()
	for _index: int in range(POCKMARK_COUNT):
		marks.append(_edge_interior_point(
			edge,
			rng.randf_range(0.04, 0.96),
			rng.randf_range(3.0, 15.0)
		))
	return marks


func _edge_interior_point(edge: int, along: float, inset: float) -> Vector2:
	var half_size: Vector2 = _cell_size * 0.5
	if edge == Edge.TOP:
		return Vector2(lerpf(-half_size.x, half_size.x, along), -half_size.y + inset)
	if edge == Edge.BOTTOM:
		return Vector2(lerpf(-half_size.x, half_size.x, along), half_size.y - inset)
	if edge == Edge.LEFT:
		return Vector2(-half_size.x + inset, lerpf(-half_size.y, half_size.y, along))
	return Vector2(half_size.x - inset, lerpf(-half_size.y, half_size.y, along))


func _apply_material_palette(material_id: StringName, visual_tint: Color) -> void:
	if material_id == &"steel":
		_fill_color = Color("14191b")
		_facet_color = Color("454b4b")
	elif material_id == &"glass":
		_fill_color = Color("151b1d")
		_facet_color = Color("465154")
	else:
		_fill_color = Color("171918")
		_facet_color = Color("4c4a43")
	_fill_color *= visual_tint
	_facet_color *= visual_tint


func _draw() -> void:
	for edge: int in range(mini(_edge_polygons.size(), EDGE_COUNT)):
		if not _edge_visible[edge]:
			continue
		var polygon: PackedVector2Array = _edge_polygons[edge]
		if polygon.size() < 3:
			continue
		draw_colored_polygon(polygon, _fill_color)
		var patches: Array = _weather_patches[edge]
		for patch_index: int in range(patches.size()):
			var patch: PackedVector2Array = patches[patch_index] as PackedVector2Array
			draw_colored_polygon(patch, SOOT_COLOR if patch_index % 3 != 1 else ASH_COLOR)
		for mark_index: int in range(_pockmarks[edge].size()):
			var mark_radius: float = 1.0 + float(mark_index % 3) * 0.55
			draw_circle(
				_pockmarks[edge][mark_index],
				mark_radius,
				OUTLINE_COLOR if mark_index % 2 == 0 else ASH_COLOR
			)
		var inner_edge: PackedVector2Array = PackedVector2Array()
		for point_index: int in range(2, polygon.size()):
			inner_edge.append(polygon[point_index])
		draw_polyline(inner_edge, OUTLINE_COLOR, 2.75, true)
		draw_polyline(inner_edge, _facet_color, 1.0, true)
