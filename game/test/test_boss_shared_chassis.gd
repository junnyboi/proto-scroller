extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")

var city: CitySlice
var session: CommandBossSession


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	session = city.urban_siege.boss_session


func test_campaign_host_is_hidden_stationary_authority_and_rig_forwards_damage() -> void:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definitions()[0]
	assert_true(session.start_definition(definition))
	var rig: BossRig2D = session.utility_pool.rig
	var host: TankEnemy = session.boss
	assert_true(host.hidden_authority)
	assert_false(host.is_physics_processing())
	assert_false(host.visual.visible)
	assert_eq(host.collision_layer, 0)
	assert_eq(host.collision_mask, 0)
	assert_true(rig.visible)
	assert_eq(rig.host, host)
	assert_eq(rig.active_part_count, 2)
	assert_eq(rig.active_hurt_region_count, BossRig2D.HURT_REGION_CAPACITY)
	var armor_before: float = host.boss_armor
	assert_true(rig.receive_damage(_charged_event(3001, 3001)))
	assert_almost_eq(host.boss_armor, armor_before - 110.0, 0.001)
	host.velocity = Vector2(800.0, 200.0)
	await get_tree().physics_frame
	assert_eq(host.velocity, Vector2(800.0, 200.0))


func test_every_rig_preset_reuses_parts_sockets_and_hurt_regions_in_place() -> void:
	var rig: BossRig2D = session.utility_pool.rig
	var part_ids: PackedInt64Array = _node_ids(rig.parts)
	var socket_ids: PackedInt64Array = _node_ids(rig.sockets)
	var region_ids: PackedInt64Array = _node_ids(rig.hurt_regions)
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		assert_true(session.start_definition(definition), String(definition.boss_id))
		assert_eq(_node_ids(rig.parts), part_ids)
		assert_eq(_node_ids(rig.sockets), socket_ids)
		assert_eq(_node_ids(rig.hurt_regions), region_ids)
		assert_not_null(rig.socket(&"WEAK_POINT"))
		assert_not_null(rig.parts[0].texture)
		assert_eq(rig.mechanical_signature().active_hurt_regions, 3)
		session.stop()


func test_hidden_authority_restores_when_tank_pool_slot_is_reused() -> void:
	assert_true(session.start_definition(BossCampaignCatalog.definitions()[0]))
	var hidden_host: TankEnemy = session.boss
	assert_true(hidden_host.hidden_authority)
	session.stop()
	var reused: TankEnemy = city.encounter_runtime.acquire(
		&"tank",
		Vector2(900.0, 551.0)
	) as TankEnemy
	assert_eq(reused, hidden_host)
	assert_false(reused.hidden_authority)
	assert_true(reused.is_physics_processing())
	assert_true(reused.visual.visible)
	assert_false((reused.get_node(^"CollisionShape2D") as CollisionShape2D).disabled)
	assert_false((
		reused.get_node(^"Hurtbox/CollisionShape2D") as CollisionShape2D
	).disabled)


func test_portrait_changes_presentation_only_not_mechanics_or_phase_timing() -> void:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definitions()[2]
	assert_true(session.start_definition(definition))
	var rig: BossRig2D = session.utility_pool.rig
	rig.configure_orientation(false)
	var landscape_mechanics: Dictionary = rig.mechanical_signature()
	var landscape_presentation: Dictionary = rig.presentation_signature()
	rig.configure_orientation(true)
	var portrait_mechanics: Dictionary = rig.mechanical_signature()
	var portrait_presentation: Dictionary = rig.presentation_signature()
	assert_eq(portrait_mechanics, landscape_mechanics)
	assert_ne(portrait_presentation.scale, landscape_presentation.scale)
	for phase: BossPhaseDefinition in definition.phases:
		assert_eq(phase.recovery_duration, 0.75)
		assert_eq(phase.minimum_safe_gap, 192.0)


