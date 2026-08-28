class_name BossAttackArea2D
extends Area2D

signal core_shockwave_released

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
const PHOTON_CORE_TEXTURE: Texture2D = preload(
	"res://art/player/vfx/photon_core_orb.png"
)
const PHOTON_RELEASE_SHOCKWAVE_TEXTURE: Texture2D = preload(
	"res://art/player/vfx/photon_release_shockwave.png"
)
const CORE_CHARGE_SFX: AudioStream = preload(
	"res://audio/sfx/boss/s04_core_charge.ogg"
)
const SHOCKWAVE_RELEASE_SFX: AudioStream = preload(
	"res://audio/sfx/boss/s04_shockwave_release.ogg"
)
const SHOCKWAVE_SEGMENTS: int = 96
const CHARGE_PARTICLE_CAPACITY: int = 72
const CHARGE_PARTICLE_RADIUS: float = 300.0
const CHARGE_CORE_MIN_DIAMETER: float = 54.0
const CHARGE_CORE_MAX_DIAMETER: float = 238.0
const CORE_COLOR_SHIFT_SHADER_CODE: String = """
shader_type canvas_item;
uniform vec3 shift_color = vec3(0.05, 0.63, 1.0);
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 shifted = shift_color * (0.38 + luminance * 1.16);
	COLOR = vec4(shifted, source.a) * COLOR;
}
"""

static var _next_activation_attack_id: int = 9_000_000

var visual_state: VisualState = VisualState.HIDDEN
var presentation_role: PresentationRole = PresentationRole.GENERIC
var footprint_size: Vector2 = Vector2(192.0, 96.0)
var attack_id: StringName = &""
var activation_attack_id: int = 0
var damage_amount: float = DEFAULT_DAMAGE
var radial_age: float = 0.0
var shockwave_travel_seconds: float = 1.0
var shockwave_band_thickness: float = 92.0
var shockwave_telegraph_seconds: float = 1.7
var core_charge_sfx_play_count: int = 0
var shockwave_release_sfx_play_count: int = 0

var _damage_target: GiantRobotController
var _damaged_target_ids: Dictionary[int, bool] = {}
var _charge_particles: CPUParticles2D
var _charge_core: Sprite2D
var _release_shockwave: Sprite2D
var _charge_sfx_player: AudioStreamPlayer2D
var _release_sfx_player: AudioStreamPlayer2D


func setup_damage_target(robot: GiantRobotController) -> void:
	_damage_target = robot
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func configure_core_shockwave(
	travel_seconds_value: float,
	band_thickness_value: float,
	telegraph_seconds_value: float
) -> void:
	shockwave_travel_seconds = maxf(travel_seconds_value, 0.1)
	shockwave_band_thickness = maxf(band_thickness_value, 24.0)
	shockwave_telegraph_seconds = maxf(telegraph_seconds_value, 0.1)
	_ensure_radial_charge_vfx()
	queue_redraw()


func configure_footprint(
	world_position: Vector2,
	size_value: Vector2,
	state_value: VisualState,
	attack: StringName
) -> void:
	var previous_state: VisualState = visual_state
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
	if presentation_role == PresentationRole.RADIAL_SHOCKWAVE:
		_ensure_radial_charge_vfx()
		if visual_state == VisualState.TELEGRAPH and previous_state != VisualState.TELEGRAPH:
			radial_age = 0.0
			_start_core_charge()
		elif visual_state == VisualState.ARMED and previous_state != VisualState.ARMED:
			radial_age = 0.0
			_start_shockwave_release()
		elif visual_state == VisualState.HIDDEN:
			_reset_radial_vfx()
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
	_update_radial_vfx()
	queue_redraw()


