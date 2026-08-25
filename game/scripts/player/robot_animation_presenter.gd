class_name RobotAnimationPresenter
extends Node

const ATTACK_EVENT_FRAME: int = AttackResolver.ATTACK_EVENT_FRAME
const PUNCH_CONTACT_FRAMES: Array[int] = [11, 14]
const PUNCH_CONTACT_INTERVAL_SECONDS: float = (
	float(PUNCH_CONTACT_FRAMES[1] - PUNCH_CONTACT_FRAMES[0])
	/ RobotSpriteFramesBuilder.DEFAULT_FPS
)
const WALK_REFERENCE_SPEED: float = 260.0
const AUDIO_VOICE_CAPACITY: int = 4
const AFTERIMAGE_CAPACITY: int = 8
const AFTERIMAGE_INTERVAL: float = 0.035
const AFTERIMAGE_LIFETIME: float = 0.22
const AFTERIMAGE_ALPHA: float = 0.34
const DUST_INTERVAL: float = 0.055
const CRITICAL_HEALTH_RATIO: float = 0.25
const ATTACK_IMPACT_BASE_VOLUME_DB: float = 1.5
const ATTACK_IMPACT_GAIN_DB: float = 9.5424250941
const ATTACK_IMPACT_REDUCTION_DB: float = -2.4987747322
const ATTACK_IMPACT_VOLUME_DB: float = (
	ATTACK_IMPACT_BASE_VOLUME_DB + ATTACK_IMPACT_GAIN_DB
	+ ATTACK_IMPACT_REDUCTION_DB
)
const CRITICAL_SMOKE_OFFSET: Vector2 = Vector2(28.0, -42.0)
const CHARGE_PARTICLE_OFFSET: Vector2 = Vector2(0.0, 34.0)
const CHARGE_PARTICLE_COLOR: Color = Color(1.0, 0.72, 0.16, 0.92)
const CRITICAL_SMOKE_TEXTURE: Texture2D = preload(
	"res://art/player/weapons/missile_explosion_smoke.png"
)
const WALK_SERVO_FRAMES: Array[int] = [2, 15]
const WALK_CONTACT_FRAMES: Array[int] = [5, 18]
const FOOTSTEP_SFX: AudioStream = preload(
	"res://audio/sfx/robot/robot_footstep.wav"
)
const SERVO_SFX: AudioStream = preload(
	"res://audio/sfx/robot/robot_servo.wav"
)
const DASH_WARP_SFX: AudioStream = preload(
	"res://audio/sfx/robot/robot_dash_warp_drive.wav"
)
const DODGE_RECHARGED_SFX: AudioStream = preload(
	"res://audio/sfx/robot/dodge_energy_recharged.wav"
)
const GROUND_SLAM_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/robot/ground_slam_impact.wav"
)
const DOUBLE_PUNCH_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/robot/double_punch_impact.wav"
)

var robot: GiantRobotController
var sprite: AnimatedSprite2D
var attacking: bool = false
var dodging: bool = false
var selected_attack_id: int = 0
var audio_play_count: int = 0
var footstep_play_count: int = 0
var servo_play_count: int = 0
var dash_warp_sfx_play_count: int = 0
var dodge_recharged_sfx_play_count: int = 0
var attack_impact_play_count: int = 0
var audio_recycle_count: int = 0
var audio_drop_count: int = 0
var audio_preemption_count: int = 0
var last_preempted_priority: int = AudioVoicePriority.UNUSED
var last_audio_cue: StringName = &""
var last_completed_attack_frame: int = -1
var completed_full_attack_count: int = 0
var charging: bool = false
var last_charge_progress: float = 0.0
var dust_intensity_scale: float = 1.0
var _audio_players: Array[AudioStreamPlayer2D] = []
var _status_sfx_player: AudioStreamPlayer
var _voice_started_order: int = 0
var _afterimage_root: Node2D
var _afterimages: Array[Sprite2D] = []
var _afterimage_remaining: Array[float] = []
var _afterimage_cursor: int = 0
var _afterimage_elapsed: float = 0.0
var _dust_pool: DodgeDustPool2D
var _dust_elapsed: float = 0.0
var _dodge_facing: int = 1
var _critical_smoke: CPUParticles2D
var _charge_particles: CPUParticles2D


