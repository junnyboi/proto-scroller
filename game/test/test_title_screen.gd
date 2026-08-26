extends GutTest

const TITLE_SCREEN_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"
const LANGUAGE_PREFERENCE_PATH: String = "user://test-title-language.cfg"
const AUDIO_PREFERENCE_PATH: String = "user://test-title-audio.cfg"
const INPUT_PREFERENCE_PATH: String = "user://test-title-input.cfg"
const MINIMUM_TEXT_HEIGHT: float = 32.0

var screen: TitleScreen


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	if FileAccess.file_exists(TEST_COUNT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_COUNT_PATH))


func before_each() -> void:
	L10n.clear_locale_preference(LANGUAGE_PREFERENCE_PATH)
	AudioVolumeSettings.clear_preference(AUDIO_PREFERENCE_PATH)
	InputBindingSettings.reset_to_defaults(INPUT_PREFERENCE_PATH, false)
	_clear_input_preference()
	_reset_audio_settings()
	L10n.set_locale("en")
	screen = TITLE_SCREEN_SCENE.instantiate() as TitleScreen
	screen.locale_preference_path = LANGUAGE_PREFERENCE_PATH
	screen.audio_preference_path = AUDIO_PREFERENCE_PATH
	screen.input_preference_path = INPUT_PREFERENCE_PATH
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	L10n.set_locale("en")
	L10n.clear_locale_preference(LANGUAGE_PREFERENCE_PATH)
	AudioVolumeSettings.clear_preference(AUDIO_PREFERENCE_PATH)
	InputBindingSettings.reset_to_defaults(INPUT_PREFERENCE_PATH, false)
	_clear_input_preference()
	_reset_audio_settings()


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
	var english_button: Button = screen.get_node("%EnglishButton") as Button
	var chinese_button: Button = screen.get_node("%ChineseButton") as Button
	assert_null(screen.get_node_or_null("%AutomaticButton"))
	assert_eq(title_label.text, "PROTOS")
	assert_eq(
		(screen.get_node("%InstructionLabel") as Label).text,
		"Obelisk killed everyone you loved.\n"
		+ "PROJECT CHOIR kept their minds. Decide what survives."
	)
	assert_null(screen.get_node_or_null("HintLabel"))
	assert_eq(english_button.text, "EN")
	assert_eq(chinese_button.text, "CN")
	assert_true(english_button.button_pressed)
	assert_false(chinese_button.button_pressed)
	assert_eq((screen.get_node("%SettingsButton") as Button).text, L10n.t("title.settings"))
	assert_true(screen.select_language("zh-CN"))
	assert_eq(L10n.current_locale(), "zh-CN")
	assert_eq(L10n.preferred_locale(LANGUAGE_PREFERENCE_PATH), "zh-CN")
	assert_eq(title_label.text, "PROTOS")
	assert_true(chinese_button.button_pressed)
	assert_false(english_button.button_pressed)
	assert_eq(
		(screen.get_node("%SettingsHeading") as Label).text,
		L10n.t("title.settings_heading")
	)
	assert_true(
		(screen.get_node("%BriefingArt") as TextureRect)
		.texture.resource_path.contains("briefing_landscape_zh_cn")
	)
	assert_true(screen.select_language("en"))
	assert_eq(L10n.preferred_locale(LANGUAGE_PREFERENCE_PATH), "en")
	assert_true(english_button.button_pressed)
	assert_false(chinese_button.button_pressed)
	_record_test_execution()


