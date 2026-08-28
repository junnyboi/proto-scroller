extends SceneTree

const DEVICE_ID: int = 4242
const MAX_FRAMES: int = 240
const MINIMUM_TEXT_HEIGHT: float = 32.0
const REPORT_PATH: String = "res://artifacts/title_screen/report.json"
const SHOT_PATH: String = "res://artifacts/title_screen/title-screen.png"
const BRIEFING_SHOT_PATH: String = "res://artifacts/title_screen/title-screen-briefing.png"
const CODEX_SHOT_PATH: String = "res://artifacts/title_screen/title-screen-codex.png"
const SETTINGS_SHOT_PATH: String = "res://artifacts/title_screen/title-screen-settings.png"
const LEADERBOARD_LOCAL_SHOT_PATH: String = (
	"res://artifacts/title_screen/title-screen-leaderboard-local.png"
)
const LEADERBOARD_GLOBAL_SHOT_PATH: String = (
	"res://artifacts/title_screen/title-screen-leaderboard-global.png"
)
const LANGUAGE_PREFERENCE_PATH: String = "user://title-scenario-language.cfg"
const AUDIO_PREFERENCE_PATH: String = "user://title-scenario-audio.cfg"
const INPUT_PREFERENCE_PATH: String = "user://title-scenario-input.cfg"

var checks: Array[Dictionary] = []
var completed: bool = false
var elapsed_frames: int = 0


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred("_run")


func _on_process_frame() -> void:
	if completed:
		return
	elapsed_frames += 1
	if elapsed_frames > MAX_FRAMES:
		_check(
			"frame_watchdog",
			false,
			"frames=%s max_frames=%s" % [elapsed_frames, MAX_FRAMES]
		)
		_finish("SKIP", "")


