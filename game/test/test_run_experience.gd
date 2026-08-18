extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_required_experience_uses_exponential_curve() -> void:
	assert_eq(RunExperience.required_for_level(1), 500)
	assert_eq(RunExperience.required_for_level(2), 675)
	assert_eq(RunExperience.required_for_level(3), 911)
	assert_eq(RunExperience.required_for_level(4), 1230)
	assert_gt(
		RunExperience.required_for_level(12),
		RunExperience.required_for_level(11)
	)


func test_experience_levels_repeatedly_and_preserves_overflow() -> void:
	var experience: RunExperience = RunExperience.new()
	add_child_autofree(experience)
	assert_eq(experience.add_experience(1475), 2)
	assert_eq(experience.level, 3)
	assert_eq(experience.current_experience, 300)
	assert_eq(experience.total_experience, 1475)
	assert_eq(experience.experience_required(), 911)
	assert_almost_eq(experience.progress_ratio(), 300.0 / 911.0, 0.0001)


func test_session_grants_base_xp_once_and_reset_returns_to_level_one() -> void:
	var session: RampageSession = RampageSession.new()
	add_child_autofree(session)
	var event: GameplayEvent = GameplayEvent.new(
		&"xp-event",
		1,
		GameplayEvent.Kind.ENEMY_DEFEATED,
		GameplayEvent.SOLDIER_LAUNCH,
		500
	)
	assert_true(session.publish(event))
	assert_eq(session.run_experience.level, 2)
	assert_eq(session.run_experience.current_experience, 0)
	assert_false(session.publish(event))
	assert_eq(session.run_experience.total_experience, 500)
	session.reset_run()
	assert_eq(session.run_experience.level, 1)
	assert_eq(session.run_experience.current_experience, 0)
	assert_eq(session.run_experience.total_experience, 0)


func test_hud_shows_level_and_preserves_exp_ratio_across_orientation() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	assert_eq(city.gameplay_hud.experience_label.text, "LEVEL 01  EXP 0 / 500")
	city.rampage_session.run_experience.add_experience(250)
	assert_eq(city.gameplay_hud.experience_label.text, "LEVEL 01  EXP 250 / 500")
	assert_almost_eq(city.gameplay_hud.experience_fill.size.x, 127.0, 0.01)
	get_window().content_scale_size = Vector2i(720, 1280)
	get_tree().root.size = Vector2i(720, 1280)
	await get_tree().process_frame
	assert_almost_eq(
		city.gameplay_hud.experience_fill.size.x,
		(city.gameplay_hud.experience_track.size.x - 8.0) * 0.5,
		0.01
	)
	assert_true(
		Rect2(Vector2.ZERO, Vector2(720.0, 1280.0)).encloses(
			city.gameplay_hud.experience_track.get_global_rect()
		)
	)
	get_window().content_scale_size = Vector2i(1280, 720)
	get_tree().root.size = Vector2i(1280, 720)
