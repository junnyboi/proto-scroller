extends SceneTree

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const ARTIFACT_DIR: String = "res://artifacts/project_choir_wp1"
const REPORT_PATH: String = ARTIFACT_DIR + "/report.json"
const MAX_FRAMES: int = 180

var _checks: Array[Dictionary] = []
var _elapsed_frames: int = 0
var _completed: bool = false


func _initialize() -> void:
	process_frame.connect(_on_process_frame)
	call_deferred("_run")


func _on_process_frame() -> void:
	if _completed:
		return
	_elapsed_frames += 1
	if _elapsed_frames > MAX_FRAMES:
		_check("frame_watchdog", false, "frames=%d" % _elapsed_frames)
		_finish()


func _run() -> void:
	var target_size: Vector2i = (
		Vector2i(720, 1280)
		if OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1"
		else Vector2i(1280, 720)
	)
	root.get_window().content_scale_size = target_size
	root.size = target_size
	var store: CampaignProgressStore = CampaignProgressStore.new()
	store.name = "VisualCampaignProgress"
	root.add_child(store)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.campaign_progress = store
	root.add_child(city)
	await process_frame
	await process_frame
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	city.upgrade_assembler.session.set_presentation_blocked(true)
	var definition: DossierDefinition = DossierCatalog.definition_for_variant(
		city.building.current_variant_id()
	)
	_check("dossier_definition", definition != null, "variant=%s" % city.building.current_variant_id())
	if definition == null:
		city.queue_free()
		store.queue_free()
		await process_frame
		_finish()
		return
	for row: int in range(StructuralBuilding2D.ROWS):
		for column: int in range(StructuralBuilding2D.COLUMNS):
			var target_cell: Destructible2D = city.building.get_cell(column, row)
			target_cell.receive_damage(DamageEvent.new(
				91_001 + row * StructuralBuilding2D.COLUMNS + column,
				city.robot,
				99_999.0
			))
	await process_frame
	await process_frame
	var black_lab_event: StringName = &"opening_black_lab_reveal"
	var observed_events: PackedStringArray = []
	for _advance: int in range(4):
		observed_events.append(String(
			city.gameplay_hud.transmission_toast.active_event_id()
		))
		if city.gameplay_hud.transmission_toast.active_event_id() == black_lab_event:
			break
		city.gameplay_hud.transmission_toast._process(6.0)
	city.robot.set_physics_process(false)
	city.robot.velocity = Vector2.ZERO
	city.robot.global_position.x = city.building.global_position.x - 200.0
	city.camera_rig.set_physics_process(false)
	city.camera_rig.global_position.x = city.building.global_position.x
	city.camera_rig.reset_after_origin_shift()
	await process_frame
	await process_frame
	_check(
		"dossier_collected",
		store.has_dossier(definition.dossier_id),
		String(definition.dossier_id)
	)
	_check(
		"black_lab_revealed",
		city.project_choir_runtime.facade_reveal.visible_count() == 1,
		"visible=%d" % city.project_choir_runtime.facade_reveal.visible_count()
	)
	_check(
		"transmission_nonblocking",
		not paused
		and city.gameplay_hud.transmission_toast.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"paused=%s" % paused
	)
	_check(
		"black_lab_transmission",
		city.gameplay_hud.transmission_toast.active_event_id() == black_lab_event,
		JSON.stringify(observed_events)
	)
	var shot_path: String = ""
	if DisplayServer.get_name() != "headless":
		shot_path = ARTIFACT_DIR + (
			"/black-lab-reveal-portrait.png"
			if target_size.y > target_size.x
			else "/black-lab-reveal-landscape.png"
		)
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
		var error: Error = image.save_png(ProjectSettings.globalize_path(shot_path))
		_check("shot_saved", error == OK, "error=%s size=%s" % [error, image.get_size()])
		_check("shot_geometry", image.get_size() == target_size, "size=%s" % image.get_size())
	_stop_audio(city)
	city.queue_free()
	store.queue_free()
	await process_frame
	await process_frame
	_finish(shot_path)


func _check(check_id: String, passed: bool, detail: String) -> void:
	_checks.append({"id": check_id, "passed": passed, "detail": detail})


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		var player: AudioStreamPlayer = node as AudioStreamPlayer
		player.stop()
		player.stream = null
	elif node is AudioStreamPlayer2D:
		var player_2d: AudioStreamPlayer2D = node as AudioStreamPlayer2D
		player_2d.stop()
		player_2d.stream = null
	for child: Node in node.get_children():
		_stop_audio(child)


func _finish(shot_path: String = "") -> void:
	if _completed:
		return
	_completed = true
	var passed: bool = true
	for check: Dictionary in _checks:
		if not bool(check.passed):
			passed = false
	var report: Dictionary = {
		"done": true,
		"result": "PASS" if passed else "FAIL",
		"orientation": "portrait" if root.size.y > root.size.x else "landscape",
		"shot": shot_path,
		"checks": _checks,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	var file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("PROJECT_CHOIR_VISUAL=%s" % JSON.stringify(report))
	quit(0 if passed else 1)
