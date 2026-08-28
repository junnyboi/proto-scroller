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


func test_business_uses_one_core_charge_shockwave_and_capped_recurring_soldiers() -> void:
	_start(&"SETTLEMENT_ENGINE_S04")
	assert_almost_eq(
		session.boss.global_position.y,
		BossRig2D.SETTLEMENT_ROAD_CONTACT_Y,
		0.001
	)
	assert_eq(session.utility_pool.rig.scale, Vector2.ONE * 1.5)
	assert_eq(slice.active_attack_choices(), [
		BossVerticalSliceController.BUSINESS_CORE_SHOCKWAVE_ATTACK,
	])
	var shockwave: BossAttackArea2D = session.utility_pool.radial_shockwave
	assert_not_null(shockwave)
	assert_eq(shockwave.presentation_role, BossAttackArea2D.PresentationRole.RADIAL_SHOCKWAVE)
	assert_eq(
		shockwave.attack_id,
		BossVerticalSliceController.BUSINESS_CORE_SHOCKWAVE_ATTACK
	)
	assert_eq(shockwave.visual_state, BossAttackArea2D.VisualState.TELEGRAPH)
	assert_false(shockwave.uses_procedural_rendering())
	assert_almost_eq(
		shockwave.global_position.distance_to(
			session.utility_pool.rig.socket(&"CORE").global_position
		),
		0.0,
		0.001
	)
	var initial_charge: Dictionary = shockwave.shockwave_snapshot()
	assert_eq(initial_charge.mode, &"CORE_CHARGE_RELEASE")
	assert_eq(initial_charge.render_parent, &"BossAttackPresentationRoot")
	assert_true(bool(initial_charge.visible_in_tree))
	assert_gt(
		session.utility_pool.attack_presentation_root.z_index,
		session.utility_pool.rig.z_index
	)
	assert_eq(int(initial_charge.front_count), 1)
	assert_eq(int(initial_charge.trail_count), BossAttackArea2D.SHOCKWAVE_TRAIL_COUNT)
	assert_eq(int(initial_charge.trail_visible_count), 0)
	assert_almost_eq(
		float(initial_charge.trail_spacing_seconds),
		BossAttackArea2D.SHOCKWAVE_TRAIL_SPACING_SECONDS,
		0.001
	)
	assert_eq(
		String(initial_charge.core_texture),
		"res://art/player/vfx/photon_core_orb.png"
	)
	assert_eq(
		String(initial_charge.authored_texture),
		"res://art/player/vfx/photon_release_shockwave.png"
	)
	assert_eq(
		String(initial_charge.charge_sfx),
		"res://audio/sfx/boss/s04_core_charge.ogg"
	)
	assert_eq(
		String(initial_charge.release_sfx),
		"res://audio/sfx/boss/s04_shockwave_release.ogg"
	)
	assert_almost_eq(
		BossVerticalSliceController.BUSINESS_SHOCKWAVE_TELEGRAPH_SECONDS,
		1.45,
		0.001
	)
	assert_almost_eq(BossAttackArea2D.CORE_CHARGE_SFX.get_length(), 1.45, 0.02)
	assert_almost_eq(BossAttackArea2D.SHOCKWAVE_RELEASE_SFX.get_length(), 1.0, 0.02)
	assert_eq(shockwave._charge_sfx_player.bus, GameAudioBus.SFX)
	assert_eq(shockwave._release_sfx_player.bus, GameAudioBus.SFX)
	assert_eq(int(initial_charge.charge_sfx_play_count), 1)
	assert_eq(int(initial_charge.release_sfx_play_count), 0)
	assert_true(bool(initial_charge.charge_sfx_playing))
	assert_eq(
		int(initial_charge.charge_particle_capacity),
		BossAttackArea2D.CHARGE_PARTICLE_CAPACITY
	)
	assert_true(bool(initial_charge.charge_particles_emitting))
	assert_true(bool(initial_charge.core_visible))
	shockwave._process(BossVerticalSliceController.BUSINESS_SHOCKWAVE_TELEGRAPH_SECONDS * 0.55)
	var charged: Dictionary = shockwave.shockwave_snapshot()
	assert_between(float(charged.charge_progress), 0.54, 0.56)
	assert_gt(float(charged.core_diameter), 140.0)
	assert_true(bool(charged.charge_particles_emitting))
	var health_before: float = city.robot.current_health
	city.camera_rig.reset_presentation()
	assert_eq(session.core_shockwave_camera_impulse_count, 0)
	slice.advance(BossVerticalSliceController.BUSINESS_SHOCKWAVE_TELEGRAPH_SECONDS)
	assert_eq(shockwave.visual_state, BossAttackArea2D.VisualState.ARMED)
	assert_false(shockwave.try_damage_body(city.robot))
	var released_charge: Dictionary = shockwave.shockwave_snapshot()
	assert_false(bool(released_charge.charge_particles_emitting))
	assert_false(bool(released_charge.core_visible))
	assert_false(bool(released_charge.charge_sfx_playing))
	assert_true(bool(released_charge.release_sfx_playing))
	assert_eq(int(released_charge.charge_sfx_play_count), 1)
	assert_eq(int(released_charge.release_sfx_play_count), 1)
	assert_eq(session.core_shockwave_camera_impulse_count, 1)
	assert_eq(
		city.camera_rig.impact_velocity,
		Vector2(0.0, -CommandBossSession.CORE_SHOCKWAVE_CAMERA_IMPULSE * 42.0)
	)
	shockwave._process(0.42)
	var released: Dictionary = shockwave.shockwave_snapshot()
	assert_almost_eq(
		float(released.visible_band_thickness),
		shockwave.shockwave_band_thickness,
		0.001
	)
	assert_eq(int(released.trail_visible_count), BossAttackArea2D.SHOCKWAVE_TRAIL_COUNT)
	for trail_index: int in range(shockwave._release_trail.size()):
		var trail: Sprite2D = shockwave._release_trail[trail_index]
		assert_true(trail.visible)
		assert_lt(trail.scale.x, shockwave._release_shockwave.scale.x)
		if trail_index > 0:
			assert_lt(trail.scale.x, shockwave._release_trail[trail_index - 1].scale.x)
	var released_radii: PackedFloat32Array = released.radii
	var front_radius: float = float(released_radii[0])
	assert_gt(front_radius, 300.0)
	var vertical_offset: float = city.robot.global_position.y - shockwave.global_position.y
	var horizontal_offset: float = sqrt(maxf(
		front_radius * front_radius - vertical_offset * vertical_offset,
		0.0
	))
	city.robot.global_position.x = shockwave.global_position.x + horizontal_offset
	assert_true(city.robot._start_dodge())
	assert_false(shockwave.try_damage_body(city.robot))
	assert_almost_eq(city.robot.current_health, health_before, 0.001)
	city.robot.physics_step(0.0, city.robot.dodge_invulnerability_seconds + 0.01)
	city.robot.global_position.x = shockwave.global_position.x + horizontal_offset
	assert_true(shockwave.try_damage_body(city.robot))
	assert_almost_eq(
		city.robot.current_health,
		health_before - (
			BossVerticalSliceController.BUSINESS_SHOCKWAVE_DAMAGE
			* EnemyActor2D.ENEMY_DAMAGE_MULTIPLIER
			* BossEncounterDefinition.OUTGOING_DAMAGE_MULTIPLIER
		),
		0.001
	)
	assert_false(shockwave.try_damage_body(city.robot))
	assert_eq(session.core_shockwave_camera_impulse_count, 1)
	slice.advance(BossVerticalSliceController.BUSINESS_SHOCKWAVE_ACTIVE_SECONDS)
	slice.advance(BossVerticalSliceController.RECOVERY_SECONDS)
	assert_eq(slice.active_attack, BossVerticalSliceController.BUSINESS_CORE_SHOCKWAVE_ATTACK)
	assert_eq(shockwave.visual_state, BossAttackArea2D.VisualState.TELEGRAPH)
	var first_wave: Array[EnemyActor2D] = slice.deploy_business_support()
	var second_wave: Array[EnemyActor2D] = slice.deploy_business_support()
	assert_eq(first_wave.size(), BossVerticalSliceController.BUSINESS_SUPPORT_BATCH)
	assert_eq(second_wave.size(), 0)
	assert_eq(slice.deploy_business_support().size(), 0)
	for support: EnemyActor2D in first_wave + second_wave:
		assert_true(support is SoldierEnemy)
	assert_eq(
		city.encounter_runtime.active_count(&"soldier"),
		BossVerticalSliceController.BUSINESS_SUPPORT_CAP
	)
	city.encounter_runtime.release(first_wave[0])
	var replacement_wave: Array[EnemyActor2D] = slice.deploy_business_support()
	assert_eq(replacement_wave.size(), 1)
	assert_eq(slice.business_support_count(), BossVerticalSliceController.BUSINESS_SUPPORT_CAP)
	assert_eq(city.encounter_runtime.active_family_count(&"siege"), 0)
	assert_eq(city.encounter_runtime.active_family_count(&"light"), 0)
	slice.set_combat_state(CommandBossSession.STATE_EXPOSED, 0.8)
	assert_eq(slice.active_attack_choices(), [
		BossVerticalSliceController.BUSINESS_CORE_SHOCKWAVE_ATTACK,
	])
	slice.set_combat_state(CommandBossSession.STATE_EXPOSED, 0.2)
	assert_eq(slice.active_attack_choices(), [
		BossVerticalSliceController.BUSINESS_CORE_SHOCKWAVE_ATTACK,
	])


