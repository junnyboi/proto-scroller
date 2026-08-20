extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const DISTRICT: DistrictDefinition = preload("res://resources/siege/district_contact.tres")
const EXPECTED_DISPLAYS: Dictionary = {
	&"traffic_signal": Vector2(360.0, 245.0),
	&"steam_main": Vector2(150.0, 133.0),
	&"powerline": Vector2(83.0, 320.0),
	&"road_plate": Vector2(280.0, 55.0),
	&"crane_drop": Vector2(185.0, 220.0),
	&"gas_fireline": Vector2(200.0, 95.0),
	&"facade_shear": Vector2(220.0, 315.0),
	&"metro_vent": Vector2(235.0, 70.0),
	&"metro_car": Vector2(540.0, 230.0),
	&"flooded_lane": Vector2(520.0, 120.0),
	&"skybridge": Vector2(610.0, 145.0),
	&"ammo_convoy": Vector2(620.0, 160.0),
}

var city: CitySlice
var runtime: HazardRuntime


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	runtime = city.urban_siege.hazards
	runtime.release_all()


func test_catalog_has_twelve_custom_vfx_and_shake_profiles() -> void:
	assert_eq(EnvironmentalHazardCatalog.IDS.size(), 12)
	assert_true(EnvironmentalHazardCatalog.mvp_profiles_valid())
	assert_true(EnvironmentalHazardCatalog.active_profiles_valid())
	assert_eq(EnvironmentalHazardCatalog.ACTIVE_IDS.size(), 12)
	assert_eq(EnvironmentalHazardCatalog.TIER2_IDS.size(), 4)
	assert_eq(EnvironmentalHazardCatalog.APEX_IDS.size(), 4)
	var display_names: Dictionary[String, bool] = {}
	var effect_signatures: Dictionary[String, bool] = {}
	var audio_streams: Dictionary[String, bool] = {}
	var audio_signatures: Dictionary[String, bool] = {}
	for hazard_id: StringName in EnvironmentalHazardCatalog.IDS:
		var profile: Dictionary = EnvironmentalHazardCatalog.profile(hazard_id)
		var audio: Dictionary = EnvironmentalHazardCatalog.audio_profile(hazard_id)
		assert_false(profile.is_empty(), hazard_id)
		assert_false(audio.is_empty(), hazard_id)
		assert_gt(int(profile.particles), 0, hazard_id)
		assert_gt(float(profile.particle_lifetime), 0.0, hazard_id)
		assert_gt((profile.shake as Vector2).length(), 0.0, hazard_id)
		assert_gt(int(profile.shake_pulses), 0, hazard_id)
		display_names[String(profile.display_name)] = true
		var signature: String = "%d/%.2f/%s/%d" % [
			profile.particles,
			profile.particle_lifetime,
			profile.shake,
			profile.shake_pulses,
		]
		effect_signatures[signature] = true
		audio_streams[String(audio.stream)] = true
		audio_signatures["%.1f/%.2f/%.1f/%.2f/%d/%d" % [
			audio.warning_gain_db,
			audio.warning_pitch,
			audio.impact_gain_db,
			audio.impact_pitch,
			audio.priority,
			audio.retrigger_ms,
		]] = true
		_assert_hazard_wav(load(String(audio.stream)) as AudioStreamWAV)
	assert_eq(display_names.size(), 12)
	assert_eq(effect_signatures.size(), 12)
	assert_eq(audio_streams.size(), 12)
	assert_eq(audio_signatures.size(), 12)
	_assert_hazard_wav(HazardAudioPool.WARNING_SFX as AudioStreamWAV)
	_assert_hazard_wav(HazardAudioPool.CHAIN_SFX as AudioStreamWAV)
	assert_eq(runtime.audio_pool.voice_count(), RuntimeBudget.HAZARD_AUDIO_VOICES)


