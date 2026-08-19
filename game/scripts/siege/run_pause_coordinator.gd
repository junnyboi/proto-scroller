class_name RunPauseCoordinator
extends Node

signal pause_changed(paused: bool)

var dependencies: UrbanSiegeDependencies
var director: DistrictResponseDirector
var catalysts: CatalystRuntime
var _leases: Dictionary[int, StringName] = {}
var _next_token: int = 1


func setup(
	p_dependencies: UrbanSiegeDependencies,
	p_director: DistrictResponseDirector,
	p_catalysts: CatalystRuntime
) -> void:
	dependencies = p_dependencies
	director = p_director
	catalysts = p_catalysts


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


func _apply_pause(paused: bool) -> void:
	dependencies.robot.set_control_enabled(not paused)
	if paused:
		dependencies.city.contextual_attacks.cancel_attack()
	var preserve_upgrade_touches: bool = paused and _leases.values().has(&"upgrade_choice")
	dependencies.city.mobile_controls.set_controls_enabled(
		not paused,
		preserve_upgrade_touches
	)
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
	pause_changed.emit(paused)