func _run() -> void:
	L10n.clear_locale_preference(LANGUAGE_PREFERENCE_PATH)
	AudioVolumeSettings.clear_preference(AUDIO_PREFERENCE_PATH)
	InputBindingSettings.reset_to_defaults(INPUT_PREFERENCE_PATH, false)
	_clear_input_preference()
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var scene_resource: PackedScene = load("res://scenes/title_screen.tscn") as PackedScene
	_check("main_scene_loads", scene_resource != null, "loaded=%s" % [scene_resource != null])
	if scene_resource == null:
		_finish("SKIP", "")
		return

	var screen: TitleScreen = scene_resource.instantiate() as TitleScreen
	screen.configure_campaign({
		"dossiers": PackedStringArray([
			"dossier_business_mercy_exchange_annex",
			"dossier_business_helix_clearinghouse_spine",
			"dossier_business_orison_custody_vault",
		]),
		"dossier_count": 3,
		"continuity_generation": 2,
		"seen_endings": PackedStringArray(["PURGE", "DISENTANGLE"]),
	})
	screen.locale_preference_path = LANGUAGE_PREFERENCE_PATH
	screen.audio_preference_path = AUDIO_PREFERENCE_PATH
	screen.input_preference_path = INPUT_PREFERENCE_PATH
	root.add_child(screen)
	await process_frame
	await process_frame
	await process_frame

	var button: Button = screen.get_node("%InitializeButton") as Button
	var title_label: Label = screen.get_node("%TitleLabel") as Label
	_check("viewport_geometry", root.size == target_size, "size=%s" % [root.size])
	var title_visible: bool = title_label.is_visible_in_tree()
	_check("title_visible", title_visible, "visible=%s" % [title_visible])
	_check(
		"title_text",
		title_label.text == L10n.t("title.command_heading"),
		"text=%s" % [title_label.text]
	)
	_check(
		"begin_expedition_action",
		button.text.contains(L10n.t("title.begin")),
		"text=%s" % [button.text]
	)
	_check(
		"reign_of_terror_hook",
		(screen.get_node("%InstructionLabel") as Label).text.contains(
			"It's time to put an end to their reign of terror!"
		),
		"text=%s" % [(screen.get_node("%InstructionLabel") as Label).text]
	)
	_check("input_hint_removed", screen.get_node_or_null("HintLabel") == null, "removed=true")
	_check_briefing_content(screen)
	_check_language_selector(screen)
	_check("button_focused", button.has_focus(), "focused=%s" % [button.has_focus()])
	_check_minimum_text_height(screen, button)
	_check_layout_contract(screen, button)
	_check_briefing_interaction(screen)

	var shot_status: String = "SKIP"
	var shot_path: String = ""
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
	else:
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://artifacts/title_screen")
		)
		var save_error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
		_check(
			"shot_saved",
			save_error == OK,
			"error=%s width=%s height=%s" % [save_error, image.get_width(), image.get_height()]
		)
		_check(
			"shot_geometry",
			image.get_size() == target_size,
			"size=%s" % [image.get_size()]
		)
		screen.open_briefing()
		await RenderingServer.frame_post_draw
		var briefing_image: Image = root.get_texture().get_image()
		var briefing_save_error: Error = briefing_image.save_png(
			ProjectSettings.globalize_path(BRIEFING_SHOT_PATH)
		)
		_check(
			"briefing_shot_saved",
			briefing_save_error == OK,
			"error=%s size=%s" % [briefing_save_error, briefing_image.get_size()]
		)
		screen.campaign_panel.codex_button.pressed.emit()
		await RenderingServer.frame_post_draw
		var codex_image: Image = root.get_texture().get_image()
		var codex_save_error: Error = codex_image.save_png(
			ProjectSettings.globalize_path(CODEX_SHOT_PATH)
		)
		_check(
			"codex_shot_saved",
			codex_save_error == OK,
			"error=%s size=%s" % [codex_save_error, codex_image.get_size()]
		)
		_check(
			"codex_progress_visible",
			screen.dossier_codex.visible
			and screen.dossier_codex.progress_label.text.contains("3 / 25"),
			"visible=%s progress=%s" % [
				screen.dossier_codex.visible,
				screen.dossier_codex.progress_label.text,
			]
		)
		_check_codex_header_clear(screen.dossier_codex)
		screen.dossier_codex.close(false)
		screen.close_briefing()
		screen.open_settings()
		(screen.get_node("%MasterVolumeSlider") as HSlider).value = 82.0
		(screen.get_node("%MusicVolumeSlider") as HSlider).value = 35.0
		(screen.get_node("%SfxVolumeSlider") as HSlider).value = 64.0
		(screen.get_node("%VoiceVolumeSlider") as HSlider).value = 46.0
		(screen.get_node("%MusicMuteButton") as Button).button_pressed = true
		(screen.get_node("%VoiceMuteButton") as Button).button_pressed = true
		var settings_scroll: ScrollContainer = screen.get_node("%SettingsScroll") as ScrollContainer
		await process_frame
		settings_scroll.scroll_vertical = roundi(settings_scroll.get_v_scroll_bar().max_value)
		await RenderingServer.frame_post_draw
		var settings_image: Image = root.get_texture().get_image()
		var settings_save_error: Error = settings_image.save_png(
			ProjectSettings.globalize_path(SETTINGS_SHOT_PATH)
		)
		_check(
			"settings_shot_saved",
			settings_save_error == OK,
			"error=%s size=%s" % [settings_save_error, settings_image.get_size()]
		)
		_check(
			"settings_mix_applied",
			(screen.get_node("%MasterVolumeValue") as Label).text == "82%"
			and (screen.get_node("%MusicVolumeValue") as Label).text == "35%"
			and (screen.get_node("%SfxVolumeValue") as Label).text == "64%"
			and (screen.get_node("%VoiceVolumeValue") as Label).text == "46%",
			"master=%s music=%s sfx=%s voice=%s" % [
				(screen.get_node("%MasterVolumeValue") as Label).text,
				(screen.get_node("%MusicVolumeValue") as Label).text,
				(screen.get_node("%SfxVolumeValue") as Label).text,
				(screen.get_node("%VoiceVolumeValue") as Label).text,
			]
		)
		_check(
			"settings_input_controls_visible",
			(screen.get_node("%MoveLeftKeyboardButton") as Button).is_visible_in_tree()
			and (screen.get_node("%ControllerVibrationToggle") as CheckButton).is_visible_in_tree()
			and (screen.get_node("%ResetBindingsButton") as Button).is_visible_in_tree(),
			"scroll=%s" % [settings_scroll.scroll_vertical]
		)
		_check(
			"settings_mute_states_applied",
			(screen.get_node("%MasterMuteButton") as Button).text == L10n.t("title.audio_mute")
			and (screen.get_node("%MusicMuteButton") as Button).text == L10n.t("title.audio_muted")
			and (screen.get_node("%SfxMuteButton") as Button).text == L10n.t("title.audio_mute")
			and (screen.get_node("%VoiceMuteButton") as Button).text == L10n.t("title.audio_muted"),
			"master=%s music=%s sfx=%s voice=%s" % [
				(screen.get_node("%MasterMuteButton") as Button).text,
				(screen.get_node("%MusicMuteButton") as Button).text,
				(screen.get_node("%SfxMuteButton") as Button).text,
				(screen.get_node("%VoiceMuteButton") as Button).text,
			]
		)
		screen.close_settings(false)
		var leaderboard_opened: bool = screen.open_leaderboard()
		await RenderingServer.frame_post_draw
		var leaderboard_local_image: Image = root.get_texture().get_image()
		var leaderboard_local_error: Error = leaderboard_local_image.save_png(
			ProjectSettings.globalize_path(LEADERBOARD_LOCAL_SHOT_PATH)
		)
		_check(
			"leaderboard_local_shot_saved",
			leaderboard_local_error == OK,
			"error=%s size=%s" % [
				leaderboard_local_error,
				leaderboard_local_image.get_size(),
			]
		)
		_check(
			"title_leaderboard_local_tab_visible",
			leaderboard_opened
			and screen.leaderboard_overlay.local_tab_button.is_visible_in_tree()
			and screen.leaderboard_overlay.global_tab_button.is_visible_in_tree()
			and screen.leaderboard_overlay.callsign_edit.is_visible_in_tree()
			and screen.leaderboard_overlay.callsign_save_button.is_visible_in_tree()
			and screen.leaderboard_overlay.callsign_edit.max_length
			== PlayerCombatProfileStore.MAX_CALLSIGN_LENGTH
			and screen.leaderboard_overlay.current_tab == TitleLeaderboardOverlay.Tab.LOCAL,
			"opened=%s local=%s global=%s callsign=%s" % [
				leaderboard_opened,
				screen.leaderboard_overlay.local_tab_button.text,
				screen.leaderboard_overlay.global_tab_button.text,
				screen.leaderboard_overlay.callsign_edit.text,
			]
		)
		screen.leaderboard_overlay.set_tab(TitleLeaderboardOverlay.Tab.GLOBAL)
		await RenderingServer.frame_post_draw
		var leaderboard_global_image: Image = root.get_texture().get_image()
		var leaderboard_global_error: Error = leaderboard_global_image.save_png(
			ProjectSettings.globalize_path(LEADERBOARD_GLOBAL_SHOT_PATH)
		)
		_check(
			"leaderboard_global_shot_saved",
			leaderboard_global_error == OK,
			"error=%s size=%s" % [
				leaderboard_global_error,
				leaderboard_global_image.get_size(),
			]
		)
		_check(
			"title_leaderboard_global_tab_visible",
			screen.leaderboard_overlay.current_tab == TitleLeaderboardOverlay.Tab.GLOBAL
			and screen.leaderboard_overlay.status_label.is_visible_in_tree()
			and screen.leaderboard_overlay.refresh_button.is_visible_in_tree(),
			"state=%s status=%s" % [
				screen.leaderboard_overlay.current_tab,
				screen.leaderboard_overlay.status_label.text,
			]
		)
		screen.close_leaderboard(false)
		button.grab_focus()
		shot_status = "PASS" if save_error == OK else "FAIL"
		shot_path = SHOT_PATH

	_send_accept(true)
	await process_frame
	_send_accept(false)
	await process_frame
	var status_label: Label = screen.get_node("%StatusLabel") as Label
	_check("input_initializes", screen.initialized, "initialized=%s" % [screen.initialized])
	_check(
		"ready_status",
		status_label.text == L10n.t("title.expedition_active"),
		"status=%s" % [status_label.text]
	)
	_check("frame_budget", elapsed_frames <= MAX_FRAMES, _frame_budget_detail())
	_finish(shot_status, shot_path)


