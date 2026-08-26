extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const SAVE_PATH: String = "user://project_choir_finale_test.cfg"

var city: CitySlice
var store: CampaignProgressStore


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	city = CITY_SCENE.instantiate() as CitySlice
	store = CampaignProgressStore.new()
	store.save_path = SAVE_PATH
	city.campaign_progress = store
	add_child_autofree(store)
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func test_five_pylon_choir_prime_uses_generated_core_and_fixed_charge_steps() -> void:
	var session: CommandBossSession = city.urban_siege.boss_session
	var definition: BossEncounterDefinition = BossCampaignCatalog.definition(&"CHOIR_PRIME")
	assert_eq(definition.armor, 550.0)
	assert_true(session.start_definition(definition))
	assert_eq(session.boss.visual.texture.resource_path, "res://art/finale/choir-prime-core.png")
	assert_eq(_visible_pylon_count(session), 5)
	assert_eq(city.encounter_runtime.active_count(), 6)
	for index: int in range(5):
		assert_true(session.boss.receive_damage(_charged_event(1000 + index)))
		assert_eq(_visible_pylon_count(session), 4 - index)
	assert_eq(session.state, CommandBossSession.STATE_EXPOSED)
	assert_almost_eq(session.boss.boss_armor, 0.0, 0.001)


func test_eligibility_requires_twenty_dossiers_four_evidence_and_limited_losses() -> void:
	_prepare_eligible_store()
	var snapshot: FinaleEligibilitySnapshot = FinaleEligibilitySnapshot.from_store(store)
	assert_true(snapshot.disentangle_eligible)
	assert_eq(snapshot.dossier_count, 20)
	assert_eq(snapshot.evidence_count, 4)
	assert_eq(snapshot.continuity_generation, 2)
	store.increment_continuity()
	assert_false(FinaleEligibilitySnapshot.from_store(store).disentangle_eligible)


func test_completed_district_dossiers_award_one_canonical_evidence_flag() -> void:
	var business: Array[DossierDefinition] = DossierCatalog.district_definitions(&"BUSINESS")
	for definition: DossierDefinition in business:
		assert_true(store.collect_dossier(definition.dossier_id))
	city.project_choir_runtime._award_completed_district_evidence(
		business.back().building_variant_id
	)
	assert_eq(store.evidence_count(), 1)
	assert_true(store.snapshot().evidence.has("LEDGER"))


func test_purge_disentangle_and_failed_ascension_are_all_persistent() -> void:
	var siege: UrbanSiegeRuntime = city.urban_siege
	_prepare_finale(siege, false)
	assert_eq(siege.resolve_finale(BossOutcome.PURGE), BossOutcome.PURGE)
	assert_true(store.has_ending(&"PURGE"))
	store.reset_memory()
	_prepare_eligible_store()
	_prepare_finale(siege, true)
	assert_eq(siege.resolve_finale(BossOutcome.DISENTANGLE), BossOutcome.DISENTANGLE)
	assert_true(store.has_ending(&"DISENTANGLE"))
	store.reset_memory()
	_prepare_finale(siege, false)
	assert_eq(
		siege.resolve_finale(BossOutcome.DISENTANGLE),
		BossOutcome.ASCENSION_FAILURE
	)
	assert_true(store.has_ending(&"ASCENSION_FAILURE"))


func test_finale_choice_overlay_is_focus_safe_and_hides_legacy_actions() -> void:
	var snapshot: FinaleEligibilitySnapshot = FinaleEligibilitySnapshot.from_store(store)
	city.gameplay_hud._show_finale_choice(snapshot)
	assert_true(city.gameplay_hud.game_over_overlay.visible)
	assert_true(city.gameplay_hud.purge_button.visible)
	assert_true(city.gameplay_hud.disentangle_button.visible)
	assert_false(city.gameplay_hud.retry_button.visible)
	assert_false(city.gameplay_hud.extract_button.visible)
	assert_false(city.gameplay_hud.continue_button.visible)
	assert_true(city.gameplay_hud.disentangle_button.has_focus())


func test_royal_arc_and_streamed_choir_prime_must_both_complete() -> void:
	var siege: UrbanSiegeRuntime = city.urban_siege
	var finale: BossEncounterDefinition = BossCampaignCatalog.definition(&"CHOIR_PRIME")
	watch_signals(siege)
	siege._on_arc_completed()
	assert_signal_not_emitted(siege, "district_completed")
	siege._on_campaign_boss_completed(finale)
	assert_signal_emitted(siege, "district_completed")
	assert_true(siege.finale_pending)


func test_resolved_ending_offers_new_game_plus_before_extracting_summary() -> void:
	var siege: UrbanSiegeRuntime = city.urban_siege
	_prepare_finale(siege, false)
	assert_eq(siege.resolve_finale(BossOutcome.PURGE), BossOutcome.PURGE)
	assert_false(city.game_over_active)
	assert_eq(city.run_lifecycle._pending_ending_id, &"PURGE")
	assert_true(city.gameplay_hud.extract_button.visible)
	assert_true(city.gameplay_hud.continue_button.visible)
	assert_true(city.gameplay_hud.new_game_plus_badge.visible)
	assert_false(city.gameplay_hud.purge_button.visible)
	assert_true(city.gameplay_hud.overlay_title.text.contains("ASH PROTOCOL"))
	city.run_lifecycle._on_extract_pressed()
	assert_true(city.game_over_active)
	assert_eq(city.rampage_session.frozen_summary.ending_id, &"PURGE")


func _prepare_eligible_store() -> void:
	for index: int in range(20):
		store.collect_dossier(DossierCatalog.definitions()[index].dossier_id)
	for evidence_id: StringName in [&"LEDGER", &"NURSERY", &"STAGE", &"ARSENAL"]:
		store.preserve_evidence(evidence_id)
	store.increment_continuity()
	store.increment_continuity()


func _prepare_finale(siege: UrbanSiegeRuntime, eligible: bool) -> void:
	if eligible and store.dossier_count() < FinaleEligibilitySnapshot.DOSSIER_REQUIREMENT:
		_prepare_eligible_store()
	siege.finale_snapshot = FinaleEligibilitySnapshot.from_store(store)
	siege.finale_pending = true
	assert_true(siege.present_finale_choice())


func _charged_event(attack_id: int) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		city.robot,
		999.0,
		&"jab_cross",
		Vector2.ZERO,
		Vector2.RIGHT,
		0.0,
		0,
		0,
		DamageEvent.FLAG_FULL_CHARGE
	)


func _visible_pylon_count(session: CommandBossSession) -> int:
	var count: int = 0
	for pylon: Node2D in session.utility_pool.pylon_presentations:
		if pylon.visible:
			count += 1
	return count
