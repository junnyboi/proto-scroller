class_name HazardPressureController
extends RefCounted

const SYSTEM_SALT: int = 0x48A2A4D
const MINIMUM_DISTANCE: float = 300.0
const MAXIMUM_DISTANCE: float = 520.0

var runtime: HazardRuntime
var assignments: Array[Dictionary] = []
var roll_count: int = 0
var last_used_budget: int = 0
var peak_used_budget: int = 0
var _seed: int = SYSTEM_SALT
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(p_runtime: HazardRuntime) -> void:
	runtime = p_runtime


func configure(run_seed: int, cycle: int) -> void:
	_seed = run_seed ^ SYSTEM_SALT ^ maxi(cycle, 1) * 1237
	_rng.seed = _seed
	assignments.clear()
	roll_count = 0
	last_used_budget = 0
	peak_used_budget = 0


func reset_sequence() -> void:
	_rng.seed = _seed
	assignments.clear()
	roll_count = 0
	last_used_budget = 0


func plan_for_beat(
	act_index: int,
	beat_index: int,
	act: DistrictAct,
	beat: DistrictBeat,
	robot_x: float
) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	last_used_budget = 0
	if (
		runtime == null
		or not act.chaos_enabled
		or act.hazard_pressure_budget <= 0
		or act.hazard_events_per_beat <= 0
	):
		return plan
	var candidates: Array[StringName] = _eligible_ids(act_index)
	for actor: EnvironmentalHazard2D in runtime.actors:
		if actor.active:
			candidates.erase(StringName(actor.get_meta(&"pool_hazard_id", &"")))
	for event_index: int in range(act.hazard_events_per_beat):
		var affordable: Array[StringName] = []
		for hazard_id: StringName in candidates:
			var candidate_cost: int = EnvironmentalHazardCatalog.pressure_cost(hazard_id)
			if last_used_budget + candidate_cost <= act.hazard_pressure_budget:
				affordable.append(hazard_id)
		if affordable.is_empty():
			break
		var draw: int = _rng.randi_range(0, affordable.size() - 1)
		var hazard_id: StringName = affordable[draw]
		roll_count += 1
		candidates.erase(hazard_id)
		var side: int = -1 if _rng.randf() < 0.5 else 1
		var distance: float = _rng.randf_range(MINIMUM_DISTANCE, MAXIMUM_DISTANCE)
		var world_x: float = clampf(robot_x + float(side) * distance, 140.0, 2420.0)
		var delay: float = 0.55 + float(event_index) * 0.88 + _rng.randf_range(0.0, 0.38)
		roll_count += 3
		var selected_cost: int = EnvironmentalHazardCatalog.pressure_cost(hazard_id)
		last_used_budget += selected_cost
		var record: Dictionary = {
			"hazard_id": hazard_id,
			"remaining": delay,
			"position": Vector2(world_x, CitySlice.LAND_VISUAL_BASELINE_Y),
			"facing": -side,
			"cost": selected_cost,
			"act_index": act_index,
			"beat_index": beat_index,
			"beat_id": beat.beat_id,
		}
		plan.append(record)
		assignments.append(record.duplicate())
	peak_used_budget = maxi(peak_used_budget, last_used_budget)
	return plan


func _eligible_ids(act_index: int) -> Array[StringName]:
	if act_index <= 3:
		return [&"traffic_signal", &"steam_main", &"road_plate", &"metro_vent"]
	if act_index == 4:
		return [
			&"traffic_signal", &"steam_main", &"powerline", &"road_plate",
			&"crane_drop", &"gas_fireline", &"metro_vent",
		]
	return EnvironmentalHazardCatalog.ACTIVE_IDS.duplicate()
