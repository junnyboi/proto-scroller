class_name RobotAnimationPresenter
extends Node

const ATTACK_EVENT_FRAME: int = AttackResolver.ATTACK_EVENT_FRAME
const WALK_REFERENCE_SPEED: float = 260.0
const AUDIO_VOICE_CAPACITY: int = 4
const WALK_SERVO_FRAMES: Array[int] = [2, 15]
const WALK_CONTACT_FRAMES: Array[int] = [5, 18]
const FOOTSTEP_SFX: AudioStream = preload(
	"res://audio/sfx/robot/robot_footstep.wav"
)
const SERVO_SFX: AudioStream = preload(
	"res://audio/sfx/robot/robot_servo.wav"
)

var robot: GiantRobotController
var sprite: AnimatedSprite2D
var attacking: bool = false
var dodging: bool = false
var selected_attack_id: int = 0
var audio_play_count: int = 0
var footstep_play_count: int = 0
var servo_play_count: int = 0
var attack_impact_play_count: int = 0
var audio_recycle_count: int = 0
var last_audio_cue: StringName = &""
var last_completed_attack_frame: int = -1
var completed_full_attack_count: int = 0
var _audio_players: Array[AudioStreamPlayer2D] = []
var _audio_cursor: int = 0


func setup(p_robot: GiantRobotController, p_sprite: AnimatedSprite2D) -> void:
	robot = p_robot
	sprite = p_sprite
	robot.facing_changed.connect(_on_facing_changed)
	robot.locomotion_changed.connect(_on_locomotion_changed)
	robot.attack_mode_selected.connect(_on_attack_selected)
	robot.attack_committed.connect(_on_attack_committed)
	robot.dodge_started.connect(_on_dodge_started)
	robot.dodge_finished.connect(_on_dodge_finished)
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	_prewarm_audio()
	_show_idle()


func bind_attacks(controller: ContextualAttackController) -> void:
	controller.attack_finished.connect(_on_attack_finished)


func audio_voice_count() -> int:
	return _audio_players.size()


func _process(_delta: float) -> void:
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


func _on_attack_committed(mode: int, attack_id: int) -> void:
	if not attacking or attack_id != selected_attack_id:
		return
	if sprite.frame < ATTACK_EVENT_FRAME:
		sprite.set_frame_and_progress(ATTACK_EVENT_FRAME, 0.0)
	var pitch: float = 0.84 if mode == AttackSpec.Mode.GROUND_SMASH else 1.0
	_play_mechanics(FOOTSTEP_SFX, &"attack_piston", 2.0, pitch)


func _on_attack_finished(spec: AttackSpec) -> void:
	if spec == null or spec.attack_id != selected_attack_id:
		return
	last_completed_attack_frame = sprite.frame
	if sprite.frame == RobotSpriteFramesBuilder.FRAME_COUNT - 1:
		completed_full_attack_count += 1
	attacking = false
	selected_attack_id = 0
	if robot.locomotion_state == GiantRobotController.LocomotionState.WALK:
		_play_walk()
	else:
		_show_idle()


func _on_dodge_started(p_facing: int, _duration: float) -> void:
	dodging = true
	_show_idle()
	sprite.skew = -float(p_facing) * 0.10
	sprite.modulate = Color(0.72, 0.94, 1.0, 0.82)


func _on_dodge_finished() -> void:
	dodging = false
	sprite.skew = 0.0
	sprite.modulate = Color.WHITE
	if robot.locomotion_state == GiantRobotController.LocomotionState.WALK:
		_play_walk()
	else:
		_show_idle()


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
	var animation: StringName = &"idle_s" if robot.facing >= 0 else &"idle_n"
	sprite.speed_scale = 1.0
	sprite.play(animation)
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


func _prewarm_audio() -> void:
	for index: int in range(AUDIO_VOICE_CAPACITY):
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		player.name = "RobotMechanicsAudio%02d" % index
		player.max_distance = 1500.0
		player.attenuation = 0.45
		add_child(player)
		_audio_players.append(player)


func _play_mechanics(
	stream: AudioStream,
	cue: StringName,
	volume_db: float,
	pitch_scale: float
) -> void:
	if stream == null or _audio_players.is_empty():
		return
	var player: AudioStreamPlayer2D = _acquire_audio_voice()
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
	audio_play_count += 1
	last_audio_cue = cue
	if cue == &"walk_footstep":
		footstep_play_count += 1
	elif cue == &"attack_piston":
		attack_impact_play_count += 1
	else:
		servo_play_count += 1


func _acquire_audio_voice() -> AudioStreamPlayer2D:
	for player: AudioStreamPlayer2D in _audio_players:
		if not player.playing:
			return player
	var player: AudioStreamPlayer2D = _audio_players[_audio_cursor]
	_audio_cursor = (_audio_cursor + 1) % _audio_players.size()
	audio_recycle_count += 1
	return player
