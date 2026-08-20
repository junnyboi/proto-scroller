extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func after_each() -> void:
	Input.action_release(&"stomp")


func test_upgrade_setup_executes_outside_release_stripped_assertions() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/gameplay/city_slice.gd"
	)
	assert_true(source.contains("upgrade_assembler.setup(self)"))
	assert_false(source.contains("assert(upgrade_assembler.setup(self)"))


func test_level_offer_waits_for_triggering_smash_release_before_accepting_input() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var overlay: UpgradeChoiceOverlay = city.gameplay_hud.upgrade_choice_overlay
	var session: UpgradeSession = city.upgrade_assembler.session
	Input.action_press(&"stomp")
	var reward: GameplayEvent = GameplayEvent.new(
		&"held-smash-upgrade",
		1,
		GameplayEvent.Kind.ENEMY_DEFEATED,
		GameplayEvent.SOLDIER_LAUNCH,
		1500
	)
	assert_true(city.rampage_session.publish(reward))
	await get_tree().process_frame
	assert_true(overlay.visible)
	assert_not_null(session.active_offer)
	assert_true(city.urban_siege.pause_coordinator.is_paused())
	assert_true(overlay.cards[0].disabled)
	assert_true(overlay.cards[1].disabled)
	Input.action_release(&"stomp")
	await get_tree().process_frame
	assert_true(overlay.visible)
	assert_not_null(session.active_offer)
	assert_false(overlay.cards[0].disabled)
	assert_false(overlay.cards[1].disabled)


func test_level_offer_uses_two_fixed_cards_and_preserves_mobile_touches() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	var overlay: UpgradeChoiceOverlay = city.gameplay_hud.upgrade_choice_overlay
	var session: UpgradeSession = city.upgrade_assembler.session
	var baseline_nodes: int = int(RuntimeBudget.snapshot(city).node_count)
	assert_false(overlay.visible)
	assert_eq(overlay.cards.size(), 2)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var joystick_press: InputEventScreenTouch = _touch(4, Vector2(180.0, 520.0), true)
	var smash_position: Vector2 = city.mobile_controls.smash_bounds().get_center()
	var smash_press: InputEventScreenTouch = _touch(9, smash_position, true)
	city.mobile_controls.handle_touch_input(joystick_press)
	city.mobile_controls.handle_touch_input(smash_press)
	assert_eq(city.mobile_controls.joystick_touch_index(), 4)
	assert_eq(city.mobile_controls.smash_touch_index(), 9)
	var reward: GameplayEvent = GameplayEvent.new(
		&"open-upgrade",
		1,
		GameplayEvent.Kind.ENEMY_DEFEATED,
		GameplayEvent.SOLDIER_LAUNCH,
		1500
	)
	assert_true(city.rampage_session.publish(reward))
	await get_tree().process_frame
	assert_true(overlay.visible)
	assert_true(city.urban_siege.pause_coordinator.is_paused())
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(session.active_offer.choice_ids.size(), 2)
	assert_ne(session.active_offer.choice_ids[0], session.active_offer.choice_ids[1])
	assert_eq(city.mobile_controls.joystick_touch_index(), 4)
	assert_eq(city.mobile_controls.smash_touch_index(), 9)
	var offer_sequence: int = session.active_offer.sequence
	var choices: PackedStringArray = session.active_offer.choice_ids.duplicate()
	get_window().content_scale_size = Vector2i(720, 1280)
	get_tree().root.size = Vector2i(720, 1280)
	await get_tree().process_frame
	assert_eq(session.active_offer.sequence, offer_sequence)
	assert_eq(session.active_offer.choice_ids, choices)
	assert_eq(city.mobile_controls.joystick_touch_index(), 4)
	assert_eq(city.mobile_controls.smash_touch_index(), 9)
	assert_true(_viewport_rect().encloses(overlay.cards[0].get_global_rect()))
	assert_true(_viewport_rect().encloses(overlay.cards[1].get_global_rect()))
	assert_false(overlay.cards[0].get_global_rect().intersects(
		overlay.cards[1].get_global_rect()
	))
	assert_eq(int(RuntimeBudget.snapshot(city).node_count), baseline_nodes)
	var selected: StringName = session.active_offer.choice_ids[0]
	assert_true(session.select_choice(selected, offer_sequence))
	assert_false(overlay.visible)
	assert_false(city.urban_siege.pause_coordinator.is_paused())
	assert_eq(city.mobile_controls.joystick_touch_index(), 4)
	assert_eq(city.mobile_controls.smash_touch_index(), 9)
	city.mobile_controls.handle_touch_input(_touch(4, Vector2.ZERO, false))
	city.mobile_controls.handle_touch_input(_touch(9, Vector2.ZERO, false))
	assert_eq(city.mobile_controls.joystick_touch_index(), -1)
	assert_eq(city.mobile_controls.smash_touch_index(), -1)
	get_window().content_scale_size = Vector2i(1280, 720)
	get_tree().root.size = Vector2i(1280, 720)


func test_runtime_budget_reports_fixed_upgrade_ui_shape() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	var snapshot: Dictionary = RuntimeBudget.snapshot(city)
	assert_eq(snapshot.upgrade_sessions, 1)
	assert_eq(snapshot.upgrade_overlays, 1)
	assert_eq(snapshot.upgrade_cards, 2)
	assert_eq(snapshot.weapon_status_strips, 1)
	assert_eq(RuntimeBudget.validation_errors(city), PackedStringArray())


func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _viewport_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(get_tree().root.size))
