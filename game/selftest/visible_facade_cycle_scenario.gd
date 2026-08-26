extends SceneTree

const ARTIFACT_DIR: String = "res://artifacts/visible_facade_cycle"
const MAX_ADVANCE_FRAMES: int = 480

var _report: Dictionary = {
	"done": false,
	"result": "FAIL",
	"orientation": "",
	"variants": [],
	"shots": [],
}


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var target_size: Vector2i = _target_size()
	root.get_window().content_scale_size = target_size
	root.size = target_size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	var scene: PackedScene = load("res://scenes/gameplay/city_slice.tscn") as PackedScene
	_check("scene_loads", scene != null, "city_slice")
	var city: CitySlice = scene.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	_prepare_city(city)
	var expected_variants: Array[StringName] = []
	for local_index: int in range(CityDistrictCatalog.VARIANTS_PER_DISTRICT):
		expected_variants.append(
			CityDistrictCatalog.variant_for_chunk(
				city.world_stream.run_seed,
				local_index
			).variant_id
		)
	for local_index: int in range(CityDistrictCatalog.VARIANTS_PER_DISTRICT):
		_check(
			"chunk_%d_reached" % local_index,
			city.world_stream.current_logical_chunk == local_index,
			"current=%d" % city.world_stream.current_logical_chunk
		)
		_check(
			"chunk_%d_variant" % local_index,
			city.building.current_variant_id() == expected_variants[local_index],
			String(city.building.current_variant_id())
		)
		await _settle_camera(city)
		var shot_path: String = "%s/business-%02d-%s.png" % [
			ARTIFACT_DIR,
			local_index,
			"portrait" if _is_portrait() else "landscape",
		]
		_check("chunk_%d_shot" % local_index, _capture(shot_path), shot_path)
		_report.variants.append(String(city.building.current_variant_id()))
		_report.shots.append({
			"logical_chunk": local_index,
			"variant": String(city.building.current_variant_id()),
			"path": shot_path,
		})
		if local_index < CityDistrictCatalog.VARIANTS_PER_DISTRICT - 1:
			_open_ground_breach(city.building)
			await physics_frame
			_check(
				"chunk_%d_passage_open" % local_index,
				city.building.ground_passage_open(),
				String(city.building.current_variant_id())
			)
			_check(
				"chunk_%d_natural_advance" % local_index,
				await _advance_to_chunk(city, local_index + 1),
				"robot_x=%.2f current=%d"
				% [city.robot.global_position.x, city.world_stream.current_logical_chunk]
			)
	_check(
		"five_unique_visible_facades",
		_report.variants.size() == CityDistrictCatalog.VARIANTS_PER_DISTRICT
		and _unique_count(_report.variants) == CityDistrictCatalog.VARIANTS_PER_DISTRICT,
		JSON.stringify(_report.variants)
	)
	_report.orientation = "portrait" if _is_portrait() else "landscape"
	_report.done = true
	_report.result = "PASS"
	_write_report()
	city.queue_free()
	await process_frame
	await process_frame
	print("[VISIBLE-FACADE-CYCLE-DONE] result=PASS variants=%s" % [
		JSON.stringify(_report.variants)
	])
	quit(0)


func _prepare_city(city: CitySlice) -> void:
	city.encounter_runtime.release_all()
	city.encounter_director.process_mode = Node.PROCESS_MODE_DISABLED
	if city.gameplay_hud.first_run_tutorial != null:
		city.gameplay_hud.first_run_tutorial._finish_tutorial(true)
	city.robot.set_physics_process(false)
	city.world_stream.set_physics_process(false)
	city.robot.gravity = 0.0
	city.robot.velocity = Vector2.ZERO
	city.camera_rig.follow_speed = 10000.0


func _open_ground_breach(building: StructuralBuilding2D) -> void:
	var state: Dictionary = building.capture_stream_state()
	var cells: Array = state.cells as Array
	var ground_cell_index: int = StructuralBuilding2D.COLUMNS
	var breached: Dictionary = cells[ground_cell_index] as Dictionary
	breached.health = 0.0
	breached.destroyed = true
	breached.pristine = false
	cells[ground_cell_index] = breached
	state.cells = cells
	state.pristine = false
	building.restore_stream_state(state)


func _advance_to_chunk(city: CitySlice, target_chunk: int) -> bool:
	var reached_target: bool = false
	for _frame: int in range(MAX_ADVANCE_FRAMES):
		city.robot.physics_step(1.0, 1.0 / 60.0)
		city.world_stream.advance_stream()
		await physics_frame
		if city.world_stream.current_logical_chunk == target_chunk:
			reached_target = true
		if reached_target and is_zero_approx(city.robot.velocity.x):
			return true
	return false


func _settle_camera(city: CitySlice) -> void:
	for _frame: int in range(8):
		city.camera_rig._physics_process(1.0 / 60.0)
		await physics_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _capture(path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
		return true
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	return (
		error == OK
		and FileAccess.file_exists(path)
		and image.get_size() == _target_size()
	)


func _unique_count(values: Array) -> int:
	var unique: Dictionary[String, bool] = {}
	for value: Variant in values:
		unique[String(value)] = true
	return unique.size()


func _check(check_name: String, passed: bool, detail: String) -> void:
	if passed:
		print("[CHECK] PASS %s — %s" % [check_name, detail])
		return
	push_error("[CHECK] FAIL %s — %s" % [check_name, detail])
	_report.done = true
	_report.result = "FAIL"
	_write_report()
	quit(1)


func _write_report() -> void:
	var path: String = "%s/report-%s.json" % [
		ARTIFACT_DIR,
		"portrait" if _is_portrait() else "landscape",
	]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "  "))


func _is_portrait() -> bool:
	return OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1"


func _target_size() -> Vector2i:
	return Vector2i(720, 1280) if _is_portrait() else Vector2i(1280, 720)
