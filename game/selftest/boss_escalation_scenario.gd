extends SceneTree

const ARTIFACT_DIR: String = "res://artifacts/boss_escalation"
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
	var entertainment: Dictionary = await _present_entertainment(session, portrait)
	var military: Dictionary = await _present_military(session, portrait)
	var orientation: String = "portrait" if portrait else "landscape"
	var report: Dictionary = {
		"done": true,
		"result": "PASS" if _all_passed() else "FAIL",
		"orientation": orientation,
		"entertainment": entertainment,
		"military": military,
		"checks": _checks,
	}
	var report_path: String = "%s/report-%s.json" % [ARTIFACT_DIR, orientation]
	var file: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path(report_path), FileAccess.WRITE
	)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	quit(0 if _all_passed() else 1)


func _present_entertainment(
	session: CommandBossSession,
	portrait: bool
) -> Dictionary:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(&"MIMESIS_04")
	_check("entertainment_started", session.start_definition(definition))
	var escalation: BossEscalationController = session.utility_pool.escalation
	var recorder: MotionEchoRecorder = session.utility_pool.motion_echo_recorder
	for index: int in range(10):
		recorder.record_motion(
			session.boss.global_position + Vector2(float(index) * 64.0 - 256.0, 0.0),
			float(index) * 0.1
		)
	_check("entertainment_four_attacks", escalation.active_attack_choices().size() == 4)
	_check("entertainment_eight_markers", recorder.count == 8)
	_check("entertainment_cyan_safe", not recorder.history_can_damage())
	_check("entertainment_arm", recorder.arm_marker(5, &"ARMED_AFTERIMAGE"))
	_check("entertainment_magenta", recorder.activate_armed_footprint())
	_check("entertainment_footprint", recorder.damage_footprint_matches_collision())
	_check("entertainment_siren", escalation.deploy_siren() != null)
	for _connection: int in range(3):
		escalation.register_armor_connection()
	_check("entertainment_record", escalation.continuity_record_played)
	_check("entertainment_direct_target", escalation.direct_clear_seconds >= 45.0 and (
		escalation.direct_clear_seconds <= 75.0
	))
	await process_frame
	var shot: String = await _capture("entertainment", portrait)
	var result: Dictionary = {
		"boss_id": String(definition.boss_id),
		"attacks": escalation.active_attack_choices(),
		"marker_count": recorder.count,
		"history_damages": recorder.history_can_damage(),
		"record": escalation.completion_payload(),
		"signature": escalation.mechanical_signature(),
		"shot": shot,
	}
	session.stop()
	await process_frame
	return result


func _present_military(session: CommandBossSession, portrait: bool) -> Dictionary:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(
		&"CANTOR_31_PALE_ENGINE"
	)
	_check("military_started", session.start_definition(definition))
	var escalation: BossEscalationController = session.utility_pool.escalation
	while escalation.active_attack != &"SUTURE_SALVO":
		escalation.advance(
			BossEscalationController.TELEGRAPH_SECONDS
			+ BossEscalationController.ACTIVE_SECONDS
			+ BossEscalationController.RECOVERY_SECONDS
		)
	_check("military_four_attacks", escalation.active_attack_choices().size() == 4)
	_check("military_safe_lane", escalation.safe_lane_exists())
	_check("military_runner", escalation.request_dispatch() != null)
	_check("military_one_aux", escalation.live_auxiliary_count() == 1)
	for index: int in range(3):
		_check(
			"military_anchor_%d" % index,
			escalation.create_freight_anchor(
				session.boss.global_position + Vector2(float(index - 1) * 280.0, 0.0)
			) == index
		)
	_check("military_anchor_cap", escalation.create_freight_anchor() == -1)
	_check("military_no_live_seraph", escalation.live_seraph_count() == 0)
	_check("military_reclamation_finite", escalation.resolve_pale_reclamation() <= 2)
	for _connection: int in range(3):
		escalation.register_armor_connection()
	_check("military_export_record", escalation.export_record_visible)
	_check("military_direct_target", escalation.direct_clear_seconds >= 45.0 and (
		escalation.direct_clear_seconds <= 75.0
	))
	await process_frame
	var shot: String = await _capture("military", portrait)
	var result: Dictionary = {
		"boss_id": String(definition.boss_id),
		"attacks": escalation.active_attack_choices(),
		"anchors": escalation.anchors_created,
		"live_auxiliaries": escalation.live_auxiliary_count(),
		"live_seraphs": escalation.live_seraph_count(),
		"record": escalation.completion_payload(),
		"signature": escalation.mechanical_signature(),
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
