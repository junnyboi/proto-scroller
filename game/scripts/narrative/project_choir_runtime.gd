class_name ProjectChoirRuntime
extends Node

var campaign_progress: CampaignProgressStore
var director: NarrativeDirector
var facade_reveal: FacadeRevealRuntime
var _city: CitySlice
var _released_containment: Dictionary[StringName, bool] = {}


static func mount(city: CitySlice, progress: CampaignProgressStore) -> ProjectChoirRuntime:
	var runtime: ProjectChoirRuntime = ProjectChoirRuntime.new()
	runtime.name = "ProjectChoirRuntime"
	city.add_child(runtime)
	runtime.setup(city, progress)
	return runtime


func setup(city: CitySlice, progress: CampaignProgressStore) -> void:
	_city = city
	_released_containment.clear()
	campaign_progress = progress
	if campaign_progress == null:
		campaign_progress = CampaignProgressStore.new()
		campaign_progress.name = "EphemeralCampaignProgressStore"
		add_child(campaign_progress)
		campaign_progress.reset_memory()
	assert(DossierCatalog.validation_errors().is_empty())
	facade_reveal = FacadeRevealRuntime.new()
	facade_reveal.name = "FacadeRevealRuntime"
	add_child(facade_reveal)
	facade_reveal.setup(city.streamed_destructibles, campaign_progress)
	director = NarrativeDirector.new()
	director.name = "NarrativeDirector"
	director.setup(campaign_progress)
	director.transmission_requested.connect(city.gameplay_hud.transmission_toast.present)
	director.facade_reveal_requested.connect(facade_reveal.reveal)
	add_child(director)
	city.world_stream.district_changed.connect(_on_spatial_district_changed)
	city.streamed_destructibles.building_cell_destroyed.connect(_on_building_cell_destroyed)
	city.encounter_runtime.enemy_acquired.connect(director.handle_enemy_acquired)
	city.encounter_runtime.enemy_died.connect(director.handle_enemy_defeated)
	city.run_lifecycle.run_finished.connect(_on_run_finished)
	var boss_campaign: BossCampaignDirector = city.urban_siege.boss_campaign
	boss_campaign.attempt_started.connect(director.handle_boss_attempt_started)
	city.urban_siege.boss_session.state_changed.connect(director.handle_boss_state_changed)
	var initial_district: CityDistrictProfile = CityDistrictCatalog.district_for_chunk(
		city.world_stream.current_logical_chunk
	)
	director.begin_run(city.world_stream.run_seed, initial_district.district_id)


func _on_spatial_district_changed(
	_previous_district_id: StringName,
	district_id: StringName,
	_logical_chunk: int
) -> void:
	director.handle_spatial_district_arrival(district_id)


func _on_building_cell_destroyed(
	building: StructuralBuilding2D,
	column: int,
	row: int,
	_event: DamageEvent
) -> void:
	director.handle_building_cell_destroyed(building, column, row)
	_try_release_containment(building, column, row)


func containment_release_count() -> int:
	return _released_containment.size()


func commit_boss_completion(
	definition: BossEncounterDefinition,
	canonical_evidence_event: Dictionary
) -> bool:
	return director.handle_boss_completed(definition, canonical_evidence_event)


func _try_release_containment(
	building: StructuralBuilding2D,
	column: int,
	row: int
) -> void:
	if building == null:
		return
	var definition: DossierDefinition = DossierCatalog.definition_for_variant(
		building.current_variant_id()
	)
	if (
		definition == null
		or definition.district_id != &"ENTERTAINMENT"
		or not definition.trigger_matches(column, row)
		or _released_containment.has(definition.building_variant_id)
	):
		return
	var spawn_position: Vector2 = building.global_position + Vector2(0.0, 50.0)
	var released: int = 0
	for copy_index: int in range(EnemySpawnTuning.QUANTITY_MULTIPLIER):
		var crawler: EnemyActor2D = _city.encounter_runtime.acquire(
			&"ossuary_crawler",
			spawn_position + EnemySpawnTuning.offset_for_copy(copy_index, 90.0)
		)
		released += 1 if crawler != null else 0
	if released > 0:
		_released_containment[definition.building_variant_id] = true


func _on_run_finished(completed: bool, _summary: RunSummarySnapshot) -> void:
	if not completed:
		director.record_chassis_loss()
	_city.gameplay_hud._set_campaign_summary(
		campaign_progress.dossier_count(),
		campaign_progress.continuity_generation()
	)
