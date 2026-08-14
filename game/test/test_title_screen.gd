extends GutTest

const TITLE_SCREEN_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"
const MINIMUM_TEXT_HEIGHT: float = 32.0

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


func test_all_ui_text_meets_the_32_pixel_rendered_height_pin() -> void:
	var measured_controls: int = 0
	var minimum_height: float = INF
	for label_node: Node in screen.find_children("*", "Label", true, false):
		var label: Label = label_node as Label
		minimum_height = minf(minimum_height, _rendered_line_height(label))
		measured_controls += 1
	var initialize_button: Button = screen.get_node("%InitializeButton") as Button
	minimum_height = minf(minimum_height, _rendered_line_height(initialize_button))
	measured_controls += 1
	assert_true(measured_controls >= 10, "Expected at least ten visible UI text controls.")
	assert_true(
		minimum_height >= MINIMUM_TEXT_HEIGHT,
		"Minimum rendered line height was %.2f px; expected at least %.2f px."
		% [minimum_height, MINIMUM_TEXT_HEIGHT]
	)
	_record_test_execution()


func test_initialize_action_does_not_overlap_the_footer() -> void:
	var initialize_button: Button = screen.get_node("%InitializeButton") as Button
	var bottom_rail: HBoxContainer = screen.get_node("BottomRail") as HBoxContainer
	var button_rect: Rect2 = initialize_button.get_global_rect()
	var footer_rect: Rect2 = bottom_rail.get_global_rect()
	assert_false(
		button_rect.intersects(footer_rect),
		"Initialize rect %s overlapped footer rect %s." % [button_rect, footer_rect]
	)
	_record_test_execution()


func _rendered_line_height(control: Control) -> float:
	var font: Font = control.get_theme_font(&"font")
	var font_size: int = control.get_theme_font_size(&"font_size")
	return font.get_height(font_size)


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
