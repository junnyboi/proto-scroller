extends GutTest

const TITLE_SCREEN_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"

var screen: TitleScreen


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	if FileAccess.file_exists(TEST_COUNT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_COUNT_PATH))


func before_each() -> void:
	screen = TITLE_SCREEN_SCENE.instantiate() as TitleScreen
	add_child_autofree(screen)
	await get_tree().process_frame


func test_launch_scene_contract() -> void:
	var title_label: Label = screen.get_node("%TitleLabel") as Label
	var initialize_button: Button = screen.get_node("%InitializeButton") as Button
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Proto Scroller")
	assert_eq(
		ProjectSettings.get_setting("application/run/main_scene"),
		"res://scenes/title_screen.tscn"
	)
	assert_eq(title_label.text, "PROTO\nSCROLLER")
	assert_eq(initialize_button.text, "INITIALIZE")
	assert_eq(initialize_button.focus_mode, Control.FOCUS_ALL)
	_record_test_execution()


func test_initialize_seam_transitions_once() -> void:
	var status_label: Label = screen.get_node("%StatusLabel") as Label
	var initialize_button: Button = screen.get_node("%InitializeButton") as Button
	assert_false(screen.initialized)
	assert_true(screen.initialize_game())
	assert_true(screen.initialized)
	assert_eq(status_label.text, "SYSTEM READY")
	assert_eq(initialize_button.text, "READY")
	assert_true(initialize_button.disabled)
	assert_false(screen.initialize_game(), "A second initialization must reject without mutation.")
	assert_eq(status_label.text, "SYSTEM READY")
	_record_test_execution()


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
