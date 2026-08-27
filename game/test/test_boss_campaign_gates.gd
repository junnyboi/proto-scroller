extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const EXPECTED_TRIGGERS: Array[int] = [9, 21, 33, 45, 57]
const ARENA_WALL_LAYER: int = BossArenaBarrier2D.COLLISION_LAYER


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


func test_gate_lease_uses_six_existing_chunks_without_summoning_a_landmark() -> void:
	var city: CitySlice = await _spawn_city()
	var baseline_ids: PackedInt64Array = PackedInt64Array()
	for building: StructuralBuilding2D in city.streamed_destructibles.buildings:
		baseline_ids.append(building.get_instance_id())
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(9)
	assert_false(definition.summon_uses_arena_landmark)
	await _trigger(city, definition)
	assert_true(campaign.arena_lease.active)
	assert_eq(campaign.arena_lease.resident_count(), CityWorldStream.CHUNK_CAPACITY)
	assert_eq(city.world_stream.active_chunk_count(), CityWorldStream.CHUNK_CAPACITY)
	assert_eq(city.streamed_destructibles.active_building_count(), CityWorldStream.CHUNK_CAPACITY)
	assert_eq(campaign.arena_lease.landmark_instance_count(), 0)
	assert_null(city.urban_siege.boss_session.utility_pool.arena_adapter.building)
	var arena_building: StructuralBuilding2D = campaign.arena_lease.arena_building
	assert_true(arena_building.encounter_suppressed)
	assert_false(arena_building.visible)
	await get_tree().physics_frame
	for row: int in range(StructuralBuilding2D.ROWS):
		for column: int in range(StructuralBuilding2D.COLUMNS):
			var cell: Destructible2D = arena_building.get_cell(column, row)
			var collision: CollisionShape2D = cell.get_node_or_null(
				^"IntactBody/CollisionShape2D"
			) as CollisionShape2D
			assert_true(collision.disabled)
	assert_eq(city.world_stream.post_warm_creation_count, 0)
	assert_eq(city.streamed_destructibles.post_warm_creation_count, 0)
	for index: int in range(baseline_ids.size()):
		assert_eq(city.streamed_destructibles.buildings[index].get_instance_id(), baseline_ids[index])
	campaign.stop()
	assert_false(arena_building.encounter_suppressed)
	assert_true(arena_building.visible)


func test_origin_rebase_keeps_gate_and_arena_anchors_aligned() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(9)
	await _trigger(city, definition)
	var gate_before: Vector2 = campaign.active_gate.cached_world_anchor
	var anchor_before: Vector2 = campaign.arena_lease.cached_building_anchors[0]
	var barrier_before: Vector2 = campaign.arena_barrier.global_position
	var offset: Vector2 = Vector2(-CityWorldStream.CHUNK_WIDTH * 32.0, 0.0)
	city.world_stream.origin_shift_requested.emit(offset, 32)
	assert_eq(campaign.active_gate.cached_world_anchor, gate_before + offset)
	assert_eq(campaign.arena_lease.cached_building_anchors[0], anchor_before + offset)
	assert_eq(campaign.arena_barrier.global_position, barrier_before + offset)


func test_interlock_freezes_siege_and_leaves_robot_controls_live() -> void:
	var city: CitySlice = await _spawn_city()
	var siege: UrbanSiegeRuntime = city.urban_siege
	var campaign: BossCampaignDirector = siege.boss_campaign
	var director: DistrictResponseDirector = siege.director
	director.stop()
	city.encounter_runtime.release_all()
	director.start()
	director.advance(0.01)
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(9)
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
	assert_true(campaign.active_gate.blocker_collision.disabled)
	assert_true(city.world_stream._rear_barrier_collision.disabled)
	assert_eq(city.robot.collision_mask & CityWorldStream.REAR_BARRIER_LAYER, 0)
	assert_eq(city.robot.collision_mask & CitySlice.BUILDING_LAYER, 0)
	assert_not_null(campaign.arena_barrier)
	assert_true(campaign.arena_barrier.active)
	assert_false(campaign.arena_barrier.collision.disabled)
	assert_eq(city.robot.collision_mask & ARENA_WALL_LAYER, ARENA_WALL_LAYER)
	city.robot.set_physics_process(false)
	city.robot.collision_mask = 0
	city.robot.gravity = 0.0
	var gate_x: float = campaign.active_gate.global_position.x
	city.robot.global_position.x = gate_x - 60.0
	for _movement_step: int in range(36):
		city.robot.physics_step(1.0, 1.0 / 60.0)
	assert_gt(city.robot.global_position.x, gate_x + 60.0)


