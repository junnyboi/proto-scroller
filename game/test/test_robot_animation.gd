extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const EXPECTED_ANIMATIONS: Array[StringName] = [
	&"attack_e",
	&"attack_se",
	&"attack_sw",
	&"attack_w",
	&"idle_s",
	&"walk_e",
	&"walk_w",
]
const FORBIDDEN_SCROLLER_ANIMATIONS: Array[StringName] = [
	&"walk_n",
	&"walk_ne",
	&"walk_nw",
	&"attack_n",
	&"attack_ne",
	&"attack_nw",
	&"idle_n",
]


func test_library_excludes_all_northward_walk_and_attack_directions() -> void:
	var city: CitySlice = await _spawn_city()
	var sprite: AnimatedSprite2D = _sprite(city)
	var visual_root: Node2D = sprite.get_parent() as Node2D
	assert_almost_eq(
		visual_root.position.y,
		CityWorldBuilder.ROBOT_ROAD_CENTER_VISUAL_OFFSET_Y,
		0.001
	)
	var body_collision: CollisionShape2D = city.robot.get_node(^"BodyCollision") as CollisionShape2D
	assert_eq(body_collision.position, Vector2(0.0, 21.0))
	var gameplay_ground: Marker2D = city.robot.get_node(^"GroundImpactOrigin") as Marker2D
	var visual_ground: Marker2D = city.robot.get_node(
		^"VisualRoot/VisualGroundOrigin"
	) as Marker2D
	assert_eq(gameplay_ground.position, Vector2(0.0, 126.0))
	assert_eq(visual_ground.position, Vector2(0.0, 126.0))
	assert_almost_eq(
		visual_ground.global_position.y - gameplay_ground.global_position.y,
		CityWorldBuilder.ROBOT_ROAD_CENTER_VISUAL_OFFSET_Y,
		0.001
	)
	var names: PackedStringArray = sprite.sprite_frames.get_animation_names()
	names.sort()
	assert_eq(names, PackedStringArray(EXPECTED_ANIMATIONS))
	for animation: StringName in EXPECTED_ANIMATIONS:
		var expected_frames: int = 1 if animation == &"idle_s" else 25
		assert_eq(sprite.sprite_frames.get_frame_count(animation), expected_frames)
	for forbidden_animation: StringName in FORBIDDEN_SCROLLER_ANIMATIONS:
		assert_false(sprite.sprite_frames.has_animation(forbidden_animation))
	assert_false(sprite.flip_h)
	assert_almost_eq(sprite.scale.x, 1.246, 0.001)
	assert_almost_eq(sprite.position.y, 72.0, 0.001)


func test_idle_always_faces_south_while_walk_uses_east_and_west() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var sprite: AnimatedSprite2D = _sprite(city)
	var visual_root: Node2D = robot.get_node(^"VisualRoot") as Node2D
	var emitter: Node2D = visual_root.get_node(^"LaserEmitter") as Node2D
	assert_eq(sprite.animation, &"idle_s")
	assert_eq(sprite.frame, 0)
	assert_false(sprite.is_playing())
	robot.locomotion_state = GiantRobotController.LocomotionState.WALK
	robot.locomotion_changed.emit(robot.locomotion_state)
	assert_eq(sprite.animation, &"walk_e")
	assert_true(sprite.is_playing())
	robot.facing = -1
	robot.facing_changed.emit(robot.facing)
	assert_eq(sprite.animation, &"walk_w")
	assert_gt(visual_root.scale.x, 0.0)
	assert_lt(emitter.position.x, 0.0)
	robot.locomotion_state = GiantRobotController.LocomotionState.IDLE
	robot.locomotion_changed.emit(robot.locomotion_state)
	assert_eq(sprite.animation, &"idle_s")
	assert_eq(sprite.frame, 0)
	assert_false(sprite.is_playing())


func test_attacks_map_cardinal_punches_and_diagonal_slams_with_frame_11_commit() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	var sprite: AnimatedSprite2D = _sprite(city)
	_assert_attack(presenter, robot, sprite, AttackSpec.Mode.GROUND_SMASH, 1, &"attack_se")
	_assert_attack(presenter, robot, sprite, AttackSpec.Mode.GROUND_SMASH, -1, &"attack_sw")
	_assert_attack(presenter, robot, sprite, AttackSpec.Mode.JAB_CROSS, 1, &"attack_e")
	_assert_attack(presenter, robot, sprite, AttackSpec.Mode.JAB_CROSS, -1, &"attack_w")


