extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const EXPECTED_TRIGGERS: Array[int] = [4, 9, 14, 19, 24]


func test_authored_gates_trigger_once_before_each_district_transition() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	for trigger: int in EXPECTED_TRIGGERS:
		var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(trigger)
		await _prepare_gate_window(city, definition)
		var transition_count: int = city.world_stream.transition_count
		city.robot.global_position.x = _threshold_x(city, definition) + 1.0
		campaign.advance()
		var gate: BossGateMarker = campaign.gate_for_trigger(trigger)
		assert_eq(gate.trigger_count, 1)
		assert_true(gate.owned)
		assert_eq(city.world_stream.current_logical_chunk, trigger)
		assert_eq(city.world_stream.transition_count, transition_count)
		campaign.advance()
		assert_eq(gate.trigger_count, 1)
		campaign.stop()
		campaign._triggered_ids[definition.boss_id] = true
		campaign._completed_ids[definition.boss_id] = true


func test_gate_lease_uses_six_existing_chunks_and_one_landmark() -> void:
	var city: CitySlice = await _spawn_city()
	var baseline_ids: PackedInt64Array = PackedInt64Array()
	for building: StructuralBuilding2D in city.streamed_destructibles.buildings:
		baseline_ids.append(building.get_instance_id())
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(4)
	await _trigger(city, definition)
	assert_true(campaign.arena_lease.active)
	assert_eq(campaign.arena_lease.resident_count(), CityWorldStream.CHUNK_CAPACITY)
	assert_eq(city.world_stream.active_chunk_count(), CityWorldStream.CHUNK_CAPACITY)
	assert_eq(city.streamed_destructibles.active_building_count(), CityWorldStream.CHUNK_CAPACITY)
	assert_eq(campaign.arena_lease.landmark_instance_count(), 1)
	assert_eq(city.world_stream.post_warm_creation_count, 0)
	assert_eq(city.streamed_destructibles.post_warm_creation_count, 0)
	for index: int in range(baseline_ids.size()):
		assert_eq(city.streamed_destructibles.buildings[index].get_instance_id(), baseline_ids[index])


func test_origin_rebase_keeps_gate_and_arena_anchors_aligned() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(4)
	await _trigger(city, definition)
	var gate_before: Vector2 = campaign.active_gate.cached_world_anchor
	var anchor_before: Vector2 = campaign.arena_lease.cached_building_anchors[0]
	var offset: Vector2 = Vector2(-CityWorldStream.CHUNK_WIDTH * 32.0, 0.0)
	city.world_stream.origin_shift_requested.emit(offset, 32)
	assert_eq(campaign.active_gate.cached_world_anchor, gate_before + offset)
	assert_eq(campaign.arena_lease.cached_building_anchors[0], anchor_before + offset)


func test_interlock_freezes_siege_and_leaves_robot_controls_live() -> void:
	var city: CitySlice = await _spawn_city()
	var siege: UrbanSiegeRuntime = city.urban_siege
	var director: DistrictResponseDirector = siege.director
	director.stop()
	city.encounter_runtime.release_all()
	director.start()
	director.advance(0.01)
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(4)
	await _trigger(city, definition)
	var frozen_elapsed: float = director.elapsed
	var frozen_phase: int = director.phase_index
	var frozen_beat: int = director.beat_index
	for _step: int in range(20):
		director.advance(0.25)
	assert_almost_eq(director.elapsed, frozen_elapsed, 0.0001)
	assert_eq(director.phase_index, frozen_phase)
	assert_eq(director.beat_index, frozen_beat)
	assert_eq(director.pending_count(), 0)
	assert_eq(director.hazard_pending_count(), 0)
	assert_eq(director.ledger.pending_count(), 0)
	assert_eq(siege.hazards.active_count(), 0)
	assert_eq(siege.catalysts.active_count(), 0)
	assert_false(siege.directives.is_active())
	assert_eq(siege.trait_runtime.command_source, siege.boss_session.boss)
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		if enemy != siege.boss_session.boss:
			assert_almost_eq(enemy.external_attack_interval_multiplier, 1.0, 0.0001)
	assert_true(city.robot.can_request_attack())
	assert_false(siege.is_simulation_paused())


