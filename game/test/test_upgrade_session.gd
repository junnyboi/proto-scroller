extends GutTest


func test_catalog_resource_is_valid_and_contains_all_profiles() -> void:
	var catalog: UpgradeCatalog = load(
		"res://resources/upgrades/upgrade_catalog.tres"
	) as UpgradeCatalog
	assert_not_null(catalog)
	assert_eq(catalog.rebuild(), PackedStringArray())
	assert_eq(catalog.size(), 14)
	var total_ranks: int = 0
	for profile: UpgradeProfile in catalog.sorted_profiles():
		total_ranks += profile.max_rank
	assert_eq(total_ranks, 49)


func test_same_seed_and_selections_replay_identical_distinct_offers() -> void:
	var first: UpgradeSession = _session(88173, _catalog(5))
	var second: UpgradeSession = _session(88173, _catalog(5))
	for level: int in range(2, 10):
		assert_true(first.queue_level(level, level * 10))
		assert_true(second.queue_level(level, level * 10))
		first.resolve_pending_for_tests()
		second.resolve_pending_for_tests()
		assert_eq(first.active_offer.choice_ids, second.active_offer.choice_ids)
		assert_eq(first.active_offer.choice_ids.size(), 2)
		assert_ne(first.active_offer.choice_ids[0], first.active_offer.choice_ids[1])
		var selected: StringName = first.active_offer.choice_ids[0]
		assert_true(first.select_choice(selected, first.active_offer.sequence))
		assert_true(second.select_choice(selected, second.active_offer.sequence))
	assert_eq(first.replay_records, second.replay_records)


func test_capped_profiles_leave_legal_pool_and_stale_selection_is_rejected() -> void:
	var session: UpgradeSession = _session(7, _catalog(3, 1))
	assert_true(session.queue_level(2, 100))
	session.resolve_pending_for_tests()
	var first_sequence: int = session.active_offer.sequence
	var first_id: StringName = session.active_offer.choice_ids[0]
	assert_true(session.select_choice(first_id, first_sequence))
	assert_eq(session.rank_of(first_id), 1)
	assert_false(session.select_choice(first_id, first_sequence))
	assert_true(session.queue_level(3, 101))
	session.resolve_pending_for_tests()
	if session.active_offer != null:
		assert_false(session.active_offer.choice_ids.has(first_id))
		assert_false(session.select_choice(session.active_offer.choice_ids[0], first_sequence))


func test_single_and_zero_legal_profiles_consume_no_rng_draw() -> void:
	var session: UpgradeSession = _session(91, _catalog(1, 1))
	assert_true(session.queue_level(2, 12))
	session.resolve_pending_for_tests()
	assert_eq(session.rng_draw_count, 0)
	assert_eq(session.rank_of(&"UPGRADE_0"), 1)
	assert_null(session.active_offer)
	assert_true(session.queue_level(3, 13))
	session.resolve_pending_for_tests()
	assert_eq(session.rng_draw_count, 0)
	assert_eq(session.state, UpgradeSession.State.IDLE)


func test_multilevel_batch_holds_one_pause_lease_until_drained() -> void:
	var session: UpgradeSession = _session(44, _catalog(5))
	assert_true(session.queue_level(2, 50))
	assert_true(session.queue_level(3, 50))
	assert_true(session.queue_level(4, 50))
	session.resolve_pending_for_tests()
	var pause: FakePauseCoordinator = session.pause as FakePauseCoordinator
	assert_eq(pause.acquire_count, 1)
	assert_eq(pause.release_count, 0)
	for choice_index: int in range(3):
		assert_not_null(session.active_offer)
		var sequence: int = session.active_offer.sequence
		var selected: StringName = session.active_offer.choice_ids[0]
		assert_true(session.select_choice(selected, sequence))
		if choice_index < 2:
			assert_eq(pause.release_count, 0)
	assert_eq(pause.acquire_count, 1)
	assert_eq(pause.release_count, 1)
	assert_eq(session.state, UpgradeSession.State.IDLE)


func test_duplicate_entitlement_claim_changes_nothing() -> void:
	var session: UpgradeSession = _session(12, _catalog(3))
	assert_true(session.queue_level(2, 99))
	assert_false(session.queue_level(2, 99))
	assert_eq(session.pending.size(), 1)
	assert_eq(session.rng_draw_count, 0)


func _session(p_seed: int, catalog: UpgradeCatalog) -> UpgradeSession:
	var session: UpgradeSession = UpgradeSession.new()
	add_child_autofree(session)
	var runtimes: Dictionary[StringName, UpgradeRuntime] = {}
	for profile: UpgradeProfile in catalog.profiles:
		var runtime: UpgradeRuntime = UpgradeRuntime.new()
		runtime.setup(profile.runtime_key, profile.max_rank)
		session.add_child(runtime)
		runtimes[profile.runtime_key] = runtime
	var pause: FakePauseCoordinator = FakePauseCoordinator.new()
	session.add_child(pause)
	assert_eq(session.setup(p_seed, catalog, pause, runtimes), PackedStringArray())
	return session


func _catalog(count: int, max_rank: int = 5) -> UpgradeCatalog:
	var catalog: UpgradeCatalog = UpgradeCatalog.new()
	for index: int in range(count):
		var profile: UpgradeProfile = UpgradeProfile.new()
		profile.upgrade_id = StringName("UPGRADE_%d" % index)
		profile.display_name = "UPGRADE %d" % index
		profile.description = "TEST PROFILE %d" % index
		profile.category = &"test"
		profile.max_rank = max_rank
		profile.runtime_key = profile.upgrade_id
		profile.offer_weight = 50 + index * 10
		profile.sort_order = index
		catalog.profiles.append(profile)
	return catalog


class FakePauseCoordinator:
	extends RunPauseCoordinator

	var acquire_count: int = 0
	var release_count: int = 0
	var current_token: int = 0

	func acquire(_reason: StringName) -> int:
		acquire_count += 1
		current_token += 1
		return current_token

	func release(token: int) -> bool:
		if token <= 0:
			return false
		release_count += 1
		return true
