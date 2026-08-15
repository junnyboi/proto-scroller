class_name EnemyActor2D
extends CharacterBody2D

signal projectile_requested(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	kind: StringName,
	source: Node
)
signal died(actor: EnemyActor2D)

@export var max_health: float = 60.0

var current_health: float
var target: GiantRobotController
var dead: bool = false
var facing: int = -1
var _seen_attacks: Dictionary[int, bool] = {}

@onready var visual: Sprite2D = get_node_or_null(^"Visual") as Sprite2D


func _ready() -> void:
	current_health = max_health


func set_target(p_target: GiantRobotController) -> void:
	target = p_target


func receive_damage(event: DamageEvent) -> bool:
	if dead or event == null or event.amount <= 0.0:
		return false
	if event.attack_id != 0 and _seen_attacks.has(event.attack_id):
		return false
	if event.attack_id != 0:
		_seen_attacks[event.attack_id] = true
	current_health = maxf(current_health - event.amount, 0.0)
	velocity += event.direction * event.impulse_per_mass * 0.18
	if visual != null:
		visual.modulate = Color("ffd0a6")
		var tween: Tween = create_tween()
		tween.tween_property(visual, "modulate", Color.WHITE, 0.12)
	if current_health <= 0.0:
		_die()
	return true


func request_projectile(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	kind: StringName
) -> void:
	projectile_requested.emit(origin, direction, speed, damage, kind, self)


func _update_facing() -> void:
	if target == null:
		return
	facing = -1 if target.global_position.x < global_position.x else 1
	if visual != null:
		visual.flip_h = facing > 0


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	set_physics_process(false)
	if visual != null:
		visual.modulate = Color("3a3030")
	died.emit(self)
