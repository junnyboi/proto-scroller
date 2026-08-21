class_name TelegraphPresenter2D
extends Node2D

const TELEGRAPH_BADGE: Texture2D = preload(
	"res://art/presentation/telegraph_badge.png"
)

@export_range(1, 16, 1) var capacity: int = RuntimeBudget.TELEGRAPH_RECORDS

var denial_count: int = 0
var peak_active_count: int = 0
var _records: Array[Dictionary] = []
var _next_id: int = 1


func _ready() -> void:
	z_index = 80
	set_process(true)


func _process(delta: float) -> void:
	for record: Dictionary in _records:
		record.remaining = maxf(float(record.remaining) - delta, 0.0)
	queue_redraw()


func reserve(
	p_owner: EnemyActor2D,
	kind: StringName,
	origin: Vector2,
	target: Vector2,
	duration: float
) -> int:
	if p_owner == null or _records.size() >= capacity:
		denial_count += 1
		return 0
	cancel_owner(p_owner)
	var record_id: int = _next_id
	_next_id += 1
	_records.append({
		"id": record_id,
		"owner": p_owner,
		"kind": kind,
		"origin": origin,
		"target": target,
		"duration": maxf(duration, 0.01),
		"remaining": maxf(duration, 0.01),
	})
	peak_active_count = maxi(peak_active_count, _records.size())
	queue_redraw()
	return record_id


func cancel(record_id: int) -> void:
	for index: int in range(_records.size() - 1, -1, -1):
		if int(_records[index].id) == record_id:
			_records.remove_at(index)
	queue_redraw()


func cancel_owner(p_owner: EnemyActor2D) -> void:
	for index: int in range(_records.size() - 1, -1, -1):
		if _records[index].owner == p_owner:
			_records.remove_at(index)
	queue_redraw()


func cancel_all() -> void:
	_records.clear()
	queue_redraw()


func active_count() -> int:
	return _records.size()


func available_count() -> int:
	return capacity - _records.size()


func rebase_cached_world_state(offset: Vector2) -> void:
	for record: Dictionary in _records:
		record.origin = (record.origin as Vector2) + offset
		record.target = (record.target as Vector2) + offset
	queue_redraw()


func snapshot(record_id: int) -> Dictionary:
	for record: Dictionary in _records:
		if int(record.id) == record_id:
			return record.duplicate()
	return {}


func _draw() -> void:
	for record: Dictionary in _records:
		var progress: float = 1.0 - float(record.remaining) / float(record.duration)
		var origin: Vector2 = to_local(record.origin)
		var target: Vector2 = to_local(record.target)
		var base_color: Color = Color(1.0, 0.35, 0.12, 0.34 + progress * 0.56)
		var kind: StringName = record.kind
		if kind == &"shell" or kind == &"rocket":
			var badge_size: Vector2 = Vector2.ONE * (38.0 + progress * 10.0)
			draw_texture_rect(
				TELEGRAPH_BADGE,
				Rect2(target - badge_size * 0.5, badge_size),
				false,
				Color(1.0, 1.0, 1.0, 0.58 + progress * 0.38)
			)
		if kind == &"shell":
			draw_line(origin, target, base_color, 8.0, true)
			draw_line(origin, target, Color(1.0, 0.82, 0.42, 0.86), 2.0, true)
			draw_circle(target, 26.0 + progress * 10.0, Color(1.0, 0.28, 0.10, 0.20))
			draw_arc(target, 31.0, 0.0, TAU * progress, 32, base_color, 4.0, true)
		elif kind == &"rocket":
			draw_dashed_line(origin, target, base_color, 3.0, 12.0, true)
			draw_arc(target, 42.0, 0.0, TAU * progress, 36, base_color, 5.0, true)
			draw_line(target + Vector2(-18.0, 0.0), target + Vector2(18.0, 0.0), base_color, 3.0)
			draw_line(target + Vector2(0.0, -18.0), target + Vector2(0.0, 18.0), base_color, 3.0)
		else:
			draw_line(origin, target, Color(1.0, 0.72, 0.34, 0.35 + progress * 0.45), 2.0, true)
			draw_circle(origin, 5.0 + progress * 4.0, base_color)
