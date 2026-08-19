extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"
const TEST_PREFERENCE_PATH: String = "user://test_combat_tutorial.cfg"


func before_each() -> void:
	L10n.set_locale("en")
	_remove_test_preference()


func after_each() -> void:
	L10n.set_locale("en")
	_remove_test_preference()


func test_mechanic_signals_advance_and_complete_the_four_step_uplink() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var tutorial: FirstRunCombatTutorial = city.gameplay_hud.first_run_tutorial
	tutorial.start_for_test()
	assert_true(tutorial.visible)
	assert_true(tutorial.tutorial_active)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.MOVE)
	assert_eq(tutorial.progress_label.text, "COMBAT UPLINK  01 / 04")
	city.robot.locomotion_changed.emit(GiantRobotController.LocomotionState.WALK)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.GROUND_SMASH)
	city.robot.attack_committed.emit(AttackSpec.Mode.GROUND_SMASH, 101)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.JAB_CROSS)
	city.robot.attack_committed.emit(AttackSpec.Mode.JAB_CROSS, 102)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.RECOVERY_DODGE)
	city.contextual_attacks.dodge_buffered.emit(102)
	assert_eq(tutorial.current_step, FirstRunCombatTutorial.Step.COMPLETE)
	assert_true(tutorial.completed)
	assert_false(tutorial.tutorial_active)
	assert_false(tutorial.skipped)
	assert_eq(tutorial.title_label.text, "COMBAT UPLINK COMPLETE")
	assert_true(tutorial.body_label.text.contains("Dash Amplifier"))
	_record_test_execution()


func test_completion_persists_and_skip_uses_the_same_first_run_contract() -> void:
	var first: FirstRunCombatTutorial = FirstRunCombatTutorial.new()
	first.setup(null, null, null, TEST_PREFERENCE_PATH)
	add_child_autofree(first)
	await get_tree().process_frame
	assert_true(first.tutorial_active)
	first.skip_button.pressed.emit()
	assert_true(first.completed)
	assert_true(first.skipped)
	assert_true(FileAccess.file_exists(TEST_PREFERENCE_PATH))
	first.queue_free()
	await get_tree().process_frame
	var second: FirstRunCombatTutorial = FirstRunCombatTutorial.new()
	second.setup(null, null, null, TEST_PREFERENCE_PATH)
	add_child_autofree(second)
	await get_tree().process_frame
	assert_true(second.completed)
	assert_false(second.tutorial_active)
	assert_false(second.visible)
	_record_test_execution()


func test_tutorial_localizes_and_stays_inside_landscape_and_portrait() -> void:
	L10n.set_locale("zh-CN")
	var tutorial: FirstRunCombatTutorial = FirstRunCombatTutorial.new()
	tutorial.setup(null, null, null, TEST_PREFERENCE_PATH)
	add_child_autofree(tutorial)
	await get_tree().process_frame
	tutorial.start_for_test()
	assert_eq(tutorial.title_label.text, "移动原型机")
	assert_true(tutorial.body_label.text.contains("移动端摇杆"))
	tutorial.apply_responsive_layout(Vector2(1280.0, 720.0))
	assert_true(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)).encloses(
		Rect2(tutorial.panel.position, tutorial.panel.size)
	))
	tutorial.apply_responsive_layout(Vector2(720.0, 1280.0))
	assert_true(Rect2(Vector2.ZERO, Vector2(720.0, 1280.0)).encloses(
		Rect2(tutorial.panel.position, tutorial.panel.size)
	))
	assert_gte(tutorial.body_label.get_theme_font_size(&"font_size"), 20)
	_record_test_execution()


func _remove_test_preference() -> void:
	if FileAccess.file_exists(TEST_PREFERENCE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PREFERENCE_PATH))


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
