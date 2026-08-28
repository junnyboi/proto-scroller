class_name EnemyWreck2D
extends RigidBody2D

signal scrapped(wreck: EnemyWreck2D, event: DamageEvent)
signal crash_landed(wreck: EnemyWreck2D)
signal crash_impact_accepted(wreck: EnemyWreck2D, event: DamageEvent, target: Node)

const ENEMY_LAYER: int = 1 << 2
const BUILDING_LAYER: int = 1 << 3
const PROP_LAYER: int = 1 << 7
const ROBOT_LAYER: int = 1 << 1
const REMAINS_LAYER: int = 1 << 9
const REMAINS_GROUND_LAYER: int = 1 << 10
const MIN_CRASH_IMPACT_SPEED: float = 220.0
const MAX_CRASH_IMPACT_DAMAGE: float = 180.0
const CRASH_IMPACT_DAMAGE_SCALE: float = 0.12
const PLAYER_ATTACK_KNOCKBACK_SCALE: float = 1.10
const NON_PLAYER_KNOCKBACK_SCALE: float = 0.32

static var _next_crash_attack_id: int = 2_000_000

@export var scrap_health: float = 120.0
@export var wreck_kind: StringName = &"machinery"

var current_scrap_health: float
var scrapped_state: bool = false
var display_size: Vector2 = Vector2(220.0, 90.0)
var collision_size: Vector2 = Vector2(205.0, 72.0)
var wreck_texture: Texture2D
var fatal_event: DamageEvent
var airborne_crash: bool = false
var crash_landing_count: int = 0
var crash_impact_count: int = 0
var finisher_requires_ground_smash: bool = false
var finisher_damage_types: PackedStringArray = PackedStringArray()
var _seen_attacks: Dictionary[int, bool] = {}
var _seen_root_attacks: Dictionary[int, bool] = {}
var _finisher_receiver_active: bool = true
var _crash_attack_id: int = 0
var _crash_impact_targets: Dictionary[int, bool] = {}
var _last_crash_velocity: Vector2 = Vector2.ZERO
var _steel_profile: StructuralMaterialProfile
var _crucible_captured: bool = false
var _crucible_armed: bool = false
var _crucible_source: Node
var _crucible_root_attack_id: int = 0
var _crucible_delivery_id: int = 0
var _crucible_damage: float = 0.0
var _crucible_effect_flags: int = DamageEvent.FLAG_NONE
var _capture_linear_velocity: Vector2 = Vector2.ZERO
var _capture_angular_velocity: float = 0.0
var _capture_collision_layer: int = 0
var _capture_collision_mask: int = 0
var _capture_gravity_scale: float = 1.0
var _capture_linear_damp: float = 0.0
var _capture_angular_damp: float = 0.0
var _capture_can_sleep: bool = true
var _capture_shape_disabled: bool = false


func _ready() -> void:
	_steel_profile = StructuralMaterialProfile.steel()
	gravity_scale = 1.0
	linear_damp = 0.9
	angular_damp = 1.5
	can_sleep = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	z_index = 29
	_build_collision()
	_build_visual()
	deactivate()


