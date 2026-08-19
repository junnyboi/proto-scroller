extends SceneTree

const DEVICE_ID: int = 4242
const MAX_FRAMES: int = 240
const MINIMUM_TEXT_HEIGHT: float = 32.0
const REPORT_PATH: String = "res://artifacts/title_screen/report.json"
const SHOT_PATH: String = "res://artifacts/title_screen/title-screen.png"
const BRIEFING_SHOT_PATH: String = "res://artifacts/title_screen/title-screen-briefing.png"
const LANGUAGE_PREFERENCE_PATH: String = "user://title-scenario-language.cfg"

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
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var scene_resource: PackedScene = load("res://scenes/title_screen.tscn") as PackedScene
	_check("main_scene_loads", scene_resource != null, "loaded=%s" % [scene_resource != null])
	if scene_resource == null:
		_finish("SKIP", "")
		return

	var screen: TitleScreen = scene_resource.instantiate() as TitleScreen
	screen.locale_preference_path = LANGUAGE_PREFERENCE_PATH
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
		screen.close_briefing()
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
	var status_rail: PanelContainer = screen.get_node("StatusRail") as PanelContainer
	var button_rect: Rect2 = button.get_global_rect()
	var briefing_toggle_rect: Rect2 = briefing_toggle.get_global_rect()
	var status_rect: Rect2 = status_rail.get_global_rect()
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(root.size))
	_check(
		"action_briefing_separation",
		not button_rect.intersects(briefing_toggle_rect),
		"button=%s briefing=%s" % [button_rect, briefing_toggle_rect]
	)
	_check(
		"language_below_launch",
		language_selector.get_global_rect().position.y >= button_rect.end.y,
		"button=%s language=%s" % [button_rect, language_selector.get_global_rect()]
	)
	_check(
		"status_rail_inside_viewport",
		viewport_rect.encloses(status_rect),
		"viewport=%s status=%s" % [viewport_rect, status_rect]
	)
	var background: TextureRect = screen.get_node("%BackgroundArt") as TextureRect
	_check(
		"generated_art_fills_viewport",
		background.get_global_rect() == viewport_rect,
		"background=%s viewport=%s" % [background.get_global_rect(), viewport_rect]
	)


func _check_briefing_content(screen: TitleScreen) -> void:
	var story: String = (screen.get_node("%InstructionLabel") as Label).text
	var controls: String = (screen.get_node("%ControlsLabel") as Label).text
	var field_note: String = (screen.get_node("SemanticContract/FieldNote") as Label).text
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
		controls == L10n.t("title.controls_body")
		and field_note == L10n.t("title.field_note"),
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


func _check_language_selector(screen: TitleScreen) -> void:
	var initial_locale: String = L10n.current_locale()
	var alternate_locale: String = "en" if initial_locale == "zh-CN" else "zh-CN"
	var automatic_button: Button = screen.get_node("%AutomaticButton") as Button
	_check(
		"automatic_mode_shows_resolved_locale",
		automatic_button.button_pressed
		and automatic_button.text == _expected_automatic_label(),
		"pressed=%s text=%s" % [automatic_button.button_pressed, automatic_button.text]
	)
	var switched: bool = screen.select_language(alternate_locale)
	_check(
		"language_switches_live",
		switched and L10n.current_locale() == alternate_locale,
		"locale=%s" % [L10n.current_locale()]
	)
	_check(
		"language_preference_persists",
		L10n.preferred_locale(LANGUAGE_PREFERENCE_PATH) == alternate_locale,
		"persisted=%s" % [L10n.preferred_locale(LANGUAGE_PREFERENCE_PATH)]
	)
	var restored: bool = screen.select_automatic_language()
	_check(
		"automatic_mode_restores_detected_locale",
		restored
		and L10n.current_locale() == initial_locale
		and L10n.uses_automatic_locale(LANGUAGE_PREFERENCE_PATH)
		and automatic_button.button_pressed
		and automatic_button.text == _expected_automatic_label(),
		"locale=%s automatic=%s text=%s"
		% [
			L10n.current_locale(),
			L10n.uses_automatic_locale(LANGUAGE_PREFERENCE_PATH),
			automatic_button.text,
		]
	)


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


func _check_briefing_interaction(screen: TitleScreen) -> void:
	var briefing_layer: Control = screen.get_node("%BriefingLayer") as Control
	var briefing_art: TextureRect = screen.get_node("%BriefingArt") as TextureRect
	var opened: bool = screen.open_briefing()
	_check(
		"briefing_opens",
		opened and briefing_layer.visible,
		"visible=%s" % [briefing_layer.visible]
	)
	_check(
		"briefing_uses_generated_art",
		briefing_art.texture.resource_path.contains("command_deck_briefing"),
		"texture=%s" % [briefing_art.texture.resource_path]
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
