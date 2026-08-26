extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const DISTRICT: DistrictDefinition = preload("res://resources/siege/district_contact.tres")

var city: CitySlice
var runtime: EncounterRuntime
var transmission_ids: Array[StringName] = []


func before_each() -> void:
	transmission_ids.clear()
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	runtime = city.encounter_runtime
	city.urban_siege.stop_run()
	runtime.release_all()


func test_hybrid_profiles_reconfigure_existing_family_shells() -> void:
	var pairs: Array[Array] = [
		[&"bulwark", &"reclaimed_breacher"],
		[&"jackal", &"graft_runner"],
		[&"needle", &"choir_siren"],
		[&"static", &"ossuary_crawler"],
		[&"hive", &"seraph_carrier"],
		[&"goliath", &"pale_engine"],
	]
	for pair: Array in pairs:
		var baseline: ProceduralEnemy = runtime.acquire(
			pair[0] as StringName,
			Vector2(1200.0, 400.0)
		) as ProceduralEnemy
		assert_not_null(baseline)
		var shell_id: int = baseline.get_instance_id()
		runtime.release(baseline)
		var hybrid: ProceduralEnemy = runtime.acquire(
			pair[1] as StringName,
			Vector2(1200.0, 400.0)
		) as ProceduralEnemy
		assert_not_null(hybrid)
		assert_eq(hybrid.get_instance_id(), shell_id, pair[1])
		runtime.release(hybrid)
	assert_eq(runtime.post_warm_creation_count, 0)


func test_spatial_resolver_is_deterministic_and_never_mutates_authored_entries() -> void:
	var base: DistrictBeat = _family_beat()
	var original: Array[StringName] = _kinds(base)
	var districts: Array[StringName] = [
		&"BUSINESS", &"RESIDENTIAL", &"ENTERTAINMENT", &"MILITARY", &"ROYAL",
	]
	var expected_eligible: Array[Array] = [
		[],
		[&"reclaimed_breacher", &"graft_runner"],
		[&"choir_siren", &"ossuary_crawler", &"graft_runner"],
		[&"seraph_carrier", &"pale_engine", &"graft_runner"],
		[
			&"reclaimed_breacher", &"graft_runner", &"choir_siren",
			&"ossuary_crawler", &"seraph_carrier", &"pale_engine",
		],
	]
	for index: int in range(districts.size()):
		var first: DistrictBeat = HybridEncounterResolver.resolve_beat(
			base, districts[index], 2, 1, 913
		)
		var replay: DistrictBeat = HybridEncounterResolver.resolve_beat(
			base, districts[index], 2, 1, 913
		)
		assert_eq(_kinds(first), _kinds(replay), districts[index])
		assert_eq(
			HybridEncounterResolver.eligible_hybrids(districts[index]),
			expected_eligible[index]
		)
		if districts[index] == &"BUSINESS":
			assert_eq(first, base)
		else:
			assert_gt(HybridEncounterResolver.substitutions(base, first).size(), 0)
	assert_eq(_kinds(base), original)


func test_authored_campaign_exposes_each_districts_complete_hybrid_roster() -> void:
	for district_id: StringName in [
		&"RESIDENTIAL", &"ENTERTAINMENT", &"MILITARY", &"ROYAL",
	]:
		var seen: Dictionary[StringName, bool] = {}
		for act_index: int in range(DISTRICT.acts.size()):
			var act: DistrictAct = DISTRICT.acts[act_index]
			for beat_index: int in range(act.beats.size()):
				var base: DistrictBeat = act.beats[beat_index]
				var resolved: DistrictBeat = HybridEncounterResolver.resolve_beat(
					base, district_id, act_index, beat_index, 913
				)
				for change: Dictionary in HybridEncounterResolver.substitutions(base, resolved):
					seen[StringName(change.after)] = true
		for hybrid_id: StringName in HybridEncounterResolver.eligible_hybrids(district_id):
			assert_true(seen.has(hybrid_id), "%s/%s" % [district_id, hybrid_id])


