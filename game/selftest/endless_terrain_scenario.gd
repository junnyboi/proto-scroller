extends SceneTree

const MAX_FRAMES: int = 900
const REPORT_PATH: String = "res://artifacts/endless_terrain/report.json"
const SHOT_PATH: String = "res://artifacts/endless_terrain/endless-terrain.png"

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
		_check("frame_watchdog", false, "frames=%d" % elapsed_frames)
		_finish("SKIP", "")


func _run() -> void:
	root.get_window().content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	_check("city_scene_loads", packed != null, "loaded=%s" % [packed != null])
	if packed == null:
		_finish("SKIP", "")
		return
	var city: CitySlice = packed.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	await physics_frame
	city.urban_siege.stop_run()
	city.upgrade_assembler.session.set_presentation_blocked(true)
	city.gameplay_hud.first_run_tutorial.visible = false
	city.encounter_runtime.release_all()
	var baseline_nodes: int = RuntimeBudget.snapshot(city).node_count
	var origin_cell: Destructible2D = city.building.get_cell(0, 1)
	origin_cell.receive_damage(_fatal_event(city, origin_cell, 51_001))
	city.car.current_health = 1.0
	city.car.receive_damage(_fatal_event(city, city.car, 51_002))
	for logical_index: int in range(-12, 49):
		_move_to_logical_chunk(city, logical_index)
	for logical_index: int in range(48, 39, -1):
		_move_to_logical_chunk(city, logical_index)
	_check(
		"six_chunk_window",
		city.world_stream.active_chunk_count() == CityWorldStream.CHUNK_CAPACITY,
		"chunks=%d" % city.world_stream.active_chunk_count()
	)
	_check(
		"traversal_exceeds_fixed_map",
		city.world_stream.maximum_visited_chunk >= 48,
		"max_chunk=%d" % city.world_stream.maximum_visited_chunk
	)
	_check(
		"floating_origin_applied",
		city.world_stream.floating_origin.shift_count > 0,
		"shifts=%d origin_chunk=%d"
		% [
			city.world_stream.floating_origin.shift_count,
			city.world_stream.floating_origin.origin_chunk,
		]
	)
	_check(
		"no_stream_growth",
		RuntimeBudget.snapshot(city).node_count == baseline_nodes
		and city.world_stream.post_warm_creation_count == 0
		and city.streamed_destructibles.post_warm_creation_count == 0,
		"nodes=%d baseline=%d terrain_creations=%d content_creations=%d"
		% [
			RuntimeBudget.snapshot(city).node_count,
			baseline_nodes,
			city.world_stream.post_warm_creation_count,
			city.streamed_destructibles.post_warm_creation_count,
		]
	)
	_move_to_logical_chunk(city, 0)
	_check(
		"destruction_state_persisted",
		city.building.is_cell_destroyed(0, 1) and city.car.is_broken,
		"cell=%s car=%s mutations=%d"
		% [
			city.building.is_cell_destroyed(0, 1),
			city.car.is_broken,
			city.streamed_destructibles.mutation_count(),
		]
	)
	_check(
		"progression_pressure_scaled",
		city.world_stream.progression_tier() == CityWorldStream.MAX_PROGRESSION_TIER,
		"tier=%d max_chunk=%d"
		% [city.world_stream.progression_tier(), city.world_stream.maximum_visited_chunk]
	)
	city.robot.global_position.x = (
		city.world_stream.runtime_x_for_logical_index(40)
		+ CityWorldStream.CHUNK_WIDTH * 0.48
	)
	city.world_stream.advance_stream()
	city.camera_rig.global_position = Vector2(city.robot.global_position.x, 360.0)
	city.camera_rig.follow_speed = 10000.0
	city.camera_rig.reset_after_origin_shift()
	var enemy_kinds: Array[StringName] = [&"soldier", &"bulwark", &"lancer", &"helicopter"]
	var enemy_offsets: Array[Vector2] = [
		Vector2(-460.0, 542.5 - city.robot.global_position.y),
		Vector2(-280.0, 542.5 - city.robot.global_position.y),
		Vector2(330.0, 542.5 - city.robot.global_position.y),
		Vector2(500.0, 180.0 - city.robot.global_position.y),
	]
	for enemy_index: int in range(enemy_kinds.size()):
		var enemy: EnemyActor2D = city.encounter_runtime.acquire(
			enemy_kinds[enemy_index],
			city.robot.global_position + enemy_offsets[enemy_index]
		)
		if enemy != null:
			enemy.set_physics_process(false)
	for settle_frame: int in range(6):
		await physics_frame
		city.camera_rig._physics_process(1.0 / 60.0)
	var spawn_position: Vector2 = city.encounter_runtime.resolve_spawn_position(
		Vector2(0.0, 542.5),
		&"AHEAD"
	)
	_check(
		"camera_relative_spawns",
		spawn_position.x > city.robot.global_position.x,
		"robot_x=%.1f spawn_x=%.1f" % [city.robot.global_position.x, spawn_position.x]
	)
	_check(
		"origin_landmarks_culled",
		not city.landmark_root.visible
		and city.landmark_root.process_mode == Node.PROCESS_MODE_DISABLED,
		"visible=%s mode=%d" % [city.landmark_root.visible, city.landmark_root.process_mode]
	)
	_check(
		"runtime_caps_hold",
		RuntimeBudget.validation_errors(city).is_empty(),
		"errors=%s" % RuntimeBudget.validation_errors(city)
	)
	var shot_status: String = "SKIP"
	var shot_path: String = ""
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
	else:
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://artifacts/endless_terrain")
		)
		var error: Error = image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
		_check("shot_saved", error == OK, "error=%d" % error)
		_check("shot_geometry", image.get_size() == Vector2i(1280, 720), "size=%s" % image.get_size())
		shot_status = "PASS" if error == OK else "FAIL"
		shot_path = SHOT_PATH
	city.queue_free()
	await process_frame
	# Work around godotengine/godot#76745 in fixed-FPS command-line runs.
	OS.delay_msec(100)
	_finish(shot_status, shot_path)