func set_presentation_role(role: PresentationRole) -> void:
	if _is_echo_attack() and role != PresentationRole.ECHO_PRESENTATION:
		return
	presentation_role = role
	if role == PresentationRole.RADIAL_SHOCKWAVE:
		_ensure_radial_charge_vfx()
	else:
		_reset_radial_vfx()
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
			return PHOTON_RELEASE_SHOCKWAVE_TEXTURE
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
		var front_radius: float = _shockwave_front_radius()
		return front_radius >= 0.0 and absf(local_point.length() - front_radius) <= (
			shockwave_band_thickness * 0.5
		)
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
		&"boss_core_shockwave"
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
	radial_age += maxf(delta, 0.0)
	_update_radial_vfx()
	if visual_state == VisualState.ARMED and _damage_target != null:
		try_damage_body(_damage_target)
	queue_redraw()


func _is_echo_attack() -> bool:
	return String(attack_id).begins_with("ECHO_")


func _draw() -> void:
	if visual_state == VisualState.HIDDEN:
		return
	if presentation_role == PresentationRole.RADIAL_SHOCKWAVE:
		_draw_core_shockwave()
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


func shockwave_snapshot() -> Dictionary:
	return {
		"mode": &"CORE_CHARGE_RELEASE",
		"front_count": 1,
		"radii": PackedFloat32Array([_shockwave_front_radius()]),
		"travel_seconds": shockwave_travel_seconds,
		"band_thickness": shockwave_band_thickness,
		"telegraph_seconds": shockwave_telegraph_seconds,
		"charge_progress": _charge_progress(),
		"charge_particles_emitting": (
			_charge_particles != null and _charge_particles.emitting
		),
		"charge_particle_capacity": (
			_charge_particles.amount if _charge_particles != null else 0
		),
		"core_visible": _charge_core != null and _charge_core.visible,
		"core_diameter": _core_diameter(),
		"core_texture": PHOTON_CORE_TEXTURE.resource_path,
		"authored_texture": PHOTON_RELEASE_SHOCKWAVE_TEXTURE.resource_path,
		"charge_sfx": CORE_CHARGE_SFX.resource_path,
		"release_sfx": SHOCKWAVE_RELEASE_SFX.resource_path,
		"charge_sfx_play_count": core_charge_sfx_play_count,
		"release_sfx_play_count": shockwave_release_sfx_play_count,
		"charge_sfx_playing": _charge_sfx_player != null and _charge_sfx_player.playing,
		"release_sfx_playing": _release_sfx_player != null and _release_sfx_player.playing,
	}


func _draw_core_shockwave() -> void:
	if visual_state == VisualState.TELEGRAPH:
		var progress: float = _charge_progress()
		var pulse: float = 0.5 + 0.5 * sin(radial_age * lerpf(5.0, 15.0, progress))
		var aura_radius: float = _core_diameter() * 0.5 + 10.0 + pulse * 8.0
		draw_circle(Vector2.ZERO, aura_radius, Color(0.04, 0.62, 1.0, 0.07 + progress * 0.08))
		draw_arc(
			Vector2.ZERO,
			aura_radius,
			0.0,
			TAU,
			SHOCKWAVE_SEGMENTS,
			Color(0.48, 0.94, 1.0, 0.48 + pulse * 0.42),
			3.0 + progress * 4.0,
			true
		)
		return
	if visual_state != VisualState.ARMED:
		return
	var front_radius: float = _shockwave_front_radius()
	if front_radius < 0.0:
		return
	var travel_ratio: float = clampf(radial_age / shockwave_travel_seconds, 0.0, 1.0)
	var alpha: float = pow(1.0 - travel_ratio, 0.24)
	draw_circle(Vector2.ZERO, front_radius, Color(0.04, 0.58, 1.0, alpha * 0.035))
	draw_arc(
		Vector2.ZERO,
		front_radius,
		0.0,
		TAU,
		SHOCKWAVE_SEGMENTS,
		Color(0.82, 0.98, 1.0, alpha),
		10.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		maxf(front_radius - shockwave_band_thickness * 0.32, 6.0),
		0.0,
		TAU,
		SHOCKWAVE_SEGMENTS,
		Color(0.02, 0.54, 1.0, alpha * 0.72),
		16.0,
		true
	)


