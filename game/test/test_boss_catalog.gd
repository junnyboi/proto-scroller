extends GutTest


func test_catalog_has_exact_canonical_roster_triggers_and_campaign_results() -> void:
	assert_eq(BossCampaignCatalog.validation_errors(), PackedStringArray())
	var definitions: Array[BossEncounterDefinition] = BossCampaignCatalog.definitions()
	assert_eq(definitions.size(), BossCampaignCatalog.DEFINITION_COUNT)
	var expected: Array[Array] = [
		[
			&"SETTLEMENT_ENGINE_S04", &"BUSINESS", 9, 12,
			"SETTLEMENT ENGINE S-04 — The Fiduciary Saint",
			&"B05_EASTBOUND_CONSIDERATION", &"LEDGER",
		],
		[
			&"SAMARITAN_15", &"RESIDENTIAL", 21, 24,
			"SAMARITAN-15 — The Last Evacuation",
			&"ASHWATER_INTAKE_MANIFEST", &"NURSERY",
		],
		[
			&"MIMESIS_04", &"ENTERTAINMENT", 33, 36,
			"MIMESIS-04 — The Afterimage Conductor",
			&"AUDIENCE_OF_ONE_0417_CONTINUITY", &"STAGE",
		],
		[
			&"CANTOR_31_PALE_ENGINE", &"MILITARY", 45, 48,
			"CANTOR-31 / PALE ENGINE — The Export Surgeon",
			&"EXPORT_LITANY_31", &"ARSENAL",
		],
		[
			&"CHOIR_PRIME", &"ROYAL", 57, -1,
			"CHOIR Prime — The Last Sovereign",
			&"CROWN_05_CONSENT_EXCISION_ORDER", &"CROWN",
		],
	]
	for index: int in range(definitions.size()):
		var definition: BossEncounterDefinition = definitions[index]
		var row: Array = expected[index]
		assert_eq(definition.boss_id, row[0])
		assert_eq(definition.district_id, row[1])
		assert_eq(definition.trigger_chunk, row[2])
		assert_eq(definition.unlock_chunk, row[3])
		assert_eq(definition.display_name, row[4])
		assert_eq(definition.capstone_dossier_id, row[5])
		assert_eq(definition.evidence_flag_id, row[6])
		assert_eq(
			definition.armor_policy,
			(
				EnemyActor2D.ArmorPolicy.ALL_DAMAGE
				if index == 0
				else EnemyActor2D.ArmorPolicy.FULL_CHARGE_FIXED_STEP
			)
		)
		assert_eq(definition.armor_fixed_step, 110.0)
		assert_true(definition.direct_damage_route)
		assert_false(definition.summon_uses_arena_landmark)
		assert_false(definition.arena_landmark_variant_id.is_empty())
		assert_eq(BossCampaignCatalog.definition(definition.boss_id), definition)
		assert_eq(BossCampaignCatalog.definition_for_trigger(definition.trigger_chunk), definition)
	assert_eq(definitions.back().outcomes, BossOutcome.values())
	assert_eq(BossOutcome.id_for(BossOutcome.PURGE), &"PURGE")
	assert_eq(BossOutcome.id_for(BossOutcome.DISENTANGLE), &"DISENTANGLE")
	assert_eq(BossOutcome.id_for(BossOutcome.ASCENSION_FAILURE), &"ASCENSION_FAILURE")


