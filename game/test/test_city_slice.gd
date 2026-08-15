extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"
const LAND_VISUAL_BASELINE_Y: float = 655.0


func test_main_transitions_from_title_to_city_slice() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	assert_not_null(main.title_screen)
	main.start_game()
	await get_tree().process_frame
	assert_not_null(main.city_slice)
	assert_true(main.city_slice.robot is GiantRobotController)
	_record_test_execution()


func test_city_slice_builds_parallax_destructibles_and_enemies() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	assert_eq(city.get_node("ParallaxCity").get_child_count(), 5)
	assert_not_null(city.building)
	assert_not_null(city.streetlamp)
	assert_not_null(city.car)
	assert_true(city.soldier is SoldierEnemy)
	assert_true(city.tank is TankEnemy)
	assert_true(city.helicopter is HelicopterEnemy)
	assert_eq(city.debris_pool.available_count(), 24)
	_record_test_execution()


func test_stomp_breaks_the_nearby_car_and_lamp() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.car.current_health = 1.0
	city.streetlamp.current_health = 1.0
	city.robot.stomp_radius = 600.0
	city.robot.stomp_damage = 200.0
	city.trigger_test_stomp()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(city.car.is_broken)
	assert_true(city.streetlamp.is_broken)
	assert_false(city.building.is_destroyed())
	_record_test_execution()


func test_land_visuals_share_the_asphalt_baseline() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var visuals: Array[Sprite2D] = [
		city.building.get_node(^"IntactVisual") as Sprite2D,
		city.streetlamp.get_node(^"Visual") as Sprite2D,
		city.car.get_node(^"Visual") as Sprite2D,
		city.soldier.get_node(^"Visual") as Sprite2D,
		city.tank.get_node(^"Visual") as Sprite2D,
	]
	for visual: Sprite2D in visuals:
		assert_almost_eq(_visual_bottom(visual), LAND_VISUAL_BASELINE_Y, 1.0)
	_record_test_execution()


func test_ground_enemies_bounce_only_while_moving() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	city.soldier.set_physics_process(false)
	city.tank.set_physics_process(false)
	city.soldier.velocity.x = 0.0
	city.tank.velocity.x = 0.0
	for settle_step: int in range(12):
		city.soldier.update_movement_bounce(0.1)
		city.tank.update_movement_bounce(0.1)
	var soldier_rest_y: float = city.soldier.visual.position.y
	var tank_rest_y: float = city.tank.visual.position.y
	city.soldier.velocity.x = city.soldier.move_speed
	city.tank.velocity.x = city.tank.move_speed
	city.soldier.update_movement_bounce(0.06)
	city.tank.update_movement_bounce(0.08)
	assert_lt(city.soldier.visual.position.y, soldier_rest_y)
	assert_lt(city.tank.visual.position.y, tank_rest_y)
	assert_false(city.helicopter.movement_bounce_enabled)
	_record_test_execution()


func test_game_over_retry_replaces_the_city_with_fresh_health() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.start_game()
	await get_tree().process_frame
	var first_city: CitySlice = main.city_slice
	var fatal_event: DamageEvent = DamageEvent.new(9001, null, 9999.0)
	assert_true(first_city.robot.receive_damage(fatal_event))
	assert_true(first_city.game_over_active)
	var overlay: Control = first_city.get_node(^"HUD/GameOverOverlay") as Control
	var retry_button: Button = overlay.get_node(^"RetryButton") as Button
	assert_true(overlay.visible)
	retry_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_ne(main.city_slice, first_city)
	assert_false(main.city_slice.game_over_active)
	assert_eq(main.city_slice.robot.current_health, main.city_slice.robot.max_health)
	_record_test_execution()


func _visual_bottom(visual: Sprite2D) -> float:
	var rendered_height: float = visual.texture.get_size().y * absf(visual.global_scale.y)
	return visual.global_position.y + rendered_height * 0.5


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
