class_name SoldierRagdoll2D
extends Node2D

signal recycle_requested(ragdoll: SoldierRagdoll2D)

const REMAINS_LAYER: int = 1 << 9
const REMAINS_GROUND_LAYER: int = 1 << 10
const TORSO_TEXTURE: Texture2D = preload(
	"res://art/city/enemies/soldier_ragdoll/torso.png"
)
const HEAD_TEXTURE: Texture2D = preload(
	"res://art/city/enemies/soldier_ragdoll/head.png"
)
const ARM_TEXTURE: Texture2D = preload(
	"res://art/city/enemies/soldier_ragdoll/arm.png"
)
const LEG_TEXTURE: Texture2D = preload(
	"res://art/city/enemies/soldier_ragdoll/leg.png"
)
const RIFLE_TEXTURE: Texture2D = preload(
	"res://art/city/enemies/soldier_ragdoll/rifle.png"
)

@export_range(1.0, 30.0, 0.5) var hard_lifetime: float = 12.0
@export_range(0.5, 10.0, 0.5) var sleeping_recycle_delay: float = 3.0

var pieces: Array[RigidBody2D] = []
var joints: Array[PinJoint2D] = []
var custom_animation_play_count: int = 0
var _active: bool = false
var _age: float = 0.0
var _sleeping_age: float = 0.0
var _facing: int = -1
var _impact_event: DamageEvent
var _impact_tween: Tween
var _rest_positions: Dictionary[StringName, Vector2] = {}
var _visuals: Array[Sprite2D] = []


func _ready() -> void:
	z_index = 28
	_build_ragdoll()
	deactivate()


func activate(
	world_position: Vector2,
	facing: int,
	impact_event: DamageEvent
) -> void:
	global_position = world_position
	_facing = facing
	_impact_event = impact_event
	_age = 0.0
	_sleeping_age = 0.0
	_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	_reset_pieces()
	_apply_fatal_impact()
	_play_fatal_hit_animation()


func deactivate() -> void:
	_active = false
	set_physics_process(false)
	if _impact_tween != null and _impact_tween.is_valid():
		_impact_tween.kill()
	for body: RigidBody2D in pieces:
		body.collision_layer = 0
		body.collision_mask = 0
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0
		body.freeze = true
		body.sleeping = true
	visible = false


func is_active() -> bool:
	return _active


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


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	var all_sleeping: bool = true
	for piece: RigidBody2D in pieces:
		if not piece.sleeping:
			all_sleeping = false
			break
	_sleeping_age = _sleeping_age + delta if all_sleeping else 0.0
	if _age >= hard_lifetime or _sleeping_age >= sleeping_recycle_delay:
		recycle_requested.emit(self)


func _build_ragdoll() -> void:
	var torso: RigidBody2D = _create_piece(
		&"Torso",
		Vector2(0.0, -43.0),
		Vector2(34.0, 48.0),
		8.0,
		TORSO_TEXTURE,
		Vector2(42.0, 58.0)
	)
	var head: RigidBody2D = _create_piece(
		&"Head",
		Vector2(0.0, -77.0),
		Vector2(25.0, 27.0),
		2.2,
		HEAD_TEXTURE,
		Vector2(32.0, 34.0)
	)
	var left_arm: RigidBody2D = _create_piece(
		&"LeftArm",
		Vector2(-27.0, -45.0),
		Vector2(35.0, 22.0),
		3.0,
		ARM_TEXTURE,
		Vector2(42.0, 29.0)
	)
	var right_arm: RigidBody2D = _create_piece(
		&"RightArm",
		Vector2(27.0, -45.0),
		Vector2(35.0, 22.0),
		3.0,
		ARM_TEXTURE,
		Vector2(42.0, 29.0),
		true
	)
	var left_leg: RigidBody2D = _create_piece(
		&"LeftLeg",
		Vector2(-10.0, -10.0),
		Vector2(14.0, 39.0),
		5.0,
		LEG_TEXTURE,
		Vector2(18.0, 47.0)
	)
	var right_leg: RigidBody2D = _create_piece(
		&"RightLeg",
		Vector2(10.0, -10.0),
		Vector2(14.0, 39.0),
		5.0,
		LEG_TEXTURE,
		Vector2(18.0, 47.0),
		true
	)
	_add_rifle_visual(right_arm)
	_create_joint("NeckJoint", torso, head, Vector2(0.0, -64.0))
	_create_joint("LeftShoulderJoint", torso, left_arm, Vector2(-18.0, -53.0))
	_create_joint("RightShoulderJoint", torso, right_arm, Vector2(18.0, -53.0))
	_create_joint("LeftHipJoint", torso, left_leg, Vector2(-9.0, -24.0))
	_create_joint("RightHipJoint", torso, right_leg, Vector2(9.0, -24.0))


