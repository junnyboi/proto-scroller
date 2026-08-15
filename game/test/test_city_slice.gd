extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"


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


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