func test_active_sprites_are_alpha_clean_and_fit_authored_pixel_bounds() -> void:
	for hazard_id: StringName in EnvironmentalHazardCatalog.ACTIVE_IDS:
		var profile: Dictionary = EnvironmentalHazardCatalog.profile(hazard_id)
		var texture: Texture2D = load(String(profile.texture)) as Texture2D
		assert_not_null(texture, hazard_id)
		var actor: EnvironmentalHazard2D = runtime.activate(
			hazard_id,
			Vector2(900.0, CitySlice.LAND_VISUAL_BASELINE_Y),
			1
		)
		assert_not_null(actor, hazard_id)
		assert_eq(profile.display as Vector2, EXPECTED_DISPLAYS[hazard_id], hazard_id)
		var rendered: Vector2 = actor.visual.texture.get_size() * actor.visual.scale
		var expected: Vector2 = EXPECTED_DISPLAYS[hazard_id] as Vector2
		assert_lte(rendered.x, expected.x + 0.01, hazard_id)
		assert_lte(rendered.y, expected.y + 0.01, hazard_id)
		assert_true(
			is_equal_approx(rendered.x, expected.x)
			or is_equal_approx(rendered.y, expected.y),
			hazard_id
		)
		runtime.release(actor)


func test_each_active_hazard_triggers_animates_and_releases_without_growth() -> void:
	var baseline_nodes: int = RuntimeBudget.snapshot(city).node_count
	for hazard_id: StringName in EnvironmentalHazardCatalog.ACTIVE_IDS:
		runtime.audio_pool.reset_all()
		var warning_count: int = runtime.audio_pool.warning_play_count
		var impact_audio_count: int = runtime.audio_pool.impact_play_count
		var actor: EnvironmentalHazard2D = runtime.activate(
			hazard_id,
			Vector2(820.0, CitySlice.LAND_VISUAL_BASELINE_Y),
			-1
		)
		assert_true(actor.receive_damage(DamageEvent.new(
			101,
			city.robot,
			80.0,
			&"ground_smash",
			actor.global_position,
			Vector2.RIGHT,
			400.0
		)), hazard_id)
		assert_eq(actor.state, EnvironmentalHazard2D.STATE_TELEGRAPH, hazard_id)
		assert_eq(runtime.audio_pool.warning_play_count, warning_count + 1, hazard_id)
		assert_eq(runtime.audio_pool.last_phase, &"warning", hazard_id)
		var before_transform: Transform2D = actor.visual.transform
		actor._process(float(actor.profile.telegraph) + 0.01)
		assert_eq(actor.state, EnvironmentalHazard2D.STATE_ACTIVE, hazard_id)
		await get_tree().process_frame
		assert_ne(actor.visual.transform, before_transform, hazard_id)
		assert_eq(actor.last_root_attack_id, 101, hazard_id)
		assert_eq(runtime.last_hazard_id, hazard_id, hazard_id)
		assert_gt(runtime.vfx_pool.play_count, 0, hazard_id)
		assert_eq(runtime.audio_pool.impact_play_count, impact_audio_count + 1, hazard_id)
		assert_eq(runtime.audio_pool.last_hazard_id, hazard_id, hazard_id)
		actor._process(float(actor.profile.active) + 0.01)
		actor._process(float(actor.profile.aftermath) + 0.01)
		assert_false(actor.active, hazard_id)
	assert_eq(runtime.total_count(), RuntimeBudget.HAZARD_ACTORS)
	assert_eq(RuntimeBudget.snapshot(city).node_count, baseline_nodes)
	assert_eq(runtime.post_warm_creation_count, 0)
	assert_gt(city.camera_rig.impact_velocity.length(), 0.0)