func setup(p_robot: GiantRobotController, p_sprite: AnimatedSprite2D) -> void:
	robot = p_robot
	sprite = p_sprite
	robot.facing_changed.connect(_on_facing_changed)
	robot.locomotion_changed.connect(_on_locomotion_changed)
	robot.attack_mode_selected.connect(_on_attack_selected)
	robot.attack_committed.connect(_on_attack_committed)
	robot.dodge_started.connect(_on_dodge_started)
	robot.dodge_finished.connect(_on_dodge_finished)
	robot.dodge_cooldown_ready.connect(_on_dodge_cooldown_ready)
	robot.health_changed.connect(_on_health_changed)
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	_prewarm_audio()
	_prewarm_afterimages()
	_prewarm_dust()
	_prewarm_critical_smoke()
	_prewarm_charge_particles()
	_on_health_changed(robot.current_health, robot.max_health)
	_show_idle()


func bind_attacks(controller: ContextualAttackController) -> void:
	controller.attack_finished.connect(_on_attack_finished)
	controller.charge_started.connect(_on_charge_started)
	controller.charge_updated.connect(_on_charge_updated)
	controller.charge_released.connect(_on_charge_released)


func audio_voice_count() -> int:
	return _audio_players.size() + (1 if _status_sfx_player != null else 0)


func afterimage_slot_count() -> int:
	return _afterimages.size()


func active_afterimage_count() -> int:
	var active_count: int = 0
	for ghost: Sprite2D in _afterimages:
		if ghost.visible:
			active_count += 1
	return active_count


func dust_slot_count() -> int:
	return _dust_pool.slot_count() if _dust_pool != null else 0


func active_dust_slot_count() -> int:
	return _dust_pool.active_slot_count() if _dust_pool != null else 0


func critical_smoke_emitter_count() -> int:
	return 1 if _critical_smoke != null else 0


func critical_smoke_emitting() -> bool:
	return _critical_smoke != null and _critical_smoke.emitting


func charge_particle_emitter_count() -> int:
	return 1 if _charge_particles != null else 0


func charge_particles_emitting() -> bool:
	return _charge_particles != null and _charge_particles.emitting


func _process(delta: float) -> void:
	_advance_afterimages(delta)
	if dodging:
		_afterimage_elapsed += delta
		while _afterimage_elapsed >= AFTERIMAGE_INTERVAL:
			_afterimage_elapsed -= AFTERIMAGE_INTERVAL
			_spawn_afterimage()
		_dust_elapsed += delta
		while _dust_elapsed >= DUST_INTERVAL:
			_dust_elapsed -= DUST_INTERVAL
			_spawn_dodge_dust(0.82)
	if robot == null or sprite == null or attacking:
		return
	if robot.locomotion_state == GiantRobotController.LocomotionState.WALK:
		sprite.speed_scale = clampf(
			absf(robot.velocity.x) / WALK_REFERENCE_SPEED,
			0.45,
			1.35
		)


func _on_facing_changed(_facing: int) -> void:
	_update_emitter_facing()
	if attacking:
		return
	if robot.locomotion_state == GiantRobotController.LocomotionState.WALK:
		_play_walk()
	else:
		_show_idle()


func _on_locomotion_changed(state: int) -> void:
	if attacking or dodging:
		return
	if state == GiantRobotController.LocomotionState.WALK:
		_play_walk()
	else:
		_show_idle()


func _on_attack_selected(mode: int, attack_id: int) -> void:
	attacking = true
	selected_attack_id = attack_id
	sprite.speed_scale = 1.0
	sprite.play(_attack_animation(mode), 1.0, false)
	var pitch: float = 0.86 if mode == AttackSpec.Mode.GROUND_SMASH else 1.03
	_play_mechanics(SERVO_SFX, &"attack_windup", 2.5, pitch)


func _on_charge_started(spec: AttackSpec) -> void:
	if spec == null or spec.attack_id != selected_attack_id:
		return
	charging = true
	last_charge_progress = 0.0
	sprite.pause()
	sprite.set_frame_and_progress(0, 0.0)
	if _charge_particles != null:
		_charge_particles.emitting = true


func _on_charge_updated(
	spec: AttackSpec,
	_duration: float,
	progress: float,
	_multiplier: float
) -> void:
	if spec == null or spec.attack_id != selected_attack_id or not charging:
		return
	last_charge_progress = clampf(progress, 0.0, 1.0)
	if _charge_particles != null:
		_charge_particles.emitting = last_charge_progress < 1.0
		_charge_particles.amount = 28 + roundi(last_charge_progress * 28.0)
		_charge_particles.initial_velocity_min = 44.0 + last_charge_progress * 24.0
		_charge_particles.initial_velocity_max = 104.0 + last_charge_progress * 46.0


