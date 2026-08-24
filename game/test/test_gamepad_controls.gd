extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TITLE_SCREEN_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"
const TEST_PREFERENCE_PATH: String = "user://test-input-bindings.cfg"


func before_each() -> void:
	InputBindingSettings.reset_to_defaults(TEST_PREFERENCE_PATH, false)
	_clear_preference()


func after_each() -> void:
	InputBindingSettings.reset_to_defaults(TEST_PREFERENCE_PATH, false)
	_clear_preference()


func test_project_maps_standard_gamepad_pilot_controls() -> void:
	assert_true(_has_joy_motion(&"move_left", JOY_AXIS_LEFT_X, -1.0))
	assert_true(_has_joy_motion(&"move_right", JOY_AXIS_LEFT_X, 1.0))
	assert_true(_has_joy_button(&"move_left", JOY_BUTTON_DPAD_LEFT))
	assert_true(_has_joy_button(&"move_right", JOY_BUTTON_DPAD_RIGHT))
	assert_true(_has_joy_button(&"stomp", JOY_BUTTON_A))
	assert_true(_has_joy_button(&"dodge", JOY_BUTTON_B))
	assert_eq(InputBindingSettings.keyboard_key(&"dodge"), KEY_SHIFT)
	_record_test_execution()


func test_dedicated_dodge_uses_direction_then_falls_back_to_facing() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var robot: GiantRobotController = city.robot
	robot.set_physics_process(false)
	robot.collision_mask = 0
	robot.gravity = 0.0
	assert_true(robot.request_dodge(-1))
	assert_eq(robot.facing, -1)
	assert_eq(robot.locomotion_state, GiantRobotController.LocomotionState.DODGE)
	assert_eq(robot.dodge_count, 1)
	robot.physics_step(0.0, robot.dodge_duration)
	robot.physics_step(0.0, robot.dodge_cooldown_seconds)
	robot.facing = 1
	assert_true(robot.request_dodge())
	assert_eq(robot.facing, 1)
	assert_eq(robot.dodge_count, 2)
	_record_test_execution()


func test_bindings_persist_and_conflicts_swap_instead_of_duplicate() -> void:
	assert_true(
		InputBindingSettings.set_keyboard_binding(
			&"move_left",
			KEY_J,
			TEST_PREFERENCE_PATH
		)
	)
	assert_true(
		InputBindingSettings.set_gamepad_binding(
			&"stomp",
			JOY_BUTTON_Y,
			TEST_PREFERENCE_PATH
		)
	)
	assert_true(
		InputBindingSettings.set_controller_vibration_enabled(
			false,
			TEST_PREFERENCE_PATH
		)
	)
	InputBindingSettings.reset_to_defaults(TEST_PREFERENCE_PATH, false)
	assert_eq(InputBindingSettings.keyboard_key(&"move_left"), KEY_A)
	assert_eq(InputBindingSettings.gamepad_button(&"stomp"), JOY_BUTTON_A)
	assert_true(InputBindingSettings.controller_vibration_enabled())
	assert_true(InputBindingSettings.apply_saved(TEST_PREFERENCE_PATH))
	assert_eq(InputBindingSettings.keyboard_key(&"move_left"), KEY_J)
	assert_eq(InputBindingSettings.gamepad_button(&"stomp"), JOY_BUTTON_Y)
	assert_false(InputBindingSettings.controller_vibration_enabled())
	assert_true(
		InputBindingSettings.set_keyboard_binding(
			&"move_right",
			KEY_J,
			TEST_PREFERENCE_PATH
		)
	)
	assert_eq(InputBindingSettings.keyboard_key(&"move_left"), KEY_D)
	assert_eq(InputBindingSettings.keyboard_key(&"move_right"), KEY_J)
	_record_test_execution()


func test_gamepad_vibration_is_bounded_and_respects_saved_opt_out() -> void:
	var haptics: HapticsAdapter = HapticsAdapter.new()
	haptics.setup(0, 3)
	add_child_autofree(haptics)
	await get_tree().process_frame
	assert_false(haptics.mobile_device_detected)
	assert_eq(haptics.gamepad_device_id, 3)
	assert_true(haptics.pulse(250))
	assert_eq(haptics.request_count, 1)
	assert_eq(haptics.gamepad_vibration_request_count, 1)
	assert_eq(haptics.last_duration_ms, 100)
	assert_between(haptics.last_weak_magnitude, 0.18, 0.55)
	assert_between(haptics.last_strong_magnitude, 0.35, 1.0)
	assert_eq(haptics.last_gamepad_duration_seconds, 0.10)
	assert_true(
		InputBindingSettings.set_controller_vibration_enabled(
			false,
			TEST_PREFERENCE_PATH
		)
	)
	assert_false(haptics.pulse(52))
	assert_eq(haptics.request_count, 1)
	assert_eq(haptics.gamepad_vibration_request_count, 1)
	_record_test_execution()


func test_settings_capture_updates_labels_and_reset_restores_defaults() -> void:
	var screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate() as TitleScreen
	screen.input_preference_path = TEST_PREFERENCE_PATH
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_true(screen.open_settings())
	var left_keyboard: Button = screen.get_node("%MoveLeftKeyboardButton") as Button
	left_keyboard.pressed.emit()
	assert_eq(left_keyboard.text, L10n.t("title.input_press_key"))
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = KEY_J
	key_event.pressed = true
	screen._input(key_event)
	assert_eq(InputBindingSettings.keyboard_key(&"move_left"), KEY_J)
	assert_eq(left_keyboard.text, "J")
	var dodge_gamepad: Button = screen.get_node("%DodgeGamepadButton") as Button
	dodge_gamepad.pressed.emit()
	assert_eq(dodge_gamepad.text, L10n.t("title.input_press_button"))
	var button_event: InputEventJoypadButton = InputEventJoypadButton.new()
	button_event.button_index = JOY_BUTTON_X
	button_event.pressed = true
	screen._input(button_event)
	assert_eq(InputBindingSettings.gamepad_button(&"dodge"), JOY_BUTTON_X)
	assert_eq(dodge_gamepad.text, "X / SQUARE")
	assert_true((screen.get_node("MoveChip/Label") as Label).text.begins_with("J / D"))
	var vibration_toggle: CheckButton = (
		screen.get_node("%ControllerVibrationToggle") as CheckButton
	)
	vibration_toggle.button_pressed = false
	assert_false(InputBindingSettings.controller_vibration_enabled())
	(screen.get_node("%ResetBindingsButton") as Button).pressed.emit()
	assert_eq(InputBindingSettings.keyboard_key(&"move_left"), KEY_A)
	assert_eq(InputBindingSettings.gamepad_button(&"dodge"), JOY_BUTTON_B)
	assert_true(InputBindingSettings.controller_vibration_enabled())
	assert_true(vibration_toggle.button_pressed)
	assert_true((screen.get_node("MoveChip/Label") as Label).text.begins_with("A / D"))
	_record_test_execution()


func _has_joy_button(action: StringName, button_index: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var button_event: InputEventJoypadButton = event as InputEventJoypadButton
		if button_event != null and button_event.button_index == button_index:
			return true
	return false


func _has_joy_motion(action: StringName, axis: JoyAxis, axis_value: float) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var motion_event: InputEventJoypadMotion = event as InputEventJoypadMotion
		if (
			motion_event != null
			and motion_event.axis == axis
			and is_equal_approx(motion_event.axis_value, axis_value)
		):
			return true
	return false


func _clear_preference() -> void:
	if FileAccess.file_exists(TEST_PREFERENCE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PREFERENCE_PATH))


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
