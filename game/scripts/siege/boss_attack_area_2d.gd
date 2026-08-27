class_name BossAttackArea2D
extends Area2D

enum VisualState {
	HIDDEN,
	TELEGRAPH,
	ARMED,
	DRY,
}

enum PresentationRole {
	GENERIC,
	LANE_PLATE,
	LINE_BEAM,
	ECHO_PRESENTATION,
}

const ROBOT_LAYER: int = 1 << 1
const DEFAULT_DAMAGE: float = 16.0
const LANE_PLATE_TEXTURE: Texture2D = preload(
	"res://art/bosses/boss-lane-footprint.png"
)
const LINE_BEAM_TEXTURE: Texture2D = preload("res://art/bosses/boss-line-beam.png")

static var _next_activation_attack_id: int = 9_000_000

var visual_state: VisualState = VisualState.HIDDEN
var presentation_role: PresentationRole = PresentationRole.GENERIC
var footprint_size: Vector2 = Vector2(192.0, 96.0)
var attack_id: StringName = &""
var activation_attack_id: int = 0
var damage_amount: float = DEFAULT_DAMAGE

var _damage_target: GiantRobotController
var _damaged_target_ids: Dictionary[int, bool] = {}


func setup_damage_target(robot: GiantRobotController) -> void:
	_damage_target = robot
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func configure_footprint(
	world_position: Vector2,
	size_value: Vector2,
	state_value: VisualState,
	attack: StringName
) -> void:
	var was_armed: bool = visual_state == VisualState.ARMED and monitoring
	global_position = world_position
	footprint_size = size_value
	visual_state = state_value
	attack_id = attack
	if _is_echo_attack():
		presentation_role = PresentationRole.ECHO_PRESENTATION
	var collision: CollisionShape2D = get_node(^"Collision") as CollisionShape2D
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	rectangle.size = footprint_size
	var armed: bool = (
		visual_state == VisualState.ARMED
		and presentation_role != PresentationRole.ECHO_PRESENTATION
		and not _is_echo_attack()
	)
	collision.disabled = not armed
	collision_layer = 0
	collision_mask = ROBOT_LAYER if armed else 0
	monitoring = armed
	monitorable = false
	visible = visual_state != VisualState.HIDDEN
	if armed and not was_armed:
		activation_attack_id = _next_activation_attack_id
		_next_activation_attack_id += 1
		_damaged_target_ids.clear()
		call_deferred(&"_damage_current_overlaps")
	queue_redraw()


func set_presentation_role(role: PresentationRole) -> void:
	if _is_echo_attack() and role != PresentationRole.ECHO_PRESENTATION:
		return
	presentation_role = role
	queue_redraw()


func authored_texture() -> Texture2D:
	if _is_echo_attack():
		return null
	match presentation_role:
		PresentationRole.LANE_PLATE:
			return LANE_PLATE_TEXTURE
		PresentationRole.LINE_BEAM:
			return LINE_BEAM_TEXTURE
	return null


func deactivate() -> void:
	configure_footprint(
		global_position,
		footprint_size,
		VisualState.HIDDEN,
		&""
	)


func contains_world_point(world_point: Vector2) -> bool:
	if (
		visual_state != VisualState.ARMED
		or presentation_role == PresentationRole.ECHO_PRESENTATION
		or _is_echo_attack()
	):
		return false
	var local_point: Vector2 = to_local(world_point)
	return (
		absf(local_point.x) <= footprint_size.x * 0.5
		and absf(local_point.y) <= footprint_size.y * 0.5
	)


func try_damage_body(body: Node) -> bool:
	if (
		visual_state != VisualState.ARMED
		or presentation_role == PresentationRole.ECHO_PRESENTATION
		or _is_echo_attack()
		or body == null
		or body != _damage_target
	):
		return false
	var robot: GiantRobotController = body as GiantRobotController
	var target_id: int = int(robot.get_instance_id())
	if _damaged_target_ids.has(target_id):
		return false
	var direction: Vector2 = robot.global_position - global_position
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var accepted: bool = robot.receive_damage(DamageEvent.new(
		activation_attack_id,
		self,
		damage_amount,
		&"boss_hazard",
		robot.global_position,
		direction,
		0.0,
		activation_attack_id,
		0,
		DamageEvent.FLAG_HAZARD
	))
	if accepted:
		_damaged_target_ids[target_id] = true
	return accepted


func _damage_current_overlaps() -> void:
	if visual_state != VisualState.ARMED or not monitoring:
		return
	for body: Node2D in get_overlapping_bodies():
		try_damage_body(body)


func _on_body_entered(body: Node2D) -> void:
	try_damage_body(body)


func _is_echo_attack() -> bool:
	return String(attack_id).begins_with("ECHO_")


func _draw() -> void:
	if visual_state == VisualState.HIDDEN:
		return
	var rectangle: Rect2 = Rect2(-footprint_size * 0.5, footprint_size)
	var texture: Texture2D = authored_texture()
	if texture != null:
		draw_texture_rect(texture, rectangle, false)
	var fill: Color = Color(0.08, 0.82, 0.92, 0.10)
	var edge: Color = Color(0.45, 0.96, 1.0, 0.88)
	var width: float = 3.0
	if visual_state == VisualState.ARMED:
		fill = Color(0.94, 0.08, 0.72, 0.30)
		edge = Color(1.0, 0.32, 0.86, 0.98)
		width = 6.0
	elif visual_state == VisualState.DRY:
		fill = Color(0.92, 0.96, 1.0, 0.08)
		edge = Color(0.94, 1.0, 1.0, 0.94)
		width = 4.0
	draw_rect(rectangle, fill, true)
	draw_rect(rectangle, edge, false, width)
	if visual_state == VisualState.TELEGRAPH:
		for stripe: int in range(4):
			var stripe_x: float = rectangle.position.x + 24.0 + float(stripe) * 48.0
			draw_line(
				Vector2(stripe_x, rectangle.position.y),
				Vector2(stripe_x + 32.0, rectangle.end.y),
				Color(1.0, 0.72, 0.16, 0.82),
				3.0
			)