func test_contextual_attack_flow_drives_real_slam_and_punch_clips() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var sprite: AnimatedSprite2D = _sprite(city)
	robot.global_position = Vector2(80.0, 460.0)
	robot.stomp_damage = 0.0
	robot.stomp_radius = 1.0
	assert_gt(robot.request_attack(), 0)
	var ground_spec: AttackSpec = city.contextual_attacks.current_spec
	assert_true(ground_spec.is_ground_smash())
	assert_eq(sprite.animation, &"attack_se")
	await get_tree().create_timer(ground_spec.anticipation_seconds + 0.04).timeout
	assert_gte(sprite.frame, RobotAnimationPresenter.ATTACK_EVENT_FRAME)
	assert_true(sprite.is_playing())
	await _wait_for_attack(city.contextual_attacks)
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	assert_eq(presenter.last_completed_attack_frame, 24)
	assert_eq(sprite.animation, &"idle_s")
	robot.velocity.x = robot.max_speed
	assert_gt(robot.request_attack(), 0)
	var jab_spec: AttackSpec = city.contextual_attacks.current_spec
	assert_not_null(jab_spec)
	if jab_spec == null:
		return
	assert_true(jab_spec.is_jab_cross())
	assert_eq(sprite.animation, &"attack_e")
	await get_tree().create_timer(jab_spec.anticipation_seconds + 0.04).timeout
	assert_gte(sprite.frame, RobotAnimationPresenter.ATTACK_EVENT_FRAME)
	assert_true(sprite.is_playing())
	await _wait_for_attack(city.contextual_attacks)
	assert_eq(presenter.last_completed_attack_frame, 24)
	assert_eq(presenter.completed_full_attack_count, 2)
	assert_eq(sprite.animation, &"idle_s")


func test_upgrade_pause_cancels_melee_and_restores_directional_walk_animation() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var sprite: AnimatedSprite2D = _sprite(city)
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	robot.collision_mask = 0
	robot.gravity = 0.0
	robot.velocity.x = robot.max_speed
	var terminal_specs: Array[AttackSpec] = []
	city.contextual_attacks.attack_finished.connect(
		func(spec: AttackSpec) -> void:
			terminal_specs.append(spec)
	)
	assert_gt(robot.request_attack(), 0)
	assert_true(city.contextual_attacks.is_busy())
	assert_true(presenter.attacking)
	assert_eq(sprite.animation, &"attack_e")
	var pause_token: int = city.urban_siege.pause_coordinator.acquire(&"upgrade_choice")
	assert_false(city.contextual_attacks.is_busy())
	assert_eq(terminal_specs.size(), 1)
	city.contextual_attacks.cancel_attack()
	assert_eq(terminal_specs.size(), 1)
	assert_false(presenter.attacking)
	assert_eq(sprite.animation, &"idle_s")
	assert_false(sprite.is_playing())
	assert_true(city.urban_siege.pause_coordinator.release(pause_token))
	robot.physics_step(1.0, 0.10)
	assert_eq(robot.locomotion_state, GiantRobotController.LocomotionState.WALK)
	assert_eq(sprite.animation, &"walk_e")
	assert_true(sprite.is_playing())
	robot.facing = -1
	robot.facing_changed.emit(robot.facing)
	assert_eq(sprite.animation, &"walk_w")
	assert_true(sprite.is_playing())


