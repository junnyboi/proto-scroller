extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")

var city: CitySlice
var main: Main


func after_each() -> void:
	if get_tree().paused:
		get_tree().paused = false
	RuntimeTweakAccess.unbind_service()


func test_pause_adapter_freezes_tree_neutralizes_input_and_restores_exact_state() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var adapter: RuntimeTweakPauseAdapter = RuntimeTweakPauseAdapter.new()
	Input.action_press(&"stomp")
	Input.action_press(&"dodge")
	var mobile_before: bool = city.mobile_controls.controls_enabled()
	var physics_before: bool = city.robot.is_physics_processing()
	assert_true(adapter.acquire(city))
	assert_true(get_tree().paused)
	assert_false(Input.is_action_pressed(&"stomp"))
	assert_false(Input.is_action_pressed(&"dodge"))
	assert_false(city.mobile_controls.controls_enabled())
	assert_false(city.robot.is_physics_processing())
	assert_eq(city.urban_siege.pause_coordinator.lease_reasons(), [&"runtime_tuning"])
	var robot_position: Vector2 = city.robot.global_position
	var hazard_activations: int = city.urban_siege.hazards.activation_count
	var timer_finished: Array[bool] = [false]
	get_tree().create_timer(0.01, false).timeout.connect(func() -> void:
		timer_finished[0] = true
	)
	for _frame: int in range(120):
		await get_tree().process_frame
	assert_eq(city.robot.global_position, robot_position)
	assert_eq(city.urban_siege.hazards.activation_count, hazard_activations)
	assert_false(timer_finished[0])
	assert_true(adapter.release())
	assert_false(get_tree().paused)
	await get_tree().create_timer(0.02).timeout
	assert_true(timer_finished[0])
	assert_eq(city.mobile_controls.controls_enabled(), mobile_before)
	assert_eq(city.robot.is_physics_processing(), physics_before)


func test_modal_policy_rejects_existing_pause_owner_without_stealing_lease() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var coordinator: RunPauseCoordinator = city.urban_siege.pause_coordinator
	var field_token: int = coordinator.acquire(&"field_briefing")
	var status: Dictionary = RuntimeTweakModalPolicy.entry_status(city)
	assert_false(bool(status.allowed))
	assert_eq(status.reason, &"field_briefing")
	var adapter: RuntimeTweakPauseAdapter = RuntimeTweakPauseAdapter.new()
	assert_false(adapter.acquire(city))
	assert_eq(coordinator.lease_count(), 1)
	assert_true(coordinator.release(field_token))


func test_main_mounts_fixed_panel_and_space_cannot_activate_focused_close() -> void:
	main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.start_game()
	await get_tree().process_frame
	var panel: RuntimeTweakPanel = main.runtime_tweak_panel
	assert_not_null(panel)
	assert_not_null(main.runtime_tweak_layer)
	assert_eq(main.runtime_tweak_layer.layer, 200)
	assert_eq(panel.get_parent(), main.runtime_tweak_layer)
	assert_eq(panel.rows.size(), RuntimeTweakPanel.ROW_POOL_SIZE)
	assert_eq(panel.category_selector.item_count, 8)
	assert_true(panel.open())
	assert_true(get_tree().paused)
	panel.close_button.grab_focus()
	var space: InputEventKey = InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	panel._unhandled_input(space)
	assert_true(panel.is_open())
	assert_true(get_tree().paused)
	assert_true(panel.close())
	assert_false(get_tree().paused)


func test_panel_fits_landscape_and_portrait_without_rebuilding_rows() -> void:
	main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	var panel: RuntimeTweakPanel = main.runtime_tweak_panel
	var row_ids: Array[int] = []
	for row: TweakControlRow in panel.rows:
		row_ids.append(row.get_instance_id())
	for size: Vector2 in [Vector2(1280.0, 720.0), Vector2(720.0, 1280.0)]:
		panel.apply_responsive_layout(size)
		assert_eq(panel.grow_horizontal, Control.GROW_DIRECTION_END)
		assert_eq(panel.grow_vertical, Control.GROW_DIRECTION_END)
		assert_eq(panel.position, Vector2.ZERO)
		assert_eq(panel.size, size)
		assert_gte(panel.frame.position.x, 0.0)
		assert_gte(panel.frame.position.y, 0.0)
		assert_lte(panel.frame.position.x + panel.frame.size.x, size.x)
		assert_lte(panel.frame.position.y + panel.frame.size.y, size.y)
	var final_ids: Array[int] = []
	for row: TweakControlRow in panel.rows:
		final_ids.append(row.get_instance_id())
	assert_eq(final_ids, row_ids)


func test_sandbox_denial_is_clean_and_success_marks_run_without_node_growth() -> void:
	main = MAIN_SCENE.instantiate() as Main
	add_child_autofree(main)
	await get_tree().process_frame
	main.start_game()
	await get_tree().process_frame
	var panel: RuntimeTweakPanel = main.runtime_tweak_panel
	assert_true(panel.open())
	var service: RuntimeTweakService = main.runtime_tweak_service
	var node_count_before: int = _node_count(main.city_slice)
	var denied: Dictionary = panel.sandbox.spawn_enemy(&"not_allowlisted")
	assert_false(bool(denied.ok))
	assert_eq(service.provenance.status, RunTuningProvenance.BASELINE)
	var spawned: Dictionary = panel.sandbox.spawn_enemy(&"soldier")
	assert_true(bool(spawned.ok))
	assert_eq(service.provenance.status, RunTuningProvenance.SANDBOX)
	assert_eq(_node_count(main.city_slice), node_count_before)
	main.city_slice.robot.current_health = main.city_slice.robot.max_health - 150.0
	var repaired: Dictionary = panel.sandbox.repair_chassis()
	assert_true(bool(repaired.ok))
	assert_eq(repaired.amount, TuningSandboxRunner.REPAIR_GRANT)
	assert_true(panel.close())


func _node_count(root: Node) -> int:
	var total: int = 1
	for child: Node in root.get_children():
		total += _node_count(child)
	return total
