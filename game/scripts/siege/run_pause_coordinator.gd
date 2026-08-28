class_name RunPauseCoordinator
extends Node

signal pause_changed(paused: bool)

var dependencies: UrbanSiegeDependencies
var director: DistrictResponseDirector
var catalysts: CatalystRuntime
var hazards: HazardRuntime
var _leases: Dictionary[int, StringName] = {}
var _next_token: int = 1


func setup(
	p_dependencies: UrbanSiegeDependencies,
	p_director: DistrictResponseDirector,
	p_catalysts: CatalystRuntime,
	p_hazards: HazardRuntime = null
) -> void:
	dependencies = p_dependencies
	director = p_director
	catalysts = p_catalysts
	hazards = p_hazards


func acquire(reason: StringName) -> int:
	var token: int = _next_token
	_next_token += 1
	_leases[token] = reason
	if _leases.size() == 1:
		_apply_pause(true)
	return token


func release(token: int) -> bool:
	if not _leases.has(token):
		return false
	_leases.erase(token)
	if _leases.is_empty():
		_apply_pause(false)
	return true


func release_all() -> void:
	_leases.clear()
	_apply_pause(false)


func is_paused() -> bool:
	return not _leases.is_empty()


func lease_count() -> int:
	return _leases.size()


func lease_reasons() -> Array[StringName]:
	var reasons: Array[StringName] = []
	for reason: StringName in _leases.values():
		reasons.append(reason)
	reasons.sort_custom(func(first: StringName, second: StringName) -> bool:
		return String(first) < String(second)
	)
	return reasons


func _apply_pause(paused: bool) -> void:
	dependencies.city.mobile_controls.set_controls_enabled(true)
	dependencies.encounter_runtime.set_attack_gate(not paused)
	dependencies.encounter_runtime.process_mode = (
		Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	)
	dependencies.projectile_pool.process_mode = (
		Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	)
	dependencies.telegraphs.process_mode = (
		Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	)
	director.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	catalysts.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	if hazards != null:
		if paused:
			hazards.set_paused(true)
			hazards.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			hazards.process_mode = Node.PROCESS_MODE_INHERIT
			hazards.set_paused(false)
	pause_changed.emit(paused)
