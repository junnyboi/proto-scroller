extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")

var city: CitySlice
var session: CommandBossSession
var slice: BossVerticalSliceController


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	session = city.urban_siege.boss_session
	slice = session.utility_pool.vertical_slice


func test_business_and_residential_each_cover_all_64_facade_masks() -> void:
	var adapter: BossStructuralAdapter = session.utility_pool.arena_adapter
	for boss_id: StringName in [
		&"SETTLEMENT_ENGINE_S04", &"SAMARITAN_15",
	]:
		var definition: BossEncounterDefinition = BossCampaignCatalog.definition(boss_id)
		var rows: int = 0
		for mask: int in range(BossStructuralAdapter.MASK_COUNT):
			var binding: Dictionary = adapter.binding_for_mask(
				mask, definition.arena_cell_indices
			)
			assert_true(bool(binding.lower_passage), "%s mask=%d" % [boss_id, mask])
			assert_true(bool(binding.visible_weak_point), "%s mask=%d" % [boss_id, mask])
			assert_true(bool(binding.direct_damage_route), "%s mask=%d" % [boss_id, mask])
			assert_true(bool(binding.valid_finisher_receiver), "%s mask=%d" % [boss_id, mask])
			rows += 1
		assert_eq(rows, 64)


func test_business_phases_all_five_attacks_and_bounds_one_time_support() -> void:
	_start(&"SETTLEMENT_ENGINE_S04")
	assert_eq(slice.active_attack_choices(), [&"SETTLEMENT_SWEEP", &"DOUBLE_ENTRY_BARRAGE"])
	var support: Array[EnemyActor2D] = slice.deploy_business_support()
	assert_eq(support.size(), 2)
	assert_eq(slice.deploy_business_support().size(), 0)
	assert_eq(city.encounter_runtime.active_family_count(&"infantry"), 2)
	assert_eq(city.encounter_runtime.active_family_count(&"siege"), 0)
	assert_eq(city.encounter_runtime.active_family_count(&"light"), 0)
	slice.set_combat_state(CommandBossSession.STATE_EXPOSED, 0.8)
	assert_eq(slice.active_attack_choices(), [&"FORECLOSURE_STAMP", &"AUDIT_BEAM"])
	slice.set_combat_state(CommandBossSession.STATE_EXPOSED, 0.2)
	assert_eq(slice.active_attack_choices(), [&"AUDIT_BEAM", &"FOUNDATION_CASCADE"])


func test_business_boss_has_complete_damage_and_visible_finisher_path() -> void:
	_start(&"SETTLEMENT_ENGINE_S04")
	var attack_id: int = 91_000
	while session.boss.boss_armor > 0.0:
		assert_true(session.boss.receive_damage(_charged_event(attack_id)))
		attack_id += 1
	assert_eq(session.state, CommandBossSession.STATE_EXPOSED)
	assert_true(session.boss.receive_damage(_charged_event(attack_id)))
	attack_id += 1
	var receiver: BossWreckReceiver2D = session.utility_pool.default_wreck_receiver
	assert_eq(session.state, CommandBossSession.STATE_WRECK)
	assert_true(receiver.active)
	assert_true(receiver.visible)
	assert_eq(receiver.display_label, L10n.t("boss.receiver.finish_label"))
	assert_true(receiver.receive_damage(_smash_event(attack_id)))
	assert_eq(session.state, CommandBossSession.STATE_COMPLETE)


func test_residential_has_four_attacks_dry_lane_cradle_and_glass_separation() -> void:
	_start(&"SAMARITAN_15")
	assert_eq(slice.active_attack_choices(), [&"TRIAGE_SWEEP", &"PRESSURE_SENTENCE"])
	assert_true(slice.central_cradle_preserved)
	assert_true(slice.mechanical_targets_clear_of_glass())
	slice.set_combat_state(CommandBossSession.STATE_EXPOSED, 0.2)
	assert_eq(
		slice.active_attack_choices(),
		[&"BLACKOUT_HARVEST", &"PRESSURE_SENTENCE", &"EXTRACTION_CLAMP"]
	)
	for _cycle: int in range(4):
		while slice.active_attack != &"BLACKOUT_HARVEST":
			slice.advance(
				BossVerticalSliceController.TELEGRAPH_SECONDS
				+ BossVerticalSliceController.ACTIVE_SECONDS
				+ BossVerticalSliceController.RECOVERY_SECONDS
			)
		assert_true(slice.dry_lane_exists())
		slice.advance(
			BossVerticalSliceController.TELEGRAPH_SECONDS
			+ BossVerticalSliceController.ACTIVE_SECONDS
			+ BossVerticalSliceController.RECOVERY_SECONDS
		)


