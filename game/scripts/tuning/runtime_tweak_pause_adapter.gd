class_name RuntimeTweakPauseAdapter
extends RefCounted

var city: CitySlice
var pause_coordinator: RunPauseCoordinator
var pause_token: int = 0
var tree_was_paused: bool = false
var robot_physics_was_enabled: bool = true
var mobile_controls_were_enabled: bool = true


func acquire(target_city: CitySlice) -> bool:
	if pause_token != 0 or target_city == null or target_city.urban_siege == null:
		return false
	city = target_city
	pause_coordinator = city.urban_siege.pause_coordinator
	if pause_coordinator == null or pause_coordinator.is_paused():
		city = null
		return false
	tree_was_paused = city.get_tree().paused
	if city.robot != null:
		robot_physics_was_enabled = city.robot.is_physics_processing()
		city.robot.set_virtual_move_axis(0.0)
		city.robot.set_physics_process(false)
	if city.mobile_controls != null:
		mobile_controls_were_enabled = city.mobile_controls.controls_enabled()
		city.mobile_controls.set_controls_enabled(false)
	_release_gameplay_actions()
	pause_token = pause_coordinator.acquire(&"runtime_tuning")
	if pause_token == 0:
		_restore_local_input()
		city = null
		return false
	if city.mobile_controls != null:
		city.mobile_controls.set_controls_enabled(false)
	city.get_tree().paused = true
	return true


func release() -> bool:
	if pause_token == 0 or city == null:
		return false
	var tree: SceneTree = city.get_tree()
	if pause_coordinator != null:
		pause_coordinator.release(pause_token)
	pause_token = 0
	tree.paused = tree_was_paused
	_restore_local_input()
	_release_gameplay_actions()
	city = null
	pause_coordinator = null
	return true


func is_active() -> bool:
	return pause_token != 0


func _restore_local_input() -> void:
	if city == null:
		return
	if city.robot != null:
		city.robot.set_virtual_move_axis(0.0)
		city.robot.set_physics_process(robot_physics_was_enabled)
	if city.mobile_controls != null:
		city.mobile_controls.set_controls_enabled(mobile_controls_were_enabled)


func _release_gameplay_actions() -> void:
	for action: StringName in [&"move_left", &"move_right", &"stomp", &"dodge"]:
		Input.action_release(action)
