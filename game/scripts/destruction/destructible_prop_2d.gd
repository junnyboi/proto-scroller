class_name DestructibleProp2D
extends RigidBody2D

signal destroyed(prop: DestructibleProp2D, event: DamageEvent)

const REMAINS_LAYER: int = 1 << 9
const WORLD_LAYER: int = 1 << 0

@export var max_health: float = 60.0
@export var intact_texture: Texture2D
@export var destroyed_texture: Texture2D
@export var intact_display_size: Vector2 = Vector2(150.0, 80.0)
@export var destroyed_display_size: Vector2 = Vector2(160.0, 80.0)
@export var destroyed_collision_size: Vector2 = Vector2(130.0, 50.0)
@export var visual_ground_offset: float = 0.0

var current_health: float
var is_broken: bool = false
var _seen_attacks: Dictionary[int, bool] = {}

@onready var visual: Sprite2D = get_node(^"Visual") as Sprite2D
@onready var collision_shape: CollisionShape2D = get_node(^"CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	current_health = max_health
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true
	can_sleep = true
	visual.texture = intact_texture
	_fit_visual(intact_display_size)


func receive_damage(event: DamageEvent) -> bool:
	if is_broken or event == null or event.amount <= 0.0:
		return false
	if event.attack_id != 0 and _seen_attacks.has(event.attack_id):
		return false
	if event.attack_id != 0:
		_seen_attacks[event.attack_id] = true
	current_health = maxf(current_health - event.amount, 0.0)
	if current_health <= 0.0:
		_break_prop(event)
	return true


func _break_prop(event: DamageEvent) -> void:
	is_broken = true
	visual.texture = destroyed_texture
	_fit_visual(destroyed_display_size)
	collision_layer = REMAINS_LAYER
	collision_mask = WORLD_LAYER
	set_meta(&"enemy_remains", &"destroyed_prop")
	freeze = false
	sleeping = false
	call_deferred("_apply_destroyed_collision")
	destroyed.emit(self, event)


func _apply_destroyed_collision() -> void:
	var rectangle: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = destroyed_collision_size


func _fit_visual(display_size: Vector2) -> void:
	if visual.texture == null:
		return
	var texture_size: Vector2 = visual.texture.get_size()
	var fit_scale: float = minf(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	visual.scale = Vector2.ONE * fit_scale
	visual.position.y = visual_ground_offset - texture_size.y * fit_scale * 0.5