func test_active_boss_lease_allows_streaming_past_arena_and_back() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(9)
	await _trigger(city, definition)
	var boss_id: int = city.urban_siege.boss_session.boss.get_instance_id()
	var baseline_nodes: int = int(RuntimeBudget.snapshot(city).node_count)
	assert_true(campaign.arena_lease.active)
	assert_true(city.world_stream.resident_lease_active())
	city.robot.global_position.x = (
		city.world_stream.runtime_x_for_logical_index(12)
		+ CityWorldStream.CHUNK_WIDTH * 0.5
	)
	city.world_stream.advance_stream()
	assert_eq(city.world_stream.current_logical_chunk, 12)
	assert_eq(city.urban_siege.boss_session.boss.get_instance_id(), boss_id)
	city.robot.global_position.x = (
		city.world_stream.runtime_x_for_logical_index(2)
		+ CityWorldStream.CHUNK_WIDTH * 0.5
	)
	city.world_stream.advance_stream()
	assert_eq(city.world_stream.current_logical_chunk, 2)
	assert_eq(city.urban_siege.boss_session.boss.get_instance_id(), boss_id)
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), baseline_nodes)


func test_boss_arena_wall_stands_1000_pixels_right_and_drops_on_body_defeat() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(9)
	await _trigger(city, definition)
	var boss: TankEnemy = city.urban_siege.boss_session.boss
	var barrier: BossArenaBarrier2D = campaign.arena_barrier
	assert_true(barrier.active)
	assert_false(barrier.collision.disabled)
	assert_almost_eq(
		barrier.global_position.x,
		boss.global_position.x + BossArenaBarrier2D.OFFSET_FROM_BOSS_X,
		0.001
	)
	assert_eq(city.robot.collision_mask & ARENA_WALL_LAYER, ARENA_WALL_LAYER)
	assert_true(boss.receive_damage(DamageEvent.new(
		83_001, city.robot, definition.armor, &"bullet"
	)))
	assert_true(boss.receive_damage(DamageEvent.new(
		83_002, city.robot, definition.health, &"impact"
	)))
	assert_false(barrier.active)
	assert_true(barrier.collision.disabled)
	assert_eq(city.robot.collision_mask & ARENA_WALL_LAYER, 0)


func test_success_waits_for_salvage_shop_but_never_for_route_travel() -> void:
	var city: CitySlice = await _spawn_city()
	var siege: UrbanSiegeRuntime = city.urban_siege
	var director: DistrictResponseDirector = siege.director
	var campaign: BossCampaignDirector = siege.boss_campaign
	director.stop()
	city.encounter_runtime.release_all()
	director.start()
	director.advance(0.01)
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(9)
	await _trigger(city, definition)
	var boss: TankEnemy = siege.boss_session.boss
	assert_true(boss.receive_damage(DamageEvent.new(
		81_001, city.robot, definition.armor, &"bullet"
	)))
	assert_true(boss.receive_damage(DamageEvent.new(
		81_002, city.robot, definition.health, &"impact"
	)))
	assert_not_null(siege.boss_session.boss_wreck)
	siege.boss_session.boss_wreck.receive_damage(
		DamageEvent.new(81_003, city.robot, 999.0, &"ground_smash")
	)
	assert_eq(campaign.handoff_state, BossCampaignDirector.HANDOFF_SALVAGE)
	assert_true(director.is_suspended_for_boss())
	campaign._on_salvage_claimed()
	assert_true(city.weapon_shop_assembler.session.active)
	assert_true(city.weapon_shop_assembler.session.close_shop())
	assert_eq(campaign.handoff_state, BossCampaignDirector.HANDOFF_CORRIDOR)
	campaign._process(0.0)
	assert_eq(director.state, DistrictResponseDirector.STATE_WAITING)
	assert_eq(director.beat_index, -1)
	assert_eq(director.phase_index, 1)
	assert_false(director.is_suspended_for_boss())


func test_completion_write_failure_retains_gate_then_retries_idempotently() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(9)
	var gate: BossGateMarker = campaign.gate_for_trigger(definition.trigger_chunk)
	assert_true(gate.acquire(Vector2.ZERO))
	campaign.active_definition = definition
	campaign.active_gate = gate
	assert_true(city.urban_siege.boss_session.start_definition(definition))
	var store: CampaignProgressStore = city.project_choir_runtime.campaign_progress
	store.fault_injection = CampaignProgressStore.FAIL_BEFORE_WRITE
	var session: CommandBossSession = city.urban_siege.boss_session
	assert_true(session.boss.receive_damage(DamageEvent.new(
		82_001, city.robot, definition.armor, &"ground_smash"
	)))
	assert_true(session.boss.receive_damage(DamageEvent.new(
		82_002, city.robot, definition.health, &"impact"
	)))
	assert_true(session.utility_pool.default_wreck_receiver.receive_damage(
		DamageEvent.new(
			82_003,
			city.robot,
			999.0,
			&"ground_smash",
			Vector2.ZERO,
			Vector2.RIGHT,
			0.0,
			182_005
		)
	))
	assert_true(campaign.completion_pending)
	assert_true(campaign.owns_combat())
	assert_true(campaign.active_gate.owned)
	assert_eq(session.state, CommandBossSession.STATE_COMPLETION_PENDING)
	store.fault_injection = &""
	campaign._process(BossCampaignDirector.COMPLETION_RETRY_SECONDS)
	assert_false(campaign.completion_pending)
	assert_false(campaign.owns_combat())
	assert_true(store.has_evidence(&"LEDGER"))
	assert_eq(store.pending_reward_grants().count("boss:SETTLEMENT_ENGINE_S04:reward"), 1)


