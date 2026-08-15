extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"


func test_mobile_detection_floating_joystick_and_smash_multitouch() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var desktop_controls: MobileControls = MobileControls.new()
	desktop_controls.detection_override = 0
	add_child_autofree(desktop_controls)
	await get_tree().process_frame
	assert_false(desktop_controls.mobile_device_detected)
	assert_false(desktop_controls.visible)
	var controls: MobileControls = MobileControls.new()
	controls.detection_override = 1
	add_child_autofree(controls)
	await get_tree().process_frame
	assert_true(controls.mobile_device_detected)
	assert_true(controls.visible)
	assert_gt(controls.smash_bounds().position.x, 1000.0)
	assert_gt(controls.smash_bounds().position.y, 500.0)
	controls.handle_touch_input(_screen_touch(3, Vector2(240.0, 520.0), true))
	assert_true(controls.joystick_active)
	controls.handle_touch_input(_screen_drag(3, Vector2(330.0, 520.0)))
	for response_step: int in range(8):
		controls.process_controls(1.0 / 60.0)
	assert_gt(controls.movement_axis(), 0.8)
	var smash_position: Vector2 = controls.smash_bounds().get_center()
	controls.handle_touch_input(_screen_touch(9, smash_position, true))
	assert_eq(controls.smash_press_count, 1)
	assert_true(controls.joystick_active)
	assert_gt(controls.movement_axis(), 0.8)
	controls.handle_touch_input(_screen_touch(9, smash_position, false))
	controls.handle_touch_input(_screen_touch(3, Vector2(330.0, 520.0), false))
	for settle_step: int in range(8):
		controls.process_controls(1.0 / 60.0)
	assert_false(controls.joystick_active)
	assert_lt(absf(controls.movement_axis()), 0.05)
	_record_test_execution()


func test_mobile_controls_drive_robot_and_smash_then_disable_on_defeat() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	await get_tree().physics_frame
	assert_true(city.mobile_controls.mobile_device_detected)
	assert_true(city.mobile_controls.visible)
	assert_eq(city.mobile_controls.get_parent().name, "HUD")
	var start_x: float = city.robot.position.x
	city.robot.set_physics_process(false)
	city.mobile_controls.handle_touch_input(
		_screen_touch(2, Vector2(210.0, 530.0), true)
	)
	city.mobile_controls.handle_touch_input(
		_screen_drag(2, Vector2(300.0, 530.0))
	)
	for response_step: int in range(8):
		city.mobile_controls.process_controls(1.0 / 60.0)
	assert_gt(city.robot.virtual_move_axis, 0.8)
	for movement_step: int in range(60):
		city.robot.physics_step(city.robot.virtual_move_axis, 1.0 / 60.0)
		await get_tree().physics_frame
	assert_gt(city.robot.position.x, start_x + 150.0)
	city.car.current_health = 1.0
	var smash_position: Vector2 = city.mobile_controls.smash_bounds().get_center()
	city.mobile_controls.handle_touch_input(
		_screen_touch(8, smash_position, true)
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(city.car.is_broken)
	city.robot.receive_damage(DamageEvent.new(9201, null, 9999.0))
	assert_true(city.game_over_active)
	assert_false(city.mobile_controls.joystick_active)
	assert_eq(city.mobile_controls.movement_axis(), 0.0)
	_record_test_execution()


func _screen_touch(
	index: int,
	position: Vector2,
	pressed: bool
) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _screen_drag(index: int, position: Vector2) -> InputEventScreenDrag:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = position
	return event


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
