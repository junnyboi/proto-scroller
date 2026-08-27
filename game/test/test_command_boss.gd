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


func test_boss_reuses_one_tank_and_enters_reserved_barrage() -> void:
	var tank_total: int = city.encounter_runtime.total_count(&"tank")
	assert_true(session.start())
	assert_eq(city.encounter_runtime.total_count(&"tank"), tank_total)
	assert_eq(session.state, CommandBossSession.STATE_SCREEN)
	assert_true(session.boss.boss_mode)
	assert_eq(session.boss.trait_id, &"COMMAND")
	session.advance(CommandBossSession.SCREEN_DURATION)
	assert_eq(session.state, CommandBossSession.STATE_BARRAGE)
	session.boss._begin_shell()
	assert_true(session.boss.is_telegraphing())
	assert_eq(city.projectile_root.reservation_count(&"shell"), 1)


func test_only_jab_cross_breaks_armor_then_body_accepts_damage() -> void:
	assert_true(session.start())
	var boss: TankEnemy = session.boss
	var armor_before: float = boss.boss_armor
	assert_false(boss.receive_damage(DamageEvent.new(
		1001, city.robot, 999.0, &"ground_smash"
	)))
	assert_almost_eq(boss.boss_armor, armor_before, 0.001)
	for index: int in range(3):
		assert_true(boss.receive_damage(DamageEvent.new(
			1010 + index,
			city.robot,
			110.0,
			&"jab_cross"
		)))
	assert_eq(session.state, CommandBossSession.STATE_EXPOSED)
	assert_almost_eq(boss.boss_armor, 0.0, 0.001)
	assert_true(boss.receive_damage(DamageEvent.new(
		1020, city.robot, 80.0, &"ground_smash"
	)))
	assert_almost_eq(boss.current_health, CommandBossSession.HEALTH - 80.0, 0.001)


func test_legacy_amount_policy_still_accepts_one_oversized_jab_cross() -> void:
	assert_true(session.start())
	assert_eq(
		session.boss.boss_armor_policy,
		EnemyActor2D.ArmorPolicy.LEGACY_AMOUNT_BASED
	)
	assert_true(session.boss.receive_damage(DamageEvent.new(
		1050, city.robot, CommandBossSession.ARMOR, &"jab_cross"
	)))
	assert_eq(session.state, CommandBossSession.STATE_EXPOSED)
	assert_almost_eq(session.boss.boss_armor, 0.0, 0.001)


func test_later_campaign_policy_requires_three_distinct_full_charge_fixed_steps() -> void:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definitions()[1]
	assert_true(session.start_definition(definition))
	var boss: TankEnemy = session.boss
	assert_eq(boss.boss_armor_policy, EnemyActor2D.ArmorPolicy.FULL_CHARGE_FIXED_STEP)
	assert_false(boss.receive_damage(DamageEvent.new(
		1060, city.robot, 999.0, &"jab_cross"
	)))
	assert_almost_eq(boss.boss_armor, 330.0, 0.001)
	for index: int in range(3):
		assert_true(boss.receive_damage(DamageEvent.new(
			1061 + index,
			city.robot,
			999.0,
			&"jab_cross",
			Vector2.ZERO,
			Vector2.RIGHT,
			0.0,
			0,
			0,
			DamageEvent.FLAG_FULL_CHARGE
		)))
		assert_almost_eq(boss.boss_armor, 220.0 - 110.0 * index, 0.001)
	assert_eq(session.state, CommandBossSession.STATE_EXPOSED)
	assert_false(boss.receive_damage(DamageEvent.new(
		1063, city.robot, 40.0, &"impact"
	)))
	assert_true(boss.receive_damage(DamageEvent.new(
		1070, city.robot, 40.0, &"impact"
	)))
	assert_almost_eq(boss.current_health, definition.health - 40.0, 0.001)


func test_later_campaign_armor_rejections_provide_exact_input_feedback() -> void:
	var definition: BossEncounterDefinition = BossCampaignCatalog.definitions()[1]
	assert_true(session.start_definition(definition))
	var rig: BossRig2D = session.utility_pool.rig
	assert_false(rig.receive_damage(DamageEvent.new(
		1090, city.robot, 999.0, &"ground_smash"
	)))
	assert_eq(
		String(session.live_boss_feedback().objective),
		L10n.t("boss.feedback.keep_moving")
	)
	assert_false(rig.receive_damage(DamageEvent.new(
		1091, city.robot, 999.0, &"jab_cross"
	)))
	assert_eq(
		String(session.live_boss_feedback().objective),
		L10n.t("boss.feedback.full_charge")
	)
	assert_false(rig.receive_damage(DamageEvent.new(
		1092, city.robot, 999.0, &"bullet"
	)))
	assert_eq(
		String(session.live_boss_feedback().objective),
		L10n.t("boss.feedback.armor_locked")
	)
	assert_true(rig.receive_damage(DamageEvent.new(
		1093,
		city.robot,
		999.0,
		&"jab_cross",
		Vector2.ZERO,
		Vector2.RIGHT,
		0.0,
		1093,
		0,
		DamageEvent.FLAG_FULL_CHARGE
	)))
	assert_eq(
		String(session.live_boss_feedback().objective),
		L10n.t("boss.objective.business.connect", {"current": 1, "total": 3})
	)


