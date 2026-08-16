class_name Projectile2D
extends CharacterBody2D

signal recycle_requested(projectile: Projectile2D)

static var _next_attack_id: int = 10000

var damage: float = 10.0
var source: Node
var lifetime: float = 2.5
var projectile_color: Color = Color("ffb45e")
var projectile_radius: float = 5.0
var damage_type: StringName = &"projectile"
var active: bool = false
var _attack_id: int


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_build_collision()
	queue_redraw()


func setup(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	p_damage: float,
	p_source: Node,
	target_mask: int,
	kind: StringName = &"bullet"
) -> void:
	activate(origin, direction, speed, p_damage, p_source, target_mask, kind)


func activate(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	p_damage: float,
	p_source: Node,
	target_mask: int,
	kind: StringName = &"bullet"
) -> void:
	_next_attack_id += 1
	_attack_id = _next_attack_id
	active = true
	visible = true
	set_physics_process(true)
	lifetime = 2.5
	global_position = origin
	velocity = direction.normalized() * speed
	damage = p_damage
	source = p_source
	collision_layer = 0
	collision_mask = target_mask
	damage_type = kind
	if kind == &"shell":
		projectile_radius = 9.0
		projectile_color = Color("ff7d3e")
	elif kind == &"rocket":
		projectile_radius = 7.0
		projectile_color = Color("ff9d52")
	else:
		projectile_radius = 5.0
		projectile_color = Color("ffb45e")
	var collision: CollisionShape2D = get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		(collision.shape as CircleShape2D).radius = maxf(projectile_radius, 5.0)
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false
	set_physics_process(false)
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	source = null
	lifetime = 2.5


func _physics_process(delta: float) -> void:
	if not active:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		recycle_requested.emit(self)
		return
	var collision: KinematicCollision2D = move_and_collide(velocity * delta)
	if collision == null:
		return
	_deliver_damage(collision.get_collider() as Object, collision.get_position())
	recycle_requested.emit(self)


func _draw() -> void:
	var trail: float = maxf(14.0, projectile_radius * 3.0)
	var backward: Vector2 = -velocity.normalized() * trail
	draw_line(Vector2.ZERO, backward, projectile_color.darkened(0.35), projectile_radius)
	draw_circle(Vector2.ZERO, projectile_radius, projectile_color)


func _build_collision() -> void:
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = maxf(projectile_radius, 5.0)
	shape_node.shape = shape
	add_child(shape_node)


func _deliver_damage(collider: Object, hit_position: Vector2) -> void:
	var receiver: Node = collider as Node
	while receiver != null:
		if receiver.has_method("receive_damage"):
			var event: DamageEvent = DamageEvent.new(
				_attack_id,
				source,
				damage,
				damage_type,
				hit_position,
				velocity.normalized(),
				0.0
			)
			receiver.call("receive_damage", event)
			return
		receiver = receiver.get_parent()
