extends SceneTree

const DEVICE_ID: int = 4242
const REPORT_PATH: String = "res://artifacts/title_screen/report.json"
const SHOT_PATH: String = "res://artifacts/title_screen/title-screen.png"

var checks: Array[Dictionary] = []
var completed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
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
	_check("viewport_geometry", root.size == Vector2i(1280, 720), "size=%s" % [root.size])
	var title_visible: bool = title_label.is_visible_in_tree()
	_check("title_visible", title_visible, "visible=%s" % [title_visible])
	_check("title_text", title_label.text == "PROTO\nSCROLLER", "text=%s" % [title_label.text])
	_check("button_focused", button.has_focus(), "focused=%s" % [button.has_focus()])

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
			image.get_size() == Vector2i(1280, 720),
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
	_check("ready_status", status_label.text == "SYSTEM READY", "status=%s" % [status_label.text])
	_finish(shot_status, shot_path)


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