func test_command_deck_teaches_core_loop_and_briefing_preserves_full_intel() -> void:
	var hook: String = (screen.get_node("%InstructionLabel") as Label).text
	var controls: String = (screen.get_node("%ControlsLabel") as Label).text
	var field_note: String = (screen.get_node("SemanticContract/FieldNote") as Label).text
	var enemy_intel: String = (screen.get_node("%EnemyIntel") as Label).text
	var run_rule: String = (screen.get_node("%RunRule") as Label).text
	assert_eq(hook, L10n.t("title.command_hook"))
	for required_control: String in [
		"A/D",
		"STICK",
		"D-PAD",
		"TOUCH",
		"HOLD",
		"SPACE",
		"A / CROSS",
		"RELEASE TO STRIKE",
		"DASH",
		"SHIFT",
		"B / CIRCLE",
		"DOUBLE-TAP",
	]:
		assert_true(controls.contains(required_control), required_control)
	var info_panel: PanelContainer = screen.get_node("StatusRail") as PanelContainer
	var controls_label: Label = screen.get_node("%ControlsLabel") as Label
	assert_true(info_panel.get_global_rect().encloses(controls_label.get_global_rect()))
	assert_null(screen.get_node_or_null("StatusRail/InfoContent/StatusItems"))
	assert_lt(
		controls_label.get_theme_font_size(&"font_size"),
		(screen.get_node("%InstructionLabel") as Label).get_theme_font_size(&"font_size")
	)
	assert_true(field_note.contains("Bindings can be changed"))
	assert_true(field_note.contains("AUTO SAVE"))
	assert_true(
		(screen.get_node("SemanticContract/ObjectiveOne") as Label).text.contains(
			"recover dossiers"
		)
	)
	assert_true(
		(screen.get_node("SemanticContract/ObjectiveThree") as Label).text.contains(
			"Continuity Cradle"
		)
	)
	assert_true(enemy_intel.contains("Armor + aircraft"))
	assert_true(enemy_intel.contains("Reclaimed + carriers"))
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
	assert_null(screen.get_node_or_null("%AutomaticButton"))
	assert_true((screen.get_node("%EnglishButton") as Button).disabled)
	assert_true((screen.get_node("%ChineseButton") as Button).disabled)
	assert_true((screen.get_node("%SettingsButton") as Button).disabled)
	assert_false(screen.initialize_game(), "A second initialization must reject without mutation.")
	assert_eq(status_label.text, L10n.t("title.expedition_active"))
	_record_test_execution()


