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
const OUTLINE_COLOR: Color = Color(0.035, 0.028, 0.025, 0.90)

var _cell_size: Vector2 = Vector2.ZERO
var _edge_polygons: Array[PackedVector2Array] = []
var _edge_visible: Array[bool] = [false, false, false, false]
var _fill_color: Color = Color("4f4a46")
var _facet_color: Color = Color("786d65")


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


func _build_polygons(pattern_seed: int) -> void:
	_edge_polygons.clear()
	for edge: int in range(EDGE_COUNT):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = pattern_seed * 104729 + edge * 15485863
		_edge_polygons.append(_edge_polygon(edge, rng))


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


func _apply_material_palette(material_id: StringName, visual_tint: Color) -> void:
	if material_id == &"steel":
		_fill_color = Color("222b30")
		_facet_color = Color("58656b")
	elif material_id == &"glass":
		_fill_color = Color("26373b")
		_facet_color = Color("557078")
	else:
		_fill_color = Color("302c29")
		_facet_color = Color("655b54")
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
		var inner_edge: PackedVector2Array = PackedVector2Array()
		for point_index: int in range(2, polygon.size()):
			inner_edge.append(polygon[point_index])
		draw_polyline(inner_edge, OUTLINE_COLOR, 2.75, true)
		draw_polyline(inner_edge, _facet_color, 1.0, true)
