extends GutTest

const TITLE_SCREEN_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"
const LANGUAGE_PREFERENCE_PATH: String = "user://test-title-language.cfg"
const MINIMUM_TEXT_HEIGHT: float = 32.0

var screen: TitleScreen


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	if FileAccess.file_exists(TEST_COUNT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_COUNT_PATH))


func before_each() -> void:
	L10n.clear_locale_preference(LANGUAGE_PREFERENCE_PATH)
	L10n.set_locale("en")
	screen = TITLE_SCREEN_SCENE.instantiate() as TitleScreen
	screen.locale_preference_path = LANGUAGE_PREFERENCE_PATH
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	L10n.set_locale("en")
	L10n.clear_locale_preference(LANGUAGE_PREFERENCE_PATH)


func test_launch_scene_contract() -> void:
	var title_label: Label = screen.get_node("%TitleLabel") as Label
	var initialize_button: Button = screen.get_node("%InitializeButton") as Button
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Proto Scroller")
	assert_eq(
		ProjectSettings.get_setting("application/run/main_scene"),
		"res://scenes/main/main.tscn"
	)
	assert_eq(title_label.text, L10n.t("title.command_heading"))
	assert_true(initialize_button.text.contains(L10n.t("title.begin")))
	assert_eq(initialize_button.focus_mode, Control.FOCUS_ALL)
	var launch_actions: int = 0
	for button_node: Node in screen.find_children("*", "Button", true, false):
		var button: Button = button_node as Button
		if button.text.contains(L10n.t("title.begin")):
			launch_actions += 1
	assert_eq(launch_actions, 1, "The Command Deck must expose one launch action only.")
	var automatic_button: Button = screen.get_node("%AutomaticButton") as Button
	var english_button: Button = screen.get_node("%EnglishButton") as Button
	var chinese_button: Button = screen.get_node("%ChineseButton") as Button
	assert_eq(automatic_button.text, _expected_automatic_label())
	assert_true(automatic_button.button_pressed)
	assert_false(english_button.button_pressed)
	assert_false(chinese_button.button_pressed)
	assert_true(chinese_button.get_theme_font(&"font").has_char("中".unicode_at(0)))
	assert_true(screen.select_language("zh-CN"))
	assert_eq(L10n.current_locale(), "zh-CN")
	assert_eq(L10n.preferred_locale(LANGUAGE_PREFERENCE_PATH), "zh-CN")
	assert_eq(title_label.text, L10n.t("title.command_heading"))
	assert_eq(automatic_button.text, _expected_automatic_label())
	assert_false(automatic_button.button_pressed)
	assert_true(chinese_button.button_pressed)
	assert_false(english_button.button_pressed)
	assert_true(
		(screen.get_node("%BriefingArt") as TextureRect)
		.texture.resource_path.contains("briefing_landscape_zh_cn")
	)
	assert_true(screen.select_language("en"))
	assert_eq(L10n.preferred_locale(LANGUAGE_PREFERENCE_PATH), "en")
	assert_false(automatic_button.button_pressed)
	assert_true(english_button.button_pressed)
	assert_false(chinese_button.button_pressed)
	var detected_locale: String = L10n.automatic_locale()
	assert_true(screen.select_automatic_language())
	assert_eq(L10n.current_locale(), detected_locale)
	assert_eq(L10n.preferred_locale(LANGUAGE_PREFERENCE_PATH), "")
	assert_eq(automatic_button.text, _expected_automatic_label())
	assert_true(automatic_button.button_pressed)
	assert_false(english_button.button_pressed)
	assert_false(chinese_button.button_pressed)
	_record_test_execution()


func test_command_deck_teaches_core_loop_and_briefing_preserves_full_intel() -> void:
	var hook: String = (screen.get_node("%InstructionLabel") as Label).text
	var controls: String = (screen.get_node("%ControlsLabel") as Label).text
	var field_note: String = (screen.get_node("SemanticContract/FieldNote") as Label).text
	var enemy_intel: String = (screen.get_node("%EnemyIntel") as Label).text
	var run_rule: String = (screen.get_node("%RunRule") as Label).text
	assert_eq(hook, L10n.t("title.command_hook"))
	for required_control: String in ["A / D", "Mobile joystick", "SPACE", "SMASH"]:
		assert_true(controls.contains(required_control), required_control)
	assert_true(field_note.contains("recovery"))
	assert_true(field_note.contains("dash dodge"))
	assert_eq(
		(screen.get_node("SemanticContract/PrimaryObjective") as Label).text,
		"PRIMARY  Survive the city response."
	)
	assert_true(
		(screen.get_node("SemanticContract/ObjectiveOne") as Label).text.contains("earn EXP")
	)
	assert_true(
		(screen.get_node("SemanticContract/ObjectiveThree") as Label).text.contains("1 of 2 upgrades")
	)
	assert_true(enemy_intel.contains("Soldiers + tanks"))
	assert_true(enemy_intel.contains("Helicopters + rockets"))
	assert_true(run_rule.contains("reset when you Retry"))
	assert_true(screen.open_briefing())
	assert_true((screen.get_node("%BriefingLayer") as Control).visible)
	assert_true(screen.close_briefing())
	assert_false((screen.get_node("%BriefingLayer") as Control).visible)
	_record_test_execution()