func test_settings_menu_applies_and_persists_the_complete_audio_mix() -> void:
	var settings_layer: Control = screen.get_node("%SettingsLayer") as Control
	var sliders: Dictionary = {
		AudioVolumeSettings.Channel.MASTER: screen.get_node("%MasterVolumeSlider"),
		AudioVolumeSettings.Channel.MUSIC: screen.get_node("%MusicVolumeSlider"),
		AudioVolumeSettings.Channel.SFX: screen.get_node("%SfxVolumeSlider"),
		AudioVolumeSettings.Channel.VOICE: screen.get_node("%VoiceVolumeSlider"),
	}
	var labels: Dictionary = {
		AudioVolumeSettings.Channel.MASTER: screen.get_node("%MasterVolumeValue"),
		AudioVolumeSettings.Channel.MUSIC: screen.get_node("%MusicVolumeValue"),
		AudioVolumeSettings.Channel.SFX: screen.get_node("%SfxVolumeValue"),
		AudioVolumeSettings.Channel.VOICE: screen.get_node("%VoiceVolumeValue"),
	}
	var mute_buttons: Dictionary = {
		AudioVolumeSettings.Channel.MASTER: screen.get_node("%MasterMuteButton"),
		AudioVolumeSettings.Channel.MUSIC: screen.get_node("%MusicMuteButton"),
		AudioVolumeSettings.Channel.SFX: screen.get_node("%SfxMuteButton"),
		AudioVolumeSettings.Channel.VOICE: screen.get_node("%VoiceMuteButton"),
	}
	var requested: Dictionary = {
		AudioVolumeSettings.Channel.MASTER: 82.0,
		AudioVolumeSettings.Channel.MUSIC: 35.0,
		AudioVolumeSettings.Channel.SFX: 64.0,
		AudioVolumeSettings.Channel.VOICE: 46.0,
	}
	assert_false(settings_layer.visible)
	assert_true(screen.open_settings())
	assert_true(settings_layer.visible)
	assert_true((screen.get_node("%SettingsScroll") as ScrollContainer).visible)
	assert_eq(
		(screen.get_node("%ControlsHeading") as Label).text,
		L10n.t("title.controls_settings_heading")
	)
	assert_true((screen.get_node("%ControllerVibrationToggle") as CheckButton).button_pressed)
	for channel: int in AudioVolumeSettings.CHANNELS:
		var slider: HSlider = sliders[channel] as HSlider
		var value_label: Label = labels[channel] as Label
		var percent: float = float(requested[channel])
		slider.value = percent
		assert_eq(value_label.text, "%d%%" % int(percent))
		var bus_index: int = AudioServer.get_bus_index(
			AudioVolumeSettings.bus_name(channel)
		)
		assert_almost_eq(
			AudioServer.get_bus_volume_db(bus_index),
			AudioVolumeSettings.percent_to_db(percent),
			0.01
		)
		assert_almost_eq(
			AudioVolumeSettings.load_percent(channel, AUDIO_PREFERENCE_PATH),
			percent,
			0.01
		)
		var mute_button: Button = mute_buttons[channel] as Button
		mute_button.button_pressed = true
		assert_eq(mute_button.text, L10n.t("title.audio_muted"))
		assert_true(AudioServer.is_bus_mute(bus_index))
		assert_true(AudioVolumeSettings.load_muted(channel, AUDIO_PREFERENCE_PATH))
	assert_true(screen.close_settings())
	assert_false(settings_layer.visible)
	var restored_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate() as TitleScreen
	restored_screen.audio_preference_path = AUDIO_PREFERENCE_PATH
	add_child_autofree(restored_screen)
	await get_tree().process_frame
	for channel: int in AudioVolumeSettings.CHANNELS:
		var slider_name: String = {
			AudioVolumeSettings.Channel.MASTER: "%MasterVolumeSlider",
			AudioVolumeSettings.Channel.MUSIC: "%MusicVolumeSlider",
			AudioVolumeSettings.Channel.SFX: "%SfxVolumeSlider",
			AudioVolumeSettings.Channel.VOICE: "%VoiceVolumeSlider",
		}[channel]
		assert_almost_eq(
			(restored_screen.get_node(slider_name) as HSlider).value,
			float(requested[channel]),
			0.01
		)
		var mute_button_name: String = {
			AudioVolumeSettings.Channel.MASTER: "%MasterMuteButton",
			AudioVolumeSettings.Channel.MUSIC: "%MusicMuteButton",
			AudioVolumeSettings.Channel.SFX: "%SfxMuteButton",
			AudioVolumeSettings.Channel.VOICE: "%VoiceMuteButton",
		}[channel]
		var restored_mute_button: Button = (
			restored_screen.get_node(mute_button_name) as Button
		)
		assert_true(restored_mute_button.button_pressed)
		assert_eq(restored_mute_button.text, L10n.t("title.audio_muted"))
	_record_test_execution()


func test_settings_and_briefing_are_mutually_exclusive() -> void:
	assert_true(screen.open_briefing())
	assert_true(screen.open_settings())
	assert_false(screen.briefing_open)
	assert_true(screen.settings_open)
	assert_false((screen.get_node("%BriefingLayer") as Control).visible)
	assert_true(screen.open_briefing())
	assert_true(screen.briefing_open)
	assert_false(screen.settings_open)
	assert_false((screen.get_node("%SettingsLayer") as Control).visible)
	_record_test_execution()


