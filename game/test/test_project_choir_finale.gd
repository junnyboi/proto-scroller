extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const SAVE_PATH: String = "user://project_choir_finale_test.json"

var city: CitySlice
var store: CampaignProgressStore
var session: CommandBossSession
var royal: BossRoyalFinaleController


func before_each() -> void:
	_remove_saves()
	store = CampaignProgressStore.new()
	store.setup(SAVE_PATH)
	city = CITY_SCENE.instantiate() as CitySlice
	city.campaign_progress = store
	add_child_autofree(store)
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	session = city.urban_siege.boss_session
	royal = session.royal_finale


func after_each() -> void:
	_remove_saves()


func test_choir_prime_uses_five_pylons_three_connections_and_commits_crown_first() -> void:
	_start_royal()
	assert_eq(session.active_definition.armor, 330.0)
	assert_eq(session.active_definition.armor_fixed_step, 110.0)
	assert_eq(_visible_pylon_count(), 5)
	assert_true(royal.all_pylons_distinct())
	assert_eq(royal.live_support_count(), 0)
	assert_false(royal.player_motion_history_recorded())
	for index: int in range(BossRoyalFinaleController.CONNECTION_COUNT):
		assert_true(session.boss.receive_damage(_charged_event(10_000 + index)))
		assert_eq(royal.armor_connections, index + 1)
	assert_eq(_visible_pylon_count(), 0)
	assert_eq(session.state, CommandBossSession.STATE_EXPOSED)
	assert_true(store.has_transaction(ProjectChoirRuntime.CROWN_PYLON_TRANSACTION_ID))
	assert_true(store.has_dossier(&"CROWN_05_CONSENT_EXCISION_ORDER"))
	assert_true(store.has_evidence(&"CROWN"))
	assert_false(store.echo7_resolved())


func test_all_masks_keep_palace_routes_and_direct_core_fallback() -> void:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(&"CHOIR_PRIME")
	var adapter: BossStructuralAdapter = BossStructuralAdapter.new()
	add_child_autofree(adapter)
	adapter.definition = definition
	for mask: int in range(BossStructuralAdapter.MASK_COUNT):
		var binding: Dictionary = adapter.binding_for_mask(mask, definition.arena_cell_indices)
		assert_true(bool(binding.palace_lower_route), "lower mask=%d" % mask)
		assert_true(bool(binding.palace_upper_crownfall), "upper mask=%d" % mask)
		assert_true(bool(binding.direct_core_fallback), "core mask=%d" % mask)
		assert_true(bool(binding.valid_finisher_receiver), "finisher mask=%d" % mask)


func test_five_testimonies_serialize_one_mechanic_and_noncolliding_echo() -> void:
	_start_royal()
	var seen: Dictionary[StringName, bool] = {}
	for phase: Dictionary in [
		{"state": CommandBossSession.STATE_BARRAGE, "health": 1.0},
		{"state": CommandBossSession.STATE_EXPOSED, "health": 0.8},
		{"state": CommandBossSession.STATE_EXPOSED, "health": 0.2},
	]:
		royal.set_combat_state(StringName(phase.state), float(phase.health))
		for _index: int in range(2):
			seen[royal.active_mechanic] = true
			assert_eq(royal.active_mechanic_count(), 1)
			assert_eq(royal.active_composition_echo_count(), 1)
			assert_between(royal.composition_marker_count(), 1, BossUtilityPool.MARKER_CAPACITY)
			assert_eq(royal.echo_collision_count(), 0)
			assert_between(
				royal.live_support_count(),
				0,
				BossRoyalFinaleController.ROYAL_REINFORCEMENT_CAP
			)
			for reinforcement_id: StringName in royal.reinforcement_ids():
				assert_has(BossRoyalFinaleController.ROYAL_REINFORCEMENTS, reinforcement_id)
			assert_false(royal.player_motion_history_recorded())
			royal.advance(BossRoyalFinaleController.TELEGRAPH_SECONDS)
			royal.advance(BossRoyalFinaleController.ACTIVE_SECONDS)
			royal.advance(BossRoyalFinaleController.RECOVERY_SECONDS)
	assert_eq(seen.size(), BossRoyalFinaleController.PYLON_COUNT)
	for mechanic_id: StringName in BossRoyalFinaleController.MECHANICS:
		assert_true(seen.has(mechanic_id), mechanic_id)