func test_business_boss_auto_commits_rubble_after_defeat_spectacle() -> void:
	_start(&"SETTLEMENT_ENGINE_S04")
	var attack_id: int = 91_000
	for damage_type: StringName in [
		&"jab_cross", &"ground_smash", &"bullet", &"shell", &"rocket", &"impact",
	]:
		var armor_before: float = session.boss.boss_armor
		assert_true(session.boss.receive_damage(DamageEvent.new(
			attack_id, city.robot, 10.0, damage_type
		)))
		assert_almost_eq(session.boss.boss_armor, armor_before - 10.0, 0.001)
		attack_id += 1
	assert_true(session.boss.receive_damage(DamageEvent.new(
		attack_id, city.robot, session.boss.boss_armor, &"bullet"
	)))
	attack_id += 1
	assert_eq(session.state, CommandBossSession.STATE_EXPOSED)
	assert_true(session.boss.receive_damage(_charged_event(attack_id)))
	attack_id += 1
	var receiver: BossWreckReceiver2D = session.utility_pool.default_wreck_receiver
	assert_eq(session.state, CommandBossSession.STATE_WRECK)
	assert_false(receiver.active)
	assert_false(receiver.visible)
	assert_false(receiver.receive_damage(_smash_event(attack_id)))
	session.utility_pool.defeat_spectacle.advance(
		BossDefeatSpectacle2D.PRESENTATION_SECONDS
	)
	assert_eq(session.state, CommandBossSession.STATE_COMPLETE)
	assert_eq(session.automatic_rubble_commit_count, 1)