func test_critical_health_smoke_emits_at_or_below_twenty_five_percent() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	var smoke: CPUParticles2D = (
		robot.get_node(^"VisualRoot/CriticalHealthSmoke") as CPUParticles2D
	)
	assert_eq(presenter.critical_smoke_emitter_count(), 1)
	assert_not_null(smoke.texture)
	assert_false(presenter.critical_smoke_emitting())
	robot.current_health = robot.max_health * 0.26
	robot.health_changed.emit(robot.current_health, robot.max_health)
	assert_false(presenter.critical_smoke_emitting())
	robot.current_health = robot.max_health * 0.25
	robot.health_changed.emit(robot.current_health, robot.max_health)
	assert_true(presenter.critical_smoke_emitting())
	assert_gt(smoke.position.x, 0.0)
	robot.facing = -1
	robot.facing_changed.emit(-1)
	assert_lt(smoke.position.x, 0.0)
	robot.current_health = 0.0
	robot.health_changed.emit(robot.current_health, robot.max_health)
	assert_false(presenter.critical_smoke_emitting())
	robot.current_health = robot.max_health * 0.5
	robot.health_changed.emit(robot.current_health, robot.max_health)
	assert_false(presenter.critical_smoke_emitting())
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_robot_mechanics_audio_is_pcm_fixed_and_frame_synchronized() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var sprite: AnimatedSprite2D = _sprite(city)
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	_assert_pcm_cue(RobotAnimationPresenter.FOOTSTEP_SFX)
	_assert_pcm_cue(RobotAnimationPresenter.SERVO_SFX)
	_assert_pcm_cue(RobotAnimationPresenter.DODGE_SERVO_SFX)
	_assert_pcm_cue(RobotAnimationPresenter.DODGE_RECHARGED_SFX)
	_assert_compressed_runtime_cue(RobotAnimationPresenter.GROUND_SLAM_IMPACT_SFX)
	_assert_compressed_runtime_cue(RobotAnimationPresenter.DOUBLE_PUNCH_IMPACT_SFX)
	assert_eq(presenter.audio_voice_count(), RuntimeBudget.ROBOT_AUDIO_VOICES)
	for audio_node: Node in presenter.find_children("RobotMechanicsAudio*", "AudioStreamPlayer2D"):
		assert_eq((audio_node as AudioStreamPlayer2D).bus, GameAudioBus.MECHANICS)
	assert_eq(
		(presenter.get_node(^"RobotStatusRechargeSfx") as AudioStreamPlayer).bus,
		GameAudioBus.MECHANICS
	)
	var frame_callable: Callable = presenter._on_sprite_frame_changed
	sprite.frame_changed.disconnect(frame_callable)
	robot.locomotion_state = GiantRobotController.LocomotionState.WALK
	sprite.play(&"walk_e")
	sprite.pause()
	var impact_positions: Array[Vector2] = []
	robot.footstep_impact.connect(
		func(position: Vector2, _strength: float) -> void:
			impact_positions.append(position)
	)
	_set_walk_audio_frame(presenter, sprite, 1)
	assert_eq(presenter.audio_play_count, 0)
	_set_walk_audio_frame(presenter, sprite, 2)
	assert_eq(presenter.servo_play_count, 1)
	assert_eq(presenter.last_audio_cue, &"walk_servo")
	_set_walk_audio_frame(presenter, sprite, 5)
	assert_eq(presenter.footstep_play_count, 1)
	assert_eq(impact_positions.size(), 1)
	_set_walk_audio_frame(presenter, sprite, 15)
	_set_walk_audio_frame(presenter, sprite, 18)
	assert_eq(presenter.servo_play_count, 2)
	assert_eq(presenter.footstep_play_count, 2)
	assert_eq(impact_positions.size(), 2)
	presenter._on_attack_selected(AttackSpec.Mode.GROUND_SMASH, 501)
	assert_eq(presenter.servo_play_count, 3)
	assert_eq(presenter.last_audio_cue, &"attack_windup")
	presenter._on_attack_committed(AttackSpec.Mode.GROUND_SMASH, 501)
	assert_eq(presenter.attack_impact_play_count, 1)
	assert_eq(presenter.last_audio_cue, &"ground_slam_impact")
	assert_eq(sprite.frame, RobotAnimationPresenter.ATTACK_EVENT_FRAME)
	presenter._on_attack_committed(AttackSpec.Mode.JAB_CROSS, 501)
	assert_eq(presenter.attack_impact_play_count, 2)
	assert_eq(presenter.last_audio_cue, &"double_punch_impact")
	for cycle_index: int in range(8):
		presenter.attacking = false
		_set_walk_audio_frame(presenter, sprite, 2 if cycle_index % 2 == 0 else 5)
	assert_eq(presenter.audio_voice_count(), RuntimeBudget.ROBOT_AUDIO_VOICES)
	assert_gt(presenter.audio_recycle_count, 0)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_robot_mechanics_priority_stealing_protects_signature_cues() -> void:
	var city: CitySlice = await _spawn_city()
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	for index: int in range(RobotAnimationPresenter.AUDIO_VOICE_CAPACITY):
		presenter._play_mechanics(
			RobotAnimationPresenter.SERVO_SFX,
			&"walk_servo",
			-7.0,
			1.0
		)
	for player: AudioStreamPlayer2D in presenter._audio_players:
		assert_eq(
			AudioVoicePriority.priority_of(player),
			AudioVoicePriority.LOCOMOTION
		)
	for index: int in range(RobotAnimationPresenter.AUDIO_VOICE_CAPACITY):
		presenter._play_mechanics(
			RobotAnimationPresenter.DOUBLE_PUNCH_IMPACT_SFX,
			&"double_punch_impact",
			2.0,
			1.0
		)
	assert_eq(
		presenter.audio_preemption_count,
		RobotAnimationPresenter.AUDIO_VOICE_CAPACITY
	)
	assert_eq(presenter.last_preempted_priority, AudioVoicePriority.LOCOMOTION)
	for player: AudioStreamPlayer2D in presenter._audio_players:
		assert_eq(
			AudioVoicePriority.priority_of(player),
			AudioVoicePriority.SIGNATURE
		)
	var accepted_count: int = presenter.audio_play_count
	presenter._play_mechanics(
		RobotAnimationPresenter.SERVO_SFX,
		&"walk_servo",
		-7.0,
		1.0
	)
	assert_eq(presenter.audio_play_count, accepted_count)
	assert_eq(presenter.audio_drop_count, 1)
	assert_eq(presenter.last_audio_cue, &"double_punch_impact")
	assert_eq(presenter.audio_voice_count(), RuntimeBudget.ROBOT_AUDIO_VOICES)