func _shockwave_front_radius() -> float:
	if visual_state != VisualState.ARMED:
		return -1.0
	if radial_age < 0.0 or radial_age > shockwave_travel_seconds:
		return -1.0
	var travel_ratio: float = clampf(radial_age / shockwave_travel_seconds, 0.0, 1.0)
	var radius: float = maxf(footprint_size.x, footprint_size.y) * 0.5
	return lerpf(
		CHARGE_CORE_MAX_DIAMETER * 0.34,
		radius,
		1.0 - pow(1.0 - travel_ratio, 1.28)
	)


func _charge_progress() -> float:
	if visual_state != VisualState.TELEGRAPH:
		return 0.0
	return clampf(radial_age / shockwave_telegraph_seconds, 0.0, 1.0)


func _core_diameter() -> float:
	var progress: float = _charge_progress()
	var pulse: float = (
		1.0 + sin(radial_age * lerpf(5.0, 15.0, progress)) * 0.045 * progress
	)
	return lerpf(CHARGE_CORE_MIN_DIAMETER, CHARGE_CORE_MAX_DIAMETER, progress) * pulse


func _ensure_radial_charge_vfx() -> void:
	if _charge_particles != null:
		return
	_charge_particles = CPUParticles2D.new()
	_charge_particles.name = "BossCoreChargeParticles"
	_charge_particles.texture = PHOTON_CORE_TEXTURE
	_charge_particles.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_charge_particles.amount = CHARGE_PARTICLE_CAPACITY
	_charge_particles.lifetime = 0.82
	_charge_particles.preprocess = 0.28
	_charge_particles.randomness = 0.84
	_charge_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_charge_particles.emission_sphere_radius = CHARGE_PARTICLE_RADIUS
	_charge_particles.direction = Vector2.ZERO
	_charge_particles.spread = 180.0
	_charge_particles.gravity = Vector2.ZERO
	_charge_particles.initial_velocity_min = 46.0
	_charge_particles.initial_velocity_max = 116.0
	_charge_particles.radial_accel_min = -520.0
	_charge_particles.radial_accel_max = -340.0
	_charge_particles.damping_min = 22.0
	_charge_particles.damping_max = 36.0
	_charge_particles.scale_amount_min = 0.025
	_charge_particles.scale_amount_max = 0.070
	_charge_particles.color = Color(0.22, 0.84, 1.0, 0.96)
	_charge_particles.z_index = 1
	var particle_material: CanvasItemMaterial = CanvasItemMaterial.new()
	particle_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_charge_particles.material = particle_material
	_charge_particles.emitting = false
	_charge_particles.visible = false
	add_child(_charge_particles)
	_charge_core = Sprite2D.new()
	_charge_core.name = "BossCoreEnergySphere"
	_charge_core.texture = PHOTON_CORE_TEXTURE
	_charge_core.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_charge_core.z_index = 3
	var core_shader: Shader = Shader.new()
	core_shader.code = CORE_COLOR_SHIFT_SHADER_CODE
	var core_material: ShaderMaterial = ShaderMaterial.new()
	core_material.shader = core_shader
	core_material.set_shader_parameter(&"shift_color", Vector3(0.05, 0.63, 1.0))
	_charge_core.material = core_material
	_charge_core.visible = false
	add_child(_charge_core)
	_release_shockwave = Sprite2D.new()
	_release_shockwave.name = "BossCoreReleaseShockwave"
	_release_shockwave.texture = PHOTON_RELEASE_SHOCKWAVE_TEXTURE
	_release_shockwave.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_release_shockwave.z_index = 2
	_release_shockwave.modulate = Color(0.48, 0.91, 1.0, 1.0)
	_release_shockwave.visible = false
	add_child(_release_shockwave)
	_charge_sfx_player = _make_core_audio_player(
		"BossCoreChargeAudio",
		CORE_CHARGE_SFX,
		-3.0
	)
	_release_sfx_player = _make_core_audio_player(
		"BossCoreShockwaveReleaseAudio",
		SHOCKWAVE_RELEASE_SFX,
		1.0
	)


