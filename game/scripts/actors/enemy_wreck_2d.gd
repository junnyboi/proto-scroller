class_name EnemyWreck2D
extends RigidBody2D

signal scrapped(wreck: EnemyWreck2D, event: DamageEvent)
signal crash_landed(wreck: EnemyWreck2D)

const REMAINS_LAYER: int = 1 << 9
const REMAINS_GROUND_LAYER: int = 1 << 10

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
var _seen_attacks: Dictionary[int, bool] = {}
var _steel_profile: StructuralMaterialProfile


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
	p_airborne_crash: bool = false
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
	_seen_attacks.clear()
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
	collision_mask = REMAINS_GROUND_LAYER | REMAINS_LAYER
	set_meta(&"enemy_remains", wreck_kind)
	var collision: CollisionShape2D = get_node(^"WreckCollision") as CollisionShape2D
	(collision.shape as RectangleShape2D).size = collision_size
	collision.set_deferred(&"disabled", false)
	_update_visual()
	_apply_fatal_impact()


func deactivate(preserve_scrapped: bool = false) -> void:
	visible = false
	freeze = true
	sleeping = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	airborne_crash = false
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
	if scrapped_state or event == null or event.amount <= 0.0:
		return false
	if event.attack_id != 0 and _seen_attacks.has(event.attack_id):
		return false
	if event.attack_id != 0:
		_seen_attacks[event.attack_id] = true
	current_scrap_health = maxf(current_scrap_health - event.amount, 0.0)
	var direction: Vector2 = event.direction
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	apply_central_impulse(direction * event.impulse_per_mass * mass * 0.32)
	apply_torque_impulse(direction.x * event.impulse_per_mass * mass * 0.16)
	if current_scrap_health <= 0.0:
		_turn_to_scrap(event)
	return true


func get_material_profile() -> StructuralMaterialProfile:
	return _steel_profile


func is_scrapped() -> bool:
	return scrapped_state


func is_crashing() -> bool:
	return airborne_crash


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
	if not airborne_crash or not body is CollisionObject2D:
		return
	var collision_body: CollisionObject2D = body as CollisionObject2D
	if collision_body.collision_layer & REMAINS_GROUND_LAYER == 0:
		return
	airborne_crash = false
	crash_landing_count += 1
	gravity_scale = 1.0
	linear_damp = 1.1
	angular_damp = 1.8
	can_sleep = true
	crash_landed.emit(self)


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
