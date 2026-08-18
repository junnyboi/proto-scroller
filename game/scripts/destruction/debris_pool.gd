class_name DebrisPool
extends Node2D

signal aerial_impact_accepted(
	body: DebrisBody2D,
	event: DamageEvent,
	target: EnemyActor2D
)

@export var debris_scene: PackedScene
@export_range(1, 128, 1) var capacity: int = 48

var recycle_count: int = 0
var peak_active_count: int = 0
var _free: Array[DebrisBody2D] = []
var _active: Array[DebrisBody2D] = []


func _ready() -> void:
	for index: int in range(capacity):
		var body: DebrisBody2D
		if debris_scene != null:
			body = debris_scene.instantiate() as DebrisBody2D
		else:
			body = DebrisBody2D.new()
		if body == null:
			push_error("debris_scene root must extend DebrisBody2D")
			return
		body.name = "Debris_%03d" % index
		body.recycle_requested.connect(_on_recycle_requested)
		body.aerial_impact_accepted.connect(_on_aerial_impact_accepted)
		add_child(body)
		body.deactivate()
		_free.append(body)


func acquire(
	spawn_transform: Transform2D,
	linear_impulse: Vector2,
	angular_impulse: float = 0.0,
	body_mass: float = 4.0,
	body_size: Vector2 = Vector2(36.0, 22.0),
	material_id: StringName = &"concrete",
	primary_color: Color = Color("4f4a46"),
	facet_color: Color = Color("786d65")
) -> DebrisBody2D:
	if _free.is_empty():
		release(_active.front())
		recycle_count += 1
	var body: DebrisBody2D = _free.pop_back()
	_active.append(body)
	peak_active_count = maxi(peak_active_count, _active.size())
	body.activate(
		spawn_transform,
		linear_impulse,
		angular_impulse,
		body_mass,
		body_size,
		material_id,
		primary_color,
		facet_color
	)
	return body


func release(body: DebrisBody2D) -> void:
	if body == null or not _active.has(body):
		return
	_active.erase(body)
	body.deactivate()
	_free.append(body)


func available_count() -> int:
	return _free.size()


func active_count() -> int:
	return _active.size()


func _on_recycle_requested(body: DebrisBody2D) -> void:
	release(body)


func _on_aerial_impact_accepted(
	body: DebrisBody2D,
	event: DamageEvent,
	target: EnemyActor2D
) -> void:
	aerial_impact_accepted.emit(body, event, target)