func _on_charge_released(
	spec: AttackSpec,
	_duration: float,
	_multiplier: float
) -> void:
	if spec == null or spec.attack_id != selected_attack_id:
		return
	charging = false
	if _charge_particles != null:
		_charge_particles.emitting = false
	sprite.speed_scale = 1.0
	sprite.play()


func _on_attack_committed(mode: int, attack_id: int) -> void:
	if not attacking or attack_id != selected_attack_id:
		return
	if sprite.frame < ATTACK_EVENT_FRAME:
		sprite.set_frame_and_progress(ATTACK_EVENT_FRAME, 0.0)
	if mode == AttackSpec.Mode.GROUND_SMASH:
		_play_mechanics(
			GROUND_SLAM_IMPACT_SFX,
			&"ground_slam_impact",
			ATTACK_IMPACT_VOLUME_DB,
			1.0
		)
	else:
		_play_mechanics(
			DOUBLE_PUNCH_IMPACT_SFX,
			&"double_punch_impact",
			ATTACK_IMPACT_VOLUME_DB,
			1.0
		)


func _on_attack_finished(spec: AttackSpec) -> void:
	if spec == null or spec.attack_id != selected_attack_id:
		return
	last_completed_attack_frame = sprite.frame
	if sprite.frame == RobotSpriteFramesBuilder.FRAME_COUNT - 1:
		completed_full_attack_count += 1
	attacking = false
	charging = false
	last_charge_progress = 0.0
	if _charge_particles != null:
		_charge_particles.emitting = false
	selected_attack_id = 0
	if robot.locomotion_state == GiantRobotController.LocomotionState.WALK:
		_play_walk()
	else:
		_show_idle()


func _on_dodge_started(p_facing: int, _duration: float) -> void:
	dodging = true
	_dodge_facing = 1 if p_facing >= 0 else -1
	_play_mechanics(DASH_WARP_SFX, &"dash_warp", 0.5, 1.0)
	_show_idle()
	sprite.skew = -float(p_facing) * 0.10
	sprite.modulate = Color(0.72, 0.94, 1.0, 0.82)
	_afterimage_elapsed = 0.0
	_dust_elapsed = 0.0
	_spawn_afterimage()
	_spawn_dodge_dust(1.20)


func _on_dodge_finished() -> void:
	dodging = false
	_spawn_dodge_dust(0.70)
	sprite.skew = 0.0
	sprite.modulate = Color.WHITE
	if robot.locomotion_state == GiantRobotController.LocomotionState.WALK:
		_play_walk()
	else:
		_show_idle()


func _on_health_changed(current: float, maximum: float) -> void:
	if _critical_smoke == null:
		return
	var ratio: float = current / maxf(maximum, 1.0)
	_critical_smoke.emitting = current > 0.0 and ratio <= CRITICAL_HEALTH_RATIO


func _on_dodge_cooldown_ready() -> void:
	if _status_sfx_player == null or DODGE_RECHARGED_SFX == null:
		return
	_status_sfx_player.stop()
	_status_sfx_player.stream = DODGE_RECHARGED_SFX
	_status_sfx_player.volume_db = -4.0
	_status_sfx_player.play()
	dodge_recharged_sfx_play_count += 1
	audio_play_count += 1
	last_audio_cue = &"dodge_recharged"


func _on_sprite_frame_changed() -> void:
	if attacking or robot.locomotion_state != GiantRobotController.LocomotionState.WALK:
		return
	if sprite.animation != &"walk_e" and sprite.animation != &"walk_w":
		return
	if sprite.frame in WALK_SERVO_FRAMES:
		var servo_index: int = WALK_SERVO_FRAMES.find(sprite.frame)
		var servo_pitch: float = 0.96 if servo_index == 0 else 1.04
		_play_mechanics(SERVO_SFX, &"walk_servo", -7.0, servo_pitch)
	elif sprite.frame in WALK_CONTACT_FRAMES:
		var contact_index: int = WALK_CONTACT_FRAMES.find(sprite.frame)
		var foot_pitch: float = 0.94 if contact_index == 0 else 1.02
		var speed_ratio: float = clampf(
			absf(robot.velocity.x) / maxf(robot.max_speed, 1.0),
			0.65,
			1.35
		)
		robot.notify_footstep(speed_ratio)
		_play_mechanics(
			FOOTSTEP_SFX,
			&"walk_footstep",
			clampf(-2.0 + speed_ratio * 1.5, -1.0, 0.5),
			foot_pitch
		)