func test_ineligible_royal_wreck_automatically_commits_purge_after_spectacle() -> void:
	_start_royal()
	_break_armor(20_000)
	_kill_body(20_100)
	var snapshot: FinaleEligibilitySnapshot = royal.finale_snapshot
	assert_not_null(snapshot)
	assert_false(snapshot.disentangle_eligible)
	assert_lt(snapshot.dossier_count, FinaleEligibilitySnapshot.DOSSIER_REQUIREMENT)
	var purge: BossWreckReceiver2D = session.utility_pool.default_wreck_receiver
	var disentangle: BossWreckReceiver2D = session.utility_pool.royal_outcome_receiver
	assert_false(purge.active)
	assert_false(disentangle.active)
	assert_false(disentangle.receive_damage(_smash_event(20_200)))
	session.utility_pool.defeat_spectacle.advance(
		BossDefeatSpectacle2D.PRESENTATION_SECONDS
	)
	assert_eq(session.state, CommandBossSession.STATE_COMPLETE)
	assert_eq(
		int(session.completion_payload().finale_outcome),
		BossOutcome.PURGE
	)


func test_eligible_royal_wreck_automatically_commits_disentangle_after_spectacle() -> void:
	_prepare_pre_crown_eligible_store()
	_start_royal()
	_break_armor(30_000)
	_kill_body(30_100)
	assert_true(royal.finale_snapshot.disentangle_eligible)
	assert_eq(royal.finale_snapshot.dossier_count, 20)
	assert_false(session.utility_pool.royal_outcome_receiver.active)
	session.utility_pool.defeat_spectacle.advance(
		BossDefeatSpectacle2D.PRESENTATION_SECONDS
	)
	assert_eq(session.state, CommandBossSession.STATE_COMPLETE)
	assert_false(royal.severance_active)
	assert_eq(
		royal.severance_completed,
		BossRoyalFinaleController.SEVERANCE_WINDOW_COUNT
	)
	assert_eq(int(session.completion_payload().finale_outcome), BossOutcome.DISENTANGLE)
	assert_eq(
		int(session.completion_payload().severance_windows_completed),
		BossRoyalFinaleController.SEVERANCE_WINDOW_COUNT
	)


func test_automatic_purge_succeeds_for_ineligible_evidence_state() -> void:
	_start_royal()
	_break_armor(40_000)
	_kill_body(40_100)
	var purge: BossWreckReceiver2D = session.utility_pool.default_wreck_receiver
	var disentangle: BossWreckReceiver2D = session.utility_pool.royal_outcome_receiver
	assert_false(purge.active)
	assert_false(disentangle.active)
	session.utility_pool.defeat_spectacle.advance(
		BossDefeatSpectacle2D.PRESENTATION_SECONDS
	)
	assert_eq(session.state, CommandBossSession.STATE_COMPLETE)
	assert_eq(int(session.completion_payload().finale_outcome), BossOutcome.PURGE)
	assert_false(disentangle.receive_damage(_smash_event(40_201)))
	city.urban_siege.finale_snapshot = store.finale_snapshot()
	city.urban_siege.finale_pending = true
	assert_eq(city.urban_siege.resolve_finale(BossOutcome.PURGE), BossOutcome.PURGE)
	assert_true(store.has_ending(&"PURGE"))


