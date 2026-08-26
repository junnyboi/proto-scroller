class_name RunSummarySnapshot
extends RefCounted

var score: int:
	get:
		return _score
var peak_combo: int:
	get:
		return _peak_combo
var best_chain: int:
	get:
		return _best_chain
var waves_cleared: int:
	get:
		return _waves_cleared
var overdrive_activations: int:
	get:
		return _overdrive_activations
var rare_events: Dictionary[StringName, int]:
	get:
		return _rare_events.duplicate()
var grade: StringName:
	get:
		return _grade
var mastery_points: int:
	get:
		return _mastery_points
var strongest_metric: StringName:
	get:
		return _strongest_metric
var weakest_metric: StringName:
	get:
		return _weakest_metric
var retry_objective: String:
	get:
		return _retry_objective
var heavy_hits: int:
	get:
		return _heavy_hits
var unique_actions: int:
	get:
		return _unique_actions
var causal_depth: int:
	get:
		return _causal_depth
var directive_path: StringName:
	get:
		return _directive_path
var boss_result: StringName:
	get:
		return _boss_result
var contract_result: StringName:
	get:
		return _contract_result
var run_seed: int:
	get:
		return _run_seed
var cycle_count: int:
	get:
		return _cycle_count
var ending_id: StringName:
	get:
		return _ending_id

var _score: int
var _peak_combo: int
var _best_chain: int
var _waves_cleared: int
var _overdrive_activations: int
var _rare_events: Dictionary[StringName, int]
var _grade: StringName
var _mastery_points: int
var _strongest_metric: StringName
var _weakest_metric: StringName
var _retry_objective: String
var _heavy_hits: int
var _unique_actions: int
var _causal_depth: int
var _directive_path: StringName
var _boss_result: StringName
var _contract_result: StringName
var _run_seed: int
var _cycle_count: int
var _ending_id: StringName


func _init(
	p_score: int,
	p_peak_combo: int,
	p_best_chain: int,
	p_waves_cleared: int,
	p_overdrive_activations: int,
	p_rare_events: Dictionary[StringName, int],
	metrics: Dictionary = {}
) -> void:
	_score = p_score
	_peak_combo = p_peak_combo
	_best_chain = p_best_chain
	_waves_cleared = p_waves_cleared
	_overdrive_activations = p_overdrive_activations
	_rare_events = p_rare_events.duplicate()
	_grade = metrics.get("grade", &"D") as StringName
	_mastery_points = int(metrics.get("mastery_points", 0))
	_strongest_metric = metrics.get("strongest", &"DISTRICT") as StringName
	_weakest_metric = metrics.get("weakest", &"DISTRICT") as StringName
	_retry_objective = String(metrics.get("objective", "summary.retry.reach_next_act"))
	_heavy_hits = int(metrics.get("heavy_hits", 0))
	_unique_actions = int(metrics.get("unique_actions", 0))
	_causal_depth = int(metrics.get("causal_depth", 0))
	_directive_path = metrics.get("directive_path", &"NONE") as StringName
	_boss_result = metrics.get("boss_result", &"UNRESOLVED") as StringName
	_contract_result = metrics.get("contract_result", &"NONE") as StringName
	_run_seed = int(metrics.get("run_seed", 0))
	_cycle_count = int(metrics.get("cycle_count", 1))
	_ending_id = metrics.get("ending_id", &"NONE") as StringName