func test_campaign_archive_renders_injected_progress_and_focus_safe_codex() -> void:
	var archive_screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate() as TitleScreen
	archive_screen.configure_campaign({
		"dossiers": PackedStringArray([
			"dossier_business_mercy_exchange_annex",
		]),
		"dossier_count": 1,
		"continuity_generation": 3,
		"seen_endings": PackedStringArray(["PURGE", "DISENTANGLE"]),
	})
	archive_screen.locale_preference_path = LANGUAGE_PREFERENCE_PATH
	archive_screen.audio_preference_path = AUDIO_PREFERENCE_PATH
	archive_screen.input_preference_path = INPUT_PREFERENCE_PATH
	add_child_autofree(archive_screen)
	await get_tree().process_frame
	assert_true(archive_screen.open_briefing())
	assert_true(archive_screen.campaign_panel.progress_label.text.contains("1 / 25"))
	assert_true(archive_screen.campaign_panel.continuity_label.text.contains("3"))
	assert_true(archive_screen.campaign_panel.endings_label.text.contains("ASH PROTOCOL"))
	assert_true(archive_screen.campaign_panel.endings_label.text.contains("SEVERANCE"))
	archive_screen.campaign_panel.codex_button.pressed.emit()
	assert_true(archive_screen.dossier_codex.visible)
	assert_true(
		archive_screen.dossier_codex.detail_title.text.contains("Mercy Exchange Annex")
	)
	assert_false(archive_screen.dossier_codex.detail_body.text.contains("encrypted"))
	archive_screen.dossier_codex.dossier_list.select(1)
	archive_screen.dossier_codex.dossier_list.item_selected.emit(1)
	assert_eq(
		archive_screen.dossier_codex.detail_title.text,
		L10n.t("narrative.codex.locked_title")
	)
	var cancel_event: InputEventAction = InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	archive_screen._unhandled_input(cancel_event)
	assert_false(archive_screen.dossier_codex.visible)
	await get_tree().process_frame
	assert_eq(
		get_viewport().gui_get_focus_owner(),
		archive_screen.campaign_panel.codex_button
	)
	assert_true(archive_screen.select_language("zh-CN"))
	assert_true(archive_screen.campaign_panel.heading_label.text.contains("合唱"))
	assert_eq(int(archive_screen.campaign_snapshot.dossier_count), 1)
	_record_test_execution()


func test_all_ui_text_meets_the_32_pixel_rendered_height_pin() -> void:
	var measured_controls: int = 0
	var minimum_height: float = INF
	for label_node: Node in screen.find_children("*", "Label", true, false):
		var label: Label = label_node as Label
		if label == screen.get_node("%ControlsLabel"):
			assert_gte(_rendered_line_height(label), 28.0)
			continue
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
		initialize_button.get_global_rect().end.y + 16.0,
		"The launch action must retain at least 16 px of bottom spacing."
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
	assert_true(source.contains("protoScrollerSetTitleBackdropActive"))
	var host_source: String = FileAccess.get_file_as_string("res://../client/src/main.ts")
	assert_true(host_source.contains("title-loop-landscape.mp4"))
	assert_true(host_source.contains("title-loop-portrait.mp4"))
	assert_true(host_source.contains("title-poster-landscape.jpg"))
	assert_true(host_source.contains("title-poster-portrait.jpg"))
	var shell_source: String = FileAccess.get_file_as_string(
		"res://../scripts/patch-title-video-shell.mjs"
	)
	for runtime_source: String in [host_source, shell_source]:
		assert_true(runtime_source.contains("title-loop-landscape.mp4"))
		assert_true(runtime_source.contains("title-loop-portrait.mp4"))
		assert_true(runtime_source.contains("protoScrollerScheduleTitleBeatCommit"))
		assert_true(runtime_source.contains("protoScrollerCancelTitleBeatCommit"))
		assert_true(runtime_source.contains("requestAnimationFrame"))
		assert_true(runtime_source.contains("requestVideoFrameCallback"))
		assert_true(runtime_source.contains("getOutputTimestamp"))
		assert_true(runtime_source.contains("AudioBufferSourceNode"))
		assert_true(runtime_source.contains("prototype.start"))
		assert_true(runtime_source.contains("commitCallback"))
		assert_true(runtime_source.contains("__PROTO_SCROLLER_TITLE_MUSIC_SYNC__"))
	assert_true(host_source.contains("88 / 24"))
	assert_true(host_source.contains("66 / 24"))
	_record_test_execution()


func _rendered_line_height(control: Control) -> float:
	var font: Font = control.get_theme_font(&"font")
	var font_size: int = control.get_theme_font_size(&"font_size")
	return font.get_height(font_size)


func _reset_audio_settings() -> void:
	for channel: int in AudioVolumeSettings.CHANNELS:
		AudioVolumeSettings.apply_percent(
			channel,
			AudioVolumeSettings.default_percent(channel)
		)
		AudioVolumeSettings.apply_muted(channel, false)


func _clear_input_preference() -> void:
	if FileAccess.file_exists(INPUT_PREFERENCE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(INPUT_PREFERENCE_PATH))


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