func test_mid_attempt_retry_restores_pylons_attack_and_single_grammar() -> void:
	_start_royal()
	for index: int in range(2):
		assert_true(session.boss.receive_damage(_charged_event(45_000 + index)))
	royal.advance(BossRoyalFinaleController.TELEGRAPH_SECONDS)
	var expected_mechanic: StringName = royal.active_mechanic
	var snapshot: Dictionary = session.capture_attempt_state()
	session.restore_attempt_state(snapshot)
	assert_true(session.start_definition(BossCampaignCatalog.definition(&"CHOIR_PRIME")))
	assert_eq(royal.armor_connections, 2)
	assert_eq(royal.remaining_pylon_count(), 1)
	assert_almost_eq(session.boss.boss_armor, 110.0, 0.001)
	assert_eq(royal.active_mechanic, expected_mechanic)
	assert_eq(royal.active_mechanic_count(), 1)
	assert_eq(royal.active_composition_echo_count(), 1)
	assert_eq(royal.live_support_count(), 0)


func test_choir_prime_crown_canon_and_royal_support_stop_before_wreck() -> void:
	_start_royal()
	assert_eq(session.utility_pool.rig.scale, Vector2.ONE * 1.5)
	assert_almost_eq(
		session.boss.global_position.y,
		BossRig2D.road_contact_y_for_preset(&"CHOIR_PRIME"),
		0.001
	)
	var planned: Dictionary = royal.projectile_signature()
	assert_eq(planned.kind, &"rocket")
	assert_eq(planned.visual_key, ProjectileVisualCatalog.ENEMY_ROCKET_DIRECT)
	assert_eq(planned.planned, 2)
	assert_almost_eq(planned.presentation_scale, 1.5, 0.001)
	var warning: Dictionary = city.telegraph_presenter.snapshot(planned.telegraph_id)
	assert_eq(warning.origin, session.utility_pool.rig.attack_telegraph_origin())
	assert_eq(warning.kind, &"rocket")
	assert_eq(warning.presentation_variant, BossProjectileVolley.TELEGRAPH_PRESENTATION_VARIANT)
	assert_eq((warning.style_data.origins as Array).size(), 2)
	assert_eq((warning.style_data.targets as Array).size(), 2)
	assert_eq((warning.style_data.projectile_origins as Array).size(), 2)
	for warning_origin: Vector2 in warning.style_data.origins as Array:
		assert_eq(warning_origin, warning.origin)
	assert_eq(city.projectile_root.reservation_count(&"rocket"), 2)
	royal.advance(BossRoyalFinaleController.TELEGRAPH_SECONDS)
	assert_eq(city.projectile_root.active_count(&"rocket"), 1)
	royal.advance(0.23)
	assert_eq(city.projectile_root.active_count(&"rocket"), 2)
	for projectile: Projectile2D in city.projectile_root._active_order:
		if projectile.damage_type == &"rocket":
			assert_eq(projectile.source, session.boss)
			assert_almost_eq(projectile.presentation_scale, 1.5, 0.001)
	royal.set_combat_state(CommandBossSession.STATE_BARRAGE, 1.0)
	for _index: int in range(BossRoyalFinaleController.ROYAL_REINFORCEMENT_CAP):
		royal.advance(BossRoyalFinaleController.ROYAL_REINFORCEMENT_SECONDS)
	assert_eq(
		royal.reinforcement_ids(),
		BossRoyalFinaleController.ROYAL_REINFORCEMENTS.slice(
			0, BossRoyalFinaleController.ROYAL_REINFORCEMENT_CAP
		)
	)
	royal.set_combat_state(CommandBossSession.STATE_EXPOSED, 0.0)
	assert_eq(royal.live_support_count(), 0)
	assert_eq(city.projectile_root.active_count(&"rocket"), 0)
	royal.advance(BossRoyalFinaleController.ROYAL_REINFORCEMENT_SECONDS * 2.0)
	assert_eq(royal.live_support_count(), 0)