func activate(
	p_wreck_kind: StringName,
	p_wreck_texture: Texture2D,
	p_display_size: Vector2,
	p_collision_size: Vector2,
	p_mass: float,
	p_scrap_health: float,
	spawn_position: Vector2,
	p_fatal_event: DamageEvent,
	p_airborne_crash: bool = false,
	p_finisher_requires_ground_smash: bool = false
) -> void:
	wreck_kind = p_wreck_kind
	wreck_texture = p_wreck_texture
	display_size = p_display_size
	collision_size = p_collision_size
	mass = p_mass
	scrap_health = p_scrap_health
	current_scrap_health = scrap_health
	fatal_event = p_fatal_event
	airborne_crash = p_airborne_crash
	crash_landing_count = 0
	crash_impact_count = 0
	configure_finisher_policy(p_finisher_requires_ground_smash, p_fatal_event)
	_crash_impact_targets.clear()
	_crash_attack_id = _allocate_crash_attack_id() if airborne_crash else 0
	_last_crash_velocity = Vector2.ZERO
	scrapped_state = false
	visible = true
	freeze = false
	sleeping = false
	gravity_scale = 1.45 if airborne_crash else 1.0
	linear_damp = 0.25 if airborne_crash else 0.9
	angular_damp = 0.45 if airborne_crash else 1.5
	can_sleep = not airborne_crash
	global_position = spawn_position
	rotation = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	collision_layer = REMAINS_LAYER
	collision_mask = REMAINS_GROUND_LAYER | ROBOT_LAYER
	if airborne_crash:
		collision_mask |= ENEMY_LAYER
	set_meta(&"enemy_remains", wreck_kind)
	var collision: CollisionShape2D = get_node(^"WreckCollision") as CollisionShape2D
	(collision.shape as RectangleShape2D).size = collision_size
	collision.set_deferred(&"disabled", false)
	_update_visual()
	_apply_fatal_impact()


func deactivate(preserve_scrapped: bool = false) -> void:
	_crucible_captured = false
	_clear_crucible_delivery()
	visible = false
	freeze = true
	sleeping = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	airborne_crash = false
	crash_impact_count = 0
	finisher_requires_ground_smash = false
	finisher_damage_types = PackedStringArray()
	_finisher_receiver_active = false
	_seen_attacks.clear()
	_seen_root_attacks.clear()
	_crash_attack_id = 0
	_crash_impact_targets.clear()
	_last_crash_velocity = Vector2.ZERO
	gravity_scale = 1.0
	linear_damp = 0.9
	angular_damp = 1.5
	can_sleep = true
	if not preserve_scrapped:
		scrapped_state = false
	var collision: CollisionShape2D = get_node_or_null(^"WreckCollision") as CollisionShape2D
	if collision != null:
		collision.set_deferred(&"disabled", true)
	_apply_fatal_impact()


func receive_damage(event: DamageEvent) -> bool:
	if (
		scrapped_state
		or not _finisher_receiver_active
		or event == null
		or event.amount <= 0.0
	):
		return false
	if finisher_requires_ground_smash and event.damage_type != &"ground_smash":
		return false
	if not finisher_damage_types.is_empty() and not finisher_damage_types.has(event.damage_type):
		return false
	if event.attack_id != 0 and _seen_attacks.has(event.attack_id):
		return false
	if event.root_attack_id != 0 and _seen_root_attacks.has(event.root_attack_id):
		return false
	if event.attack_id != 0:
		_seen_attacks[event.attack_id] = true
	if event.root_attack_id != 0:
		_seen_root_attacks[event.root_attack_id] = true
	current_scrap_health = maxf(current_scrap_health - event.amount, 0.0)
	var direction: Vector2 = event.direction
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var knockback_scale: float = (
		PLAYER_ATTACK_KNOCKBACK_SCALE
		if event.source is GiantRobotController
		else NON_PLAYER_KNOCKBACK_SCALE
	)
	apply_central_impulse(direction * event.impulse_per_mass * mass * knockback_scale)
	apply_torque_impulse(
		direction.x * event.impulse_per_mass * mass * knockback_scale * 0.5
	)
	if current_scrap_health <= 0.0:
		_turn_to_scrap(event)
	return true


func configure_finisher_policy(
	requires_ground_smash: bool,
	p_fatal_event: DamageEvent = fatal_event,
	allowed_damage_types: PackedStringArray = PackedStringArray()
) -> void:
	finisher_requires_ground_smash = requires_ground_smash
	finisher_damage_types = allowed_damage_types.duplicate()
	_seen_attacks.clear()
	_seen_root_attacks.clear()
	if p_fatal_event != null:
		if p_fatal_event.attack_id != 0:
			_seen_attacks[p_fatal_event.attack_id] = true
		if p_fatal_event.root_attack_id != 0:
			_seen_root_attacks[p_fatal_event.root_attack_id] = true
	_finisher_receiver_active = true