func test_breacher_frontal_brace_and_pale_armor_are_independent() -> void:
	city.robot.global_position = Vector2(800.0, 600.0)
	var breacher: ProceduralEnemy = runtime.acquire(
		&"reclaimed_breacher", Vector2(1100.0, 540.0)
	) as ProceduralEnemy
	assert_eq(breacher.facing, -1)
	assert_true(breacher.receive_damage(DamageEvent.new(
		90_001, city.robot, 100.0, &"jab_cross", breacher.global_position, Vector2.RIGHT
	)))
	assert_almost_eq(breacher.current_health, 380.0, 0.01)
	assert_true(breacher.receive_damage(DamageEvent.new(
		90_002, city.robot, 100.0, &"ground_smash", breacher.global_position, Vector2.RIGHT
	)))
	assert_almost_eq(breacher.current_health, 280.0, 0.01)
	runtime.release(breacher)
	var pale: ProceduralEnemy = runtime.acquire(
		&"pale_engine", Vector2(1200.0, 482.0)
	) as ProceduralEnemy
	assert_almost_eq(pale.ablative_armor, 180.0, 0.01)
	assert_true(pale.receive_damage(DamageEvent.new(
		90_003, city.robot, 100.0, &"jab_cross", pale.global_position, Vector2.RIGHT
	)))
	assert_almost_eq(pale.current_health, pale.max_health, 0.01)
	assert_almost_eq(pale.ablative_armor, 80.0, 0.01)
	assert_true(pale.receive_damage(DamageEvent.new(
		90_004, city.robot, 100.0, &"jab_cross", pale.global_position, Vector2.RIGHT
	)))
	assert_almost_eq(pale.current_health, pale.max_health - 20.0, 0.01)


func test_siren_mark_enables_runner_and_seraph_deploys_bounded_pack() -> void:
	city.robot.global_position = Vector2(800.0, 600.0)
	var runner: ProceduralEnemy = runtime.acquire(
		&"graft_runner", Vector2(1040.0, 554.0)
	) as ProceduralEnemy
	assert_false(runner._can_attack())
	runtime.release(runner)
	var siren: ProceduralEnemy = runtime.acquire(
		&"choir_siren", Vector2(1200.0, 210.0)
	) as ProceduralEnemy
	siren._begin_attack()
	assert_true(siren.is_telegraphing())
	siren._complete_attack()
	assert_gt(runtime.target_mark_remaining, 0.0)
	runtime.release(siren)
	runner = runtime.acquire(&"graft_runner", Vector2(1040.0, 554.0)) as ProceduralEnemy
	assert_true(runner._can_attack())
	runtime.release(runner)
	var seraph: ProceduralEnemy = runtime.acquire(
		&"seraph_carrier", Vector2(1260.0, 180.0)
	) as ProceduralEnemy
	seraph._begin_attack()
	seraph._complete_attack()
	assert_eq(runtime.active_count(&"graft_runner"), RuntimeBudget.PROCEDURAL_LIGHT)
	assert_eq(seraph._spawned_children, RuntimeBudget.PROCEDURAL_LIGHT)
	assert_eq(runtime.available_family_count(&"light"), 0)
	runtime.release_all()
	assert_eq(city.projectile_root.reservation_count(), 0)
	assert_eq(city.telegraph_presenter.active_count(), 0)


func test_hybrid_first_contact_transmission_fires_once_per_run() -> void:
	city.project_choir_runtime.director.transmission_requested.connect(
		_capture_transmission
	)
	var first: ProceduralEnemy = runtime.acquire(
		&"reclaimed_breacher", Vector2(1100.0, 540.0)
	) as ProceduralEnemy
	runtime.release(first)
	var second: ProceduralEnemy = runtime.acquire(
		&"reclaimed_breacher", Vector2(1100.0, 540.0)
	) as ProceduralEnemy
	runtime.release(second)
	assert_eq(transmission_ids.count(&"hybrid_reclaimed_breacher_contact"), 1)


func _capture_transmission(
	event_id: StringName,
	_speaker: String,
	_line: String,
	_duration: float,
	_priority: int
) -> void:
	transmission_ids.append(event_id)


func _family_beat() -> DistrictBeat:
	var beat: DistrictBeat = DistrictBeat.new()
	beat.beat_id = &"HYBRID_TEST"
	beat.maximum_threat = 20
	for kind: StringName in [&"bulwark", &"jackal", &"needle", &"goliath"]:
		var entry: EnemySpawnEntry = EnemySpawnEntry.new()
		entry.kind = String(kind)
		beat.spawns.append(entry)
	return beat


func _kinds(beat: DistrictBeat) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: EnemySpawnEntry in beat.spawns:
		result.append(StringName(entry.kind))
	return result
