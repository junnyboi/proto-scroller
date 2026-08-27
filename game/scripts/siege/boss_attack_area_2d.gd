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
	RADIAL_SHOCKWAVE,
}

const ROBOT_LAYER: int = 1 << 1
const DEFAULT_DAMAGE: float = 16.0
const LANE_PLATE_TEXTURE: Texture2D = preload(
	"res://art/bosses/boss-lane-footprint.png"
)
const LINE_BEAM_TEXTURE: Texture2D = preload("res://art/bosses/boss-line-beam.png")
const SHOCKWAVE_RING_TEXTURE: Texture2D = preload(
	"res://art/bosses/attacks/settlement-shockwave-ring.webp"
)
const MAX_SHOCKWAVE_FRONTS: int = 3
const SHOCKWAVE_SEGMENTS: int = 72

static var _next_activation_attack_id: int = 9_000_000

var visual_state: VisualState = VisualState.HIDDEN
var presentation_role: PresentationRole = PresentationRole.GENERIC
var footprint_size: Vector2 = Vector2(192.0, 96.0)
var attack_id: StringName = &""
var activation_attack_id: int = 0
var damage_amount: float = DEFAULT_DAMAGE
var radial_age: float = 0.0
var shockwave_front_count: int = 1
var shockwave_release_delays: PackedFloat32Array = PackedFloat32Array([0.0])
var shockwave_travel_seconds: float = 0.82
var shockwave_vertical_ratio: float = 0.26
var shockwave_band_thickness: float = 84.0
var shockwave_telegraph_seconds: float = 0.9

var _damage_target: GiantRobotController
var _damaged_target_ids: Dictionary[int, bool] = {}


