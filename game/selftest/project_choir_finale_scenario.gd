extends SceneTree

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const ARTIFACT_DIR: String = "res://artifacts/project_choir_finale"
const SAVE_PATH: String = "user://project_choir_finale_visual.json"

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
	_remove_saves()
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	root.add_child(city)
	await process_frame
	await process_frame
	var store: CampaignProgressStore = city.project_choir_runtime.campaign_progress
	store.save_path = SAVE_PATH
	store.reset_memory()
	_prepare_pre_crown_eligible_store(store)
	city.gameplay_hud.transmission_toast.set_process(false)
	city.gameplay_hud.transmission_toast.visible = false
	city.encounter_runtime.release_all()
	city.robot.gravity = 0.0
	city.robot.velocity = Vector2.ZERO
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(&"CHOIR_PRIME")
	var session: CommandBossSession = city.urban_siege.boss_session
	var royal: BossRoyalFinaleController = session.royal_finale
	_check("choir_prime_started", session.start_definition(definition))
	city.robot.global_position = session.boss.global_position + Vector2(-220.0, 0.0)
	city.camera_rig.global_position = session.boss.global_position + Vector2(0.0, -120.0)
	city.gameplay_hud.set_campaign_boss_status(
		definition,
		session.state,
		session.boss.boss_armor,
		session.boss.boss_max_armor,
		session.boss.current_health,
		session.boss.max_health,
		&"CROWN",
		royal.hud_feedback()
	)
	await _settle_render_frames()
	var boss_shot: String = await _capture("choir-prime-%s.png" % orientation)
	var initial_pylon_count: int = _visible_pylon_count(session)
	_check("five_distinct_pylons", initial_pylon_count == 5 and royal.all_pylons_distinct())
	_check("no_live_support", royal.live_support_count() == 0)
	_check("no_motion_history", not royal.player_motion_history_recorded())
	for index: int in range(BossRoyalFinaleController.CONNECTION_COUNT):
		_check(
			"armor_connection_%d" % index,
			session.boss.receive_damage(_charged_event(city, 70_000 + index))
		)
	_check("three_connections", royal.armor_connections == 3)
	_check("crown_committed", store.has_transaction(
		ProjectChoirRuntime.CROWN_PYLON_TRANSACTION_ID
	))
	_check("crown_dossier", store.has_dossier(&"CROWN_05_CONSENT_EXCISION_ORDER"))
	_check("crown_evidence", store.has_evidence(&"CROWN"))
	_check("body_exposed", session.state == CommandBossSession.STATE_EXPOSED)
	_check("body_defeated", session.boss.receive_damage(DamageEvent.new(
		70_100,
		city.robot,
		definition.health,
		&"impact",
		session.boss.global_position,
		Vector2.RIGHT
	)))
	var snapshot: FinaleEligibilitySnapshot = royal.finale_snapshot
	_check("snapshot_exists", snapshot != null)
	_check("severance_eligible", snapshot != null and snapshot.disentangle_eligible)
	_check("snapshot_twenty", snapshot != null and snapshot.dossier_count == 20)
	var purge: BossWreckReceiver2D = session.utility_pool.default_wreck_receiver
	var disentangle: BossWreckReceiver2D = session.utility_pool.royal_outcome_receiver
	_check("purge_visible", purge.active)
	_check("disentangle_visible", disentangle.active)
	_check(
		"receivers_separated",
		purge.global_position.distance_to(disentangle.global_position)
		> BossEncounterDefinition.DEFAULT_GROUND_SMASH_RADIUS
	)
	_check("severance_started", disentangle.receive_damage(_smash_event(city, 70_200)))
	royal.advance(BossRoyalFinaleController.SEVERANCE_WINDOW_SECONDS * 2.2)
	_check("no_overall_timeout", royal.severance_active and royal.severance_loop_count > 0)
	for index: int in range(BossRoyalFinaleController.SEVERANCE_WINDOW_COUNT - 1):
		_check("severance_window_%d" % index, disentangle.receive_damage(
			_smash_event(city, 70_300 + index)
		))
		_check("one_mechanic_%d" % index, royal.active_mechanic_count() == 1)
		_check("one_echo_%d" % index, royal.active_composition_echo_count() == 1)
		_check("echo_noncolliding_%d" % index, royal.echo_collision_count() == 0)
	city.gameplay_hud.set_campaign_boss_status(
		definition,
		session.state,
		0.0,
		definition.armor,
		0.0,
		definition.health,
		&"CROWN",
		royal.hud_feedback()
	)
	await _settle_render_frames()
	var choice_shot: String = await _capture("ending-choice-%s.png" % orientation)
	var final_armor_connections: int = royal.armor_connections
	var final_mechanical_signature: Dictionary = royal.mechanical_signature()
	_check("final_severance", disentangle.receive_damage(_smash_event(city, 70_400)))
	_check("session_complete", session.state == CommandBossSession.STATE_COMPLETE)
	var payload: Dictionary = session.completion_payload()
	_check("disentangle_payload", int(payload.get("finale_outcome", -1)) == BossOutcome.DISENTANGLE)
	_check(
		"five_windows",
		int(payload.get("severance_windows_completed", 0))
		== BossRoyalFinaleController.SEVERANCE_WINDOW_COUNT
	)
	_check(
		"ending_transaction",
		city.project_choir_runtime.commit_finale_ending(BossOutcome.DISENTANGLE, payload)
	)
	_check(
		"ending_idempotent",
		city.project_choir_runtime.commit_finale_ending(BossOutcome.DISENTANGLE, payload)
	)
	city.gameplay_hud._show_finale_result(BossOutcome.DISENTANGLE, 1, true)
	await _settle_render_frames()
	var ending_shot: String = await _capture("ending-severance-%s.png" % orientation)
	var ending_actions_valid: bool = (
		city.gameplay_hud.game_over_overlay.visible
		and city.gameplay_hud.extract_button.visible
		and city.gameplay_hud.continue_button.visible
		and city.gameplay_hud.new_game_plus_badge.visible
		and not city.gameplay_hud.purge_button.visible
		and not city.gameplay_hud.disentangle_button.visible
		and city.gameplay_hud.continue_button.has_focus()
	)
	_check("ending_actions_valid", ending_actions_valid)
	_report = {
		"done": true,
		"result": "PASS" if _failures.is_empty() else "FAIL",
		"orientation": orientation,
		"boss_id": String(definition.boss_id),
		"pylon_count": initial_pylon_count,
		"armor_connections": final_armor_connections,
		"eligible": snapshot.as_dictionary() if snapshot != null else {},
		"mechanical_signature": final_mechanical_signature,
		"completion_payload": payload,
		"boss_shot": boss_shot,
		"choice_shot": choice_shot,
		"ending_shot": ending_shot,
		"ending_actions_valid": ending_actions_valid,
		"failures": Array(_failures),
	}
	_write_report(orientation)
	city.queue_free()
	await process_frame
	_remove_saves()
	quit(0 if _failures.is_empty() else 1)


func _prepare_pre_crown_eligible_store(store: CampaignProgressStore) -> void:
	var collected: int = 0
	for definition: DossierDefinition in DossierCatalog.definitions():
		if definition.dossier_id == &"CROWN_05_CONSENT_EXCISION_ORDER":
			continue
		store.collect_dossier(definition.dossier_id)
		collected += 1
		if collected == FinaleEligibilitySnapshot.DOSSIER_REQUIREMENT - 1:
			break
	for evidence_id: StringName in [&"LEDGER", &"NURSERY", &"STAGE", &"ARSENAL"]:
		store.preserve_evidence(evidence_id)


func _charged_event(city: CitySlice, attack_id: int) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		city.robot,
		999.0,
		&"jab_cross",
		Vector2.ZERO,
		Vector2.RIGHT,
		0.0,
		attack_id,
		0,
		DamageEvent.FLAG_FULL_CHARGE
	)


func _smash_event(city: CitySlice, attack_id: int) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		city.robot,
		999.0,
		&"ground_smash",
		Vector2.ZERO,
		Vector2.RIGHT,
		0.0,
		attack_id + 100_000
	)


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


func _remove_saves() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
