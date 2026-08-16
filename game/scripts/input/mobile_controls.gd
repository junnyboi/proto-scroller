class_name MobileControls
extends Control

signal move_axis_changed(axis: float)
signal smash_pressed

const JOYSTICK_RADIUS: float = 78.0
const KNOB_RADIUS: float = 34.0
const EDGE_PADDING: float = 14.0

@export_range(-1, 1, 1) var detection_override: int = -1
@export_range(0.0, 0.5, 0.01) var deadzone: float = 0.14
@export_range(1.0, 30.0, 0.5) var response_speed: float = 13.0
@export_range(0.1, 1.0, 0.05) var smash_cooldown: float = 0.40

var mobile_device_detected: bool = false
var joystick_active: bool = false
var smash_button: Button
var smash_press_count: int = 0
var haptic_request_count: int = 0
var last_haptic_duration_ms: int = 0
var robot: GiantRobotController
var _controls_enabled: bool = true
var _joystick_touch_index: int = -1
var _smash_touch_index: int = -1
var _touch_anchor: Vector2
var _joystick_origin: Vector2
var _knob_offset: Vector2
var _target_axis: float = 0.0
var _current_axis: float = 0.0
var _smash_cooldown_remaining: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_sync_to_viewport()
	get_viewport().size_changed.connect(_sync_to_viewport)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	mobile_device_detected = _detect_mobile_device()
	if robot != null:
		move_axis_changed.connect(robot.set_virtual_move_axis)
		smash_pressed.connect(robot.request_stomp)
		robot.heavy_impact_requested.connect(play_smash_impact_haptic)
	_build_smash_button()
	visible = mobile_device_detected
	set_process(mobile_device_detected)
	set_process_input(mobile_device_detected)


func _process(delta: float) -> void:
	process_controls(delta)


func _input(event: InputEvent) -> void:
	handle_touch_input(event)


func process_controls(delta: float) -> void:
	if not mobile_device_detected:
		return
	_smash_cooldown_remaining = maxf(
		_smash_cooldown_remaining - delta,
		0.0
	)
	var previous_axis: float = _current_axis
	_current_axis = move_toward(
		_current_axis,
		_target_axis if _controls_enabled else 0.0,
		response_speed * delta
	)
	if not is_equal_approx(previous_axis, _current_axis):
		move_axis_changed.emit(_current_axis)
	queue_redraw()


func handle_touch_input(event: InputEvent) -> void:
	if not mobile_device_detected or not _controls_enabled:
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)


func movement_axis() -> float:
	return _current_axis


func setup(p_robot: GiantRobotController, p_detection_override: int = -1) -> void:
	robot = p_robot
	detection_override = p_detection_override


func smash_bounds() -> Rect2:
	if smash_button == null:
		return Rect2()
	return smash_button.get_global_rect()


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if smash_button != null:
		smash_button.modulate.a = 1.0 if enabled else 0.35
	if not enabled:
		_release_joystick()
		_release_smash()
		_current_axis = 0.0
		move_axis_changed.emit(0.0)


func play_smash_impact_haptic(
	_origin: Vector2,
	_radius: float,
	_damage: float,
	_impulse_per_mass: float,
	_attack_id: int
) -> void:
	_request_haptic(28)


func play_building_destruction_haptic(
	_column: int,
	_row: int,
	_event: DamageEvent
) -> void:
	_request_haptic(48)


func _detect_mobile_device() -> bool:
	if detection_override >= 0:
		return detection_override == 1
	if OS.has_feature("web"):
		var browser_touch: Variant = JavaScriptBridge.eval(
			"(navigator.maxTouchPoints || 0) > 0",
			true
		)
		if bool(browser_touch):
			return true
	return (
		OS.has_feature("mobile")
		or OS.has_feature("android")
		or OS.has_feature("ios")
		or DisplayServer.is_touchscreen_available()
	)


func _request_haptic(duration_ms: int) -> void:
	if not mobile_device_detected or not _controls_enabled:
		return
	last_haptic_duration_ms = clampi(duration_ms, 1, 100)
	haptic_request_count += 1
	if detection_override >= 0:
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"navigator.vibrate && navigator.vibrate(%d)" % last_haptic_duration_ms,
			true
		)
		return
	Input.vibrate_handheld(last_haptic_duration_ms)


