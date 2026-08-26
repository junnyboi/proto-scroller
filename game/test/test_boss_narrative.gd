extends GutTest

const TEST_PATH: String = "user://test_boss_narrative.json"


func before_each() -> void:
	_remove_saves()
	L10n.set_locale("en")


func after_each() -> void:
	_remove_saves()
	L10n.set_locale("en")


func test_boss_lines_are_localized_observations_and_never_pause_control() -> void:
	var store: CampaignProgressStore = _store()
	var director: NarrativeDirector = NarrativeDirector.new()
	director.setup(store)
	add_child_autofree(director)
	watch_signals(director)
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(
		&"SETTLEMENT_ENGINE_S04"
	)
	director.handle_boss_attempt_started(definition)
	director.handle_boss_state_changed(CommandBossSession.STATE_EXPOSED)
	assert_signal_emit_count(director, "transmission_requested", 2)
	assert_false(get_tree().paused)
	assert_eq(director.echo7_status_key(), "narrative.echo7.ambiguous")
	assert_ne(L10n.t(String(definition.voice_caption_keys[&"echo"])), "")
	assert_ne(L10n.t(String(definition.voice_caption_keys[&"veyr"])), "")


func test_boss_completion_commits_capstone_and_reward_once() -> void:
	var store: CampaignProgressStore = _store()
	var director: NarrativeDirector = NarrativeDirector.new()
	director.setup(store)
	add_child_autofree(director)
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(&"SAMARITAN_15")
	assert_true(director.handle_boss_completed(definition))
	assert_false(director.handle_boss_completed(definition))
	assert_true(store.has_dossier(&"ASHWATER_INTAKE_MANIFEST"))
	assert_false(store.has_evidence(&"NURSERY"))
	assert_true(store.completed_boss_ids().has("SAMARITAN_15"))
	assert_true(store.pending_reward_grants().has("boss:SAMARITAN_15:reward"))


func test_crown_capstone_repeats_canon_without_premature_echo_resolution() -> void:
	var store: CampaignProgressStore = _store()
	var director: NarrativeDirector = NarrativeDirector.new()
	director.setup(store)
	add_child_autofree(director)
	var definitions: Array[DossierDefinition] = DossierCatalog.definitions()
	for index: int in range(18):
		assert_true(store.collect_dossier(definitions[index].dossier_id))
	assert_true(director.handle_boss_completed(BossCampaignCatalog.definition(&"CHOIR_PRIME")))
	assert_true(store.has_evidence(&"CROWN"))
	assert_eq(store.dossier_count(), 19)
	assert_false(store.echo7_resolved())
	assert_eq(director.echo7_status_key(), "narrative.echo7.ambiguous")
	var capstone: DossierDefinition = DossierCatalog.capstone_for_boss(&"CHOIR_PRIME")
	assert_true(L10n.t(capstone.body_secondary_key).contains("Below twenty dossiers"))


func test_all_boss_voice_and_capstone_keys_exist_in_both_locales() -> void:
	for locale: String in L10n.available_locales():
		assert_true(L10n.set_locale(locale))
		assert_ne(L10n.t("narrative.speaker.veyr"), "narrative.speaker.veyr")
		for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
			assert_ne(
				L10n.t(String(definition.voice_caption_keys[&"echo"])),
				String(definition.voice_caption_keys[&"echo"])
			)
			assert_ne(
				L10n.t(String(definition.voice_caption_keys[&"veyr"])),
				String(definition.voice_caption_keys[&"veyr"])
			)
			var capstone: DossierDefinition = DossierCatalog.capstone_for_boss(
				definition.boss_id
			)
			assert_ne(L10n.t(capstone.title_key), capstone.title_key)
			assert_ne(L10n.t(capstone.body_primary_key), capstone.body_primary_key)
			assert_ne(L10n.t(capstone.body_secondary_key), capstone.body_secondary_key)


func _store() -> CampaignProgressStore:
	var store: CampaignProgressStore = CampaignProgressStore.new()
	store.setup(TEST_PATH)
	add_child_autofree(store)
	return store


func _remove_saves() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
