class_name GameplayHud
extends CanvasLayer

signal retry_pressed

const PANEL_COLOR: Color = Color(0.03, 0.05, 0.08, 0.86)
const ACCENT_COLOR: Color = Color("f1b36f")
const MUTED_COLOR: Color = Color("b7c4cb")
const COMBO_GRACE_SECONDS: float = 3.0

var health_label: Label
var status_label: Label
var objective_label: Label
var score_label: Label
var combo_label: Label
var combo_ring: ComboDecayRing
var momentum_fill: ColorRect
var momentum_label: Label
var siege_progress: SiegeProgressStrip
var directive_card: DirectiveCard
var game_over_overlay: Control
var overlay_title: Label
var overlay_summary: Label
var retry_button: Button
var rare_labels: Array[Label] = []
var _robot: GiantRobotController
var _pulse_age: float = 0.0
var _overdrive_active: bool = false


func setup(robot: GiantRobotController) -> void:
	_robot = robot


func _ready() -> void:
	name = "HUD"
	layer = 20
	_build_status_panel()
	_build_momentum_panel()
	_build_score_panel()
	_build_siege_progress()
	_build_directive_card()
	_build_game_over_overlay()
	if _robot != null:
		_robot.attack_mode_selected.connect(_on_attack_mode_selected)
		_robot.attack_committed.connect(_on_attack_committed)
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
	if combo_ring != null:
		combo_ring.set_ratio(
			grace_remaining / COMBO_GRACE_SECONDS if multiplier > 1 else 0.0
		)


func set_momentum(value: float, band: int) -> void:
	var clamped_value: float = clampf(value, 0.0, 100.0)
	if momentum_fill != null:
		momentum_fill.size.x = 392.0 * clamped_value / 100.0
		momentum_fill.color = _momentum_color(band)
	if momentum_label != null:
		momentum_label.text = (
			"OVERDRIVE READY / PRESS SMASH"
			if band == MomentumMeter.Band.READY
			else "MOMENTUM %03d%%" % roundi(clamped_value)
		)


func set_overdrive(active: bool, remaining: float) -> void:
	_overdrive_active = active
	if momentum_label != null and active:
		momentum_label.text = "KINETIC OVERDRIVE  %.1fs" % maxf(remaining, 0.0)
	if momentum_fill != null and active:
		momentum_fill.size.x = 392.0 * clampf(remaining / 4.0, 0.0, 1.0)
		momentum_fill.color = Color("ff8a42")


func set_rare_tags(tags: PackedStringArray) -> void:
	for index: int in range(rare_labels.size()):
		rare_labels[index].text = tags[index] if index < tags.size() else ""
		rare_labels[index].visible = index < tags.size()


func set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func set_objective(text: String) -> void:
	if objective_label != null:
		objective_label.text = text


func set_siege_progress(
	index: int,
	total: int,
	display_name: String,
	recovery: bool
) -> void:
	if siege_progress != null:
		siege_progress.set_progress(index, total, display_name, recovery)


func show_directive(
	profile: DirectiveProfile,
	current: int,
	target: int,
	bank: int
) -> void:
	directive_card.show_directive(profile, current, target, bank)


func set_directive_progress(profile: DirectiveProfile, current: int, target: int) -> void:
	directive_card.set_progress(profile, current, target)


func set_directive_bank(value: int) -> void:
	directive_card.set_bank(value)


func show_directive_result(text: String, success: bool) -> void:
	directive_card.show_result(text, success)


func show_game_over(summary: RunSummarySnapshot = null) -> void:
	set_status("CITY RESPONSE / LOST")
	set_objective("CHASSIS SIGNAL TERMINATED")
	_show_summary(summary, false)


func show_district_complete(summary: RunSummarySnapshot) -> void:
	set_status("DISTRICT RESPONSE / BROKEN")
	set_objective("RETALIATION EXHAUSTED / EXTRACTION OPEN")
	_show_summary(summary, true)


func _show_summary(summary: RunSummarySnapshot, completed: bool) -> void:
	overlay_title.text = "DISTRICT CLEARED" if completed else "GAME OVER"
	if summary != null:
		var summary_format: String = (
			"SCORE  %08d\nPEAK COMBO  x%d    BEST CHAIN  %d\n"
				+ "ACTS  %d / 6    OVERDRIVES  %d\nRARE EVENTS  %d"
		)
		overlay_summary.text = (
			summary_format % [
				summary.score,
				summary.peak_combo,
				summary.best_chain,
				summary.waves_cleared,
				summary.overdrive_activations,
				summary.rare_events.size(),
			]
		)
	else:
		overlay_summary.text = "CHASSIS SIGNAL LOST"
	game_over_overlay.visible = true
	retry_button.grab_focus()


func _on_attack_mode_selected(mode: int, _attack_id: int) -> void:
	set_objective(
		"DRIVE LOCKED / FORWARD IMPACT"
		if mode == AttackSpec.Mode.SHOULDER_DRIVE
		else "GROUND LOCKED / RADIAL IMPACT"
	)


func _on_attack_committed(mode: int, _attack_id: int) -> void:
	if mode == AttackSpec.Mode.SHOULDER_DRIVE:
		set_objective("SHOULDER DRIVE / MOMENTUM TRANSFERRED")


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
	objective_label.text = "A/D MOVE   SPACE SMASH   KEEP MOVING"
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
	combo_ring = ComboDecayRing.new()
	combo_ring.name = "ComboDecayRing"
	combo_ring.position = Vector2(712.0, 24.0)
	combo_ring.size = Vector2(38.0, 38.0)
	combo_ring.visible = false
	add_child(combo_ring)
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
	for index: int in range(RuntimeBudget.RARE_TAG_ROWS):
		var rare_label: Label = Label.new()
		rare_label.name = "RareEvent%d" % index
		rare_label.position = Vector2(1012.0, 116.0 + float(index) * 23.0)
		rare_label.size = Vector2(220.0, 22.0)
		rare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rare_label.add_theme_font_size_override(&"font_size", 16)
		rare_label.modulate = ACCENT_COLOR
		rare_label.visible = false
		add_child(rare_label)
		rare_labels.append(rare_label)


func _build_siege_progress() -> void:
	siege_progress = SiegeProgressStrip.new()
	siege_progress.name = "SiegeProgressStrip"
	siege_progress.position = Vector2(466.0, 112.0)
	siege_progress.size = Vector2(500.0, 32.0)
	add_child(siege_progress)


func _build_directive_card() -> void:
	directive_card = DirectiveCard.new()
	directive_card.name = "DirectiveCard"
	directive_card.position = Vector2(948.0, 426.0)
	directive_card.size = Vector2(292.0, 104.0)
	add_child(directive_card)


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
	overlay_title = Label.new()
	overlay_title.position = Vector2(405.0, 218.0)
	overlay_title.size = Vector2(470.0, 72.0)
	overlay_title.text = "GAME OVER"
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override(&"font_size", 48)
	overlay_title.modulate = ACCENT_COLOR
	game_over_overlay.add_child(overlay_title)
	overlay_summary = Label.new()
	overlay_summary.position = Vector2(405.0, 296.0)
	overlay_summary.size = Vector2(470.0, 128.0)
	overlay_summary.text = "CHASSIS SIGNAL LOST"
	overlay_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_summary.add_theme_font_size_override(&"font_size", 20)
	overlay_summary.modulate = MUTED_COLOR
	game_over_overlay.add_child(overlay_summary)
	retry_button = Button.new()
	retry_button.name = "RetryButton"
	retry_button.position = Vector2(490.0, 430.0)
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
