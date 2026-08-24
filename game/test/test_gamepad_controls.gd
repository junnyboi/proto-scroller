extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"


func test_project_maps_standard_gamepad_pilot_controls() -> void:
	assert_true(_has_joy_motion(&"move_left", JOY_AXIS_LEFT_X, -1.0))
	assert_true(_has_joy_motion(&"move_right", JOY_AXIS_LEFT_X, 1.0))
	assert_true(_has_joy_button(&"move_left", JOY_BUTTON_DPAD_LEFT))
	assert_true(_has_joy_button(&"move_right", JOY_BUTTON_DPAD_RIGHT))
	assert_true(_has_joy_button(&"stomp", JOY_BUTTON_A))
	assert_true(_has_joy_button(&"dodge", JOY_BUTTON_B))
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


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