func _sync_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _build_smash_button() -> void:
	smash_button = Button.new()
	smash_button.name = "SmashButton"
	smash_button.text = "SMASH"
	smash_button.focus_mode = Control.FOCUS_NONE
	smash_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smash_button.anchor_left = 1.0
	smash_button.anchor_top = 1.0
	smash_button.anchor_right = 1.0
	smash_button.anchor_bottom = 1.0
	smash_button.offset_left = -168.0
	smash_button.offset_top = -168.0
	smash_button.offset_right = -36.0
	smash_button.offset_bottom = -36.0
	smash_button.add_theme_font_size_override(&"font_size", 25)
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.10, 0.15, 0.18, 0.84)
	normal_style.border_color = Color(0.95, 0.47, 0.25, 0.90)
	normal_style.set_border_width_all(4)
	normal_style.corner_radius_top_left = 66
	normal_style.corner_radius_top_right = 66
	normal_style.corner_radius_bottom_left = 66
	normal_style.corner_radius_bottom_right = 66
	smash_button.add_theme_stylebox_override(&"normal", normal_style)
	smash_button.add_theme_stylebox_override(&"hover", normal_style)
	smash_button.add_theme_stylebox_override(&"focus", normal_style)
	add_child(smash_button)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if smash_bounds().has_point(event.position):
			_press_smash(event.index)
		elif _joystick_touch_index == -1:
			_press_joystick(event.index, event.position)
	else:
		if event.index == _joystick_touch_index:
			_release_joystick()
		if event.index == _smash_touch_index:
			_release_smash()
	get_viewport().set_input_as_handled()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != _joystick_touch_index:
		return
	var displacement: Vector2 = event.position - _touch_anchor
	_knob_offset = displacement.limit_length(JOYSTICK_RADIUS)
	var raw_axis: float = clampf(
		displacement.x / JOYSTICK_RADIUS,
		-1.0,
		1.0
	)
	_target_axis = _apply_deadzone(raw_axis)
	queue_redraw()
	get_viewport().set_input_as_handled()


func _press_joystick(touch_index: int, touch_position: Vector2) -> void:
	_joystick_touch_index = touch_index
	_touch_anchor = touch_position
	var viewport_size: Vector2 = get_viewport_rect().size
	_joystick_origin = Vector2(
		clampf(
			touch_position.x,
			JOYSTICK_RADIUS + EDGE_PADDING,
			viewport_size.x - JOYSTICK_RADIUS - EDGE_PADDING
		),
		clampf(
			touch_position.y,
			JOYSTICK_RADIUS + EDGE_PADDING,
			viewport_size.y - JOYSTICK_RADIUS - EDGE_PADDING
		)
	)
	_knob_offset = Vector2.ZERO
	_target_axis = 0.0
	joystick_active = true
	queue_redraw()


func _release_joystick() -> void:
	_joystick_touch_index = -1
	_target_axis = 0.0
	_knob_offset = Vector2.ZERO
	joystick_active = false
	queue_redraw()


func _press_smash(touch_index: int) -> void:
	_smash_touch_index = touch_index
	smash_button.scale = Vector2(0.94, 0.94)
	smash_button.pivot_offset = smash_button.size * 0.5
	if _smash_cooldown_remaining > 0.0:
		return
	_smash_cooldown_remaining = smash_cooldown
	smash_press_count += 1
	smash_pressed.emit()


func _release_smash() -> void:
	_smash_touch_index = -1
	if smash_button != null:
		smash_button.scale = Vector2.ONE


func _apply_deadzone(raw_axis: float) -> float:
	var magnitude: float = absf(raw_axis)
	if magnitude <= deadzone:
		return 0.0
	return signf(raw_axis) * (magnitude - deadzone) / (1.0 - deadzone)


func _draw() -> void:
	if not joystick_active or not mobile_device_detected:
		return
	draw_circle(
		_joystick_origin,
		JOYSTICK_RADIUS,
		Color(0.06, 0.07, 0.08, 0.48)
	)
	draw_arc(
		_joystick_origin,
		JOYSTICK_RADIUS,
		0.0,
		TAU,
		48,
		Color(0.72, 0.74, 0.76, 0.58),
		3.0,
		true
	)
	var knob_center: Vector2 = _joystick_origin + _knob_offset
	draw_circle(
		knob_center,
		KNOB_RADIUS,
		Color(0.80, 0.81, 0.82, 0.94)
	)
