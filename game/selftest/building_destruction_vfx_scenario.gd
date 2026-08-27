extends SceneTree

const MAX_FRAMES: int = 180
const SHOT_DIR: String = "res://artifacts/building_destruction_vfx"

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
		push_error("Building destruction VFX scenario exceeded frame watchdog")
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
	root.add_child(city)
	await process_frame
	city.gameplay_hud.first_run_tutorial._finish_tutorial(true)
	city.encounter_runtime.release_all()
	city.encounter_director.process_mode = Node.PROCESS_MODE_DISABLED
	city.urban_siege.process_mode = Node.PROCESS_MODE_DISABLED
	city.gameplay_hud.transmission_toast.visible = false
	city.gameplay_hud.transmission_toast.process_mode = Node.PROCESS_MODE_DISABLED
	var damage_callback: Callable = Callable(city, "_on_streamed_building_damage_applied")
	if city.streamed_destructibles.building_damage_applied.is_connected(damage_callback):
		city.streamed_destructibles.building_damage_applied.disconnect(damage_callback)
	var cell_callback: Callable = Callable(city, "_on_streamed_building_cell_destroyed")
	if city.streamed_destructibles.building_cell_destroyed.is_connected(cell_callback):
		city.streamed_destructibles.building_cell_destroyed.disconnect(cell_callback)
	city.building.restore_stream_state({})
	city.debris_pool.release_all()
	city.building_section_burst_pool.reset_all()
	city.robot.global_position.x = city.building.global_position.x - 80.0
	city.robot.velocity = Vector2.ZERO
	city.camera_rig.reset_presentation()
	city.camera_rig.global_position.x = city.building.global_position.x
	await process_frame

	var expected: Array[StringName] = [&"concrete", &"glass", &"steel"]
	for index: int in range(expected.size()):
		var cell: Destructible2D = _first_cell_with_material(city.building, expected[index])
		if cell == null:
			quit(1)
			return
		var direction: Vector2 = Vector2(1.0, -0.28 + 0.28 * float(index)).normalized()
		var event: DamageEvent = DamageEvent.new(
			930_000 + index,
			city.robot,
			cell.max_health + 1.0,
			&"jab_cross",
			cell.global_position,
			direction,
			560.0 + 90.0 * float(index)
		)
		if not cell.receive_damage(event):
			quit(1)
			return

	for _frame: int in range(5):
		await process_frame
	var active_materials: Dictionary[StringName, bool] = {}
	for slot: BuildingSectionBurst2D in city.building_section_burst_pool.active_slots():
		active_materials[slot.material_id] = true
	if (
		city.building_section_burst_pool.spawn_count != 3
		or city.building_section_burst_pool.active_count() != 3
		or city.debris_pool.active_count() < 6
		or not active_materials.has(&"concrete")
		or not active_materials.has(&"glass")
		or not active_materials.has(&"steel")
	):
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		print("[SHOT-SKIPPED] headless lane cannot render")
		_teardown(city)
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var shot_path: String = "%s/building-destruction-vfx-%s.png" % [
		SHOT_DIR,
		"portrait" if target_size.y > target_size.x else "landscape",
	]
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(shot_path))
	if save_error != OK or image.get_size() != target_size:
		quit(1)
		return
	completed = true
	print(
		"[BUILDING-DESTRUCTION-VFX-DONE] shot=%s bursts=%d debris=%d"
		% [
			shot_path,
			city.building_section_burst_pool.spawn_count,
			city.debris_pool.active_count(),
		]
	)
	_teardown(city)


func _first_cell_with_material(
	building: StructuralBuilding2D,
	material_id: StringName
) -> Destructible2D:
	for row: int in range(StructuralBuilding2D.ROWS):
		for column: int in range(StructuralBuilding2D.COLUMNS):
			var cell: Destructible2D = building.get_cell(column, row)
			if cell != null and cell.get_material_profile().material_id == material_id:
				return cell
	return null


func _teardown(city: CitySlice) -> void:
	completed = true
	city.building_section_burst_pool.reset_all()
	city.debris_pool.release_all()
	city.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _target_size() -> Vector2i:
	if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1":
		return Vector2i(720, 1280)
	return Vector2i(1280, 720)