func test_all_five_bound_facades_cover_all_64_masks_with_required_routes() -> void:
	var adapter: BossStructuralAdapter = session.utility_pool.arena_adapter
	var row_count: int = 0
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		assert_true(adapter.all_masks_valid(definition.arena_cell_indices))
		for mask: int in range(BossStructuralAdapter.MASK_COUNT):
			var binding: Dictionary = adapter.binding_for_mask(
				mask,
				definition.arena_cell_indices
			)
			assert_true(binding.lower_passage, "%s mask=%d" % [definition.boss_id, mask])
			assert_true(binding.visible_weak_point, "%s mask=%d" % [definition.boss_id, mask])
			assert_true(binding.direct_damage_route, "%s mask=%d" % [definition.boss_id, mask])
			assert_true(binding.valid_finisher_receiver, "%s mask=%d" % [definition.boss_id, mask])
			if mask == BossStructuralAdapter.MASK_COUNT - 1:
				assert_true(binding.fallback_conductor)
			row_count += 1
	assert_eq(row_count, 320)


func test_phase_helpers_cleanup_support_projectiles_and_utility_reservations() -> void:
	var pool: BossUtilityPool = session.utility_pool
	var runtime: BossPhaseRuntime = pool.controller
	var phase: BossPhaseDefinition = BossPhaseDefinition.new()
	phase.phase_id = &"WP3_PHASE"
	phase.attack_choices = PackedStringArray(["test"])
	phase.telegraph_profile = &"BOSS_STANDARD"
	phase.reservation_requirements = {&"procedural_light": 1}
	var baseline_projectile_reservations: int = city.projectile_root.reservation_count()
	for loop_index: int in range(25):
		var token: int = pool.begin_generation()
		assert_true(runtime.begin_phase(phase, token))
		var support: EnemyActor2D = runtime.acquire_support(
			&"jackal",
			Vector2(900.0, 551.0)
		)
		assert_not_null(support)
		assert_gt(runtime.reserve_projectile(&"shell"), 0)
		assert_gt(runtime.reservation_count(), 0)
		pool.begin_generation()
		assert_eq(runtime.reservation_count(), 0)
		assert_eq(pool.reservation_count(), 0)
		assert_eq(city.projectile_root.reservation_count(), baseline_projectile_reservations)
		assert_false(support.active)


func test_safe_gap_validation_is_order_independent_and_exact_at_threshold() -> void:
	var intervals: Array[Vector2] = [
		Vector2(300.0, 500.0),
		Vector2(0.0, 120.0),
		Vector2(700.0, 1000.0),
	]
	assert_eq(BossPhaseRuntime.safe_gap_width(intervals, Vector2(0.0, 1000.0)), 200.0)
	assert_true(BossPhaseRuntime.has_safe_gap(intervals, Vector2(0.0, 1000.0), 200.0))
	assert_false(BossPhaseRuntime.has_safe_gap(intervals, Vector2(0.0, 1000.0), 201.0))


func test_boss_attack_area_damages_once_only_while_armed() -> void:
	assert_true(session.start_definition(BossCampaignCatalog.definitions()[0]))
	var area: BossAttackArea2D = session.utility_pool.lane_damage_areas[0]
	var health_before: float = city.robot.current_health
	area.configure_footprint(
		city.robot.global_position,
		Vector2(300.0, 120.0),
		BossAttackArea2D.VisualState.TELEGRAPH,
		&"TEST_BOSS_HAZARD"
	)
	assert_false(area.try_damage_body(city.robot))
	assert_almost_eq(city.robot.current_health, health_before, 0.001)
	area.configure_footprint(
		city.robot.global_position,
		Vector2(300.0, 120.0),
		BossAttackArea2D.VisualState.ARMED,
		&"TEST_BOSS_HAZARD"
	)
	assert_true(area.try_damage_body(city.robot))
	assert_almost_eq(
		city.robot.current_health,
		health_before - BossAttackArea2D.DEFAULT_DAMAGE,
		0.001
	)
	assert_false(area.try_damage_body(city.robot))
	area.deactivate()
	assert_false(area.try_damage_body(city.robot))


func test_campaign_hazards_do_not_advance_or_arm_during_screen() -> void:
	assert_true(session.start_definition(BossCampaignCatalog.definitions()[0]))
	var slice: BossVerticalSliceController = session.utility_pool.vertical_slice
	var initial_attack: StringName = slice.active_attack
	session.advance(session.active_definition.screen_seconds)
	assert_eq(session.state, CommandBossSession.STATE_BARRAGE)
	assert_eq(slice.active_attack, initial_attack)
	assert_eq(slice.attack_stage, &"TELEGRAPH")
	session.advance(BossVerticalSliceController.TELEGRAPH_SECONDS)
	assert_eq(slice.attack_stage, &"ACTIVE")


