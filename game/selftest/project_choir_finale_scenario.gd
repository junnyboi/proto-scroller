extends SceneTree

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const ARTIFACT_DIR: String = "res://artifacts/project_choir_finale"
const SAVE_PATH: String = "user://project_choir_finale_visual.cfg"

var _failures: PackedStringArray = PackedStringArray()
var _report: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var orientation: String = _orientation()
	var viewport_size: Vector2i = (
		Vector2i(720, 1280) if orientation == "portrait" else Vector2i(1280, 720)
	)
	root.content_scale_size = viewport_size
	root.size = viewport_size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	await process_frame
	var store: CampaignProgressStore = city.project_choir_runtime.campaign_progress
	store.save_path = SAVE_PATH
	store.reset_memory()
	_prepare_eligible_store(store)
	city.gameplay_hud.transmission_toast.set_process(false)
	city.gameplay_hud.transmission_toast.visible = false
	city.encounter_runtime.release_all()
	city.robot.gravity = 0.0
	city.robot.velocity = Vector2.ZERO
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(&"CHOIR_PRIME")
	var session: CommandBossSession = city.urban_siege.boss_session
	_check("choir_prime_started", session.start_definition(definition))
	city.robot.global_position = session.boss.global_position + Vector2(-220.0, 0.0)
	city.camera_rig.global_position = session.boss.global_position + Vector2(0.0, -120.0)
	await _settle_render_frames()
	var boss_shot: String = await _capture("choir-prime-%s.png" % orientation)
	var snapshot: FinaleEligibilitySnapshot = FinaleEligibilitySnapshot.from_store(store)
	_check("severance_eligible", snapshot.disentangle_eligible)
	city.gameplay_hud._show_finale_choice(snapshot)
	await _settle_render_frames()
	var choice_shot: String = await _capture("ending-choice-%s.png" % orientation)
	var summary: RunSummarySnapshot = RunSummarySnapshot.new(
		120000,
		5,
		18,
		6,
		4,
		{},
		{
			"completed": true,
			"grade": &"S",
			"mastery_points": 999,
			"ending_id": &"DISENTANGLE",
		}
	)
	city.gameplay_hud._set_campaign_summary(
		snapshot.dossier_count,
		snapshot.continuity_generation
	)
	city.gameplay_hud.show_district_complete(summary)
	await _settle_render_frames()
	var ending_shot: String = await _capture("ending-severance-%s.png" % orientation)
	_report = {
		"done": true,
		"result": "PASS" if _failures.is_empty() else "FAIL",
		"orientation": orientation,
		"boss_id": String(definition.boss_id),
		"pylon_count": _visible_pylon_count(session),
		"eligible": snapshot.as_dictionary(),
		"boss_shot": boss_shot,
		"choice_shot": choice_shot,
		"ending_shot": ending_shot,
		"failures": Array(_failures),
	}
	_write_report(orientation)
	city.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	quit(0 if _failures.is_empty() else 1)


func _prepare_eligible_store(store: CampaignProgressStore) -> void:
	for index: int in range(FinaleEligibilitySnapshot.DOSSIER_REQUIREMENT):
		store.collect_dossier(DossierCatalog.definitions()[index].dossier_id)
	for evidence_id: StringName in [&"LEDGER", &"NURSERY", &"STAGE", &"ARSENAL"]:
		store.preserve_evidence(evidence_id)


func _settle_render_frames() -> void:
	for _frame: int in range(4):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await process_frame


func _capture(filename: String) -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	var path: String = "%s/%s" % [ARTIFACT_DIR, filename]
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	_check("capture_%s" % filename, error == OK)
	return path


func _visible_pylon_count(session: CommandBossSession) -> int:
	var count: int = 0
	for pylon: Node2D in session.utility_pool.pylon_presentations:
		if pylon.visible:
			count += 1
	return count


func _orientation() -> String:
	return "portrait" if OS.has_environment("PROTO_SCROLLER_PORTRAIT") else "landscape"


func _check(label: String, passed: bool) -> void:
	if not passed:
		_failures.append(label)


func _write_report(orientation: String) -> void:
	var path: String = "%s/report-%s.json" % [ARTIFACT_DIR, orientation]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "  "))
