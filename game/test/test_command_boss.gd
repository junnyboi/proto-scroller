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


func test_wreck_requires_ground_smash_and_completes_in_target_window() -> void:
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
	assert_false(session.boss_wreck.receive_damage(DamageEvent.new(
		1102, city.robot, 999.0, &"jab_cross"
	)))
	assert_true(session.boss_wreck.receive_damage(DamageEvent.new(
		1103, city.robot, 999.0, &"ground_smash"
	)))
	assert_eq(session.state, CommandBossSession.STATE_COMPLETE)
	assert_between(session.elapsed_seconds, 45.0, 75.0)
	assert_eq(city.enemy_remains_factory.total_count(), RuntimeBudget.WRECKS)


func test_district_signal_waits_until_boss_wreck_finisher() -> void:
	watch_signals(city.urban_siege)
	city.urban_siege._on_arc_completed()
	assert_signal_not_emitted(city.urban_siege, "district_completed")
	var boss: TankEnemy = session.boss
	boss.receive_damage(DamageEvent.new(
		1200, city.robot, CommandBossSession.ARMOR, &"jab_cross"
	))
	boss.receive_damage(DamageEvent.new(
		1201, city.robot, CommandBossSession.HEALTH, &"impact"
	))
	assert_signal_not_emitted(city.urban_siege, "district_completed")
	session.boss_wreck.receive_damage(DamageEvent.new(
		1202, city.robot, 999.0, &"ground_smash"
	))
	assert_signal_emitted(city.urban_siege, "district_completed")