func _check_codex_header_clear(codex: DossierCodexOverlay) -> void:
	var evidence_rect: Rect2 = codex.evidence_label.get_global_rect()
	var list_rect: Rect2 = codex.dossier_list.get_global_rect()
	var font: Font = codex.evidence_label.get_theme_font(&"font")
	var font_size: int = codex.evidence_label.get_theme_font_size(&"font_size")
	var rendered_bottom: float = (
		evidence_rect.position.y
		+ font.get_height(font_size) * float(codex.evidence_label.get_line_count())
	)
	_check(
		"codex_header_clear_of_list",
		list_rect.position.y >= rendered_bottom + 8.0,
		"evidence=%s lines=%s rendered_bottom=%.2f list=%s"
		% [
			evidence_rect,
			codex.evidence_label.get_line_count(),
			rendered_bottom,
			list_rect,
		]
	)


func _check_minimum_text_height(screen: TitleScreen, button: Button) -> void:
	var measured_controls: int = 0
	var minimum_height: float = INF
	for label_node: Node in screen.find_children("*", "Label", true, false):
		var label: Label = label_node as Label
		minimum_height = minf(minimum_height, _rendered_line_height(label))
		measured_controls += 1
	minimum_height = minf(minimum_height, _rendered_line_height(button))
	measured_controls += 1
	_check(
		"minimum_rendered_text_height",
		minimum_height >= MINIMUM_TEXT_HEIGHT,
		"minimum_px=%.2f required_px=%.2f controls=%s"
		% [minimum_height, MINIMUM_TEXT_HEIGHT, measured_controls]
	)


