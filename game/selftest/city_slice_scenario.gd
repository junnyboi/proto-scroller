extends SceneTree

const MAX_FRAMES: int = 420
const REPORT_PATH: String = "res://artifacts/city_slice/report.json"
const SHOT_PATH: String = "res://artifacts/city_slice/city-slice.png"

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
		_check("frame_watchdog", false, "frames=%s" % elapsed_frames)
		_finish("SKIP", "")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	_check("city_scene_loads", scene != null, "loaded=%s" % [scene != null])
	if scene == null:
		_finish("SKIP", "")
		return
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	await physics_frame
	await physics_frame
	var parallax_count: int = city.get_node("ParallaxCity").get_child_count()
	_check("five_parallax_bands", parallax_count == 5, "bands=%s" % parallax_count)
	var enemies_ready: bool = (
		city.soldier != null and city.tank != null and city.helicopter != null
	)
	_check(
		"enemy_set",
		enemies_ready,
		"soldier=%s tank=%s helicopter=%s"
		% [city.soldier != null, city.tank != null, city.helicopter != null]
	)
	city.robot.set_physics_process(false)
	var initial_x: float = city.robot.position.x
	for frame_index: int in range(90):
		await physics_frame
		city.robot.physics_step(1.0, 1.0 / 60.0)
	_check(
		"robot_moves",
		city.robot.position.x > initial_x + 200.0,
		"start=%.2f end=%.2f" % [initial_x, city.robot.position.x]
	)
	for frame_index: int in range(8):
		await physics_frame
		city.robot.physics_step(-1.0, 1.0 / 60.0)
	_check("robot_turns", city.robot.facing == -1, "facing=%s" % city.robot.facing)
	city.car.current_health = 1.0
	city.streetlamp.current_health = 1.0
	for row: int in range(StructuralBuilding2D.ROWS):
		for column: int in range(StructuralBuilding2D.COLUMNS):
			city.building.get_cell(column, row).current_health = 1.0
	city.robot.stomp_radius = 950.0
	city.robot.stomp_damage = 300.0
	city.trigger_test_stomp()
	await physics_frame
	await physics_frame
	await physics_frame
	_check("car_breaks", city.car.is_broken, "broken=%s" % city.car.is_broken)
	_check("lamp_breaks", city.streetlamp.is_broken, "broken=%s" % city.streetlamp.is_broken)
	_check(
		"building_breaks",
		city.building.is_destroyed(),
		"destroyed=%s cells=%d"
		% [city.building.is_destroyed(), city.building.destroyed_cell_count()]
	)
	_check(
		"debris_activates",
		city.debris_pool.active_count() > 0,
		"active=%s" % city.debris_pool.active_count()
	)
	var shot_status: String = "SKIP"
	var shot_path: String = ""
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
	else:
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://artifacts/city_slice")
		)
		var save_error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
		_check("shot_saved", save_error == OK, "error=%s" % save_error)
		_check(
			"shot_geometry",
			image.get_size() == Vector2i(1280, 720),
			"size=%s" % image.get_size()
		)
		shot_status = "PASS" if save_error == OK else "FAIL"
		shot_path = SHOT_PATH
	_check(
		"frame_budget",
		elapsed_frames <= MAX_FRAMES,
		"frames=%s max=%s" % [elapsed_frames, MAX_FRAMES]
	)
	_finish(shot_status, shot_path)


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
		"scenario": "city_slice",
		"result": "PASS" if all_passed else "FAIL",
		"done": completed,
		"headless": DisplayServer.get_name() == "headless",
		"elapsed_frames": elapsed_frames,
		"max_frames": MAX_FRAMES,
		"checks": checks,
		"shot": {"status": shot_status, "path": shot_path},
		"engine": Engine.get_version_info().get("string", "unknown"),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/city_slice"))
	var report_file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	print("[SCENARIO-DONE] result=%s" % report["result"])
	quit(0 if all_passed else 1)
