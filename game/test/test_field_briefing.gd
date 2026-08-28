extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TITLE_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const TEST_PREFERENCE_PATH: String = "user://test-field-briefing-bindings.cfg"


func before_each() -> void:
	L10n.set_locale("en")
	InputBindingSettings.reset_to_defaults(TEST_PREFERENCE_PATH, false)
	_clear_preference()


func after_each() -> void:
	L10n.set_locale("en")
	InputBindingSettings.reset_to_defaults(TEST_PREFERENCE_PATH, false)
	_clear_preference()


func test_arrow_movement_aliases_survive_custom_primary_bindings() -> void:
	assert_true(_has_key(&"move_left", KEY_A))
	assert_true(_has_key(&"move_left", KEY_LEFT))
	assert_true(_has_key(&"move_right", KEY_D))
	assert_true(_has_key(&"move_right", KEY_RIGHT))
	assert_true(_has_key(&"field_briefing", KEY_TAB))
	assert_true(
		InputBindingSettings.set_keyboard_binding(
			&"move_left",
			KEY_J,
			TEST_PREFERENCE_PATH
		)
	)
	assert_true(
		InputBindingSettings.set_keyboard_binding(
			&"move_right",
			KEY_K,
			TEST_PREFERENCE_PATH
		)
	)
	assert_true(_has_key(&"move_left", KEY_J))
	assert_true(_has_key(&"move_left", KEY_LEFT))
	assert_true(_has_key(&"move_right", KEY_K))
	assert_true(_has_key(&"move_right", KEY_RIGHT))
	assert_false(
		InputBindingSettings.set_keyboard_binding(
			&"stomp",
			KEY_LEFT,
			TEST_PREFERENCE_PATH
		)
	)


func test_click_and_tab_toggle_pause_run_and_player_input() -> void:
	var city: CitySlice = await _spawn_city()
	var briefing: FieldBriefingPanel = city.gameplay_hud.field_briefing
	assert_true(briefing.prompt_button.visible)
	assert_true(briefing.prompt_button.text.contains("TAB"))
	briefing.prompt_button.pressed.emit()
	assert_true(briefing.is_open())
	assert_true(city.urban_siege.is_simulation_paused())
	assert_eq(city.urban_siege.pause_coordinator.lease_count(), 1)
	assert_false(city.robot.is_physics_processing())
	assert_false(city.mobile_controls._controls_enabled)
	assert_eq(city.encounter_runtime.process_mode, Node.PROCESS_MODE_DISABLED)
	var tab_event: InputEventAction = InputEventAction.new()
	tab_event.action = &"field_briefing"
	tab_event.pressed = true
	briefing._unhandled_input(tab_event)
	assert_false(briefing.is_open())
	assert_false(city.urban_siege.is_simulation_paused())
	assert_true(city.robot.is_physics_processing())
	assert_true(city.mobile_controls._controls_enabled)


func test_prompt_button_uses_half_scale_landscape_and_portrait_layouts() -> void:
	var city: CitySlice = await _spawn_city()
	var briefing: FieldBriefingPanel = city.gameplay_hud.field_briefing
	briefing.apply_responsive_layout(Vector2(1280.0, 720.0))
	assert_eq(briefing.prompt_button.size, Vector2(166.0, 24.0))
	assert_eq(briefing.prompt_button.get_theme_font_size(&"font_size"), 10)
	briefing.apply_responsive_layout(Vector2(720.0, 1280.0))
	assert_eq(briefing.prompt_button.size, Vector2(125.0, 24.0))
	assert_eq(briefing.prompt_button.get_theme_font_size(&"font_size"), 8)


func test_briefing_does_not_stack_over_an_existing_pause_lease() -> void:
	var city: CitySlice = await _spawn_city()
	var coordinator: RunPauseCoordinator = city.urban_siege.pause_coordinator
	var existing_token: int = coordinator.acquire(&"test_modal")
	assert_gt(existing_token, 0)
	assert_false(city.gameplay_hud.field_briefing.open())
	assert_false(city.gameplay_hud.field_briefing.is_open())
	assert_eq(coordinator.lease_count(), 1)
	assert_true(coordinator.release(existing_token))


func test_terminal_dismisses_briefing_and_hides_prompt_until_resume() -> void:
	var city: CitySlice = await _spawn_city()
	var briefing: FieldBriefingPanel = city.gameplay_hud.field_briefing
	assert_true(briefing.open())
	city.gameplay_hud.show_game_over()
	assert_false(briefing.is_open())
	assert_false(briefing.prompt_button.visible)
	assert_false(city.urban_siege.is_simulation_paused())
	city.gameplay_hud.hide_terminal_overlay()
	assert_true(briefing.prompt_button.visible)


func test_title_field_briefing_displays_the_shared_six_tip_doctrine() -> void:
	var screen: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_true(screen.open_briefing())
	assert_true(screen.briefing_tips_panel.is_visible_in_tree())
	assert_eq(screen.briefing_tips_label.text.count("\n"), 5)
	assert_true(screen.briefing_tips_label.text.contains("DASH + PUNCH"))
	assert_eq(
		screen.briefing_tips_label.text,
		L10n.t("briefing.tips_body", InputBindingSettings.display_placeholders())
	)
	var viewport_size: Vector2 = screen.get_viewport_rect().size
	assert_true(Rect2(Vector2.ZERO, viewport_size).encloses(
		screen.briefing_tips_panel.get_rect()
	))


func test_title_field_briefing_localizes_all_six_moves_in_simplified_chinese() -> void:
	L10n.set_locale("zh-CN")
	var screen: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_true(screen.open_briefing())
	assert_eq(
		screen.briefing_tips_label.text,
		L10n.t("briefing.tips_body", InputBindingSettings.display_placeholders())
	)
	assert_eq(screen.briefing_tips_label.text.count("\n"), 5)
	for move_name: String in [
		"行走", "冲刺", "地面重击", "刺拳连击", "蓄力攻击", "冲刺 + 出拳",
	]:
		assert_true(screen.briefing_tips_label.text.contains(move_name), move_name)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _has_key(action: StringName, keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.physical_keycode == keycode:
			return true
	return false


func _clear_preference() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(TEST_PREFERENCE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
