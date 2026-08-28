extends SceneTree

const MAX_FRAMES: int = 180

var elapsed_frames: int = 0
var completed: bool = false


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred(&"_run")


func _on_process_frame() -> void:
	if completed:
		return
	elapsed_frames += 1
	if elapsed_frames > MAX_FRAMES:
		push_error("Field briefing visual scenario exceeded frame watchdog")
		quit(1)


func _run() -> void:
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	if scene == null:
		quit(1)
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	city.mobile_detection_override = 1 if target_size.y > target_size.x else 0
	root.add_child(city)
	await process_frame
	city.gameplay_hud.first_run_tutorial._finish_tutorial(true)
	city.encounter_runtime.release_all()
	city.encounter_director.process_mode = Node.PROCESS_MODE_DISABLED
	var briefing: FieldBriefingPanel = city.gameplay_hud.field_briefing
	if not briefing.open():
		quit(1)
		return
	for _frame: int in range(4):
		await process_frame
		if (
			not briefing.is_open()
			or not city.urban_siege.is_simulation_paused()
			or city.robot.is_physics_processing()
			or briefing.tips_label.text.count("\n") != 4
			or briefing.tips_label.text
			!= L10n.t("briefing.tips_body", InputBindingSettings.display_placeholders())
		):
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
		briefing.close(false)
		city.queue_free()
		await process_frame
		quit(0)
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var shot_path: String = _shot_path(target_size)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/field_briefing")
	)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(shot_path))
	if save_error != OK or image.get_size() != target_size:
		quit(1)
		return
	completed = true
	print("[FIELD-BRIEFING-VISUAL-DONE] shot=%s" % shot_path)
	briefing.close(false)
	city.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)


func _shot_path(target_size: Vector2i) -> String:
	return (
		"res://artifacts/field_briefing/field-briefing-portrait.png"
		if target_size.y > target_size.x
		else "res://artifacts/field_briefing/field-briefing-landscape.png"
	)