func test_late_pressure_budget_is_seeded_bounded_and_escalating() -> void:
	var controller: HazardPressureController = city.urban_siege.hazard_pressure
	assert_eq(DistrictRecipeValidator.validate(DISTRICT), PackedStringArray())
	var first_trace: Array[Dictionary] = _pressure_trace(controller, 441)
	var replay_trace: Array[Dictionary] = _pressure_trace(controller, 441)
	var alternate_trace: Array[Dictionary] = _pressure_trace(controller, 442)
	assert_eq(first_trace, replay_trace)
	assert_ne(first_trace, alternate_trace)
	assert_eq(DISTRICT.acts[3].hazard_pressure_budget, 2)
	assert_eq(DISTRICT.acts[4].hazard_pressure_budget, 4)
	assert_eq(DISTRICT.acts[5].hazard_pressure_budget, 10)
	assert_eq(DISTRICT.acts[3].hazard_events_per_beat, 1)
	assert_eq(DISTRICT.acts[4].hazard_events_per_beat, 2)
	assert_eq(DISTRICT.acts[5].hazard_events_per_beat, 3)
	for assignment: Dictionary in first_trace:
		var act: DistrictAct = DISTRICT.acts[int(assignment.act_index)]
		assert_lte(int(assignment.used_budget), act.hazard_pressure_budget)
		assert_lte(int(assignment.event_count), act.hazard_events_per_beat)
	assert_lte(controller.peak_used_budget, RuntimeBudget.HAZARD_PRESSURE)
	assert_has(controller._eligible_ids(3), &"metro_vent")
	assert_does_not_have(controller._eligible_ids(3), &"crane_drop")
	assert_has(controller._eligible_ids(4), &"crane_drop")
	assert_has(controller._eligible_ids(4), &"gas_fireline")
	assert_has(controller._eligible_ids(4), &"facade_shear")
	for hazard_id: StringName in EnvironmentalHazardCatalog.TIER2_IDS:
		assert_has(controller._eligible_ids(5), hazard_id)
	var scheduled_tier2: Dictionary[StringName, bool] = {}
	for assignment: Dictionary in first_trace:
		for record: Dictionary in assignment.plan:
			var hazard_id: StringName = StringName(record.hazard_id)
			if hazard_id in EnvironmentalHazardCatalog.TIER2_IDS:
				scheduled_tier2[hazard_id] = true
	assert_eq(scheduled_tier2.size(), EnvironmentalHazardCatalog.TIER2_IDS.size())
	var scheduled_apex: Dictionary[StringName, bool] = {}
	for assignment: Dictionary in first_trace:
		for record: Dictionary in assignment.plan:
			var hazard_id: StringName = StringName(record.hazard_id)
			if hazard_id in EnvironmentalHazardCatalog.APEX_IDS:
				scheduled_apex[hazard_id] = true
	assert_eq(scheduled_apex.size(), EnvironmentalHazardCatalog.APEX_IDS.size())


func test_apex_pair_propagates_one_bounded_causal_chain() -> void:
	var target: EnvironmentalHazard2D = runtime.activate(
		&"ammo_convoy",
		Vector2(1120.0, CitySlice.LAND_VISUAL_BASELINE_Y),
		1,
		false
	)
	var source: EnvironmentalHazard2D = runtime.activate(
		&"metro_car",
		Vector2(1340.0, CitySlice.LAND_VISUAL_BASELINE_Y),
		-1,
		false
	)
	assert_not_null(source)
	assert_not_null(target)
	assert_true(source.receive_damage(DamageEvent.new(
		505,
		city.robot,
		80.0,
		&"ground_smash",
		source.global_position
	)))
	source._process(float(source.profile.telegraph) + 0.01)
	assert_eq(runtime.chain_trigger_count, 1)
	assert_eq(runtime.last_chain_source, &"metro_car")
	assert_eq(runtime.last_chain_target, &"ammo_convoy")
	assert_eq(target.state, EnvironmentalHazard2D.STATE_TELEGRAPH)
	assert_eq(target.last_root_attack_id, 505)
	assert_eq(runtime.audio_pool.chain_play_count, 1)
	assert_eq(runtime.audio_pool.last_phase, &"chain")
	target._process(float(target.profile.telegraph) + 0.01)
	assert_eq(target.state, EnvironmentalHazard2D.STATE_ACTIVE)
	assert_eq(runtime.impact_count, 2)