func configure_one_hit_melee_finisher(p_fatal_event: DamageEvent = fatal_event) -> void:
	scrap_health = 1.0
	current_scrap_health = 1.0
	configure_finisher_policy(
		false,
		p_fatal_event,
		PackedStringArray(["jab_cross", "ground_smash"])
	)


func configure_automatic_scrap() -> void:
	finisher_requires_ground_smash = false
	finisher_damage_types = PackedStringArray()
	_seen_attacks.clear()
	_seen_root_attacks.clear()
	_finisher_receiver_active = false
	collision_layer = 0


func scrap_automatically(event: DamageEvent) -> bool:
	if scrapped_state or event == null:
		return false
	_finisher_receiver_active = false
	current_scrap_health = 0.0
	_turn_to_scrap(event)
	return true


func set_wreck_visual_visible(visible_value: bool) -> void:
	var visual: Sprite2D = get_node_or_null(^"WreckVisual") as Sprite2D
	if visual != null:
		visual.visible = visible_value


func get_material_profile() -> StructuralMaterialProfile:
	return _steel_profile


func is_scrapped() -> bool:
	return scrapped_state


func is_crashing() -> bool:
	return airborne_crash


func is_crucible_captured() -> bool:
	return _crucible_captured


func is_crucible_eligible() -> bool:
	return (
		visible
		and not scrapped_state
		and not airborne_crash
		and not _crucible_captured
		and collision_layer != 0
		and not bool(get_meta(&"boss_wreck", false))
	)


func begin_crucible_capture() -> bool:
	if not is_crucible_eligible():
		return false
	var collision: CollisionShape2D = get_node_or_null(^"WreckCollision") as CollisionShape2D
	_capture_linear_velocity = linear_velocity
	_capture_angular_velocity = angular_velocity
	_capture_collision_layer = collision_layer
	_capture_collision_mask = collision_mask
	_capture_gravity_scale = gravity_scale
	_capture_linear_damp = linear_damp
	_capture_angular_damp = angular_damp
	_capture_can_sleep = can_sleep
	_capture_shape_disabled = collision.disabled if collision != null else false
	_crucible_captured = true
	_clear_crucible_delivery()
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	gravity_scale = 0.0
	freeze = true
	sleeping = true
	collision_layer = 0
	collision_mask = 0
	if collision != null:
		collision.set_deferred(&"disabled", true)
	return true


func update_crucible_capture(position_value: Vector2, rotation_value: float) -> void:
	if not _crucible_captured:
		return
	global_position = position_value
	rotation = rotation_value


func cancel_crucible_capture() -> void:
	if not _crucible_captured:
		return
	_restore_after_crucible(_capture_linear_velocity, _capture_angular_velocity)
	_clear_crucible_delivery()


func release_from_crucible(
	launch_velocity: Vector2,
	launch_angular_velocity: float,
	source_event: DamageEvent,
	damage: float,
	delivery_id: int
) -> bool:
	if not _crucible_captured or source_event == null:
		return false
	_restore_after_crucible(launch_velocity, launch_angular_velocity)
	_crucible_source = source_event.source
	_crucible_root_attack_id = source_event.root_attack_id
	_crucible_delivery_id = delivery_id
	_crucible_damage = maxf(damage, 0.0)
	_crucible_effect_flags = (
		source_event.effect_flags | DamageEvent.FLAG_GRAVITY_CRUCIBLE
	)
	_crucible_armed = _crucible_damage > 0.0 and delivery_id != 0
	if _crucible_armed:
		collision_mask = _capture_collision_mask | ENEMY_LAYER
	return _crucible_armed


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if airborne_crash and state.linear_velocity.length() >= MIN_CRASH_IMPACT_SPEED:
		_last_crash_velocity = state.linear_velocity