func _play_walk() -> void:
	var animation: StringName = &"walk_e" if robot.facing >= 0 else &"walk_w"
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)


func _show_idle() -> void:
	if sprite == null or robot == null:
		return
	sprite.speed_scale = 1.0
	sprite.play(&"idle_s")
	sprite.pause()
	sprite.set_frame_and_progress(0, 0.0)


func _attack_animation(mode: int) -> StringName:
	if mode == AttackSpec.Mode.JAB_CROSS:
		return &"attack_e" if robot.facing >= 0 else &"attack_w"
	return &"attack_se" if robot.facing >= 0 else &"attack_sw"


func _update_emitter_facing() -> void:
	var emitter: Node2D = robot.get_node_or_null(^"VisualRoot/LaserEmitter") as Node2D
	if emitter != null:
		emitter.position.x = absf(emitter.position.x) * float(robot.facing)
	if _critical_smoke != null:
		_critical_smoke.position = Vector2(
			absf(CRITICAL_SMOKE_OFFSET.x) * float(robot.facing),
			CRITICAL_SMOKE_OFFSET.y
		)


func _prewarm_critical_smoke() -> void:
	var visual_root: Node2D = robot.get_node_or_null(^"VisualRoot") as Node2D
	if visual_root == null:
		return
	_critical_smoke = CPUParticles2D.new()
	_critical_smoke.name = "CriticalHealthSmoke"
	_critical_smoke.texture = CRITICAL_SMOKE_TEXTURE
	_critical_smoke.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_critical_smoke.amount = 14
	_critical_smoke.lifetime = 1.25
	_critical_smoke.randomness = 0.55
	_critical_smoke.direction = Vector2.UP
	_critical_smoke.spread = 30.0
	_critical_smoke.gravity = Vector2(0.0, -12.0)
	_critical_smoke.initial_velocity_min = 28.0
	_critical_smoke.initial_velocity_max = 72.0
	_critical_smoke.scale_amount_min = 0.08
	_critical_smoke.scale_amount_max = 0.18
	_critical_smoke.color = Color(0.62, 0.65, 0.67, 0.74)
	_critical_smoke.z_index = -1
	_critical_smoke.emitting = false
	visual_root.add_child(_critical_smoke)
	_update_emitter_facing()


func _prewarm_charge_particles() -> void:
	var visual_root: Node2D = robot.get_node_or_null(^"VisualRoot") as Node2D
	if visual_root == null:
		return
	_charge_particles = CPUParticles2D.new()
	_charge_particles.name = "MeleeChargeParticles"
	_charge_particles.position = CHARGE_PARTICLE_OFFSET
	_charge_particles.amount = 28
	_charge_particles.lifetime = 0.72
	_charge_particles.preprocess = 0.35
	_charge_particles.randomness = 0.82
	_charge_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_charge_particles.emission_sphere_radius = 165.0
	_charge_particles.direction = Vector2.ZERO
	_charge_particles.spread = 180.0
	_charge_particles.gravity = Vector2.ZERO
	_charge_particles.initial_velocity_min = 44.0
	_charge_particles.initial_velocity_max = 104.0
	_charge_particles.radial_accel_min = -300.0
	_charge_particles.radial_accel_max = -190.0
	_charge_particles.damping_min = 18.0
	_charge_particles.damping_max = 30.0
	_charge_particles.scale_amount_min = 3.0
	_charge_particles.scale_amount_max = 7.0
	_charge_particles.color = CHARGE_PARTICLE_COLOR
	_charge_particles.z_index = 2
	_charge_particles.emitting = false
	visual_root.add_child(_charge_particles)


func _prewarm_audio() -> void:
	for index: int in range(AUDIO_VOICE_CAPACITY):
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		player.name = "RobotMechanicsAudio%02d" % index
		player.max_distance = 1500.0
		player.attenuation = 0.45
		player.bus = GameAudioBus.MECHANICS
		AudioVoicePriority.stamp(player, AudioVoicePriority.UNUSED, 0)
		add_child(player)
		_audio_players.append(player)
	_status_sfx_player = AudioStreamPlayer.new()
	_status_sfx_player.name = "RobotStatusRechargeSfx"
	_status_sfx_player.bus = GameAudioBus.MECHANICS
	add_child(_status_sfx_player)