func test_catalog_validator_rejects_duplicate_ids_triggers_and_invalid_contracts() -> void:
	var definitions: Array[BossEncounterDefinition] = []
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		definitions.append(definition.duplicate(true) as BossEncounterDefinition)
	definitions[1].boss_id = definitions[0].boss_id
	definitions[1].trigger_chunk = definitions[0].trigger_chunk
	definitions[2].district_id = &"UNKNOWN"
	definitions[2].utility_requirements = {&"markers": 9}
	definitions[3].direct_damage_route = false
	definitions[3].exposed_damage_types = PackedStringArray()
	definitions[4].wreck_receiver_offsets = PackedVector2Array([
		Vector2.ZERO, Vector2(40.0, 0.0),
	])
	var errors: PackedStringArray = BossCampaignCatalog.validation_errors(definitions)
	assert_true(_contains_error(errors, "duplicate boss_id"))
	assert_true(_contains_error(errors, "duplicate trigger_chunk"))
	assert_true(_contains_error(errors, "unknown district_id"))
	assert_true(_contains_error(errors, "utility demand markers=9"))
	assert_true(_contains_error(errors, "direct damage route missing"))
	assert_true(_contains_error(errors, "wreck receiver spacing below smash radius"))


func test_evidence_requires_recovery_rule_and_thresholds_are_strictly_descending() -> void:
	var definition: BossEncounterDefinition = (
		BossCampaignCatalog.definitions()[0].duplicate(true) as BossEncounterDefinition
	)
	definition.evidence_recovery_eligible = true
	definition.evidence_recovery_rule = &""
	definition.phase_thresholds = PackedFloat32Array([0.4, 0.7])
	var errors: PackedStringArray = definition.validation_errors()
	assert_true(_contains_error(errors, "evidence recovery rule missing"))
	assert_true(_contains_error(errors, "invalid phase thresholds"))


func test_utility_pool_prewarm_union_is_exact_and_never_grows_after_warm() -> void:
	var pool: BossUtilityPool = BossUtilityPool.new()
	add_child_autofree(pool)
	var node_count: int = _count_nodes(pool)
	assert_eq(pool.rig_count(), 1)
	assert_eq(pool.controller_count(), 1)
	assert_eq(pool.arena_adapter_count(), 1)
	assert_eq(pool.pylon_count(), 5)
	assert_eq(pool.projection_count(), 4)
	assert_eq(pool.marker_count(), 8)
	assert_eq(pool.lane_damage_areas.size(), 3)
	assert_eq(pool.line_areas.size(), 2)
	assert_not_null(pool.radial_shockwave)
	assert_eq(
		pool.radial_shockwave.presentation_role,
		BossAttackArea2D.PresentationRole.RADIAL_SHOCKWAVE
	)
	assert_eq(pool.collapse_listener_count(), 2)
	assert_eq(pool.pod_visual_count(), 4)
	assert_eq(pool.reclamation_anchor_count(), 3)
	assert_eq(pool.wreck_receiver_count(), 2)
	assert_not_null(pool.default_wreck_receiver)
	assert_not_null(pool.royal_outcome_receiver)
	for loop_index: int in range(25):
		var token: int = pool.begin_generation()
		var reservation_id: int = pool.reserve_requirements(
			{&"markers": 8, &"wreck_receivers": 2}, token
		)
		assert_gt(reservation_id, 0)
		assert_true(pool.consume_reservation(reservation_id, &"markers", 8))
		assert_true(pool.cleanup_generation(token))
	assert_eq(pool.reservation_count(), 0)
	assert_eq(pool.post_warm_creation_count, 0)
	assert_eq(_count_nodes(pool), node_count)


func test_generation_token_rejects_stale_cleanup_and_over_capacity_reservations() -> void:
	var pool: BossUtilityPool = BossUtilityPool.new()
	add_child_autofree(pool)
	var first_generation: int = pool.begin_generation()
	var reservation_id: int = pool.reserve_requirements({&"projection_slots": 4})
	assert_gt(reservation_id, 0)
	var next_generation: int = pool.begin_generation()
	assert_ne(next_generation, first_generation)
	assert_eq(pool.reservation_count(), 0)
	assert_false(pool.cleanup_generation(first_generation))
	assert_eq(pool.reserve_requirements({&"projection_slots": 5}), 0)
	assert_eq(pool.denial_count, 1)


func _contains_error(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false


func _count_nodes(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children():
		count += _count_nodes(child)
	return count
