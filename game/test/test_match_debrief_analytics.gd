extends GutTest

const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"
const TEST_PROFILE_PATH: String = "user://test_player_combat_profile.json"


func before_each() -> void:
	_clear_profile_files()


func after_each() -> void:
	_clear_profile_files()


func test_enemy_defeats_track_concrete_type_family_and_fatal_weapon() -> void:
	var session: RampageSession = _session()
	var adapter: RampageEventAdapter = RampageEventAdapter.new(session)
	var robot: GiantRobotController = GiantRobotController.new()
	var enemy: EnemyActor2D = EnemyActor2D.new()
	add_child_autofree(robot)
	add_child_autofree(enemy)
	enemy.set_meta(&"enemy_archetype", &"covenant_warden")
	enemy.set_meta(&"enemy_family", &"infantry")
	var damage_types: Array[StringName] = [
		&"ground_smash", &"jab_cross", &"machine_gun", &"missile",
		&"laser", &"flamethrower", &"chain_collapse", &"strange_ray",
	]
	var expected_weapons: Array[StringName] = [
		&"GROUND_SMASH", &"JAB_CROSS", &"MACHINE_GUN", &"MISSILE",
		&"LASER", &"FLAMETHROWER", &"ENVIRONMENT", &"UNKNOWN",
	]
	for index: int in range(damage_types.size()):
		enemy.activation_generation += 1
		assert_true(adapter.enemy_defeated(
			enemy,
			DamageEvent.new(9000 + index, robot, 100.0, damage_types[index]),
			100,
			robot
		))
	var telemetry: Dictionary = session.combat_telemetry.snapshot()
	assert_eq(telemetry.total_enemies_defeated, damage_types.size())
	assert_eq(telemetry.unique_enemy_types, 1)
	assert_eq(int(telemetry.enemy_kills[&"covenant_warden"]), damage_types.size())
	assert_eq(int(telemetry.enemy_family_kills[&"infantry"]), damage_types.size())
	for weapon_id: StringName in expected_weapons:
		assert_eq(int(telemetry.weapon_kills[weapon_id]), 1, String(weapon_id))
	assert_eq(telemetry.preferred_weapon, &"GROUND_SMASH")
	_record_test_execution()


func test_highest_authored_combo_tier_survives_multiplier_cap_and_freezes() -> void:
	var session: RampageSession = _session()
	for index: int in range(23):
		var event: GameplayEvent = _kill_event(index, &"needle", &"air", &"MISSILE")
		event.combo_progress_units = 1
		assert_true(session.publish(event))
	assert_eq(session.current_multiplier(), RampageRewardTuning.MAX_MULTIPLIER)
	assert_eq(session.combat_telemetry.highest_combo_tier, 12)
	var summary: RunSummarySnapshot = session.freeze_summary(6, 2, {"completed": true})
	assert_eq(summary.highest_combo_tier, 12)
	assert_eq(summary.total_enemies_defeated, 23)
	assert_eq(summary.unique_enemy_types, 1)
	var exposed_counts: Dictionary = summary.enemy_kills
	exposed_counts[&"needle"] = 9999
	assert_eq(int(summary.enemy_kills[&"needle"]), 23)
	assert_true(session.publish(_kill_event(99, &"pale_engine", &"siege", &"LASER")))
	assert_eq(summary.total_enemies_defeated, 23)
	assert_false(summary.enemy_kills.has(&"pale_engine"))
	_record_test_execution()


func test_ranked_entries_use_count_then_stable_id() -> void:
	var ranked: Array[Dictionary] = CombatRunTelemetry.ranked_entries({
		&"missile": 3,
		&"alpha": 5,
		&"zeta": 5,
		&"laser": 1,
	}, 3)
	assert_eq(ranked.size(), 3)
	assert_eq(ranked[0].id, &"alpha")
	assert_eq(ranked[1].id, &"zeta")
	assert_eq(ranked[2].id, &"missile")
	_record_test_execution()


func test_profile_persists_records_merges_totals_and_marks_personal_bests() -> void:
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(TEST_PROFILE_PATH)
	var first: RunSummarySnapshot = _make_summary(7200, 10, true, {
		&"needle": 4,
		&"choir_siren": 2,
	}, {
		&"MISSILE": 5,
		&"JAB_CROSS": 1,
	})
	var enriched_first: RunSummarySnapshot = store.enrich_and_submit(first)
	assert_true(enriched_first.new_score_record)
	assert_true(enriched_first.new_combo_record)
	assert_eq(int(enriched_first.career_snapshot.total_runs), 1)
	assert_eq(int(enriched_first.career_snapshot.victories), 1)
	assert_eq(int(enriched_first.career_snapshot.total_enemy_kills), 6)

	var reloaded: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(reloaded)
	reloaded.setup(TEST_PROFILE_PATH)
	var persisted: Dictionary = reloaded.snapshot()
	assert_eq(int(persisted.best_score), 7200)
	assert_eq(int(persisted.highest_combo_tier), 10)
	assert_eq(int(persisted.lifetime_enemy_kills.needle), 4)
	assert_eq(int(persisted.lifetime_weapon_kills.MISSILE), 5)
	var second: RunSummarySnapshot = _make_summary(3000, 4, false, {
		&"needle": 1,
	}, {
		&"JAB_CROSS": 1,
	})
	var enriched_second: RunSummarySnapshot = reloaded.enrich_and_submit(second)
	assert_false(enriched_second.new_score_record)
	assert_false(enriched_second.new_combo_record)
	assert_eq(int(enriched_second.career_snapshot.total_runs), 2)
	assert_eq(int(enriched_second.career_snapshot.victories), 1)
	assert_eq(int(enriched_second.career_snapshot.total_enemy_kills), 7)
	assert_eq(int(enriched_second.career_snapshot.lifetime_enemy_kills.needle), 5)
	_record_test_execution()


