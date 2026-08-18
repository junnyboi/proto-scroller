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
var active: bool = true
var activation_generation: int = 0
var telegraph_presenter: TelegraphPresenter2D
var projectile_pool: ProjectilePool
var projectile_target_mask: int = 0
var facing: int = -1
var visual_ground_offset: float = 0.0
var _seen_attacks: Dictionary[int, bool] = {}
var _bounce_phase: float = 0.0
var _visual_rest_position: Vector2
var _visual_rest_scale: Vector2 = Vector2.ONE
var _base_collision_layer: int = 0
var _base_collision_mask: int = 0
var _telegraph_id: int = 0
var _telegraph_remaining: float = 0.0
var _telegraph_kind: StringName = &""
var _telegraph_origin: Vector2 = Vector2.ZERO
var _telegraph_target: Vector2 = Vector2.ZERO
var _projectile_reservation_id: int = 0

@onready var visual: Sprite2D = get_node_or_null(^"Visual") as Sprite2D


func _ready() -> void:
	_base_collision_layer = collision_layer
	_base_collision_mask = collision_mask
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
	if not active or dead or event == null or event.amount <= 0.0:
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


func activate(spawn_position: Vector2, p_target: GiantRobotController) -> void:
	activation_generation += 1
	active = true
	dead = false
	visible = true
	global_position = spawn_position
	velocity = Vector2.ZERO
	current_health = max_health
	target = p_target
	collision_layer = _base_collision_layer
	collision_mask = _base_collision_mask
	_seen_attacks.clear()
	set_physics_process(true)
	if visual != null:
		visual.visible = true
		visual.modulate = Color.WHITE
		visual.position = _visual_rest_position
		visual.scale = _visual_rest_scale
		visual.rotation = 0.0
	_reset_archetype_state()


func deactivate() -> void:
	cancel_telegraph()
	active = false
	dead = false
	visible = false
	target = null
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	global_position = Vector2(-4096.0, -4096.0)


func begin_telegraph(
	kind: StringName,
	duration: float,
	origin: Vector2,
	target_point: Vector2
) -> bool:
	if telegraph_presenter == null or _telegraph_id != 0:
		return false
	if kind in [&"shell", &"rocket"] and projectile_pool != null:
		_projectile_reservation_id = projectile_pool.reserve(kind)
		if _projectile_reservation_id == 0:
			return false
	_telegraph_id = telegraph_presenter.reserve(self, kind, origin, target_point, duration)
	if _telegraph_id == 0:
		if projectile_pool != null and _projectile_reservation_id != 0:
			projectile_pool.cancel_reservation(_projectile_reservation_id)
			_projectile_reservation_id = 0
		return false
	_telegraph_kind = kind
	_telegraph_remaining = duration
	_telegraph_origin = origin
	_telegraph_target = target_point
	return true


func advance_telegraph(delta: float) -> bool:
	if _telegraph_id == 0:
		return false
	_telegraph_remaining = maxf(_telegraph_remaining - delta, 0.0)
	return is_zero_approx(_telegraph_remaining)


func telegraph_origin() -> Vector2:
	return _telegraph_origin


func telegraph_direction() -> Vector2:
	return _telegraph_origin.direction_to(_telegraph_target)


func fire_telegraphed_projectile(speed: float, damage: float) -> Projectile2D:
	var projectile: Projectile2D
	if projectile_pool != null and _projectile_reservation_id != 0:
		projectile = projectile_pool.acquire_reserved(
			_projectile_reservation_id,
			_telegraph_origin,
			telegraph_direction(),
			speed,
			damage,
			self,
			projectile_target_mask,
			_telegraph_kind
		)
	else:
		request_projectile(
			_telegraph_origin,
			telegraph_direction(),
			speed,
			damage,
			_telegraph_kind
		)
	_projectile_reservation_id = 0
	finish_telegraph()
	return projectile


func cancel_telegraph() -> void:
	if telegraph_presenter != null and _telegraph_id != 0:
		telegraph_presenter.cancel(_telegraph_id)
	if projectile_pool != null and _projectile_reservation_id != 0:
		projectile_pool.cancel_reservation(_projectile_reservation_id)
	_projectile_reservation_id = 0
	_telegraph_id = 0
	_telegraph_remaining = 0.0
	_telegraph_kind = &""


func finish_telegraph() -> void:
	cancel_telegraph()


func is_telegraphing() -> bool:
	return _telegraph_id != 0


func _reset_archetype_state() -> void:
	pass


func _update_facing() -> void:
	if target == null:
		return
	facing = -1 if target.global_position.x < global_position.x else 1
	if visual != null:
		visual.flip_h = facing > 0


func _die(event: DamageEvent) -> void:
	dead = true
	cancel_telegraph()
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	set_physics_process(false)
	if visual != null:
		visual.visible = false
	died.emit(self, event)