func test_modal_pause_freezes_and_restores_hazard_processing() -> void:
	var actor: EnvironmentalHazard2D = runtime.activate(
		&"steam_main",
		Vector2(900.0, CitySlice.LAND_VISUAL_BASELINE_Y),
		1
	)
	assert_not_null(actor)
	actor.receive_damage(DamageEvent.new(404, city.robot, 80.0))
	assert_gt(runtime.audio_pool.active_voice_count(), 0)
	var token: int = city.urban_siege.pause_coordinator.acquire(&"hazard_test")
	assert_eq(runtime.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_true(runtime.audio_pool.is_paused())
	city.urban_siege.pause_coordinator.release(token)
	assert_eq(runtime.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_false(runtime.audio_pool.is_paused())


func test_hazard_damage_hits_both_sides_with_lower_player_damage() -> void:
	city.robot.current_health = city.robot.max_health
	var soldier: EnemyActor2D = city.encounter_runtime.acquire(
		&"soldier",
		city.robot.global_position
	) as EnemyActor2D
	assert_not_null(soldier)
	soldier.set_physics_process(false)
	soldier.current_health = soldier.max_health
	await get_tree().physics_frame
	var robot_health: float = city.robot.current_health
	var enemy_health: float = soldier.current_health
	var actor: EnvironmentalHazard2D = runtime.activate(
		&"steam_main",
		Vector2(city.robot.global_position.x, CitySlice.LAND_VISUAL_BASELINE_Y),
		1
	)
	assert_true(actor.receive_damage(DamageEvent.new(
		202,
		city.robot,
		80.0,
		&"ground_smash",
		actor.global_position
	)))
	actor._process(float(actor.profile.telegraph) + 0.01)
	city.destruction_director._physics_process(0.016)
	var player_loss: float = robot_health - city.robot.current_health
	var enemy_loss: float = enemy_health - soldier.current_health
	assert_gt(player_loss, 0.0)
	assert_gt(enemy_loss, player_loss)
	assert_almost_eq(
		player_loss / enemy_loss,
		float(actor.profile.player_scale),
		0.06
	)


func test_release_all_cancels_queued_hazard_damage() -> void:
	var actor: EnvironmentalHazard2D = runtime.activate(
		&"traffic_signal",
		Vector2(900.0, CitySlice.LAND_VISUAL_BASELINE_Y),
		1
	)
	actor.receive_damage(DamageEvent.new(303, city.robot, 80.0))
	actor._process(float(actor.profile.telegraph) + 0.01)
	assert_gt(city.destruction_director._queue.size(), 0)
	runtime.release_all()
	for record: Dictionary in city.destruction_director._queue:
		assert_eq(int(record.effect_flags) & DamageEvent.FLAG_HAZARD, 0)


func test_final_chaos_beat_schedules_hazards_without_spend_or_pending_overflow() -> void:
	var director: DistrictResponseDirector = city.urban_siege.director
	director.stop()
	city.urban_siege.hazard_pressure.configure(991, 1)
	director.running = true
	director.completed = false
	director.phase_index = 5
	director.beat_index = 2
	director.state = DistrictResponseDirector.STATE_WAITING
	director.act_elapsed = 0.0
	director._try_start_next_beat()
	assert_eq(director.current_beat_id(), &"COMMAND_GAUNTLET")
	assert_between(director.hazard_pending_count(), 2, RuntimeBudget.PENDING_HAZARDS)
	assert_lte(
		city.urban_siege.hazard_pressure.last_used_budget,
		DISTRICT.acts[5].hazard_pressure_budget
	)
	for record: Dictionary in director._hazard_pending:
		assert_between(
			absf((record.position as Vector2).x - city.robot.global_position.x),
			HazardPressureController.MINIMUM_DISTANCE,
			HazardPressureController.MAXIMUM_DISTANCE
		)
	var pair_records: Array[Dictionary] = []
	for record: Dictionary in director._hazard_pending:
		if bool(record.get("chain_pair", false)):
			pair_records.append(record)
	assert_eq(pair_records.size(), 2)
	assert_true(bool(pair_records[0].auto_trigger) != bool(pair_records[1].auto_trigger))
	assert_lte(
		(pair_records[0].position as Vector2).distance_to(
			pair_records[1].position as Vector2
		),
		HazardPressureController.CHAIN_PAIR_SPACING + 0.01
	)


func _pressure_trace(
	controller: HazardPressureController,
	seed_value: int
) -> Array[Dictionary]:
	controller.configure(seed_value, 1)
	var trace: Array[Dictionary] = []
	for act_index: int in range(3, DISTRICT.acts.size()):
		var act: DistrictAct = DISTRICT.acts[act_index]
		for beat_index: int in range(act.beats.size()):
			var plan: Array[Dictionary] = controller.plan_for_beat(
				act_index,
				beat_index,
				act,
				act.beats[beat_index],
				760.0
			)
			trace.append({
				"act_index": act_index,
				"beat_index": beat_index,
				"used_budget": controller.last_used_budget,
				"event_count": plan.size(),
				"plan": plan,
			})
	return trace


func _assert_hazard_wav(stream: AudioStreamWAV) -> void:
	assert_not_null(stream)
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(stream.mix_rate, 48000)
	assert_false(stream.stereo)
