extends GutTest

const TEST_PATH: String = "user://test_campaign_evidence.json"


func before_each() -> void:
	_remove_saves()


func after_each() -> void:
	_remove_saves()


func test_exactly_twenty_five_facade_dossiers_and_five_capstones_validate() -> void:
	assert_eq(DossierCatalog.validation_errors(), PackedStringArray())
	assert_eq(DossierCatalog.definitions().size(), 25)
	assert_eq(DossierCatalog.capstone_definitions().size(), 5)
	assert_eq(DossierCatalog.EVIDENCE_FLAGS.size(), 5)
	for boss: BossEncounterDefinition in BossCampaignCatalog.definitions():
		var capstone: DossierDefinition = DossierCatalog.capstone_for_boss(boss.boss_id)
		assert_not_null(capstone)
		assert_eq(capstone.dossier_id, boss.capstone_dossier_id)
		assert_eq(capstone.evidence_flag_id, boss.evidence_flag_id)
		assert_eq(capstone.building_variant_id, boss.arena_landmark_variant_id)


func test_optional_evidence_loss_never_blocks_progress_and_recovers_deterministically() -> void:
	var store: CampaignProgressStore = _store()
	assert_true(store.record_evidence_loss(&"LEDGER"))
	assert_true(store.record_evidence_loss(&"NURSERY"))
	assert_eq(store.next_recoverable_evidence(0), &"LEDGER")
	assert_eq(store.next_recoverable_evidence(1), &"NURSERY")
	assert_true(store.recover_evidence_from_elite(&"LEDGER", &"seed:0:elite:0"))
	assert_false(store.recover_evidence_from_elite(&"LEDGER", &"seed:0:elite:0"))
	assert_true(store.has_evidence(&"LEDGER"))
	assert_false(store.has_evidence(&"NURSERY"))
	assert_eq(store.next_recoverable_evidence(0), &"NURSERY")
	for boss: BossEncounterDefinition in BossCampaignCatalog.definitions():
		assert_true(boss.unlock_chunk == -1 or boss.unlock_chunk > boss.trigger_chunk)


func test_crown_does_not_resolve_echo7_below_twenty_dossiers() -> void:
	var store: CampaignProgressStore = _store()
	assert_true(store.preserve_evidence(&"CROWN"))
	var definitions: Array[DossierDefinition] = DossierCatalog.definitions()
	for index: int in range(19):
		assert_true(store.collect_dossier(definitions[index].dossier_id))
	assert_eq(store.dossier_count(), 19)
	assert_false(store.echo7_resolved())
	assert_false(store.finale_eligible())
	assert_true(store.collect_dossier(definitions[19].dossier_id))
	assert_true(store.echo7_resolved())
	assert_false(store.finale_eligible())
	for evidence_id: StringName in [&"LEDGER", &"NURSERY", &"STAGE", &"ARSENAL"]:
		assert_true(store.preserve_evidence(evidence_id))
	assert_true(store.finale_eligible())


func test_crown_evidence_is_not_eligible_for_elite_recovery() -> void:
	var store: CampaignProgressStore = _store()
	assert_true(store.record_evidence_loss(&"CROWN"))
	assert_false(store.recover_evidence_from_elite(&"CROWN", &"illegal"))
	assert_eq(store.next_recoverable_evidence(0), &"")


func _store() -> CampaignProgressStore:
	var store: CampaignProgressStore = CampaignProgressStore.new()
	store.setup(TEST_PATH)
	add_child_autofree(store)
	return store


func _remove_saves() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