func test_initialize_seam_transitions_once() -> void:
	var status_label: Label = screen.get_node("%StatusLabel") as Label
	var initialize_button: Button = screen.get_node("%InitializeButton") as Button
	assert_false(screen.initialized)
	assert_true(screen.initialize_game())
	assert_true(screen.initialized)
	assert_eq(status_label.text, L10n.t("title.expedition_active"))
	assert_eq(initialize_button.text, L10n.t("title.deploying"))
	assert_true(initialize_button.disabled)
	assert_true((screen.get_node("%AutomaticButton") as Button).disabled)
	assert_true((screen.get_node("%EnglishButton") as Button).disabled)
	assert_true((screen.get_node("%ChineseButton") as Button).disabled)
	assert_false(screen.initialize_game(), "A second initialization must reject without mutation.")
	assert_eq(status_label.text, L10n.t("title.expedition_active"))
	_record_test_execution()


func test_all_ui_text_meets_the_32_pixel_rendered_height_pin() -> void:
	var measured_controls: int = 0
	var minimum_height: float = INF
	for label_node: Node in screen.find_children("*", "Label", true, false):
		var label: Label = label_node as Label
		minimum_height = minf(minimum_height, _rendered_line_height(label))
		measured_controls += 1
	for button_node: Node in screen.find_children("*", "Button", true, false):
		var button: Button = button_node as Button
		if button.text.is_empty():
			continue
		minimum_height = minf(minimum_height, _rendered_line_height(button))
		measured_controls += 1
	assert_true(measured_controls >= 10, "Expected at least ten live UI text controls.")
	assert_true(
		minimum_height >= MINIMUM_TEXT_HEIGHT,
		"Minimum rendered line height was %.2f px; expected at least %.2f px."
		% [minimum_height, MINIMUM_TEXT_HEIGHT]
	)
	_record_test_execution()


func test_launch_action_does_not_overlap_briefing_action() -> void:
	var initialize_button: Button = screen.get_node("%InitializeButton") as Button
	var language_selector: HBoxContainer = screen.get_node("%LanguageSelector") as HBoxContainer
	var briefing_toggle: Button = screen.get_node("%BriefingToggle") as Button
	assert_gte(
		language_selector.get_global_rect().position.y,
		initialize_button.get_global_rect().end.y,
		"The language selector must remain below the launch action."
	)
	assert_false(
		initialize_button.get_global_rect().intersects(briefing_toggle.get_global_rect()),
		"Launch and briefing actions must remain spatially distinct."
	)
	_record_test_execution()


func test_generated_art_contract_replaces_procedural_rendering() -> void:
	var background: TextureRect = screen.get_node("%BackgroundArt") as TextureRect
	var briefing: TextureRect = screen.get_node("%BriefingArt") as TextureRect
	assert_true(background.texture.resource_path.contains("command_deck_landscape.jpg"))
	assert_true(briefing.texture.resource_path.contains("command_deck_briefing_landscape.jpg"))
	var source_file: FileAccess = FileAccess.open("res://scripts/title_screen.gd", FileAccess.READ)
	var source: String = source_file.get_as_text()
	assert_false(source.contains("func _draw"), "Procedural title graphics are forbidden.")
	assert_false(source.contains("draw_line"), "Procedural title graphics are forbidden.")
	assert_false(source.contains("draw_circle"), "Procedural title graphics are forbidden.")
	_record_test_execution()


func _rendered_line_height(control: Control) -> float:
	var font: Font = control.get_theme_font(&"font")
	var font_size: int = control.get_theme_font_size(&"font_size")
	return font.get_height(font_size)


func _expected_automatic_label() -> String:
	var resolved_key: String = (
		"title.language_resolved_zh_cn"
		if L10n.automatic_locale() == "zh-CN"
		else "title.language_resolved_en"
	)
	return L10n.t(
		"title.language_auto_resolved",
		{
			"automatic": L10n.t("title.language_auto"),
			"resolved": L10n.t(resolved_key),
		}
	)


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