func test_residential_has_four_attacks_dry_lane_cradle_and_glass_separation() -> void:
	_start(&"SAMARITAN_15")
	assert_eq(session.utility_pool.rig.scale, Vector2.ONE * 1.5)
	assert_almost_eq(
		session.boss.global_position.y,
		BossRig2D.road_contact_y_for_preset(&"SAMARITAN"),
		0.001
	)
	var projectile: Dictionary = slice.projectile_signature()
	assert_eq(projectile.kind, &"shell")
	assert_eq(projectile.visual_key, BossVerticalSliceController.RESIDENTIAL_PROJECTILE_VISUAL)
	assert_almost_eq(projectile.presentation_scale, 1.5, 0.001)
	assert_eq(projectile.planned, 1)
	assert_gt(projectile.telegraph_id, 0)
	var warning: Dictionary = city.telegraph_presenter.snapshot(projectile.telegraph_id)
	assert_eq(warning.origin, session.utility_pool.rig.attack_telegraph_origin())
	assert_eq(warning.presentation_variant, BossProjectileVolley.TELEGRAPH_PRESENTATION_VARIANT)
	assert_eq((warning.style_data.origins as Array).size(), 1)
	assert_eq((warning.style_data.origins as Array)[0], warning.origin)
	var projectile_origin: Vector2 = (warning.style_data.projectile_origins as Array)[0]
	assert_eq(slice.active_attack_choices(), [&"TRIAGE_SWEEP", &"PRESSURE_SENTENCE"])
	assert_true(slice.central_cradle_preserved)
	assert_true(slice.mechanical_targets_clear_of_glass())
	slice.advance(BossVerticalSliceController.TELEGRAPH_SECONDS)
	var fired: Projectile2D = city.projectile_root.last_acquired
	assert_not_null(fired)
	assert_eq(fired.source, session.boss)
	assert_eq(fired.damage_type, &"shell")
	assert_eq(fired.global_position, projectile_origin)
	assert_almost_eq(fired.presentation_scale, 1.5, 0.001)
	assert_almost_eq(
		fired.damage,
		BossVerticalSliceController.RESIDENTIAL_PROJECTILE_DAMAGE
			* session.boss.cycle_attack_multiplier
			* EnemyActor2D.ENEMY_DAMAGE_MULTIPLIER
			* BossEncounterDefinition.OUTGOING_DAMAGE_MULTIPLIER,
		0.001
	)
	for area: BossAttackArea2D in (
		session.utility_pool.lane_damage_areas + session.utility_pool.line_areas
	):
		assert_false(area.monitoring)
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


func test_residential_continuously_rotates_bounded_district_support_until_body_death() -> void:
	_start(&"SAMARITAN_15")
	slice.set_combat_state(CommandBossSession.STATE_BARRAGE, 1.0)
	for _index: int in range(BossVerticalSliceController.RESIDENTIAL_REINFORCEMENT_CAP):
		slice.advance(BossVerticalSliceController.RESIDENTIAL_REINFORCEMENT_SECONDS)
	assert_eq(
		slice.residential_support_count(),
		BossVerticalSliceController.RESIDENTIAL_REINFORCEMENT_CAP
	)
	assert_eq(
		slice.residential_support_ids(),
		BossVerticalSliceController.RESIDENTIAL_REINFORCEMENTS
	)
	var replaced: EnemyActor2D = slice._residential_support_actors[0]
	assert_true(replaced.receive_damage(_smash_event(55_000)))
	await get_tree().process_frame
	slice.advance(BossVerticalSliceController.RESIDENTIAL_REINFORCEMENT_SECONDS)
	assert_eq(
		slice.residential_support_count(),
		BossVerticalSliceController.RESIDENTIAL_REINFORCEMENT_CAP
	)
	slice.set_combat_state(CommandBossSession.STATE_EXPOSED, 0.0)
	assert_eq(slice.residential_support_count(), 0)
	slice.advance(BossVerticalSliceController.RESIDENTIAL_REINFORCEMENT_SECONDS * 2.0)
	assert_eq(slice.residential_support_count(), 0)


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