func test_wreck_rejects_fatal_attack_chain_and_non_smashes_then_accepts_fresh_root() -> void:
	assert_true(session.start_definition(BossCampaignCatalog.definitions()[0]))
	var host: TankEnemy = session.boss
	for index: int in range(3):
		assert_true(host.receive_damage(_charged_event(3100 + index, 3100 + index)))
	var fatal: DamageEvent = DamageEvent.new(
		3200,
		city.robot,
		session.active_definition.health,
		&"impact",
		host.global_position,
		Vector2.RIGHT,
		0.0,
		3199
	)
	assert_true(host.receive_damage(fatal))
	var wreck: EnemyWreck2D = session.boss_wreck
	assert_not_null(wreck)
	assert_true(wreck.finisher_requires_ground_smash)
	assert_false(wreck.receive_damage(DamageEvent.new(
		3200, city.robot, 999.0, &"ground_smash", Vector2.ZERO, Vector2.RIGHT, 0.0, 4000
	)))
	assert_false(wreck.receive_damage(DamageEvent.new(
		3201, city.robot, 999.0, &"ground_smash", Vector2.ZERO, Vector2.RIGHT, 0.0, 3199
	)))
	for kind: StringName in [&"jab_cross", &"bullet", &"shell", &"rocket", &"impact"]:
		assert_false(wreck.receive_damage(DamageEvent.new(
			3300 + kind.hash() % 100,
			city.robot,
			999.0,
			kind,
			Vector2.ZERO,
			Vector2.RIGHT,
			0.0,
			4300 + kind.hash() % 100
		)))
	assert_true(wreck.receive_damage(DamageEvent.new(
		3400, city.robot, 999.0, &"ground_smash", Vector2.ZERO, Vector2.RIGHT, 0.0, 4400
	)))
	assert_eq(session.state, CommandBossSession.STATE_COMPLETE)


func test_royal_receivers_are_separated_and_only_one_can_commit() -> void:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(&"CHOIR_PRIME")
	assert_true(session.start_definition(definition))
	var host: TankEnemy = session.boss
	for index: int in range(BossRoyalFinaleController.CONNECTION_COUNT):
		assert_true(host.receive_damage(_charged_event(3500 + index, 3500 + index)))
	assert_true(host.receive_damage(DamageEvent.new(
		3600, city.robot, definition.health, &"impact"
	)))
	var default_receiver: BossWreckReceiver2D = session.utility_pool.default_wreck_receiver
	var royal_receiver: BossWreckReceiver2D = session.utility_pool.royal_outcome_receiver
	assert_true(default_receiver.active)
	assert_true(royal_receiver.active)
	assert_true(default_receiver.visible)
	assert_true(royal_receiver.visible)
	assert_eq(default_receiver.display_label, L10n.t("finale.receiver.purge_label"))
	assert_eq(royal_receiver.display_label, L10n.t("finale.receiver.disentangle_label"))
	assert_gt(
		default_receiver.global_position.distance_to(royal_receiver.global_position),
		BossEncounterDefinition.DEFAULT_GROUND_SMASH_RADIUS
	)
	assert_true(default_receiver.receive_damage(DamageEvent.new(
		3601, city.robot, 999.0, &"ground_smash", Vector2.ZERO, Vector2.RIGHT, 0.0, 4601
	)))
	assert_eq(session.state, CommandBossSession.STATE_COMPLETE)
	assert_false(royal_receiver.receive_damage(DamageEvent.new(
		3602, city.robot, 999.0, &"ground_smash", Vector2.ZERO, Vector2.RIGHT, 0.0, 4602
	)))


func _charged_event(attack_id: int, root_attack_id: int) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		city.robot,
		999.0,
		&"jab_cross",
		Vector2.ZERO,
		Vector2.RIGHT,
		0.0,
		root_attack_id,
		0,
		DamageEvent.FLAG_FULL_CHARGE
	)


func _node_ids(values: Array) -> PackedInt64Array:
	var ids: PackedInt64Array = PackedInt64Array()
	for value: Variant in values:
		ids.append((value as Node).get_instance_id())
	return ids
