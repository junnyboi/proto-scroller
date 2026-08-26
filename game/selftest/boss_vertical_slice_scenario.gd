extends SceneTree

const ARTIFACT_DIR: String = "res://artifacts/boss_vertical_slice"
const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")

var _checks: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var portrait: bool = OS.get_environment("PROTO_SCROLLER_PORTRAIT") == "1"
	var target_size: Vector2i = Vector2i(720, 1280) if portrait else Vector2i(1280, 720)
	root.content_scale_size = target_size
	root.size = target_size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	city.encounter_runtime.release_all()
	var session: CommandBossSession = city.urban_siege.boss_session
	var business: Dictionary = await _present_business(session, portrait)
	var residential: Dictionary = await _present_residential(session, portrait)
	var orientation: String = "portrait" if portrait else "landscape"
	var report: Dictionary = {
		"done": true,
		"result": "PASS" if _all_passed() else "FAIL",
		"orientation": orientation,
		"business": business,
		"residential": residential,
		"checks": _checks,
	}
	var report_path: String = "%s/report-%s.json" % [ARTIFACT_DIR, orientation]
	var file: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path(report_path),
		FileAccess.WRITE
	)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	quit(0 if _all_passed() else 1)


func _present_business(session: CommandBossSession, portrait: bool) -> Dictionary:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(
		&"SETTLEMENT_ENGINE_S04"
	)
	_check("business_started", session.start_definition(definition))
	var slice: BossVerticalSliceController = session.utility_pool.vertical_slice
	_check("business_five_attacks", slice.active_attack_choices().size() == 5)
	_check(
		"business_direct_target",
		slice.direct_clear_seconds >= 45.0 and slice.direct_clear_seconds <= 75.0
	)
	_check("business_support_cap", slice.deploy_business_support().size() == 2)
	for _connection: int in range(2):
		slice.register_armor_connection()
	await process_frame
	var shot: String = await _capture("business", portrait)
	var result: Dictionary = {
		"boss_id": String(definition.boss_id),
		"attacks": slice.active_attack_choices(),
		"armor_connections": slice.armor_connections,
		"archive_preserved": slice.archive_preserved,
		"signature": slice.mechanical_signature(),
		"shot": shot,
	}
	session.stop()
	await process_frame
	return result


func _present_residential(session: CommandBossSession, portrait: bool) -> Dictionary:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(&"SAMARITAN_15")
	_check("residential_started", session.start_definition(definition))
	var slice: BossVerticalSliceController = session.utility_pool.vertical_slice
	for _connection: int in range(3):
		slice.register_armor_connection()
	while slice.active_attack != &"BLACKOUT_HARVEST":
		slice.advance(
			BossVerticalSliceController.TELEGRAPH_SECONDS
			+ BossVerticalSliceController.ACTIVE_SECONDS
			+ BossVerticalSliceController.RECOVERY_SECONDS
		)
	_check("residential_four_attacks", slice.active_attack_choices().size() == 4)
	_check("residential_dry_lane", slice.dry_lane_exists())
	_check("residential_cradle", slice.central_cradle_preserved)
	_check("residential_glass_safe", slice.mechanical_targets_clear_of_glass())
	_check("residential_extraction", slice.begin_extraction(1))
	await process_frame
	var shot: String = await _capture("residential", portrait)
	var result: Dictionary = {
		"boss_id": String(definition.boss_id),
		"attacks": slice.active_attack_choices(),
		"dry_lane_index": slice.dry_lane_index,
		"central_cradle_preserved": slice.central_cradle_preserved,
		"rescue_tally": slice.rescue_tally,
		"pod_loss_count": slice.pod_loss_count,
		"signature": slice.mechanical_signature(),
		"shot": shot,
	}
	session.stop()
	return result


func _capture(label: String, portrait: bool) -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	await process_frame
	await RenderingServer.frame_post_draw
	var orientation: String = "portrait" if portrait else "landscape"
	var path: String = "%s/%s-%s.png" % [ARTIFACT_DIR, label, orientation]
	var image: Image = root.get_texture().get_image()
	_check("%s_shot_saved" % label, image.save_png(ProjectSettings.globalize_path(path)) == OK)
	return path


func _check(name: String, passed: bool) -> void:
	_checks.append({"name": name, "passed": passed})
	print("[CHECK] %s %s" % ["PASS" if passed else "FAIL", name])


func _all_passed() -> bool:
	for check: Dictionary in _checks:
		if not bool(check.passed):
			return false
	return true
