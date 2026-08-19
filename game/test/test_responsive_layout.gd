extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const TITLE_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const PORTRAIT_SIZE: Vector2i = Vector2i(720, 1280)
const LANDSCAPE_SIZE: Vector2i = Vector2i(1280, 720)


func after_each() -> void:
	_set_viewport(LANDSCAPE_SIZE)
	await get_tree().process_frame


func test_orientation_manager_swaps_design_size_without_distortion() -> void:
	var responsive: ResponsiveViewport = ResponsiveViewport.new()
	add_child_autofree(responsive)
	responsive.setup()
	responsive.apply_window_size(PORTRAIT_SIZE)
	assert_true(responsive.portrait_mode)
	assert_eq(responsive.design_size, PORTRAIT_SIZE)
	assert_eq(get_window().content_scale_size, PORTRAIT_SIZE)
	assert_eq(get_window().content_scale_aspect, Window.CONTENT_SCALE_ASPECT_KEEP)
	responsive.apply_window_size(LANDSCAPE_SIZE)
	assert_false(responsive.portrait_mode)
	assert_eq(responsive.design_size, LANDSCAPE_SIZE)
	assert_eq(get_window().content_scale_size, LANDSCAPE_SIZE)


func test_title_reflows_inside_portrait_and_returns_to_landscape() -> void:
	_set_viewport(PORTRAIT_SIZE)
	var screen: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(screen.is_portrait_layout())
	assert_true(_inside_viewport(screen.get_node("HeroStack") as Control, PORTRAIT_SIZE))
	assert_true(_inside_viewport(screen.get_node("TelemetryPanel") as Control, PORTRAIT_SIZE))
	assert_true(_inside_viewport(screen.get_node("BottomRail") as Control, PORTRAIT_SIZE))
	assert_false(
		(screen.get_node("HeroStack/ActionRow/InitializeButton") as Button)
		.get_global_rect()
		.intersects((screen.get_node("BottomRail") as Control).get_global_rect())
	)
	_set_viewport(LANDSCAPE_SIZE)
	await get_tree().process_frame
	assert_false(screen.is_portrait_layout())
	assert_eq((screen.get_node("TelemetryPanel") as Control).position, Vector2(752.0, 82.0))


func test_city_portrait_hud_camera_and_mobile_controls_use_safe_zones() -> void:
	_set_viewport(PORTRAIT_SIZE)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	await get_tree().physics_frame
	var camera_rig: CameraRig = city.get_node("CameraRig") as CameraRig
	assert_true(camera_rig.is_portrait_framing())
	assert_gte(camera_rig.visible_world_size().x, 479.0)
	assert_gte(camera_rig.visible_world_size().y, 853.0)
	assert_eq(city.gameplay_hud.status_panel.position, Vector2.ZERO)
	assert_eq(city.gameplay_hud.status_panel.size, Vector2(300.0, 48.0))
	assert_lte(city.gameplay_hud.score_panel.get_rect().end.y, 172.0)
	assert_lte(city.gameplay_hud.weapon_status_strip.get_rect().end.y, 224.0)
	var hud_footprint: Rect2 = Rect2(Vector2.ZERO, Vector2(300.0, 224.0))
	assert_lt(
		hud_footprint.get_area() / (float(PORTRAIT_SIZE.x) * float(PORTRAIT_SIZE.y)),
		0.08
	)
	assert_eq(city.gameplay_hud.siege_progress.segments.size(), 6)
	assert_true(_inside_viewport(city.gameplay_hud.status_panel, PORTRAIT_SIZE))
	assert_true(_inside_viewport(city.gameplay_hud.score_panel, PORTRAIT_SIZE))
	assert_true(_inside_viewport(city.gameplay_hud.experience_track, PORTRAIT_SIZE))
	assert_true(_inside_viewport(city.gameplay_hud.directive_card, PORTRAIT_SIZE))
	assert_true(_inside_viewport(city.mobile_controls.smash_button, PORTRAIT_SIZE))
	assert_false(
		city.gameplay_hud.directive_card.get_global_rect().intersects(
			city.mobile_controls.smash_bounds()
		)
	)
	city.encounter_runtime.release_all()
	var helicopter: HelicopterEnemy = city.encounter_runtime.acquire(
		&"helicopter",
		Vector2(city.robot.global_position.x, 180.0)
	) as HelicopterEnemy
	assert_not_null(helicopter)
	assert_eq(helicopter.effective_standoff_x(), 280.0)
	var visible_world: Vector2 = camera_rig.visible_world_size()
	var world_view: Rect2 = Rect2(
		camera_rig.global_position - visible_world * 0.5,
		visible_world
	)
	assert_true(world_view.has_point(helicopter.global_position))
	var screen_scale: Vector2 = Vector2(PORTRAIT_SIZE) / visible_world
	var helicopter_screen_position: Vector2 = (
		helicopter.global_position - world_view.position
	) * screen_scale
	assert_false(hud_footprint.has_point(helicopter_screen_position))
	assert_eq(city.gameplay_hud.directive_choice_overlay.buttons.size(), 3)
	for button: Button in city.gameplay_hud.directive_choice_overlay.buttons:
		assert_true(_inside_viewport(button, PORTRAIT_SIZE))


func test_resize_preserves_touch_ownership_and_runtime_node_count() -> void:
	_set_viewport(LANDSCAPE_SIZE)
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	var controls: MobileControls = city.mobile_controls
	controls.handle_touch_input(_screen_touch(3, Vector2(220.0, 520.0), true))
	var smash_position: Vector2 = controls.smash_bounds().get_center()
	controls.handle_touch_input(_screen_touch(8, smash_position, true))
	var node_count: int = RuntimeBudget.snapshot(city).node_count
	_set_viewport(PORTRAIT_SIZE)
	await get_tree().process_frame
	assert_eq(controls.joystick_touch_index(), 3)
	assert_eq(controls.smash_touch_index(), 8)
	assert_true(controls.joystick_active)
	assert_eq(RuntimeBudget.snapshot(city).node_count, node_count)
	_set_viewport(LANDSCAPE_SIZE)
	await get_tree().process_frame
	assert_eq(controls.joystick_touch_index(), 3)
	assert_eq(controls.smash_touch_index(), 8)
	assert_eq(RuntimeBudget.snapshot(city).node_count, node_count)
	controls.handle_touch_input(_screen_touch(8, controls.smash_bounds().get_center(), false))
	controls.handle_touch_input(_screen_touch(3, Vector2(220.0, 520.0), false))


func _inside_viewport(control: Control, viewport_size: Vector2) -> bool:
	return Rect2(Vector2.ZERO, viewport_size).encloses(control.get_global_rect())


func _set_viewport(viewport_size: Vector2i) -> void:
	get_window().content_scale_size = viewport_size
	get_tree().root.size = viewport_size


func _screen_touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event