func _build_collision() -> void:
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "WreckCollision"
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = collision_size
	collision.shape = rectangle
	add_child(collision)


func _build_visual() -> void:
	var visual: Sprite2D = Sprite2D.new()
	visual.name = "WreckVisual"
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(visual)
	_update_visual()


func _update_visual() -> void:
	var visual: Sprite2D = get_node_or_null(^"WreckVisual") as Sprite2D
	if visual == null:
		return
	visual.texture = wreck_texture
	if wreck_texture != null:
		var texture_size: Vector2 = wreck_texture.get_size()
		var fit_scale: float = minf(
			display_size.x / maxf(texture_size.x, 1.0),
			display_size.y / maxf(texture_size.y, 1.0)
		)
		visual.scale = Vector2.ONE * fit_scale
	visual.modulate = Color("625d58")
	visual.position.y = (collision_size.y - display_size.y) * 0.5
	visual.visible = true


func _apply_fatal_impact() -> void:
	var direction: Vector2 = Vector2.RIGHT
	var impulse_per_mass: float = 150.0
	if fatal_event != null:
		direction = fatal_event.direction
		impulse_per_mass = maxf(fatal_event.impulse_per_mass, 150.0)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	if airborne_crash:
		linear_velocity = Vector2(
			direction.x * impulse_per_mass * 0.34,
			maxf(185.0, absf(direction.y) * impulse_per_mass + 120.0)
		)
		angular_velocity = direction.x * clampf(impulse_per_mass / 28.0, 5.0, 11.0)
		return
	var impulse: Vector2 = (
		direction * impulse_per_mass * mass * 0.24
		+ Vector2.UP * mass * impulse_per_mass * 0.10
	)
	linear_velocity = impulse / mass
	angular_velocity = direction.x * clampf(impulse_per_mass / 40.0, 3.0, 8.0)


func _on_body_entered(body: Node) -> void:
	if _crucible_armed:
		_resolve_crucible_impact(body)
		return
	if not airborne_crash or not body is CollisionObject2D:
		return
	var collision_body: CollisionObject2D = body as CollisionObject2D
	if collision_body.collision_layer & REMAINS_GROUND_LAYER != 0:
		_finish_crash_landing()
		return
	if collision_body.collision_layer & ENEMY_LAYER != 0:
		_queue_crash_damage(body)


func _queue_crash_damage(body: Node) -> void:
	var receiver: Node = _find_damage_receiver(body)
	if receiver == null or receiver == self:
		return
	var target_id: int = receiver.get_instance_id()
	if _crash_impact_targets.has(target_id):
		return
	var target_velocity: Vector2 = (
		(receiver as EnemyActor2D).velocity if receiver is EnemyActor2D else Vector2.ZERO
	)
	var impact_velocity: Vector2 = _last_crash_velocity - target_velocity
	var impact_speed: float = impact_velocity.length()
	if impact_speed < MIN_CRASH_IMPACT_SPEED:
		return
	_crash_impact_targets[target_id] = true
	call_deferred("_apply_crash_damage", receiver, impact_velocity)


func _apply_crash_damage(receiver: Node, impact_velocity: Vector2) -> void:
	if not is_instance_valid(receiver):
		return
	var impact_speed: float = impact_velocity.length()
	var mass_scale: float = clampf(sqrt(mass / 38.0), 0.7, 2.3)
	var damage: float = clampf(
		35.0
		+ (impact_speed - MIN_CRASH_IMPACT_SPEED)
		* CRASH_IMPACT_DAMAGE_SCALE
		* mass_scale,
		35.0,
		MAX_CRASH_IMPACT_DAMAGE
	)
	var direction: Vector2 = impact_velocity.normalized()
	if direction.is_zero_approx():
		direction = Vector2.DOWN
	var root_attack_id: int = (
		fatal_event.root_attack_id if fatal_event != null else _crash_attack_id
	)
	var causal_depth: int = (
		mini(fatal_event.causal_depth + 1, DamageEvent.MAX_CAUSAL_DEPTH)
		if fatal_event != null
		else 1
	)
	var event: DamageEvent = DamageEvent.new(
		_crash_attack_id,
		self,
		damage,
		&"crash_impact",
		global_position,
		direction,
		impact_speed * 0.55,
		root_attack_id,
		causal_depth,
		DamageEvent.FLAG_HAZARD
	)
	if bool(receiver.call("receive_damage", event)):
		crash_impact_count += 1
		crash_impact_accepted.emit(self, event, receiver)