func _check_layout_contract(screen: TitleScreen, button: Button) -> void:
	var briefing_toggle: Button = screen.get_node("%BriefingToggle") as Button
	var language_selector: HBoxContainer = screen.get_node("%LanguageSelector") as HBoxContainer
	var settings_button: Button = screen.get_node("%SettingsButton") as Button
	var button_rect: Rect2 = button.get_global_rect()
	var briefing_toggle_rect: Rect2 = briefing_toggle.get_global_rect()
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(root.size))
	_check(
		"action_briefing_separation",
		not button_rect.intersects(briefing_toggle_rect),
		"button=%s briefing=%s" % [button_rect, briefing_toggle_rect]
	)
	_check(
		"language_below_launch",
		language_selector.get_global_rect().position.y >= button_rect.end.y + 16.0,
		"button=%s language=%s" % [button_rect, language_selector.get_global_rect()]
	)
	_check(
		"title_controls_panel_removed",
		screen.get_node_or_null("StatusRail") == null
		and screen.get_node_or_null("%ControlsLabel") == null,
		"status_rail=%s controls_label=%s"
		% [
			screen.get_node_or_null("StatusRail") != null,
			screen.get_node_or_null("%ControlsLabel") != null,
		]
	)
	_check(
		"settings_flush_top_right",
		settings_button.position.y <= 20.0
		and float(root.size.x) - settings_button.get_rect().end.x <= 20.0,
		"settings=%s viewport=%s" % [settings_button.get_rect(), viewport_rect]
	)
	var background: TextureRect = screen.get_node("%BackgroundArt") as TextureRect
	_check(
		"generated_art_fills_viewport",
		background.get_global_rect() == viewport_rect,
		"background=%s viewport=%s" % [background.get_global_rect(), viewport_rect]
	)