func test_dodge_recharge_sfx_plays_once_when_cooldown_completes() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	robot.collision_mask = 0
	robot.gravity = 0.0
	assert_eq(presenter.dodge_recharged_sfx_play_count, 0)
	assert_eq(presenter._status_sfx_player.bus, GameAudioBus.MECHANICS)
	assert_same(
		RobotAnimationPresenter.DODGE_RECHARGED_SFX,
		load("res://audio/sfx/robot/dodge_energy_recharged.wav")
	)
	assert_true(robot._start_dodge())
	robot.physics_step(0.0, 0.60)
	assert_eq(presenter.dodge_recharged_sfx_play_count, 0)
	robot.physics_step(0.0, 0.60)
	assert_eq(presenter.dodge_recharged_sfx_play_count, 1)
	assert_eq(presenter.last_audio_cue, &"dodge_recharged")
	assert_same(presenter._status_sfx_player.stream, presenter.DODGE_RECHARGED_SFX)
	robot.physics_step(0.0, 0.20)
	assert_eq(presenter.dodge_recharged_sfx_play_count, 1)
	assert_eq(presenter.audio_voice_count(), RuntimeBudget.ROBOT_AUDIO_VOICES)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func test_dodge_uses_facing_lean_and_restores_clean_sprite_state() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var sprite: AnimatedSprite2D = _sprite(city)
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	presenter.set_process(false)
	robot.collision_mask = 0
	robot.gravity = 0.0
	robot.global_position = Vector2(600.0, 460.0)
	var baseline_nodes: int = int(RuntimeBudget.snapshot(city).node_count)
	robot.facing = -1
	robot.facing_changed.emit(-1)
	assert_true(robot._start_dodge())
	assert_eq(presenter.dodge_servo_play_count, 1)
	assert_eq(presenter.last_audio_cue, &"dodge_servo")
	assert_eq(presenter.audio_voice_count(), RuntimeBudget.ROBOT_AUDIO_VOICES)
	assert_true(presenter.dodging)
	assert_gt(sprite.skew, 0.0)
	assert_lt(sprite.modulate.a, 1.0)
	assert_eq(presenter.afterimage_slot_count(), RuntimeBudget.DODGE_AFTERIMAGE_SLOTS)
	assert_eq(presenter.active_afterimage_count(), 1)
	assert_eq(presenter.dust_slot_count(), RuntimeBudget.DODGE_DUST_SLOTS)
	assert_eq(presenter.active_dust_slot_count(), 1)
	assert_gt(presenter._dust_pool.last_direction.x, 0.0)
	assert_lt(presenter._dust_pool.last_direction.y, 0.0)
	for step_index: int in range(4):
		robot.physics_step(0.0, 0.04)
		presenter._process(0.04)
	assert_gte(presenter.active_afterimage_count(), 4)
	assert_gte(presenter.active_dust_slot_count(), 3)
	var minimum_x: float = INF
	var maximum_x: float = -INF
	for ghost: Sprite2D in presenter._afterimages:
		if ghost.visible:
			minimum_x = minf(minimum_x, ghost.global_position.x)
			maximum_x = maxf(maximum_x, ghost.global_position.x)
	assert_gt(maximum_x - minimum_x, 30.0)
	for saturation_index: int in range(16):
		presenter._spawn_afterimage()
		presenter._spawn_dodge_dust(1.0)
	assert_eq(presenter.active_afterimage_count(), RuntimeBudget.DODGE_AFTERIMAGE_SLOTS)
	assert_eq(presenter.active_dust_slot_count(), RuntimeBudget.DODGE_DUST_SLOTS)
	assert_gt(presenter._dust_pool.recycle_count, 0)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), baseline_nodes)
	robot.physics_step(0.0, 0.03)
	presenter._process(0.03)
	assert_false(presenter.dodging)
	assert_eq(sprite.skew, 0.0)
	assert_eq(sprite.modulate, Color.WHITE)
	presenter._process(RobotAnimationPresenter.AFTERIMAGE_LIFETIME + 0.01)
	assert_eq(presenter.active_afterimage_count(), 0)
	presenter._dust_pool.stop_all()
	assert_eq(presenter.active_dust_slot_count(), 0)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func _assert_attack(
	presenter: RobotAnimationPresenter,
	robot: GiantRobotController,
	sprite: AnimatedSprite2D,
	mode: int,
	facing: int,
	expected: StringName
) -> void:
	robot.facing = facing
	robot.facing_changed.emit(facing)
	var attack_id: int = 100 + mode * 10 + (1 if facing > 0 else 2)
	presenter._on_attack_selected(mode, attack_id)
	assert_eq(sprite.animation, expected)
	assert_true(sprite.is_playing())
	presenter._on_attack_committed(mode, attack_id)
	assert_eq(sprite.frame, 11)
	assert_true(sprite.is_playing())
	sprite.pause()
	sprite.set_frame_and_progress(24, 0.0)
	var spec: AttackSpec = AttackSpec.new(
		mode,
		attack_id,
		facing,
		0.0,
		0.0,
		0.0,
		0.0,
		1.0,
		1.0,
		1.0,
		Vector2.ONE,
		Vector2.ZERO
	)
	presenter._on_attack_finished(spec)
	assert_eq(presenter.last_completed_attack_frame, 24)
	assert_eq(sprite.animation, &"idle_s")


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _wait_for_attack(controller: ContextualAttackController) -> void:
	var spec: AttackSpec = controller.current_spec
	if spec != null:
		await get_tree().create_timer(
			spec.anticipation_seconds
			+ spec.active_seconds
			+ spec.recovery_seconds
			+ 0.10
		).timeout
	assert_false(controller.is_busy())