func test_leaderboard_candidate_is_versioned_and_privacy_minimal() -> void:
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(TEST_PROFILE_PATH)
	var summary: RunSummarySnapshot = store.enrich_and_submit(_make_summary(
		8100,
		7,
		true,
		{&"ninefold_witness": 3},
		{&"GROUND_SMASH": 3}
	))
	var payload: Dictionary = store.leaderboard_candidate(summary, "revision-test")
	assert_eq(int(payload.schema_version), PlayerCombatProfileStore.SCHEMA_VERSION)
	assert_eq(String(payload.build_revision), "revision-test")
	assert_eq(String(payload.run.preferred_weapon), "GROUND_SMASH")
	assert_eq(int(payload.run.enemy_kills.ninefold_witness), 3)
	assert_true(String(payload.anonymous_profile_id).length() >= 16)
	var serialized: String = JSON.stringify(payload)
	for forbidden: String in [
		"dossier", "campaign", "input_binding", "audio_settings", "user://", "hardware",
	]:
		assert_false(serialized.to_lower().contains(forbidden), forbidden)
	_record_test_execution()


func test_malformed_profile_falls_back_without_blocking_launch() -> void:
	var file: FileAccess = FileAccess.open(TEST_PROFILE_PATH, FileAccess.WRITE)
	file.store_string("{ not valid profile json")
	file.close()
	var store: PlayerCombatProfileStore = PlayerCombatProfileStore.new()
	add_child_autofree(store)
	store.setup(TEST_PROFILE_PATH)
	var profile: Dictionary = store.snapshot()
	assert_eq(int(profile.schema_version), PlayerCombatProfileStore.SCHEMA_VERSION)
	assert_eq(int(profile.total_runs), 0)
	assert_eq(int(profile.best_score), 0)
	assert_false(String(profile.anonymous_profile_id).is_empty())
	_record_test_execution()


func _session() -> RampageSession:
	var session: RampageSession = RampageSession.new()
	add_child_autofree(session)
	return session


func _kill_event(
	index: int,
	enemy_id: StringName,
	family_id: StringName,
	weapon_id: StringName
) -> GameplayEvent:
	var event: GameplayEvent = GameplayEvent.new(
		StringName("debrief_kill_%d" % index),
		index + 1,
		GameplayEvent.Kind.ENEMY_DEFEATED,
		GameplayEvent.ENEMY_KILL,
		100,
		8.0,
		true
	)
	event.enemy_archetype_id = enemy_id
	event.enemy_family_id = family_id
	event.weapon_id = weapon_id
	return event


func _make_summary(
	score: int,
	highest_combo_tier: int,
	completed: bool,
	enemy_kills: Dictionary,
	weapon_kills: Dictionary
) -> RunSummarySnapshot:
	var total_kills: int = 0
	for value: Variant in enemy_kills.values():
		total_kills += int(value)
	var preferred_entries: Array[Dictionary] = CombatRunTelemetry.ranked_entries(weapon_kills, 1)
	var preferred_weapon: StringName = (
		preferred_entries[0].id as StringName if not preferred_entries.is_empty() else &"UNKNOWN"
	)
	var preferred_kills: int = (
		int(preferred_entries[0].count) if not preferred_entries.is_empty() else 0
	)
	return RunSummarySnapshot.new(
		score,
		mini(highest_combo_tier, RampageRewardTuning.MAX_MULTIPLIER),
		highest_combo_tier * EnemySpawnTuning.QUANTITY_MULTIPLIER,
		6 if completed else 2,
		1,
		{},
		{
			"completed": completed,
			"grade": &"S" if completed else &"C",
			"highest_combo_tier": highest_combo_tier,
			"total_enemies_defeated": total_kills,
			"unique_enemy_types": enemy_kills.size(),
			"enemy_kills": enemy_kills,
			"weapon_kills": weapon_kills,
			"preferred_weapon": preferred_weapon,
			"preferred_weapon_kills": preferred_kills,
		}
	)


func _clear_profile_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = TEST_PROFILE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