func _check_briefing_content(screen: TitleScreen) -> void:
	var story: String = (screen.get_node("%InstructionLabel") as Label).text
	var controls: String = (
		screen.get_node("SemanticContract/BriefingControlsLabel") as Label
	).text
	var field_note: String = (screen.get_node("SemanticContract/FieldNote") as Label).text
	var tips: String = (screen.get_node("%BriefingTipsLabel") as Label).text
	var panel: Control = screen.get_node("SemanticContract") as Control
	var briefing_text: String = ""
	for label_node: Node in panel.find_children("*", "Label", true, false):
		briefing_text += (label_node as Label).text + "\n"
	_check(
		"story_present",
		story == L10n.t("title.command_hook"),
		"text=%s" % [story]
	)
	_check(
		"tutorial_present",
			controls == L10n.t(
				"title.controls_body",
				InputBindingSettings.display_placeholders()
			)
			and field_note == L10n.t(
				"title.field_note",
				InputBindingSettings.display_placeholders()
			),
		"controls=%s note=%s" % [controls, field_note]
	)
	_check(
		"objectives_present",
		briefing_text.contains(L10n.t("title.primary_objective"))
		and briefing_text.contains(L10n.t("title.objective_one"))
		and briefing_text.contains(L10n.t("title.objective_three")),
		"text=%s" % [briefing_text]
	)
	_check(
		"enemy_and_retry_intel_present",
		briefing_text.contains(L10n.t("title.enemy_intel"))
		and briefing_text.contains(L10n.t("title.run_protocol")),
		"text=%s" % [briefing_text]
	)
	_check(
		"movement_melee_doctrine_present",
		tips.count("\n") == 5
		and tips
		== L10n.t("briefing.tips_body", InputBindingSettings.display_placeholders()),
		"tips=%s" % [tips]
	)


func _check_language_selector(screen: TitleScreen) -> void:
	var initial_locale: String = L10n.current_locale()
	var alternate_locale: String = "en" if initial_locale == "zh-CN" else "zh-CN"
	var english_button: Button = screen.get_node("%EnglishButton") as Button
	var chinese_button: Button = screen.get_node("%ChineseButton") as Button
	_check(
		"language_selector_has_only_en_cn",
		screen.get_node_or_null("%AutomaticButton") == null
		and english_button.text == "EN"
		and chinese_button.text == "CN",
		"en=%s cn=%s" % [english_button.text, chinese_button.text]
	)
	_check(
		"resolved_language_is_highlighted",
		(english_button.button_pressed and initial_locale == "en")
		or (chinese_button.button_pressed and initial_locale == "zh-CN"),
		"locale=%s en=%s cn=%s"
		% [initial_locale, english_button.button_pressed, chinese_button.button_pressed]
	)
	var switched: bool = screen.select_language(alternate_locale)
	_check(
		"language_switches_live",
		switched
		and L10n.current_locale() == alternate_locale
		and english_button.button_pressed == (alternate_locale == "en")
		and chinese_button.button_pressed == (alternate_locale == "zh-CN"),
		"locale=%s en=%s cn=%s"
		% [L10n.current_locale(), english_button.button_pressed, chinese_button.button_pressed]
	)
	_check(
		"language_preference_persists",
		L10n.preferred_locale(LANGUAGE_PREFERENCE_PATH) == alternate_locale,
		"persisted=%s" % [L10n.preferred_locale(LANGUAGE_PREFERENCE_PATH)]
	)
	var restored: bool = screen.select_language(initial_locale)
	_check(
		"initial_language_restores_explicitly",
		restored
		and L10n.current_locale() == initial_locale
		and L10n.preferred_locale(LANGUAGE_PREFERENCE_PATH) == initial_locale,
		"locale=%s persisted=%s"
		% [L10n.current_locale(), L10n.preferred_locale(LANGUAGE_PREFERENCE_PATH)]
	)