func _prewarm_afterimages() -> void:
	_afterimage_root = Node2D.new()
	_afterimage_root.name = "DodgeAfterimagePool"
	_afterimage_root.top_level = true
	_afterimage_root.z_as_relative = false
	_afterimage_root.z_index = 99
	add_child(_afterimage_root)
	for index: int in range(AFTERIMAGE_CAPACITY):
		var ghost: Sprite2D = Sprite2D.new()
		ghost.name = "DodgeAfterimage%02d" % index
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.visible = false
		_afterimage_root.add_child(ghost)
		_afterimages.append(ghost)
		_afterimage_remaining.append(0.0)


func _prewarm_dust() -> void:
	_dust_pool = DodgeDustPool2D.new()
	_dust_pool.name = "DodgeDustPool"
	add_child(_dust_pool)
	_dust_pool.setup()


func _spawn_dodge_dust(intensity: float) -> void:
	if _dust_pool == null or robot == null:
		return
	var ground_origin: Node2D = robot.get_node_or_null(
		^"VisualRoot/VisualGroundOrigin"
	) as Node2D
	var origin: Vector2 = (
		ground_origin.global_position if ground_origin != null else robot.global_position
	)
	_dust_pool.spawn(origin, _dodge_facing, intensity * dust_intensity_scale)


func _spawn_afterimage() -> void:
	if sprite == null or _afterimages.is_empty():
		return
	var ghost: Sprite2D = _afterimages[_afterimage_cursor]
	var frame_texture: Texture2D = sprite.sprite_frames.get_frame_texture(
		sprite.animation,
		sprite.frame
	)
	ghost.texture = frame_texture
	ghost.global_transform = sprite.global_transform
	ghost.skew = sprite.skew
	ghost.modulate = Color(0.35, 0.92, 1.0, AFTERIMAGE_ALPHA)
	ghost.visible = true
	_afterimage_remaining[_afterimage_cursor] = AFTERIMAGE_LIFETIME
	_afterimage_cursor = (_afterimage_cursor + 1) % _afterimages.size()


func _advance_afterimages(delta: float) -> void:
	for index: int in range(_afterimages.size()):
		var ghost: Sprite2D = _afterimages[index]
		if not ghost.visible:
			continue
		_afterimage_remaining[index] = maxf(_afterimage_remaining[index] - delta, 0.0)
		var ratio: float = _afterimage_remaining[index] / AFTERIMAGE_LIFETIME
		ghost.modulate.a = AFTERIMAGE_ALPHA * ratio * ratio
		if is_zero_approx(_afterimage_remaining[index]):
			ghost.visible = false


func _play_mechanics(
	stream: AudioStream,
	cue: StringName,
	volume_db: float,
	pitch_scale: float
) -> void:
	if stream == null or _audio_players.is_empty():
		return
	var priority: int = _priority_for_mechanics(cue)
	var player: AudioStreamPlayer2D = _acquire_audio_voice(priority)
	if player == null:
		audio_drop_count += 1
		return
	player.stop()
	player.stream = stream
	player.global_position = robot.global_position if robot != null else Vector2.ZERO
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	_voice_started_order += 1
	AudioVoicePriority.stamp(player, priority, _voice_started_order)
	player.play()
	audio_play_count += 1
	last_audio_cue = cue
	if cue == &"walk_footstep":
		footstep_play_count += 1
	elif cue in [&"ground_slam_impact", &"double_punch_impact"]:
		attack_impact_play_count += 1
	else:
		servo_play_count += 1
		if cue == &"dash_warp":
			dash_warp_sfx_play_count += 1


func _acquire_audio_voice(priority: int) -> AudioStreamPlayer2D:
	var player: AudioStreamPlayer2D = AudioVoicePriority.select_2d(
		_audio_players,
		priority
	)
	if player == null:
		return null
	if player.playing:
		var existing_priority: int = AudioVoicePriority.priority_of(player)
		audio_recycle_count += 1
		if existing_priority < priority:
			audio_preemption_count += 1
			last_preempted_priority = existing_priority
	return player


func _priority_for_mechanics(cue: StringName) -> int:
	match cue:
		&"ground_slam_impact", &"double_punch_impact", &"dash_warp":
			return AudioVoicePriority.SIGNATURE
		&"attack_windup":
			return AudioVoicePriority.MAJOR
		&"walk_footstep":
			return AudioVoicePriority.UI_NAVIGATION
		_:
			return AudioVoicePriority.LOCOMOTION