func _assert_pcm_cue(stream: AudioStream) -> void:
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	assert_not_null(wav)
	if wav == null:
		return
	assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(wav.mix_rate, 48000)
	assert_false(wav.stereo)


func _assert_compressed_runtime_cue(stream: AudioStream) -> void:
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	assert_not_null(wav)
	if wav == null:
		return
	assert_eq(wav.format, AudioStreamWAV.FORMAT_QOA)
	assert_eq(wav.mix_rate, 48000)
	assert_false(wav.stereo)
	assert_gt(wav.get_length(), 1.0)
	assert_lt(wav.get_length(), 2.1)


func _assert_compact_voice_cue(stream: AudioStream) -> void:
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	assert_not_null(wav)
	if wav == null:
		return
	assert_eq(wav.format, AudioStreamWAV.FORMAT_QOA)
	assert_eq(wav.mix_rate, 24000)
	assert_false(wav.stereo)


func _set_walk_audio_frame(
	presenter: RobotAnimationPresenter,
	sprite: AnimatedSprite2D,
	frame: int
) -> void:
	sprite.set_frame_and_progress(frame, 0.0)
	presenter._on_sprite_frame_changed()


func _sprite(city: CitySlice) -> AnimatedSprite2D:
	return city.robot.get_node(^"VisualRoot/RobotAnimatedSprite") as AnimatedSprite2D
