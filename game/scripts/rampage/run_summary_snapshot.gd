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

var _score: int
var _peak_combo: int
var _best_chain: int
var _waves_cleared: int
var _overdrive_activations: int
var _rare_events: Dictionary[StringName, int]


func _init(
	p_score: int,
	p_peak_combo: int,
	p_best_chain: int,
	p_waves_cleared: int,
	p_overdrive_activations: int,
	p_rare_events: Dictionary[StringName, int]
) -> void:
	_score = p_score
	_peak_combo = p_peak_combo
	_best_chain = p_best_chain
	_waves_cleared = p_waves_cleared
	_overdrive_activations = p_overdrive_activations
	_rare_events = p_rare_events.duplicate()
