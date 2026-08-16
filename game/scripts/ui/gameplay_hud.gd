class_name GameplayHud
extends CanvasLayer

signal retry_pressed

const PANEL_COLOR: Color = Color(0.03, 0.05, 0.08, 0.86)
const ACCENT_COLOR: Color = Color("f1b36f")
const MUTED_COLOR: Color = Color("b7c4cb")

var health_label: Label
var status_label: Label
var objective_label: Label
var score_label: Label
var combo_label: Label
var momentum_fill: ColorRect
var momentum_label: Label
var game_over_overlay: Control
var retry_button: Button
var _robot: GiantRobotController
var _pulse_age: float = 0.0


func setup(robot: GiantRobotController) -> void:
	_robot = robot


func _ready() -> void:
	name = "HUD"
	layer = 20
	_build_status_panel()
	_build_momentum_panel()
	_build_score_panel()
	_build_game_over_overlay()
	if _robot != null:
		set_health(_robot.current_health, _robot.max_health)
	set_score(0)
	set_combo(1, 0.0)
	set_momentum(0.0, 0)


func _process(delta: float) -> void:
	_pulse_age += delta
	if status_label != null:
		status_label.modulate.a = 0.86 + sin(_pulse_age * 2.2) * 0.14


func set_health(current: float, maximum: float) -> void:
	if health_label == null:
		return
	health_label.text = "CHASSIS %03d / %03d" % [roundi(current), roundi(maximum)]


func set_score(value: int) -> void:
	if score_label != null:
		score_label.text = "%08d" % maxi(value, 0)


func set_combo(multiplier: int, grace_remaining: float) -> void:
	if combo_label == null:
		return
	combo_label.text = "x%d COMBO" % clampi(multiplier, 1, 5)
	combo_label.visible = multiplier > 1
	combo_label.modulate.a = clampf(grace_remaining / 0.55, 0.55, 1.0)


func set_momentum(value: float, band: int) -> void:
	var clamped_value: float = clampf(value, 0.0, 100.0)
	if momentum_fill != null:
		momentum_fill.size.x = 392.0 * clamped_value / 100.0
		momentum_fill.color = _momentum_color(band)
	if momentum_label != null:
		momentum_label.text = "MOMENTUM %03d%%" % roundi(clamped_value)


func set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func set_objective(text: String) -> void:
	if objective_label != null:
		objective_label.text = text


func show_game_over() -> void:
	set_status("CITY RESPONSE / LOST")
	set_objective("CHASSIS SIGNAL TERMINATED")
	game_over_overlay.visible = true
	retry_button.grab_focus()


func _build_status_panel() -> void:
	var panel: ColorRect = ColorRect.new()
	panel.position = Vector2(24.0, 22.0)
	panel.size = Vector2(420.0, 112.0)
	panel.color = PANEL_COLOR
	add_child(panel)
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.position = Vector2(48.0, 34.0)
	status_label.text = "CITY RESPONSE / ACTIVE"
	status_label.add_theme_font_size_override(&"font_size", 24)
	status_label.modulate = ACCENT_COLOR
	add_child(status_label)
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.position = Vector2(48.0, 68.0)
	health_label.add_theme_font_size_override(&"font_size", 25)
	add_child(health_label)
	objective_label = Label.new()
	objective_label.name = "ObjectiveLabel"
	objective_label.position = Vector2(48.0, 100.0)
	objective_label.text = "A/D MOVE   SPACE STOMP   BREAK THE STREET"
	objective_label.add_theme_font_size_override(&"font_size", 20)
	objective_label.modulate = MUTED_COLOR
	add_child(objective_label)


func _build_momentum_panel() -> void:
	var panel: ColorRect = ColorRect.new()
	panel.position = Vector2(466.0, 22.0)
	panel.size = Vector2(500.0, 88.0)
	panel.color = PANEL_COLOR
	add_child(panel)
	momentum_label = Label.new()
	momentum_label.name = "MomentumLabel"
	momentum_label.position = Vector2(490.0, 30.0)
	momentum_label.size = Vector2(260.0, 28.0)
	momentum_label.add_theme_font_size_override(&"font_size", 18)
	momentum_label.modulate = MUTED_COLOR
	add_child(momentum_label)
	combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.position = Vector2(764.0, 28.0)
	combo_label.size = Vector2(176.0, 32.0)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.add_theme_font_size_override(&"font_size", 22)
	combo_label.modulate = ACCENT_COLOR
	add_child(combo_label)
	var momentum_track: ColorRect = ColorRect.new()
	momentum_track.name = "MomentumTrack"
	momentum_track.position = Vector2(490.0, 66.0)
	momentum_track.size = Vector2(452.0, 18.0)
	momentum_track.color = Color(0.11, 0.15, 0.18, 0.95)
	add_child(momentum_track)
	momentum_fill = ColorRect.new()
	momentum_fill.name = "MomentumFill"
	momentum_fill.position = Vector2(496.0, 71.0)
	momentum_fill.size = Vector2(0.0, 8.0)
	momentum_fill.color = Color("5dc9c2")
	add_child(momentum_fill)


func _build_score_panel() -> void:
	var panel: ColorRect = ColorRect.new()
	panel.position = Vector2(988.0, 22.0)
	panel.size = Vector2(268.0, 88.0)
	panel.color = PANEL_COLOR
	add_child(panel)
	var caption: Label = Label.new()
	caption.position = Vector2(1012.0, 30.0)
	caption.size = Vector2(220.0, 28.0)
	caption.text = "RAMPAGE SCORE"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.add_theme_font_size_override(&"font_size", 18)
	caption.modulate = ACCENT_COLOR
	add_child(caption)
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.position = Vector2(1012.0, 56.0)
	score_label.size = Vector2(220.0, 42.0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override(&"font_size", 30)
	add_child(score_label)


func _build_game_over_overlay() -> void:
	game_over_overlay = Control.new()
	game_over_overlay.name = "GameOverOverlay"
	game_over_overlay.z_index = 20
	game_over_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.visible = false
	game_over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(game_over_overlay)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.02, 0.03, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	game_over_overlay.add_child(shade)
	var panel: ColorRect = ColorRect.new()
	panel.position = Vector2(365.0, 188.0)
	panel.size = Vector2(550.0, 340.0)
	panel.color = Color(0.025, 0.05, 0.065, 0.97)
	game_over_overlay.add_child(panel)
	var title: Label = Label.new()
	title.position = Vector2(405.0, 232.0)
	title.size = Vector2(470.0, 86.0)
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 58)
	title.modulate = ACCENT_COLOR
	game_over_overlay.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.position = Vector2(405.0, 320.0)
	subtitle.size = Vector2(470.0, 46.0)
	subtitle.text = "CHASSIS SIGNAL LOST"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override(&"font_size", 24)
	subtitle.modulate = MUTED_COLOR
	game_over_overlay.add_child(subtitle)
	retry_button = Button.new()
	retry_button.name = "RetryButton"
	retry_button.position = Vector2(490.0, 398.0)
	retry_button.size = Vector2(300.0, 78.0)
	retry_button.text = "RETRY"
	retry_button.focus_mode = Control.FOCUS_ALL
	retry_button.add_theme_font_size_override(&"font_size", 30)
	retry_button.pressed.connect(retry_pressed.emit)
	game_over_overlay.add_child(retry_button)


func _momentum_color(band: int) -> Color:
	match band:
		1:
			return Color("f1b36f")
		2:
			return Color("ff815c")
		3:
			return Color("fff0a8")
		_:
			return Color("5dc9c2")