func test_direct_clear_target_is_45_to_75_seconds_for_both_bosses() -> void:
	for boss_id: StringName in [
		&"SETTLEMENT_ENGINE_S04", &"SAMARITAN_15",
	]:
		_start(boss_id)
		assert_between(slice.direct_clear_seconds, 45.0, 75.0)
		session.stop()


func test_residential_support_caps_reuses_runner_and_never_overlaps_extraction() -> void:
	_start(&"SAMARITAN_15")
	var breacher: EnemyActor2D = slice.deploy_breacher()
	assert_not_null(breacher)
	assert_null(slice.deploy_breacher())
	assert_false(slice.begin_extraction(0))
	city.encounter_runtime.release(breacher)
	assert_true(slice.begin_extraction(0))
	assert_null(slice.deploy_next_runner())
	assert_true(slice.interrupt_extraction())
	var runner_one: EnemyActor2D = slice.deploy_next_runner()
	assert_not_null(runner_one)
	assert_null(slice.deploy_next_runner())
	assert_false(slice.begin_extraction(1))
	slice.release_active_runner()
	var runner_two: EnemyActor2D = slice.deploy_next_runner()
	assert_not_null(runner_two)
	assert_eq(runner_two, runner_one)
	slice.release_active_runner()
	assert_null(slice.deploy_next_runner())
	assert_eq(slice.runners_deployed, 2)


func test_snapshot_restore_preserves_counters_and_restores_one_support_actor() -> void:
	_start(&"SAMARITAN_15")
	for _connection: int in range(2):
		assert_true(slice.register_armor_connection())
	assert_true(slice.begin_extraction(1))
	slice.advance(0.6)
	assert_true(slice.interrupt_extraction())
	assert_true(slice.begin_extraction(2))
	slice.advance(BossVerticalSliceController.EXTRACTION_SECONDS)
	var runner: EnemyActor2D = slice.deploy_next_runner()
	assert_not_null(runner)
	var snapshot: Dictionary = session.capture_attempt_state()
	var before: Dictionary = snapshot.vertical_slice
	var baseline_total: int = city.encounter_runtime.total_count()
	session.restore_attempt_state(snapshot)
	assert_true(session.start_definition(BossCampaignCatalog.definition(&"SAMARITAN_15")))
	var restored: Dictionary = slice.capture_state()
	for key: String in [
		"attack_index", "attack_stage", "active_attack", "armor_connections",
		"runners_deployed", "rescue_tally", "pod_loss_count", "pod_states",
	]:
		assert_eq(restored[key], before[key], key)
	assert_eq(city.encounter_runtime.active_family_count(&"light"), 1)
	assert_eq(city.encounter_runtime.total_count(), baseline_total)
	assert_eq(session.utility_pool.post_warm_creation_count, 0)


func test_portrait_and_landscape_have_identical_vertical_slice_mechanics() -> void:
	for boss_id: StringName in [
		&"SETTLEMENT_ENGINE_S04", &"SAMARITAN_15",
	]:
		_start(boss_id)
		var landscape: Dictionary = slice.mechanical_signature()
		var definition: BossEncounterDefinition = session.active_definition
		var token: int = session.utility_pool.begin_generation()
		assert_true(slice.start(definition, token, session.boss.global_position, true))
		var portrait: Dictionary = slice.mechanical_signature()
		assert_eq(portrait, landscape)
		session.stop()


func test_optional_pod_loss_never_changes_central_cradle_or_direct_route() -> void:
	_start(&"SAMARITAN_15")
	assert_true(slice.begin_extraction(0))
	assert_true(slice.lose_targeted_pod())
	assert_eq(slice.pod_loss_count, 1)
	assert_eq(slice.rescue_tally, 3)
	assert_true(slice.central_cradle_preserved)
	assert_true(session.active_definition.direct_damage_route)
	assert_true(slice.mechanical_targets_clear_of_glass())


func test_25_restart_loops_add_no_nodes_actors_or_post_warm_allocations() -> void:
	var baseline_nodes: int = RuntimeBudget.snapshot(city).node_count
	var baseline_actors: int = city.encounter_runtime.total_count()
	for index: int in range(25):
		_start(
			&"SETTLEMENT_ENGINE_S04" if index % 2 == 0 else &"SAMARITAN_15"
		)
		session.stop()
	assert_eq(RuntimeBudget.snapshot(city).node_count, baseline_nodes)
	assert_eq(city.encounter_runtime.total_count(), baseline_actors)
	assert_eq(session.utility_pool.post_warm_creation_count, 0)
	assert_eq(city.encounter_runtime.post_warm_creation_count, 0)


func _start(boss_id: StringName) -> void:
	assert_true(session.start_definition(BossCampaignCatalog.definition(boss_id)))
	assert_true(slice.active())


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
		attack_id + 1_000_000
	)
