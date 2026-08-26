extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")


func test_begin_expedition_fades_through_black_once() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.title_transition_duration_scale = 0.25
	var overlay: ColorRect = main.transition_overlay
	var screen: TitleScreen = main.title_screen
	var launch_button: Button = screen.initialize_button
	assert_false(overlay.visible)
	assert_almost_eq(overlay.modulate.a, 0.0, 0.001)
	launch_button.pressed.emit()
	assert_true(screen.initialized)
	launch_button.pressed.emit()
	await get_tree().process_frame
	assert_true(main.title_transition_active)
	assert_true(overlay.visible)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_STOP)
	for frame: int in range(120):
		if not main.title_transition_active:
			break
		await get_tree().process_frame
	assert_false(main.title_transition_active)
	assert_null(main.title_screen)
	assert_not_null(main.city_slice)
	assert_true(main.city_slice.robot is GiantRobotController)
	assert_false(overlay.visible)
	assert_almost_eq(overlay.modulate.a, 0.0, 0.001)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(main.find_children("CitySlice", "CitySlice", true, false).size(), 1)
