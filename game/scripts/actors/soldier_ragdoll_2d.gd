class_name SoldierRagdoll2D
extends Node2D

const REMAINS_LAYER: int = 1 << 9
const REMAINS_GROUND_LAYER: int = 1 << 10
const ROBOT_LAYER: int = 1 << 1

var pieces: Array[RigidBody2D] = []
var joints: Array[PinJoint2D] = []
var _facing: int = -1
var _impact_event: DamageEvent


func setup(
	world_position: Vector2,
	facing: int,
	impact_event: DamageEvent
) -> void:
	global_position = world_position
	_facing = facing
	_impact_event = impact_event


func _ready() -> void:
	z_index = 28
	_build_ragdoll()
	_apply_fatal_impact()


func piece_count() -> int:
	return pieces.size()


func joint_count() -> int:
	return joints.size()


func average_speed() -> float:
	if pieces.is_empty():
		return 0.0
	var total: float = 0.0
	for piece: RigidBody2D in pieces:
		total += piece.linear_velocity.length()
	return total / float(pieces.size())


func _build_ragdoll() -> void:
	var torso: RigidBody2D = _create_box_piece(
		"Torso",
		Vector2(0.0, -44.0),
		Vector2(24.0, 36.0),
		8.0,
		Color("46503d")
	)
	var head: RigidBody2D = _create_circle_piece(
		"Head",
		Vector2(0.0, -73.0),
		11.0,
		2.2,
		Color("a88d72")
	)
	var left_arm: RigidBody2D = _create_box_piece(
		"LeftArm",
		Vector2(-19.0, -43.0),
		Vector2(10.0, 31.0),
		3.0,
		Color("3e4938")
	)
	var right_arm: RigidBody2D = _create_box_piece(
		"RightArm",
		Vector2(19.0, -43.0),
		Vector2(10.0, 31.0),
		3.0,
		Color("3e4938")
	)
	var left_leg: RigidBody2D = _create_box_piece(
		"LeftLeg",
		Vector2(-8.0, -12.0),
		Vector2(11.0, 35.0),
		5.0,
		Color("30382f")
	)
	var right_leg: RigidBody2D = _create_box_piece(
		"RightLeg",
		Vector2(8.0, -12.0),
		Vector2(11.0, 35.0),
		5.0,
		Color("30382f")
	)
	_create_joint("NeckJoint", torso, head, Vector2(0.0, -61.0))
	_create_joint("LeftShoulderJoint", torso, left_arm, Vector2(-13.0, -52.0))
	_create_joint("RightShoulderJoint", torso, right_arm, Vector2(13.0, -52.0))
	_create_joint("LeftHipJoint", torso, left_leg, Vector2(-8.0, -27.0))
	_create_joint("RightHipJoint", torso, right_leg, Vector2(8.0, -27.0))


func _create_box_piece(
	piece_name: String,
	local_position: Vector2,
	size: Vector2,
	body_mass: float,
	color: Color
) -> RigidBody2D:
	var body: RigidBody2D = _create_body(piece_name, local_position, body_mass)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	body.add_child(collision)
	var visual: Polygon2D = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5),
	])
	visual.color = color
	body.add_child(visual)
	return body


func _create_circle_piece(
	piece_name: String,
	local_position: Vector2,
	radius: float,
	body_mass: float,
	color: Color
) -> RigidBody2D:
	var body: RigidBody2D = _create_body(piece_name, local_position, body_mass)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	collision.shape = circle
	body.add_child(collision)
	var visual: Polygon2D = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for point_index: int in range(12):
		points.append(Vector2.RIGHT.rotated(TAU * float(point_index) / 12.0) * radius)
	visual.polygon = points
	visual.color = color
	body.add_child(visual)
	return body


func _create_body(
	piece_name: String,
	local_position: Vector2,
	body_mass: float
) -> RigidBody2D:
	var body: RigidBody2D = RigidBody2D.new()
	body.name = piece_name
	body.position = local_position
	body.mass = body_mass
	body.gravity_scale = 1.0
	body.linear_damp = 1.35
	body.angular_damp = 2.4
	body.can_sleep = true
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	body.collision_layer = REMAINS_LAYER
	body.collision_mask = REMAINS_GROUND_LAYER | ROBOT_LAYER | REMAINS_LAYER
	body.set_meta(&"enemy_remains", &"soldier")
	add_child(body)
	pieces.append(body)
	return body


func _create_joint(
	joint_name: String,
	body_a: RigidBody2D,
	body_b: RigidBody2D,
	local_position: Vector2
) -> void:
	var joint: PinJoint2D = PinJoint2D.new()
	joint.name = joint_name
	joint.position = local_position
	joint.node_a = body_a.get_path()
	joint.node_b = body_b.get_path()
	joint.softness = 0.18
	joint.disable_collision = true
	add_child(joint)
	joints.append(joint)


func _apply_fatal_impact() -> void:
	var direction: Vector2 = Vector2(float(_facing), -0.35).normalized()
	var impulse_per_mass: float = 180.0
	if _impact_event != null:
		direction = _impact_event.direction
		impulse_per_mass = maxf(_impact_event.impulse_per_mass, 180.0)
	if direction.is_zero_approx():
		direction = Vector2(float(_facing), -0.35).normalized()
	for piece_index: int in range(pieces.size()):
		var piece: RigidBody2D = pieces[piece_index]
		var lift: Vector2 = Vector2.UP * piece.mass * lerpf(22.0, 48.0, float(piece_index) / 5.0)
		var impulse: Vector2 = direction * impulse_per_mass * piece.mass * 0.34 + lift
		piece.linear_velocity = impulse / piece.mass
		piece.angular_velocity = (
			lerpf(-1.0, 1.0, float(piece_index) / 5.0) * 6.5
		)