func _move_to_logical_chunk(city: CitySlice, logical_index: int) -> void:
	city.robot.global_position.x = (
		city.world_stream.runtime_x_for_logical_index(logical_index)
		+ CityWorldStream.CHUNK_WIDTH * 0.5
	)
	city.world_stream.advance_stream()


func _fatal_event(city: CitySlice, target: Node2D, attack_id: int) -> DamageEvent:
	var event: DamageEvent = DamageEvent.new(
		attack_id,
		city.robot,
		10_000.0,
		&"jab_cross"
	)
	event.hit_position = target.global_position
	event.direction = Vector2.RIGHT
	event.impulse_per_mass = 900.0
	return event


func _check(check_name: String, passed: bool, detail: String) -> void:
	checks.append({"name": check_name, "passed": passed, "detail": detail})
	print("[CHECK] %s %s — %s" % ["PASS" if passed else "FAIL", check_name, detail])


func _finish(shot_status: String, shot_path: String) -> void:
	completed = true
	var all_passed: bool = true
	for item: Dictionary in checks:
		if not bool(item.passed):
			all_passed = false
	var report: Dictionary = {
		"scenario": "endless_terrain",
		"result": "PASS" if all_passed else "FAIL",
		"done": completed,
		"headless": DisplayServer.get_name() == "headless",
		"elapsed_frames": elapsed_frames,
		"max_frames": MAX_FRAMES,
		"checks": checks,
		"shot": {"status": shot_status, "path": shot_path},
		"engine": Engine.get_version_info().get("string", "unknown"),
	}
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/endless_terrain")
	)
	var report_file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	print("[SCENARIO-DONE] result=%s" % report.result)
	quit(0 if all_passed else 1)