func _start_core_charge() -> void:
	_ensure_radial_charge_vfx()
	_release_sfx_player.stop()
	_charge_sfx_player.stop()
	_charge_sfx_player.play()
	core_charge_sfx_play_count += 1
	_release_shockwave.visible = false
	_charge_core.visible = true
	_charge_particles.visible = true
	_charge_particles.restart()
	_charge_particles.emitting = true
	_update_radial_vfx()


func _start_shockwave_release() -> void:
	_ensure_radial_charge_vfx()
	_charge_sfx_player.stop()
	_release_sfx_player.stop()
	_release_sfx_player.play()
	shockwave_release_sfx_play_count += 1
	_charge_particles.emitting = false
	_charge_particles.visible = false
	_charge_core.visible = false
	_release_shockwave.visible = true
	_update_radial_vfx()
	core_shockwave_released.emit()


func _update_radial_vfx() -> void:
	if _charge_particles == null:
		return
	if visual_state == VisualState.TELEGRAPH:
		var progress: float = _charge_progress()
		_charge_particles.visible = true
		_charge_particles.emitting = true
		_charge_particles.initial_velocity_min = 46.0 + progress * 34.0
		_charge_particles.initial_velocity_max = 116.0 + progress * 58.0
		_charge_particles.radial_accel_min = -520.0 - progress * 780.0
		_charge_particles.radial_accel_max = -340.0 - progress * 620.0
		_charge_core.visible = true
		var diameter: float = _core_diameter()
		var core_size: Vector2 = PHOTON_CORE_TEXTURE.get_size()
		_charge_core.scale = Vector2.ONE * diameter / maxf(core_size.x, 1.0)
		_charge_core.rotation = radial_age * lerpf(0.18, 0.52, progress)
		_release_shockwave.visible = false
		return
	_charge_particles.emitting = false
	_charge_particles.visible = false
	_charge_core.visible = false
	if visual_state != VisualState.ARMED:
		_release_shockwave.visible = false
		return
	var front_radius: float = _shockwave_front_radius()
	if front_radius < 0.0:
		_release_shockwave.visible = false
		return
	var travel_ratio: float = clampf(radial_age / shockwave_travel_seconds, 0.0, 1.0)
	var texture_size: Vector2 = PHOTON_RELEASE_SHOCKWAVE_TEXTURE.get_size()
	_release_shockwave.visible = true
	_release_shockwave.scale = Vector2.ONE * (front_radius * 2.0 / maxf(texture_size.x, 1.0))
	_release_shockwave.modulate = Color(0.48, 0.91, 1.0, pow(1.0 - travel_ratio, 0.24))
	_release_shockwave.rotation = radial_age * 0.34


func _reset_radial_vfx() -> void:
	if _charge_particles != null:
		_charge_particles.emitting = false
		_charge_particles.visible = false
	if _charge_core != null:
		_charge_core.visible = false
		_charge_core.rotation = 0.0
	if _release_shockwave != null:
		_release_shockwave.visible = false
		_release_shockwave.scale = Vector2.ONE
		_release_shockwave.rotation = 0.0
	if _charge_sfx_player != null:
		_charge_sfx_player.stop()
	if _release_sfx_player != null:
		_release_sfx_player.stop()


func _make_core_audio_player(
	player_name: String,
	stream: AudioStream,
	volume_db_value: float
) -> AudioStreamPlayer2D:
	var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	player.name = player_name
	player.stream = stream
	player.bus = GameAudioBus.SFX
	player.volume_db = volume_db_value
	player.max_distance = 2800.0
	player.attenuation = 0.75
	add_child(player)
	return player
