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
signal died(actor: EnemyActor2D, event: DamageEvent)

@export var max_health: float = 60.0

@export_group("Movement Bounce")
@export var movement_bounce_enabled: bool = false
@export var bounce_height: float = 4.0
@export var bounce_frequency: float = 3.5
@export var bounce_squash: float = 0.04
@export var bounce_speed_reference: float = 90.0

var current_health: float
var target: GiantRobotController
var dead: bool = false
var facing: int = -1
var visual_ground_offset: float = 0.0
var _seen_attacks: Dictionary[int, bool] = {}
var _bounce_phase: float = 0.0
var _visual_rest_position: Vector2
var _visual_rest_scale: Vector2 = Vector2.ONE

@onready var visual: Sprite2D = get_node_or_null(^"Visual") as Sprite2D


func _ready() -> void:
	current_health = max_health
	if visual != null:
		_visual_rest_position = visual.position
		_visual_rest_scale = visual.scale


func update_movement_bounce(delta: float) -> void:
	if visual == null:
		return
	var speed_ratio: float = clampf(
		absf(velocity.x) / maxf(bounce_speed_reference, 1.0),
		0.0,
		1.0
	)
	if movement_bounce_enabled and speed_ratio > 0.08 and is_on_floor():
		_bounce_phase = fmod(
			_bounce_phase + delta * TAU * bounce_frequency * lerpf(0.75, 1.0, speed_ratio),
			TAU
		)
		var hop: float = absf(sin(_bounce_phase))
		var contact: float = absf(cos(_bounce_phase))
		visual.position.y = _visual_rest_position.y - hop * bounce_height * speed_ratio
		visual.scale = Vector2(
			_visual_rest_scale.x * (1.0 + contact * bounce_squash * speed_ratio),
			_visual_rest_scale.y * (1.0 - contact * bounce_squash * speed_ratio)
		)
		visual.rotation = sin(_bounce_phase * 0.5) * 0.018 * float(facing)
		return
	_bounce_phase = 0.0
	visual.position = visual.position.move_toward(_visual_rest_position, 30.0 * delta)
	visual.scale = visual.scale.move_toward(_visual_rest_scale, 0.8 * delta)
	visual.rotation = move_toward(visual.rotation, 0.0, 0.3 * delta)


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
		_die(event)
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


func _die(event: DamageEvent) -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	set_physics_process(false)
	if visual != null:
		visual.visible = false
	died.emit(self, event)
