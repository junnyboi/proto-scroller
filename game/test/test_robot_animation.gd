extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const EXPECTED_ANIMATIONS: Array[StringName] = [
	&"attack_e",
	&"attack_se",
	&"attack_sw",
	&"attack_w",
	&"idle_n",
	&"idle_s",
	&"walk_e",
	&"walk_w",
]


func test_horizontal_sprite_library_contains_only_required_baked_directions() -> void:
	var city: CitySlice = await _spawn_city()
	var sprite: AnimatedSprite2D = _sprite(city)
	var names: PackedStringArray = sprite.sprite_frames.get_animation_names()
	names.sort()
	assert_eq(names, PackedStringArray(EXPECTED_ANIMATIONS))
	for animation: StringName in EXPECTED_ANIMATIONS:
		var expected_frames: int = 1 if animation == &"idle_n" or animation == &"idle_s" else 25
		assert_eq(sprite.sprite_frames.get_frame_count(animation), expected_frames)
	assert_false(sprite.flip_h)
	assert_almost_eq(sprite.scale.x, 1.246, 0.001)
	assert_almost_eq(sprite.position.y, 72.0, 0.001)


func test_idle_and_walk_use_front_back_and_east_west_without_root_mirroring() -> void:
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
	assert_eq(sprite.animation, &"idle_n")
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
	assert_gt(robot.request_attack(), 0)
	assert_true(city.contextual_attacks.current_spec.is_ground_smash())
	assert_eq(sprite.animation, &"attack_se")
	await get_tree().create_timer(0.12).timeout
	assert_eq(sprite.frame, 11)
	await _wait_for_attack(city.contextual_attacks)
	assert_eq(sprite.animation, &"idle_s")
	robot.velocity.x = robot.max_speed
	assert_gt(robot.request_attack(), 0)
	assert_true(city.contextual_attacks.current_spec.is_jab_cross())
	assert_eq(sprite.animation, &"attack_e")
	await get_tree().create_timer(0.07).timeout
	assert_eq(sprite.frame, 11)
	await _wait_for_attack(city.contextual_attacks)
	assert_eq(sprite.animation, &"idle_s")


func test_robot_mechanics_audio_is_pcm_fixed_and_frame_synchronized() -> void:
	var city: CitySlice = await _spawn_city()
	var robot: GiantRobotController = city.robot
	var sprite: AnimatedSprite2D = _sprite(city)
	var presenter: RobotAnimationPresenter = (
		robot.get_node(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	_assert_pcm_cue(RobotAnimationPresenter.FOOTSTEP_SFX)
	_assert_pcm_cue(RobotAnimationPresenter.SERVO_SFX)
	assert_eq(presenter.audio_voice_count(), RuntimeBudget.ROBOT_AUDIO_VOICES)
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
	assert_eq(presenter.last_audio_cue, &"attack_piston")
	assert_eq(sprite.frame, RobotAnimationPresenter.ATTACK_EVENT_FRAME)
	for cycle_index: int in range(8):
		presenter.attacking = false
		_set_walk_audio_frame(presenter, sprite, 2 if cycle_index % 2 == 0 else 5)
	assert_eq(presenter.audio_voice_count(), RuntimeBudget.ROBOT_AUDIO_VOICES)
	assert_gt(presenter.audio_recycle_count, 0)
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
	assert_false(sprite.is_playing())
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
	assert_eq(sprite.animation, &"idle_s" if facing > 0 else &"idle_n")


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _wait_for_attack(controller: ContextualAttackController) -> void:
	for frame_index: int in range(60):
		if not controller.is_busy():
			return
		await get_tree().process_frame
	assert_false(controller.is_busy())


func _assert_pcm_cue(stream: AudioStream) -> void:
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	assert_not_null(wav)
	if wav == null:
		return
	assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(wav.mix_rate, 48000)
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