func _create_piece(
	piece_name: StringName,
	local_position: Vector2,
	size: Vector2,
	body_mass: float,
	texture: Texture2D,
	display_size: Vector2,
	flip_horizontal: bool = false
) -> RigidBody2D:
	var body: RigidBody2D = RigidBody2D.new()
	body.name = String(piece_name)
	body.position = local_position
	body.mass = body_mass
	body.gravity_scale = 1.0
	body.linear_damp = 1.35
	body.angular_damp = 2.4
	body.can_sleep = true
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	body.set_meta(&"enemy_remains", &"soldier")
	var collision: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	body.add_child(collision)
	var visual: Sprite2D = Sprite2D.new()
	visual.name = "Visual"
	visual.texture = texture
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visual.flip_h = flip_horizontal
	visual.scale = _fit_scale(texture, display_size)
	visual.set_meta(&"base_scale", visual.scale)
	body.add_child(visual)
	add_child(body)
	pieces.append(body)
	_visuals.append(visual)
	_rest_positions[piece_name] = local_position
	return body


func _add_rifle_visual(right_arm: RigidBody2D) -> void:
	var rifle: Sprite2D = Sprite2D.new()
	rifle.name = "RifleVisual"
	rifle.texture = RIFLE_TEXTURE
	rifle.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rifle.position = Vector2(-7.0, -11.0)
	rifle.rotation = -0.08
	rifle.scale = _fit_scale(RIFLE_TEXTURE, Vector2(47.0, 23.0))
	rifle.set_meta(&"base_scale", rifle.scale)
	right_arm.add_child(rifle)
	_visuals.append(rifle)


func _fit_scale(texture: Texture2D, display_size: Vector2) -> Vector2:
	var texture_size: Vector2 = texture.get_size()
	var fit: float = minf(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	return Vector2.ONE * fit


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


func _reset_pieces() -> void:
	for body: RigidBody2D in pieces:
		body.freeze = true
		body.position = _rest_positions[StringName(body.name)]
		body.rotation = 0.0
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0
		body.collision_layer = REMAINS_LAYER
		body.collision_mask = REMAINS_GROUND_LAYER | REMAINS_LAYER
		body.visible = true
		body.sleeping = false
		body.reset_physics_interpolation()
		body.freeze = false
	for visual: Sprite2D in _visuals:
		visual.modulate = Color.WHITE
		visual.scale = visual.get_meta(&"base_scale") as Vector2
	var face_right: bool = _facing > 0
	(get_node(^"Head/Visual") as Sprite2D).flip_h = face_right
	(get_node(^"RightArm/RifleVisual") as Sprite2D).flip_h = face_right


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
		var lift: Vector2 = (
			Vector2.UP * piece.mass * lerpf(22.0, 48.0, float(piece_index) / 5.0)
		)
		var impulse: Vector2 = direction * impulse_per_mass * piece.mass * 0.34 + lift
		piece.linear_velocity = impulse / piece.mass
		piece.angular_velocity = lerpf(-1.0, 1.0, float(piece_index) / 5.0) * 6.5


func _play_fatal_hit_animation() -> void:
	custom_animation_play_count += 1
	_impact_tween = create_tween()
	_impact_tween.set_parallel(true)
	for visual: Sprite2D in _visuals:
		var base_scale: Vector2 = visual.get_meta(&"base_scale") as Vector2
		visual.scale = base_scale * 1.16
		visual.modulate = Color(1.45, 1.20, 0.95, 1.0)
		_impact_tween.tween_property(visual, "scale", base_scale, 0.16)
		_impact_tween.tween_property(visual, "modulate", Color.WHITE, 0.16)