func setup_damage_target(robot: GiantRobotController) -> void:
	_damage_target = robot
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func configure_traveling_shockwave(
	front_count_value: int,
	release_delays_value: PackedFloat32Array,
	travel_seconds_value: float,
	vertical_ratio_value: float,
	band_thickness_value: float,
	telegraph_seconds_value: float
) -> void:
	shockwave_front_count = clampi(front_count_value, 1, MAX_SHOCKWAVE_FRONTS)
	shockwave_release_delays = PackedFloat32Array()
	for front_index: int in range(shockwave_front_count):
		shockwave_release_delays.append(
			maxf(float(release_delays_value[front_index]), 0.0)
			if front_index < release_delays_value.size()
			else 0.0
		)
	shockwave_travel_seconds = maxf(travel_seconds_value, 0.1)
	shockwave_vertical_ratio = clampf(vertical_ratio_value, 0.15, 1.0)
	shockwave_band_thickness = maxf(band_thickness_value, 24.0)
	shockwave_telegraph_seconds = maxf(telegraph_seconds_value, 0.1)
	queue_redraw()


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
	if presentation_role == PresentationRole.RADIAL_SHOCKWAVE:
		var circle: CircleShape2D = collision.shape as CircleShape2D
		if circle == null:
			circle = CircleShape2D.new()
			collision.shape = circle
		circle.radius = maxf(footprint_size.x, footprint_size.y) * 0.5
	else:
		var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
		if rectangle == null:
			rectangle = RectangleShape2D.new()
			collision.shape = rectangle
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
		radial_age = 0.0
		call_deferred(&"_damage_current_overlaps")
	set_process(
		presentation_role == PresentationRole.RADIAL_SHOCKWAVE
		and visual_state != VisualState.HIDDEN
	)
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
		PresentationRole.RADIAL_SHOCKWAVE:
			return SHOCKWAVE_RING_TEXTURE
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
	if presentation_role == PresentationRole.RADIAL_SHOCKWAVE:
		var road_distance: float = absf(local_point.x)
		for front_index: int in range(shockwave_front_count):
			var front_radius: float = _shockwave_front_radius(front_index)
			if front_radius >= 0.0 and absf(road_distance - front_radius) <= (
				shockwave_band_thickness * 0.5
			):
				return true
		return false
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
	if not contains_world_point(robot.global_position):
		return false
	var target_id: int = int(robot.get_instance_id())
	if _damaged_target_ids.has(target_id):
		return false
	var direction: Vector2 = robot.global_position - global_position
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var accepted: bool = robot.receive_damage(DamageEvent.new(
		activation_attack_id,
		self,
		damage_amount * EnemyActor2D.ENEMY_DAMAGE_MULTIPLIER,
		&"boss_traveling_shockwave"
		if presentation_role == PresentationRole.RADIAL_SHOCKWAVE
		else &"boss_hazard",
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


func _process(delta: float) -> void:
	if presentation_role != PresentationRole.RADIAL_SHOCKWAVE or not visible:
		return
	radial_age += delta
	if visual_state == VisualState.ARMED and _damage_target != null:
		try_damage_body(_damage_target)
	queue_redraw()


func _is_echo_attack() -> bool:
	return String(attack_id).begins_with("ECHO_")


func _draw() -> void:
	if visual_state == VisualState.HIDDEN:
		return
	if presentation_role == PresentationRole.RADIAL_SHOCKWAVE:
		_draw_radial_shockwave()
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


func _draw_radial_shockwave() -> void:
	var radius: float = maxf(footprint_size.x, footprint_size.y) * 0.5
	var armed: bool = visual_state == VisualState.ARMED
	if not armed:
		_draw_shockwave_telegraph(radius)
		return
	for front_index: int in range(shockwave_front_count):
		var front_radius: float = _shockwave_front_radius(front_index)
		if front_radius < 0.0:
			var launch_ratio: float = clampf(
				1.0 - (
					shockwave_release_delays[front_index] - radial_age
				) / maxf(shockwave_release_delays[front_index], 0.01),
				0.0,
				1.0
			)
			_draw_ellipse_arc(
				lerpf(28.0, 68.0, launch_ratio),
				Color(1.0, 0.42, 0.08, 0.35 + launch_ratio * 0.55),
				4.0 + launch_ratio * 4.0
			)
			continue
		var travel_ratio: float = clampf(
			(radial_age - shockwave_release_delays[front_index])
			/ shockwave_travel_seconds,
			0.0,
			1.0
		)
		var front_alpha: float = pow(1.0 - travel_ratio, 0.28)
		_draw_authored_shockwave(front_radius, front_alpha)
		_draw_ellipse_arc(
			front_radius,
			Color(1.0, 0.97, 0.84, front_alpha),
			9.0
		)
		_draw_ellipse_arc(
			maxf(front_radius - shockwave_band_thickness * 0.42, 4.0),
			Color(1.0, 0.28, 0.04, front_alpha * 0.58),
			14.0
		)


func shockwave_snapshot() -> Dictionary:
	var radii: PackedFloat32Array = PackedFloat32Array()
	for front_index: int in range(shockwave_front_count):
		radii.append(_shockwave_front_radius(front_index))
	return {
		"front_count": shockwave_front_count,
		"release_delays": shockwave_release_delays.duplicate(),
		"radii": radii,
		"travel_seconds": shockwave_travel_seconds,
		"vertical_ratio": shockwave_vertical_ratio,
		"band_thickness": shockwave_band_thickness,
		"authored_texture": authored_texture().resource_path if authored_texture() != null else "",
	}


func _draw_shockwave_telegraph(radius: float) -> void:
	var progress: float = clampf(radial_age / shockwave_telegraph_seconds, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(radial_age * lerpf(8.0, 22.0, progress))
	draw_colored_polygon(
		_ellipse_points(radius, shockwave_vertical_ratio, SHOCKWAVE_SEGMENTS),
		Color(1.0, 0.34, 0.04, 0.035 + pulse * 0.035)
	)
	_draw_ellipse_arc(
		radius,
		Color(1.0, 0.47, 0.08, 0.56 + pulse * 0.28),
		4.0 + progress * 3.0
	)
	for front_index: int in range(shockwave_front_count):
		var ghost_radius: float = radius * (
			0.22 + float(front_index) * 0.09 + progress * 0.05
		)
		_draw_ellipse_arc(
			ghost_radius,
			Color(1.0, 0.88, 0.64, 0.42 + pulse * 0.36),
			3.0 + progress * 2.5
		)
	var emitter_radius: float = lerpf(82.0, 34.0, progress)
	_draw_authored_shockwave(emitter_radius, 0.44 + pulse * 0.38)
	for spoke_index: int in range(shockwave_front_count):
		var angle: float = -PI * 0.5 + float(spoke_index) * TAU / float(shockwave_front_count)
		var spoke_end: Vector2 = Vector2(
			cos(angle) * radius,
			sin(angle) * radius * shockwave_vertical_ratio
		)
		draw_line(
			spoke_end * 0.72,
			spoke_end,
			Color(1.0, 0.78, 0.18, 0.46 + pulse * 0.34),
			3.0
		)


func _draw_authored_shockwave(radius: float, alpha: float) -> void:
	if radius <= 1.0 or SHOCKWAVE_RING_TEXTURE == null or alpha <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, shockwave_vertical_ratio))
	draw_texture_rect(
		SHOCKWAVE_RING_TEXTURE,
		Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2.0),
		false,
		Color(1.0, 1.0, 1.0, alpha)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ellipse_arc(radius: float, color: Color, width: float) -> void:
	draw_polyline(
		_ellipse_points(radius, shockwave_vertical_ratio, SHOCKWAVE_SEGMENTS),
		color,
		width,
		true
	)


func _ellipse_points(radius: float, vertical_ratio: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for point_index: int in range(segments + 1):
		var angle: float = float(point_index) * TAU / float(segments)
		points.append(Vector2(
			cos(angle) * radius,
			sin(angle) * radius * vertical_ratio
		))
	return points


func _shockwave_front_radius(front_index: int) -> float:
	if (
		visual_state != VisualState.ARMED
		or front_index < 0
		or front_index >= shockwave_front_count
		or front_index >= shockwave_release_delays.size()
	):
		return -1.0
	var front_age: float = radial_age - shockwave_release_delays[front_index]
	if front_age < 0.0 or front_age > shockwave_travel_seconds:
		return -1.0
	var travel_ratio: float = clampf(front_age / shockwave_travel_seconds, 0.0, 1.0)
	var radius: float = maxf(footprint_size.x, footprint_size.y) * 0.5
	return lerpf(24.0, radius, 1.0 - pow(1.0 - travel_ratio, 1.35))
