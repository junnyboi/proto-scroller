class_name NarrativeDirector
extends Node

signal transmission_requested(
	event_id: StringName,
	speaker_key: String,
	line_key: String,
	duration: float,
	priority: int
)
signal dossier_collected(
	definition: DossierDefinition,
	total: int,
	district_total: int
)
signal facade_reveal_requested(
	building: StructuralBuilding2D,
	definition: DossierDefinition
)
signal district_arrived(district_id: StringName)

const DISTRICT_IDS: Array[StringName] = [
	&"BUSINESS", &"RESIDENTIAL", &"ENTERTAINMENT", &"MILITARY", &"ROYAL",
]
const HYBRID_IDS: Array[StringName] = [
	&"reclaimed_breacher", &"graft_runner", &"choir_siren",
	&"ossuary_crawler", &"seraph_carrier", &"pale_engine",
]

var campaign_progress: CampaignProgressStore
var run_seed: int = 0
var _fired_events: Dictionary[StringName, bool] = {}
var _arrived_districts: Dictionary[StringName, bool] = {}


func setup(progress: CampaignProgressStore) -> void:
	campaign_progress = progress


func begin_run(p_run_seed: int, initial_district_id: StringName = &"BUSINESS") -> void:
	run_seed = p_run_seed
	_fired_events.clear()
	_arrived_districts.clear()
	handle_spatial_district_arrival(initial_district_id)


func handle_spatial_district_arrival(district_id: StringName) -> void:
	if not district_id in DISTRICT_IDS or _arrived_districts.has(district_id):
		return
	_arrived_districts[district_id] = true
	district_arrived.emit(district_id)
	_queue_transmission(
		StringName("district_%s_arrival" % String(district_id).to_lower()),
		"narrative.speaker.echo7",
		"narrative.district.%s.arrival" % String(district_id).to_lower(),
		4.2,
		2
	)


func handle_building_cell_destroyed(
	building: StructuralBuilding2D,
	column: int,
	row: int
) -> void:
	if campaign_progress == null or building == null:
		return
	var variant_id: StringName = building.current_variant_id()
	var definition: DossierDefinition = DossierCatalog.definition_for_variant(variant_id)
	if definition == null or not definition.trigger_matches(column, row):
		return
	if not campaign_progress.collect_dossier(definition.dossier_id):
		return
	facade_reveal_requested.emit(building, definition)
	dossier_collected.emit(
		definition,
		campaign_progress.dossier_count(),
		campaign_progress.district_dossier_count(definition.district_id)
	)
	_queue_transmission(
		StringName("recovered_%s" % definition.dossier_id),
		"narrative.speaker.protos",
		"narrative.transmission.dossier_recovered",
		3.2,
		3
	)
	if definition.building_variant_id == &"business_mercy_exchange_annex":
		_queue_transmission(
			&"opening_black_lab_reveal",
			"narrative.speaker.echo7",
			"narrative.transmission.black_lab_revealed",
			5.0,
			4
		)


func record_chassis_loss() -> int:
	if campaign_progress == null:
		return 0
	var generation: int = campaign_progress.increment_continuity()
	_queue_transmission(
		StringName("continuity_%d" % generation),
		"narrative.speaker.system",
		"narrative.transmission.continuity",
		4.0,
		5
	)
	return generation


func handle_enemy_acquired(enemy: EnemyActor2D) -> void:
	if not enemy is ProceduralEnemy:
		return
	var hybrid_id: StringName = (enemy as ProceduralEnemy).archetype_id
	if not hybrid_id in HYBRID_IDS:
		return
	_queue_transmission(
		StringName("hybrid_%s_contact" % hybrid_id),
		"narrative.speaker.echo7",
		"narrative.enemy.%s.contact" % hybrid_id,
		4.6,
		3
	)


func fired_event_count() -> int:
	return _fired_events.size()


func arrived_district_count() -> int:
	return _arrived_districts.size()


func _queue_transmission(
	event_id: StringName,
	speaker_key: String,
	line_key: String,
	duration: float,
	priority: int
) -> void:
	if _fired_events.has(event_id):
		return
	_fired_events[event_id] = true
	transmission_requested.emit(event_id, speaker_key, line_key, duration, priority)