func _finish_crash_landing() -> void:
	airborne_crash = false
	crash_landing_count += 1
	gravity_scale = 1.0
	linear_damp = 1.1
	angular_damp = 1.8
	can_sleep = true
	collision_mask = REMAINS_GROUND_LAYER | ROBOT_LAYER
	_last_crash_velocity = Vector2.ZERO
	crash_landed.emit(self)


func _resolve_crucible_impact(body: Node) -> void:
	var receiver: EnemyActor2D = _find_damage_receiver(body) as EnemyActor2D
	if receiver == null or not receiver.active or receiver.dead:
		return
	var relative_velocity: Vector2 = linear_velocity - receiver.velocity
	if relative_velocity.length() < MIN_CRASH_IMPACT_SPEED:
		return
	var direction: Vector2 = relative_velocity.normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var event: DamageEvent = DamageEvent.new(
		_crucible_delivery_id,
		_crucible_source,
		_crucible_damage,
		&"debris_impact",
		global_position,
		direction,
		relative_velocity.length() * 0.45,
		_crucible_root_attack_id,
		1,
		_crucible_effect_flags
	)
	_clear_crucible_delivery()
	if receiver.receive_damage(event):
		crash_impact_count += 1
		crash_impact_accepted.emit(self, event, receiver)


func _find_damage_receiver(start_node: Node) -> Node:
	var receiver: Node = start_node
	while receiver != null:
		if receiver.has_method("receive_damage"):
			return receiver
		receiver = receiver.get_parent()
	return null


func _restore_after_crucible(
	restored_velocity: Vector2,
	restored_angular_velocity: float
) -> void:
	_crucible_captured = false
	freeze = false
	sleeping = false
	gravity_scale = _capture_gravity_scale
	linear_damp = _capture_linear_damp
	angular_damp = _capture_angular_damp
	can_sleep = _capture_can_sleep
	collision_layer = _capture_collision_layer
	collision_mask = _capture_collision_mask
	var collision: CollisionShape2D = get_node_or_null(^"WreckCollision") as CollisionShape2D
	if collision != null:
		collision.set_deferred(&"disabled", _capture_shape_disabled)
	linear_velocity = restored_velocity
	angular_velocity = restored_angular_velocity
	reset_physics_interpolation()


func _clear_crucible_delivery() -> void:
	_crucible_armed = false
	_crucible_source = null
	_crucible_root_attack_id = 0
	_crucible_delivery_id = 0
	_crucible_damage = 0.0
	_crucible_effect_flags = DamageEvent.FLAG_NONE
	if not _crucible_captured and collision_layer != 0:
		collision_mask = _capture_collision_mask


static func _allocate_crash_attack_id() -> int:
	_next_crash_attack_id += 1
	return _next_crash_attack_id


func _turn_to_scrap(event: DamageEvent) -> void:
	scrapped_state = true
	freeze = true
	collision_layer = 0
	collision_mask = 0
	var collision: CollisionShape2D = get_node(^"WreckCollision") as CollisionShape2D
	collision.set_deferred(&"disabled", true)
	var visual: Sprite2D = get_node(^"WreckVisual") as Sprite2D
	visual.visible = false
	scrapped.emit(self, event)
