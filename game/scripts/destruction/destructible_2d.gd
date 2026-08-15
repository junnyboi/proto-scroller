class_name Destructible2D
extends Node2D

signal damaged(current_health: float, maximum_health: float)
signal destroyed(event: DamageEvent)

@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0
@export_range(0.0, 1.0, 0.05) var damaged_stage_ratio: float = 0.5
@export_range(0, 8, 1) var gameplay_chunk_count: int = 3
@export var chunk_spread_degrees: float = 38.0
@export var chunk_impulse_scale: float = 1.0
@export var debris_pool_path: NodePath
@export var intact_visual_path: NodePath
@export var damaged_visual_path: NodePath
@export var rubble_visual_path: NodePath
@export var intact_collision_path: NodePath
@export var rubble_collision_path: NodePath

var current_health: float
var _destroyed: bool = false
var _seen_attacks: Dictionary[int, bool] = {}

@onready var _debris_pool: DebrisPool = get_node_or_null(debris_pool_path) as DebrisPool
@onready var _intact_visual: CanvasItem = get_node_or_null(intact_visual_path) as CanvasItem
@onready var _damaged_visual: CanvasItem = get_node_or_null(damaged_visual_path) as CanvasItem
@onready var _rubble_visual: CanvasItem = get_node_or_null(rubble_visual_path) as CanvasItem
@onready var _intact_collision: CollisionShape2D = (
	get_node_or_null(intact_collision_path) as CollisionShape2D
)
@onready var _rubble_collision: CollisionShape2D = (
	get_node_or_null(rubble_collision_path) as CollisionShape2D
)


func _ready() -> void:
	current_health = max_health
	_apply_stage(false, false)


func receive_damage(event: DamageEvent) -> bool:
	if _destroyed or event == null or event.amount <= 0.0:
		return false
	if event.attack_id != 0 and _seen_attacks.has(event.attack_id):
		return false
	if event.attack_id != 0:
		_seen_attacks[event.attack_id] = true
	current_health = maxf(current_health - event.amount, 0.0)
	damaged.emit(current_health, max_health)
	if current_health <= 0.0:
		_break(event)
	else:
		_apply_stage(current_health <= max_health * damaged_stage_ratio, false)
	return true


func is_destroyed() -> bool:
	return _destroyed


func _break(event: DamageEvent) -> void:
	if _destroyed:
		return
	_destroyed = true
	_apply_stage(false, true)
	_release_chunks(event)
	destroyed.emit(event)


func _apply_stage(show_damaged: bool, show_rubble: bool) -> void:
	if _intact_visual != null:
		_intact_visual.visible = not show_damaged and not show_rubble
	if _damaged_visual != null:
		_damaged_visual.visible = show_damaged and not show_rubble
	if _rubble_visual != null:
		_rubble_visual.visible = show_rubble
	if _intact_collision != null:
		_intact_collision.set_deferred("disabled", show_rubble)
	if _rubble_collision != null:
		_rubble_collision.set_deferred("disabled", not show_rubble)


func _release_chunks(event: DamageEvent) -> void:
	if _debris_pool == null or gameplay_chunk_count <= 0:
		return
	var base_direction: Vector2 = event.direction
	if base_direction.is_zero_approx():
		base_direction = (global_position - event.hit_position).normalized()
	if base_direction.is_zero_approx():
		base_direction = Vector2.UP
	var count: int = mini(gameplay_chunk_count, _debris_pool.available_count())
	for chunk_index: int in range(count):
		var weight: float = (float(chunk_index) + 0.5) / float(maxi(count, 1))
		var angle: float = deg_to_rad(lerpf(-chunk_spread_degrees, chunk_spread_degrees, weight))
		var direction: Vector2 = base_direction.rotated(angle)
		direction.y -= 0.35
		direction = direction.normalized()
		var speed_delta: float = event.impulse_per_mass * chunk_impulse_scale
		var transform_offset: Vector2 = direction * (10.0 + 6.0 * float(chunk_index))
		var spawn_transform: Transform2D = Transform2D(
			0.0,
			global_position + transform_offset
		)
		_debris_pool.acquire(
			spawn_transform,
			direction * speed_delta,
			lerpf(-3.0, 3.0, weight)
		)