func test_stop_and_reset_clear_campaign_and_siege_suspension() -> void:
	var city: CitySlice = await _spawn_city()
	var campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(9)
	await _trigger(city, definition)
	campaign.stop()
	assert_false(campaign.owns_combat())
	assert_false(campaign.interlock.is_owned())
	assert_false(city.urban_siege.director.is_suspended_for_boss())
	assert_false(city.world_stream.resident_lease_active())
	assert_not_null(campaign.arena_barrier)
	assert_false(campaign.arena_barrier.active)
	assert_true(campaign.arena_barrier.collision.disabled)
	assert_eq(city.robot.collision_mask & ARENA_WALL_LAYER, 0)
	assert_false(city.world_stream._rear_barrier_collision.disabled)
	assert_ne(city.robot.collision_mask & CityWorldStream.REAR_BARRIER_LAYER, 0)
	assert_ne(city.robot.collision_mask & CitySlice.BUILDING_LAYER, 0)
	await _trigger(city, definition)
	campaign.reset_run()
	assert_false(campaign.owns_combat())
	assert_false(city.urban_siege.director.is_suspended_for_boss())
	assert_false(campaign.arena_barrier.active)
	assert_eq(campaign.gate_for_trigger(9).trigger_count, 0)


func test_campaign_hud_uses_only_localized_name_and_two_durability_bars() -> void:
	var city: CitySlice = await _spawn_city()
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(9)
	await _trigger(city, definition)
	var text: String = city.gameplay_hud.boss_label.text
	assert_true(city.gameplay_hud.boss_panel.visible)
	assert_true(city.gameplay_hud.boss_label.visible)
	assert_eq(text, L10n.t(definition.display_name_key))
	assert_false(text.contains("//"))
	assert_false(text.contains("100%"))
	assert_eq(city.gameplay_hud.boss_armor_fill.color, Color("f4c542"))
	assert_eq(city.gameplay_hud.boss_health_fill.color, Color("e3313f"))
	assert_almost_eq(
		city.gameplay_hud.boss_armor_fill.size.x,
		city.gameplay_hud.boss_armor_track.size.x,
		0.001
	)
	assert_almost_eq(
		city.gameplay_hud.boss_health_fill.size.x,
		city.gameplay_hud.boss_health_track.size.x,
		0.001
	)


func test_boss_fight_herald_uses_generated_splash_and_plays_once_per_start() -> void:
	var city: CitySlice = await _spawn_city()
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition_for_trigger(9)
	await _trigger(city, definition)
	var herald: BossFightHerald = city.gameplay_hud.boss_fight_herald
	assert_true(herald.visible)
	assert_eq(herald.presentation_count, 1)
	assert_eq(herald.audio_play_count, 1)
	assert_eq(herald.splash.texture, BossFightHerald.SPLASH)
	assert_eq(herald.voice_player.stream, BossFightHerald.VOICE)
	await get_tree().create_timer(BossFightHerald.PRESENTATION_SECONDS + 0.1).timeout
	assert_false(herald.visible)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.urban_siege.run_active = true
	return city


func _prepare_gate_window(city: CitySlice, definition: BossEncounterDefinition) -> void:
	city.world_stream.end_resident_lease(city.urban_siege.boss_campaign.arena_lease)
	city.robot.global_position.x = (
		float(definition.trigger_chunk) * CityWorldStream.CHUNK_WIDTH + 100.0
	)
	city.world_stream.reset_stream(city.world_stream.run_seed)
	await get_tree().process_frame
	city.urban_siege.pause_coordinator.release_all()
	var district: CityDistrictProfile = CityDistrictCatalog.districts()[
		CityDistrictCatalog.district_index_for_chunk(definition.trigger_chunk)
	]
	for encounter_index: int in range(
		CityDistrictCatalog.FACADE_ENCOUNTERS_PER_DISTRICT
	):
		var logical_chunk: int = district.start_chunk + encounter_index
		var variant: StructuralBuildingVariant = CityDistrictCatalog.variant_for_chunk(
			city.world_stream.run_seed,
			logical_chunk
		)
		var building: StructuralBuilding2D = StructuralBuilding2D.new()
		building.set_meta(&"district_id", district.district_id)
		building.set_meta(&"district_index", district.district_index)
		building.set_meta(&"building_variant_id", variant.variant_id)
		building.set_meta(&"logical_chunk", logical_chunk)
		city.world_stream.report_building_cleared(building)
		building.free()


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
