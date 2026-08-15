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


func test_city_slice_builds_parallax_structural_cells_and_enemies() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	assert_eq(city.get_node("ParallaxCity").get_child_count(), 5)
	assert_not_null(city.building)
	assert_eq(city.building.get_child_count(), 6)
	for row: int in range(StructuralBuilding2D.ROWS):
		for column: int in range(StructuralBuilding2D.COLUMNS):
			assert_not_null(city.building.get_cell(column, row))
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
	city.streetlamp.current_health = 0.05
	city.robot.stomp_radius = 500.0
	city.robot.stomp_damage = 200.0
	city.trigger_test_stomp()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(city.car.is_broken)
	assert_true(city.streetlamp.is_broken)
	assert_eq(city.building.destroyed_cell_count(), 0)
	assert_eq(city.score, 450)
	_record_test_execution()


func test_impact_destroys_only_the_struck_lower_bay() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var hit_position: Vector2 = city.building.global_position + Vector2(-210.0, -110.0)
	var attack_id: int = city.robot.request_structure_impact(
		city.building,
		hit_position,
		Vector2.RIGHT,
		260.0
	)
	await get_tree().process_frame
	assert_gt(attack_id, 0)
	assert_true(city.building.is_cell_destroyed(0, 1))
	assert_false(city.building.is_cell_destroyed(1, 1))
	assert_false(city.building.is_cell_destroyed(2, 1))
	for column: int in range(StructuralBuilding2D.COLUMNS):
		assert_false(city.building.is_cell_destroyed(column, 0))
	assert_eq(city.building.destroyed_cell_count(), 1)
	assert_false(city.building.is_destroyed())
	assert_eq(city.score, 1150)
	var collision: CollisionShape2D = city.building.get_cell(0, 1).get_node(
		^"IntactBody/CollisionShape2D"
	) as CollisionShape2D
	assert_true(collision.disabled)
	assert_not_null(city.get_node_or_null(^"ImpactFragments"))
	var score_label: Label = city.get_node(^"HUD/ScoreLabel") as Label
	assert_eq(score_label.text, "00001150")
	_record_test_execution()


func test_upper_row_bridges_until_every_lower_support_is_destroyed() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	for column: int in [0, 1]:
		var cell: Destructible2D = city.building.get_cell(column, 1)
		cell.receive_damage(_fatal_cell_event(city, cell, 8100 + column))
		await get_tree().process_frame
	assert_eq(city.building.destroyed_cell_count(), 2)
	for column: int in range(StructuralBuilding2D.COLUMNS):
		assert_false(city.building.is_cell_destroyed(column, 0))
	var final_support: Destructible2D = city.building.get_cell(2, 1)
	final_support.receive_damage(_fatal_cell_event(city, final_support, 8102))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(city.building.destroyed_cell_count(), 6)
	assert_true(city.building.is_destroyed())
	for column: int in range(StructuralBuilding2D.COLUMNS):
		assert_true(city.building.is_cell_destroyed(column, 0))
	_record_test_execution()


func test_robot_tunnels_through_successive_lower_bays() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.robot.set_physics_process(false)
	for enemy: EnemyActor2D in [city.soldier, city.tank, city.helicopter]:
		enemy.set_physics_process(false)
	city.robot.position = Vector2(1100.0, 460.0)
	for step_index: int in range(240):
		city.robot.physics_step(1.0, 1.0 / 60.0)
		await get_tree().physics_frame
	assert_gt(city.robot.position.x, city.building.position.x + 320.0)
	for column: int in range(StructuralBuilding2D.COLUMNS):
		assert_true(city.building.is_cell_destroyed(column, 1))
	assert_true(city.building.is_destroyed())
	assert_gt(city.debris_pool.active_count(), 0)
	_record_test_execution()


func test_enemy_defeat_adds_score_once() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var fatal_event: DamageEvent = DamageEvent.new(7001, city.robot, 999.0)
	assert_true(city.soldier.receive_damage(fatal_event))
	assert_eq(city.score, 500)
	assert_false(city.soldier.receive_damage(fatal_event))
	assert_eq(city.score, 500)
	_record_test_execution()


func test_land_visuals_share_the_asphalt_baseline() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var lower_cell: Destructible2D = city.building.get_cell(0, 1)
	var lower_visual: Sprite2D = lower_cell.get_node(^"IntactVisual") as Sprite2D
	var visuals: Array[Sprite2D] = [
		lower_visual,
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


func test_game_over_retry_replaces_the_city_with_fresh_health_and_score() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.start_game()
	await get_tree().process_frame
	var first_city: CitySlice = main.city_slice
	first_city._add_score(500)
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
	assert_eq(main.city_slice.score, 0)
	_record_test_execution()


func _fatal_cell_event(
	city: CitySlice,
	cell: Destructible2D,
	attack_id: int
) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		city.robot,
		cell.max_health + 1.0,
		&"structural",
		cell.global_position,
		Vector2.RIGHT,
		260.0
	)


func _visual_bottom(visual: Sprite2D) -> float:
	var rendered_height: float = visual.region_rect.size.y * absf(visual.global_scale.y)
	if not visual.region_enabled:
		rendered_height = visual.texture.get_size().y * absf(visual.global_scale.y)
	return visual.global_position.y + rendered_height * 0.5


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
