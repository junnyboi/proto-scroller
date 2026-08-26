class_name ProjectChoirRuntime
extends Node

var campaign_progress: CampaignProgressStore
var director: NarrativeDirector
var facade_reveal: FacadeRevealRuntime
var _city: CitySlice


static func mount(city: CitySlice, progress: CampaignProgressStore) -> ProjectChoirRuntime:
	var runtime: ProjectChoirRuntime = ProjectChoirRuntime.new()
	runtime.name = "ProjectChoirRuntime"
	city.add_child(runtime)
	runtime.setup(city, progress)
	return runtime


func setup(city: CitySlice, progress: CampaignProgressStore) -> void:
	_city = city
	campaign_progress = progress
	if campaign_progress == null:
		campaign_progress = CampaignProgressStore.new()
		campaign_progress.name = "EphemeralCampaignProgressStore"
		add_child(campaign_progress)
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
	city.run_lifecycle.run_finished.connect(_on_run_finished)
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


func _on_run_finished(completed: bool, _summary: RunSummarySnapshot) -> void:
	if not completed:
		director.record_chassis_loss()
	_city.gameplay_hud._set_campaign_summary(
		campaign_progress.dossier_count(),
		campaign_progress.continuity_generation()
	)