func _check_briefing_interaction(screen: TitleScreen) -> void:
	var briefing_layer: Control = screen.get_node("%BriefingLayer") as Control
	var briefing_background: ColorRect = (
		screen.get_node("%BriefingBackground") as ColorRect
	)
	var opened: bool = screen.open_briefing()
	_check(
		"briefing_opens",
		opened and briefing_layer.visible,
		"visible=%s" % [briefing_layer.visible]
	)
	_check(
		"briefing_uses_minimal_background",
		screen.get_node_or_null("%BriefingArt") == null
		and briefing_background.color.a > 0.95,
		"background=%s" % [briefing_background.color]
	)
	_check(
		"briefing_shows_only_controls_and_archive_action",
		screen.briefing_tips_panel.is_visible_in_tree()
		and screen.campaign_panel.codex_button.is_visible_in_tree()
		and not screen.campaign_panel.panel.visible
		and not screen.campaign_panel.heading_label.visible
		and not screen.campaign_panel.progress_label.visible
		and not screen.campaign_panel.evidence_label.visible
		and not screen.campaign_panel.continuity_label.visible
		and not screen.campaign_panel.endings_label.visible,
		"controls=%s archive=%s"
		% [
			screen.briefing_tips_panel.is_visible_in_tree(),
			screen.campaign_panel.codex_button.is_visible_in_tree(),
		]
	)
	var closed: bool = screen.close_briefing()
	_check(
		"briefing_closes",
		closed and not briefing_layer.visible,
		"visible=%s" % [briefing_layer.visible]
	)


func _rendered_line_height(control: Control) -> float:
	var font: Font = control.get_theme_font(&"font")
	var font_size: int = control.get_theme_font_size(&"font_size")
	return font.get_height(font_size)


func _clear_input_preference() -> void:
	if FileAccess.file_exists(INPUT_PREFERENCE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(INPUT_PREFERENCE_PATH))


func _frame_budget_detail() -> String:
	return "frames=%s max_frames=%s" % [elapsed_frames, MAX_FRAMES]


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)


func _send_accept(pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = pressed
	event.device = DEVICE_ID
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(check_name: String, passed: bool, detail: String) -> void:
	checks.append({"name": check_name, "passed": passed, "detail": detail})
	print("[CHECK] %s %s — %s" % ["PASS" if passed else "FAIL", check_name, detail])


func _finish(shot_status: String, shot_path: String) -> void:
	completed = true
	L10n.clear_locale_preference(LANGUAGE_PREFERENCE_PATH)
	InputBindingSettings.reset_to_defaults(INPUT_PREFERENCE_PATH, false)
	_clear_input_preference()
	var all_passed: bool = true
	for item: Dictionary in checks:
		if not bool(item["passed"]):
			all_passed = false
	var report: Dictionary = {
		"scenario": "title_screen",
		"result": "PASS" if all_passed else "FAIL",
		"done": completed,
		"headless": DisplayServer.get_name() == "headless",
		"elapsed_frames": elapsed_frames,
		"max_frames": MAX_FRAMES,
		"checks": checks,
		"shot": {"status": shot_status, "path": shot_path},
		"engine": Engine.get_version_info().get("string", "unknown"),
		"unix_time": Time.get_unix_time_from_system(),
	}
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/title_screen")
	)
	var report_file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	print("[SCENARIO-DONE] result=%s" % [report["result"]])
	quit(0 if all_passed else 1)