func test_success_resumes_next_unconsumed_beat_after_one_recovery() -> void:
	var city: CitySlice = await _spawn_city()
	var siege: UrbanSiegeRuntime = city.urban_siege
	var director: DistrictResponseDirector = siege.director
	director.stop()
	city.encounter_runtime.release_all()
	director.start()
	director.advance(0.01)
	var captured_beat: int = director.beat_index
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(4)
	await _trigger(city, definition)
	var boss: TankEnemy = siege.boss_session.boss
	for attack_id: int in range(81_001, 81_004):
		assert_true(boss.receive_damage(_full_charge(city, attack_id, 999.0)))
	assert_true(boss.receive_damage(DamageEvent.new(
		81_004, city.robot, definition.health, &"impact"
	)))
	assert_not_null(siege.boss_session.boss_wreck)
	siege.boss_session.boss_wreck.receive_damage(
		DamageEvent.new(81_005, city.robot, 999.0, &"ground_smash")
	)
	assert_eq(director.state, DistrictResponseDirector.STATE_RECOVERY)
	assert_eq(director.beat_index, captured_beat)
	director.advance(BossSiegeInterlock.RECOVERY_SECONDS - 0.01)
	assert_eq(director.state, DistrictResponseDirector.STATE_RECOVERY)
	director.advance(0.02)
	assert_eq(director.state, DistrictResponseDirector.STATE_WAITING)
	director.advance(0.01)
	assert_eq(director.beat_index, captured_beat + 1)
	assert_false(director.is_suspended_for_boss())


func test_stop_and_reset_clear_campaign_and_siege_suspension() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(4)
	await _trigger(city, definition)
	campaign.stop()
	assert_false(campaign.owns_combat())
	assert_false(campaign.interlock.is_owned())
	assert_false(city.urban_siege.director.is_suspended_for_boss())
	assert_false(city.world_stream.resident_lease_active())
	await _trigger(city, definition)
	campaign.reset_run()
	assert_false(campaign.owns_combat())
	assert_false(city.urban_siege.director.is_suspended_for_boss())
	assert_eq(campaign.gate_for_trigger(4).trigger_count, 0)


func test_campaign_hud_uses_localized_name_phase_durability_and_evidence() -> void:
	var city: CitySlice = await _spawn_city()
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(4)
	await _trigger(city, definition)
	var text: String = city.gameplay_hud.boss_label.text
	assert_true(city.gameplay_hud.boss_label.visible)
	assert_true(text.contains(L10n.t(definition.display_name_key)))
	assert_true(text.contains(L10n.t("boss.state.screen")))
	assert_true(text.contains("100%"))
	assert_eq(text.count("100%"), 2)
	assert_true(text.contains(L10n.t("boss.evidence.ledger")))


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.urban_siege.run_active = true
	return city


func _prepare_gate_window(city: CitySlice, definition: BossEncounterDefinition) -> void:
	city.world_stream.end_resident_lease(city.urban_siege.boss_campaign.arena_lease)
	city.robot.global_position.x = city.world_stream.runtime_x_for_logical_index(
		definition.trigger_chunk
	) + 100.0
	city.world_stream.reset_stream(city.world_stream.run_seed)
	await get_tree().process_frame
	city.urban_siege.pause_coordinator.release_all()


func _trigger(city: CitySlice, definition: BossEncounterDefinition) -> void:
	await _prepare_gate_window(city, definition)
	city.robot.global_position.x = _threshold_x(city, definition) + 1.0
	city.urban_siege.boss_campaign.advance()


func _threshold_x(city: CitySlice, definition: BossEncounterDefinition) -> float:
	return (
		(float(definition.trigger_chunk) + BossCampaignDirector.GATE_APPROACH_FRACTION)
		* CityWorldStream.CHUNK_WIDTH
		- float(city.world_stream.floating_origin.origin_chunk) * CityWorldStream.CHUNK_WIDTH
	)


func _full_charge(city: CitySlice, attack_id: int, amount: float) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		city.robot,
		amount,
		&"jab_cross",
		Vector2.ZERO,
		Vector2.RIGHT,
		0.0,
		0,
		0,
		DamageEvent.FLAG_FULL_CHARGE
	)
