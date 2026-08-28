extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const WEAPON_IDS: Array[StringName] = [
	&"MACHINE_GUN",
	&"MISSILE",
	&"LASER",
	&"FLAMETHROWER",
]


func test_live_selection_arms_every_weapon_against_procedural_targets() -> void:
	var city: CitySlice = await _spawn_isolated_city()
	assert_false(city.gameplay_hud.weapon_status_strip.visible)
	var assembler: PlayerUpgradeAssembler = city.upgrade_assembler
	var session: UpgradeSession = assembler.session
	var machine: MachineGunRuntime = assembler.runtimes[&"MACHINE_GUN"] as MachineGunRuntime
	var missiles: MissileWeapon = assembler.runtimes[&"MISSILE"] as MissileWeapon
	var laser: PlayerLaserWeapon = assembler.runtimes[&"LASER"] as PlayerLaserWeapon
	var flame: FlamethrowerRuntime = (
		assembler.runtimes[&"FLAMETHROWER"] as FlamethrowerRuntime
	)
	for runtime: UpgradeRuntime in [machine, missiles, laser, flame]:
		runtime.set_process(false)
	var level: int = 2
	var event_id: int = 9100
	for upgrade_id: StringName in WEAPON_IDS:
		var previous_rank: int = session.rank_of(upgrade_id)
		var selection: Dictionary = await _select_through_overlay(
			city,
			upgrade_id,
			level,
			event_id
		)
		level = int(selection.level)
		event_id = int(selection.event_id)
		assert_eq(session.rank_of(upgrade_id), previous_rank + 1)
		assert_eq(
			int(city.gameplay_hud.weapon_status_strip.ranks[upgrade_id]),
			session.rank_of(upgrade_id)
		)
		assert_false(city.gameplay_hud.upgrade_choice_overlay.visible)
		assert_false(city.urban_siege.pause_coordinator.is_paused())
	var arsenal: PlayerArsenalRuntime = (
		assembler.get_node(^"PlayerArsenalRuntime") as PlayerArsenalRuntime
	)
	assert_eq(arsenal.actors.size(), city.encounter_runtime.total_count())
	assert_eq(arsenal.actors.size(), RuntimeBudget.snapshot(city).enemy_total)

	var close_ground: EnemyActor2D = _durable_target(
		city,
		&"bulwark",
		city.robot.global_position + Vector2(120.0, 0.0)
	)
	await get_tree().physics_frame
	machine.advance(MachineGunRuntime.SCAN_INTERVAL)
	assert_same(machine.target, close_ground)
	assert_eq(machine.shots_fired, 1)
	city.projectile_root.release_partition(&"player_bullet")
	city.encounter_runtime.release(close_ground)

	var missile_target: EnemyActor2D = _durable_target(
		city,
		&"jackal",
		city.robot.global_position + Vector2(MissileWeapon.IDEAL_RANGE, 0.0)
	)
	await get_tree().physics_frame
	missiles.advance(0.0)
	assert_true(missiles.ordered_targets().has(missile_target))
	assert_gt(missiles.salvos_started, 0)
	assert_gt(missiles.missiles_launched, 0)
	missiles.pool.release_all()
	city.encounter_runtime.release(missile_target)

	var ground_only: EnemyActor2D = _durable_target(
		city,
		&"bulwark",
		city.robot.global_position + Vector2(360.0, 0.0)
	)
	await get_tree().physics_frame
	laser.advance(0.0)
	assert_eq(laser.shots_fired, 0)
	city.encounter_runtime.release(ground_only)
	var air_target: EnemyActor2D = _durable_target(
		city,
		&"needle",
		city.robot.global_position + Vector2(420.0, -180.0)
	)
	var air_health_before: float = air_target.current_health
	await get_tree().physics_frame
	laser.advance(0.0)
	assert_eq(laser.shots_fired, 1)
	assert_lt(air_target.current_health, air_health_before)
	city.encounter_runtime.release(air_target)

	var flame_target: EnemyActor2D = _durable_target(
		city,
		&"bulwark",
		flame.emitter.global_position + Vector2(160.0, 0.0)
	)
	var flame_health_before: float = flame_target.current_health
	await get_tree().physics_frame
	flame.advance(0.0)
	assert_true(flame.burst_active)
	assert_eq(flame.bursts_started, 1)
	assert_eq(flame.ticks_delivered, 1)
	assert_lt(flame_target.current_health, flame_health_before)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func _select_through_overlay(
	city: CitySlice,
	desired_id: StringName,
	level: int,
	event_id: int
) -> Dictionary:
	var session: UpgradeSession = city.upgrade_assembler.session
	var overlay: UpgradeChoiceOverlay = city.gameplay_hud.upgrade_choice_overlay
	for _attempt: int in range(40):
		assert_true(session.queue_level(level, event_id))
		level += 1
		event_id += 1
		await get_tree().process_frame
		await get_tree().process_frame
		assert_not_null(session.active_offer)
		assert_true(overlay.visible)
		var selected_id: StringName = desired_id
		if not session.active_offer.choice_ids.has(desired_id):
			selected_id = _fallback_choice(session.active_offer.choice_ids)
		var selected_card: UpgradeChoiceCard = _card_for(overlay, selected_id)
		assert_not_null(selected_card)
		if selected_card == null:
			break
		assert_false(selected_card.disabled)
		selected_card.pressed.emit()
		await get_tree().process_frame
		if selected_id == desired_id:
			return {"level": level, "event_id": event_id}
	fail_test("Upgrade %s did not appear in 40 deterministic offers" % desired_id)
	return {"level": level, "event_id": event_id}


func _fallback_choice(choice_ids: PackedStringArray) -> StringName:
	for choice_id: StringName in choice_ids:
		if not WEAPON_IDS.has(choice_id):
			return choice_id
	return choice_ids[0]


func _card_for(
	overlay: UpgradeChoiceOverlay,
	upgrade_id: StringName
) -> UpgradeChoiceCard:
	for card: UpgradeChoiceCard in overlay.cards:
		if card.upgrade_id == upgrade_id:
			return card
	return null


func _spawn_isolated_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.urban_siege.stop_run()
	city.encounter_runtime.release_all()
	city.encounter_runtime.set_process(false)
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		enemy.set_physics_process(false)
	return city


func _durable_target(
	city: CitySlice,
	kind: StringName,
	position: Vector2
) -> EnemyActor2D:
	var enemy: EnemyActor2D = city.encounter_runtime.acquire(kind, position)
	assert_not_null(enemy)
	if enemy != null:
		enemy.set_physics_process(false)
		enemy.max_health = 1000000.0
		enemy.current_health = enemy.max_health
	return enemy
