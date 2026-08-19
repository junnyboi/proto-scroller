extends SceneTree

const DEVICE_ID: int = 4242
const MAX_FRAMES: int = 240
const MINIMUM_TEXT_HEIGHT: float = 32.0
const REPORT_PATH: String = "res://artifacts/title_screen/report.json"
const SHOT_PATH: String = "res://artifacts/title_screen/title-screen.png"

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
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var scene_resource: PackedScene = load("res://scenes/title_screen.tscn") as PackedScene
	_check("main_scene_loads", scene_resource != null, "loaded=%s" % [scene_resource != null])
	if scene_resource == null:
		_finish("SKIP", "")
		return

	var screen: TitleScreen = scene_resource.instantiate() as TitleScreen
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
		title_label.text == "PROTO SCROLLER\nFIELD BRIEFING",
		"text=%s" % [title_label.text]
	)
	_check(
		"begin_expedition_action",
		button.text == "BEGIN EXPEDITION",
		"text=%s" % [button.text]
	)
	_check_briefing_content(screen)
	_check("button_focused", button.has_focus(), "focused=%s" % [button.has_focus()])
	_check_minimum_text_height(screen, button)
	_check_layout_contract(screen, button)

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
		status_label.text == "EXPEDITION ACTIVE",
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
	var bottom_rail: HBoxContainer = screen.get_node("BottomRail") as HBoxContainer
	var telemetry_panel: PanelContainer = screen.get_node("TelemetryPanel") as PanelContainer
	var button_rect: Rect2 = button.get_global_rect()
	var footer_rect: Rect2 = bottom_rail.get_global_rect()
	var telemetry_rect: Rect2 = telemetry_panel.get_global_rect()
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(root.size))
	_check(
		"action_footer_separation",
		not button_rect.intersects(footer_rect),
		"button=%s footer=%s" % [button_rect, footer_rect]
	)
	_check(
		"telemetry_inside_viewport",
		viewport_rect.encloses(telemetry_rect),
		"viewport=%s telemetry=%s" % [viewport_rect, telemetry_rect]
	)


func _check_briefing_content(screen: TitleScreen) -> void:
	var story: String = (screen.get_node("%InstructionLabel") as Label).text
	var controls: String = (screen.get_node("%ControlsLabel") as Label).text
	var field_note: String = (screen.get_node("HeroStack/FieldNote") as Label).text
	var panel: VBoxContainer = screen.get_node("TelemetryPanel/PanelStack") as VBoxContainer
	var briefing_text: String = ""
	for label_node: Node in panel.find_children("*", "Label", true, false):
		briefing_text += (label_node as Label).text + "\n"
	_check(
		"story_present",
		story.contains("city defense grid went silent"),
		"text=%s" % [story]
	)
	_check(
		"tutorial_present",
		controls.contains("A / D") and controls.contains("SPACE")
		and controls.contains("Mobile joystick") and controls.contains("SMASH")
		and field_note.contains("recovery") and field_note.contains("dash dodge"),
		"controls=%s note=%s" % [controls, field_note]
	)
	_check(
		"objectives_present",
		briefing_text.contains("Survive the city response")
		and briefing_text.contains("earn EXP")
		and briefing_text.contains("1 of 2 upgrades"),
		"text=%s" % [briefing_text]
	)
	_check(
		"enemy_and_retry_intel_present",
		briefing_text.contains("Soldiers + tanks")
		and briefing_text.contains("Helicopters + rockets")
		and briefing_text.contains("reset when you Retry"),
		"text=%s" % [briefing_text]
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
