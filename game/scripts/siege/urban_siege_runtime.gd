class_name UrbanSiegeRuntime
extends Node

signal act_changed(index: int, act_id: StringName, display_name: String)
signal beat_changed(act_index: int, beat_index: int, beat_id: StringName)
signal recovery_started(duration: float)
signal milestone_reached(milestone: StringName)
signal district_completed

const DIRECTOR_SCRIPT: Script = preload("res://scripts/siege/district_response_director.gd")
const CATALYST_RUNTIME_SCRIPT: Script = preload(
	"res://scripts/destruction/catalysts/catalyst_runtime.gd"
)

var dependencies: UrbanSiegeDependencies
var district: DistrictDefinition
var director: DistrictResponseDirector
var catalysts: CatalystRuntime
var run_seed: int = 0


func setup(p_dependencies: UrbanSiegeDependencies, p_district: DistrictDefinition) -> void:
	dependencies = p_dependencies
	district = p_district
	director = DIRECTOR_SCRIPT.new() as DistrictResponseDirector
	director.name = "DistrictResponseDirector"
	director.setup_district(dependencies.encounter_runtime, district)
	director.phase_changed.connect(_on_phase_changed)
	director.beat_changed.connect(beat_changed.emit)
	director.recovery_started.connect(recovery_started.emit)
	director.milestone_reached.connect(milestone_reached.emit)
	director.district_completed.connect(district_completed.emit)
	add_child(director)
	catalysts = CATALYST_RUNTIME_SCRIPT.new() as CatalystRuntime
	catalysts.name = "CatalystRuntime"
	catalysts.setup(dependencies)
	add_child(catalysts)


func start_run(p_seed: int = 0) -> void:
	run_seed = p_seed
	director.start()


func stop_run() -> void:
	if director != null:
		director.stop()
	if catalysts != null:
		catalysts.deactivate_all()


func reset_run() -> void:
	stop_run()
	if director != null:
		director.reset_to_contact()


func is_simulation_paused() -> bool:
	return false


func _on_phase_changed(index: int, display_name: String) -> void:
	var act_id: StringName = &""
	if district != null and index >= 0 and index < district.acts.size():
		act_id = district.acts[index].act_id
	act_changed.emit(index, act_id, display_name)