func test_finale_snapshot_and_ending_are_immutable_idempotent_transactions() -> void:
	_prepare_pre_crown_eligible_store()
	_start_royal()
	_break_armor(50_000)
	_kill_body(50_100)
	var before: Dictionary = royal.finale_snapshot.as_dictionary()
	store.increment_continuity()
	var persisted: FinaleEligibilitySnapshot = store.finale_snapshot()
	assert_eq(persisted.as_dictionary(), before)
	var payload: Dictionary = royal.completion_payload(BossOutcome.PURGE)
	assert_true(city.project_choir_runtime.commit_finale_ending(BossOutcome.PURGE, payload))
	assert_true(city.project_choir_runtime.commit_finale_ending(BossOutcome.PURGE, payload))
	var reloaded: CampaignProgressStore = CampaignProgressStore.new()
	reloaded.setup(SAVE_PATH)
	add_child_autofree(reloaded)
	assert_eq(reloaded.finale_snapshot().as_dictionary(), before)
	assert_true(reloaded.has_ending(&"PURGE"))
	assert_true(reloaded.has_transaction(&"finale:CHOIR_PRIME:PURGE"))
	assert_eq(reloaded.pending_reward_grants().count("boss:CHOIR_PRIME:ending_reward"), 1)
	assert_eq(
		String(reloaded.snapshot().finale_crown_transaction_id),
		String(ProjectChoirRuntime.CROWN_PYLON_TRANSACTION_ID)
	)


func test_finale_choice_overlay_warns_but_keeps_purge_visible() -> void:
	var snapshot: FinaleEligibilitySnapshot = FinaleEligibilitySnapshot.from_store(store)
	city.gameplay_hud._show_finale_choice(snapshot)
	assert_true(city.gameplay_hud.game_over_overlay.visible)
	assert_true(city.gameplay_hud.purge_button.visible)
	assert_true(city.gameplay_hud.disentangle_button.visible)
	assert_false(city.gameplay_hud.retry_button.visible)
	assert_false(city.gameplay_hud.extract_button.visible)
	assert_true(city.gameplay_hud.purge_button.has_focus())


func test_royal_arc_and_streamed_choir_prime_must_both_complete() -> void:
	var siege: UrbanSiegeRuntime = city.urban_siege
	var finale: BossEncounterDefinition = BossCampaignCatalog.definition(&"CHOIR_PRIME")
	watch_signals(siege)
	siege._on_arc_completed()
	assert_signal_not_emitted(siege, "district_completed")
	siege._on_campaign_boss_completed(finale)
	assert_signal_emitted(siege, "district_completed")
	assert_true(siege.finale_pending)


func _start_royal() -> void:
	assert_true(session.start_definition(BossCampaignCatalog.definition(&"CHOIR_PRIME")))
	assert_true(royal.active())


func _break_armor(base_attack_id: int) -> void:
	for index: int in range(BossRoyalFinaleController.CONNECTION_COUNT):
		assert_true(session.boss.receive_damage(_charged_event(base_attack_id + index)))


func _kill_body(attack_id: int) -> void:
	assert_true(session.boss.receive_damage(DamageEvent.new(
		attack_id,
		city.robot,
		session.active_definition.health,
		&"impact",
		session.boss.global_position,
		Vector2.RIGHT
	)))
	assert_not_null(session.boss_wreck)
	assert_eq(session.state, CommandBossSession.STATE_WRECK)


func _prepare_pre_crown_eligible_store() -> void:
	var collected: int = 0
	for definition: DossierDefinition in DossierCatalog.definitions():
		if definition.dossier_id == &"CROWN_05_CONSENT_EXCISION_ORDER":
			continue
		assert_true(store.collect_dossier(definition.dossier_id))
		collected += 1
		if collected == FinaleEligibilitySnapshot.DOSSIER_REQUIREMENT - 1:
			break
	for evidence_id: StringName in [&"LEDGER", &"NURSERY", &"STAGE", &"ARSENAL"]:
		assert_true(store.preserve_evidence(evidence_id))


func _charged_event(attack_id: int) -> DamageEvent:
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


func _smash_event(attack_id: int) -> DamageEvent:
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


func _visible_pylon_count() -> int:
	var count: int = 0
	for pylon: Node2D in session.utility_pool.pylon_presentations:
		if pylon.visible:
			count += 1
	return count


func _attack_cycle_seconds() -> float:
	return (
		BossRoyalFinaleController.TELEGRAPH_SECONDS
		+ BossRoyalFinaleController.ACTIVE_SECONDS
		+ BossRoyalFinaleController.RECOVERY_SECONDS
	)


func _remove_saves() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