func test_jab_cross_event_propagates_full_charge_flag() -> void:
	var resolver: AttackResolver = AttackResolver.new()
	add_child_autofree(resolver)
	var spec: AttackSpec = resolver.resolve_jab_cross(1080, 1, 1.0).with_damage_multiplier(2.0)
	var impact: JabCrossImpact = JabCrossImpact.new()
	add_child_autofree(impact)
	var collider: Node2D = Node2D.new()
	add_child_autofree(collider)
	var event: DamageEvent = impact._make_event(spec, city.robot, collider, session.boss)
	assert_ne(event.effect_flags & DamageEvent.FLAG_FULL_CHARGE, 0)


func test_repeated_legacy_and_campaign_start_stop_loops_do_not_grow_runtime() -> void:
	var baseline: Dictionary = RuntimeBudget.snapshot(city)
	for loop_index: int in range(25):
		assert_true(
			session.start()
			if loop_index % 2 == 0
			else session.start_definition(BossCampaignCatalog.definitions()[loop_index % 5])
		)
		session.stop()
	var after: Dictionary = RuntimeBudget.snapshot(city)
	assert_eq(after.node_count, baseline.node_count)
	assert_eq(after.enemy_total, baseline.enemy_total)
	assert_eq(after.wreck_total, baseline.wreck_total)
	assert_eq(after.boss_rigs, 1)
	assert_eq(after.boss_controllers, 1)
	assert_eq(after.boss_arena_adapters, 1)
	assert_eq(after.boss_pylon_presentations, 5)
	assert_eq(after.boss_projection_slots, 4)
	assert_eq(after.boss_post_warm_creations, 0)
	assert_eq(after.boss_reservations, 0)


func test_defeated_boss_freezes_then_next_melee_makes_rubble_and_repair_drops() -> void:
	assert_true(session.start())
	session.advance(50.0)
	var boss: TankEnemy = session.boss
	boss.receive_damage(DamageEvent.new(
		1100, city.robot, CommandBossSession.ARMOR, &"jab_cross"
	))
	boss.receive_damage(DamageEvent.new(
		1101, city.robot, CommandBossSession.HEALTH, &"impact"
	))
	assert_eq(session.state, CommandBossSession.STATE_WRECK)
	assert_not_null(session.boss_wreck)
	assert_eq(city.enemy_remains_factory.active_count(), 1)
	var defeated_pose: Dictionary = session.utility_pool.rig.animation_signature()
	assert_true(defeated_pose.defeated)
	assert_eq(defeated_pose.frame, BossAnimationCatalog.FRAME_COUNT - 1)
	assert_eq(defeated_pose.modulate, BossRig2D.DEFEATED_MODULATE)
	assert_false(session.boss_wreck.get_node(^"WreckVisual").visible)
	assert_true(session.boss_wreck.receive_damage(DamageEvent.new(
		1102, city.robot, 1.0, &"jab_cross"
	)))
	assert_eq(session.state, CommandBossSession.STATE_COMPLETE)
	assert_between(session.elapsed_seconds, 45.0, 75.0)
	assert_eq(city.enemy_remains_factory.total_count(), RuntimeBudget.WRECKS)
	assert_true(session.utility_pool.boss_rubble_record.visible)
	assert_eq(
		int(session.utility_pool.boss_rubble_record.get_meta(&"presentation_role")),
		BossUtilityPool.UtilityPresentationRole.RUBBLE_BED
	)
	assert_eq(session.last_repair_drop_count, 2)
	assert_eq(city.urban_siege.catalysts.active_repair_pickup_count(), 2)
	city.robot.current_health = city.robot.max_health - 100.0
	assert_true(city.urban_siege.catalysts.repair_pickups[0].try_collect(city.robot))
	assert_almost_eq(city.robot.current_health, city.robot.max_health - 50.0, 0.001)


func test_district_signal_waits_until_boss_wreck_finisher() -> void:
	watch_signals(city.urban_siege)
	city.urban_siege._on_arc_completed()
	assert_signal_not_emitted(city.urban_siege, "district_completed")
	assert_true(session.start_definition(BossCampaignCatalog.definition(&"CHOIR_PRIME")))
	var boss: TankEnemy = session.boss
	for index: int in range(5):
		boss.receive_damage(DamageEvent.new(
			1200 + index,
			city.robot,
			110.0,
			&"jab_cross",
			Vector2.ZERO,
			Vector2.RIGHT,
			0.0,
			0,
			0,
			DamageEvent.FLAG_FULL_CHARGE
		))
	boss.receive_damage(DamageEvent.new(
		1210, city.robot, session.active_definition.health, &"impact"
	))
	assert_signal_not_emitted(city.urban_siege, "district_completed")
	session.boss_wreck.receive_damage(DamageEvent.new(
		1211, city.robot, 999.0, &"ground_smash"
	))
	assert_signal_emitted(city.urban_siege, "district_completed")
	assert_true(city.urban_siege.finale_pending)


func test_late_boss_rubble_has_three_fixed_fifty_hp_drops() -> void:
	assert_eq(ChassisRepairPickup2D.REPAIR_AMOUNT, 50.0)
	assert_eq(
		city.urban_siege.catalysts.repair_pickup_count(),
		CatalystRuntime.REPAIR_PICKUP_CAPACITY
	)
	assert_true(session.start_definition(BossCampaignCatalog.definitions()[2]))
	assert_eq(session._boss_repair_drop_count(), 3)
	assert_eq(session._spawn_boss_repair_pickups(Vector2(1200.0, 610.0), 3), 3)
	assert_eq(city.urban_siege.catalysts.active_repair_pickup_count(), 3)
