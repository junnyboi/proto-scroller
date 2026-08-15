class_name EnemyWreck2D
extends RigidBody2D

signal scrapped(wreck: EnemyWreck2D, event: DamageEvent)

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
var _seen_attacks: Dictionary[int, bool] = {}
var _steel_profile: StructuralMaterialProfile


func _ready() -> void:
	current_scrap_health = scrap_health
	_steel_profile = StructuralMaterialProfile.steel()
	collision_layer = REMAINS_LAYER
	collision_mask = REMAINS_GROUND_LAYER | REMAINS_LAYER
	gravity_scale = 1.0
	linear_damp = 0.9
	angular_damp = 1.5
	can_sleep = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	z_index = 29
	set_meta(&"enemy_remains", wreck_kind)
	_build_collision()
	_build_visual()
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
	visual.texture = wreck_texture
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if wreck_texture != null:
		var texture_size: Vector2 = wreck_texture.get_size()
		var fit_scale: float = minf(
			display_size.x / maxf(texture_size.x, 1.0),
			display_size.y / maxf(texture_size.y, 1.0)
		)
		visual.scale = Vector2.ONE * fit_scale
	visual.modulate = Color("625d58")
	visual.position.y = (collision_size.y - display_size.y) * 0.5
	add_child(visual)


func _apply_fatal_impact() -> void:
	var direction: Vector2 = Vector2.RIGHT
	var impulse_per_mass: float = 150.0
	if fatal_event != null:
		direction = fatal_event.direction
		impulse_per_mass = maxf(fatal_event.impulse_per_mass, 150.0)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var impulse: Vector2 = (
		direction * impulse_per_mass * mass * 0.24
		+ Vector2.UP * mass * impulse_per_mass * 0.10
	)
	linear_velocity = impulse / mass
	angular_velocity = direction.x * clampf(impulse_per_mass / 40.0, 3.0, 8.0)


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
