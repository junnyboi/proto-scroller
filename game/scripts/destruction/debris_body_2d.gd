class_name DebrisBody2D
extends RigidBody2D

signal recycle_requested(body: DebrisBody2D)

@export_range(0.5, 30.0, 0.5) var hard_lifetime: float = 10.0
@export_range(0.0, 5.0, 0.1) var sleeping_recycle_delay: float = 1.5
@export var max_linear_speed: float = 1000.0
@export var max_angular_speed: float = 14.0

var _age: float = 0.0
var _sleeping_age: float = 0.0
var _active: bool = false
var _body_size: Vector2 = Vector2(36.0, 22.0)
var _material_id: StringName = &"concrete"
var _primary_color: Color = Color("4f4a46")
var _facet_color: Color = Color("786d65")


func _ready() -> void:
	can_sleep = true
	gravity_scale = 1.0
	collision_layer = 1 << 8
	collision_mask = 1 << 0
	_ensure_fallback_shape()
	set_physics_process(false)


func activate(
	spawn_transform: Transform2D,
	linear_impulse: Vector2,
	angular_impulse: float = 0.0,
	body_mass: float = 4.0,
	body_size: Vector2 = Vector2(36.0, 22.0),
	material_kind: StringName = &"concrete",
	primary_color: Color = Color("4f4a46"),
	facet_color: Color = Color("786d65")
) -> void:
	mass = maxf(body_mass, 0.1)
	_body_size = Vector2(maxf(body_size.x, 4.0), maxf(body_size.y, 4.0))
	_material_id = material_kind
	_primary_color = primary_color
	_facet_color = facet_color
	set_meta(&"structural_material", _material_id)
	_apply_body_size()
	global_transform = spawn_transform
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	constant_force = Vector2.ZERO
	constant_torque = 0.0
	freeze = false
	sleeping = false
	_age = 0.0
	_sleeping_age = 0.0
	_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	queue_redraw()
	reset_physics_interpolation()
	apply_central_impulse(linear_impulse)
	if not is_zero_approx(angular_impulse):
		apply_torque_impulse(angular_impulse)


func material_id() -> StringName:
	return _material_id


func deactivate() -> void:
	_active = false
	set_physics_process(false)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	constant_force = Vector2.ZERO
	constant_torque = 0.0
	freeze = true
	sleeping = true
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	_sleeping_age = _sleeping_age + delta if sleeping else 0.0
	if _age >= hard_lifetime or _sleeping_age >= sleeping_recycle_delay:
		recycle_requested.emit(self)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not _active:
		return
	if state.linear_velocity.length() > max_linear_speed:
		state.linear_velocity = state.linear_velocity.limit_length(max_linear_speed)
	state.angular_velocity = clampf(
		state.angular_velocity,
		-max_angular_speed,
		max_angular_speed
	)


func _draw() -> void:
	if _material_id == &"glass":
		_draw_glass_shard()
		return
	if _material_id == &"steel":
		_draw_steel_beam()
		return
	_draw_concrete_chunk()


func _draw_concrete_chunk() -> void:
	var half_size: Vector2 = _body_size * 0.5
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y * 0.45),
		Vector2(-half_size.x * 0.38, -half_size.y),
		Vector2(half_size.x * 0.62, -half_size.y * 0.82),
		Vector2(half_size.x, -half_size.y * 0.22),
		Vector2(half_size.x * 0.74, half_size.y),
		Vector2(-half_size.x * 0.20, half_size.y * 0.78),
		Vector2(-half_size.x, half_size.y * 0.34),
	])
	draw_colored_polygon(outline, _primary_color)
	var facet: PackedVector2Array = PackedVector2Array([
		Vector2(-half_size.x * 0.38, -half_size.y * 0.72),
		Vector2(half_size.x * 0.48, -half_size.y * 0.60),
		Vector2(half_size.x * 0.20, -half_size.y * 0.08),
		Vector2(-half_size.x * 0.62, half_size.y * 0.12),
	])
	draw_colored_polygon(facet, _facet_color)
	draw_line(
		Vector2(-half_size.x * 0.72, half_size.y * 0.22),
		Vector2(half_size.x * 0.62, -half_size.y * 0.38),
		Color("302c2a"),
		maxf(2.0, _body_size.y * 0.12)
	)


func _draw_glass_shard() -> void:
	var half_size: Vector2 = _body_size * 0.5
	var shard: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -half_size.y),
		Vector2(half_size.x, half_size.y * 0.72),
		Vector2(-half_size.x * 0.58, half_size.y),
	])
	draw_colored_polygon(shard, _primary_color)
	draw_polyline(shard, _facet_color, 2.0)
	draw_line(
		Vector2(0.0, -half_size.y * 0.72),
		Vector2(half_size.x * 0.32, half_size.y * 0.48),
		_facet_color,
		1.5
	)


func _draw_steel_beam() -> void:
	var half_size: Vector2 = _body_size * 0.5
	draw_rect(Rect2(-half_size, _body_size), _primary_color, true)
	draw_rect(
		Rect2(
			Vector2(-half_size.x + 3.0, -half_size.y + 3.0),
			Vector2(maxf(_body_size.x - 6.0, 2.0), maxf(_body_size.y - 6.0, 2.0))
		),
		Color("1d2428"),
		true
	)
	draw_line(
		Vector2(-half_size.x, 0.0),
		Vector2(half_size.x, 0.0),
		_facet_color,
		maxf(3.0, _body_size.x * 0.22)
	)


func _ensure_fallback_shape() -> void:
	if get_child_count() > 0:
		return
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(36.0, 22.0)
	shape_node.shape = shape
	add_child(shape_node)
	queue_redraw()


func _apply_body_size() -> void:
	var shape_node: CollisionShape2D = get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape_node == null and get_child_count() > 0:
		shape_node = get_child(0) as CollisionShape2D
	if shape_node == null:
		return
	var rectangle: RectangleShape2D = shape_node.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = _body_size
