extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"


func test_prop_destruction_updates_combo_momentum_and_hud() -> void:
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
	assert_eq(city.score, 450)
	assert_eq(city.rampage_session.current_multiplier(), 2)
	assert_almost_eq(city.rampage_session.momentum_value(), 20.0, 0.01)
	var score_label: Label = city.get_node(^"HUD/ScoreLabel") as Label
	var combo_label: Label = city.get_node(^"HUD/ComboLabel") as Label
	var momentum_label: Label = city.get_node(^"HUD/MomentumLabel") as Label
	assert_eq(score_label.text, "00000450")
	assert_eq(combo_label.text, "x2 COMBO")
	assert_true(combo_label.visible)
	assert_eq(momentum_label.text, "MOMENTUM 020%")
	_record_test_execution()


func test_motion_gain_and_heavy_hostile_hit_loss_reach_live_session() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.set_process(false)
	city.robot.velocity.x = city.robot.max_speed * 0.8
	city._process(1.0)
	assert_almost_eq(city.rampage_session.momentum_value(), 12.0, 0.001)
	var heavy_event: DamageEvent = DamageEvent.new(
		6199,
		city.tank,
		40.0,
		&"shell"
	)
	assert_true(city.robot.receive_damage(heavy_event))
	assert_almost_eq(city.rampage_session.momentum_value(), 2.0, 0.001)
	_record_test_execution()


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
