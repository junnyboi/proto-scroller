class_name TitleScreen
extends Control

signal start_requested

const GRID_SIZE: float = 72.0
const BG_TOP: Color = Color("071524")
const BG_BOTTOM: Color = Color("01050d")
const GRID_COLOR: Color = Color(0.18, 0.77, 0.68, 0.11)
const ACCENT_COLOR: Color = Color(0.33, 1.0, 0.82, 0.72)

var initialized: bool = false
var scan_phase: float = 0.0

@onready var initialize_button: Button = %InitializeButton
@onready var status_label: Label = %StatusLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var system_value: Label = %SystemValue


func _ready() -> void:
	initialize_button.pressed.connect(_on_initialize_pressed)
	initialize_button.call_deferred("grab_focus")
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_localized_text()
	_apply_responsive_layout()
	L10n.apply_locale_font(self)
	queue_redraw()


func _process(delta: float) -> void:
	scan_phase = fmod(scan_phase + delta * 22.0, GRID_SIZE)
	queue_redraw()


func initialize_game() -> bool:
	if initialized:
		return false
	initialized = true
	status_label.text = L10n.t("title.expedition_active")
	status_label.modulate = Color("72ffd6")
	instruction_label.text = L10n.t("title.deployment_authorized")
	system_value.text = L10n.t("title.deploying")
	system_value.modulate = Color("72ffd6")
	initialize_button.text = L10n.t("title.deploying")
	initialize_button.disabled = true
	return true


func _on_initialize_pressed() -> void:
	if initialize_game():
		start_requested.emit()


func is_portrait_layout() -> bool:
	var viewport_size: Vector2 = get_viewport_rect().size
	return viewport_size.y > viewport_size.x


func _apply_localized_text() -> void:
	($TopRail/ProtocolLabel as Label).text = L10n.t("title.protocol")
	status_label.text = L10n.t(
		"title.expedition_active" if initialized else "title.mission_briefing"
	)
	($HeroStack/Eyebrow as Label).text = L10n.t("title.recovery_zone")
	(%TitleLabel as Label).text = L10n.t("title.heading")
	instruction_label.text = L10n.t(
		"title.deployment_authorized" if initialized else "title.story"
	)
	($HeroStack/ControlsHeading as Label).text = L10n.t("title.controls_heading")
	(%ControlsLabel as Label).text = L10n.t("title.controls_body")
	($HeroStack/FieldNote as Label).text = L10n.t("title.field_note")
	initialize_button.text = L10n.t("title.deploying" if initialized else "title.begin")
	($HeroStack/ActionRow/HintLabel as Label).text = L10n.t("title.input_hint")
	($TelemetryPanel/PanelStack/PanelHeading as Label).text = L10n.t(
		"title.objectives_heading"
	)
	($TelemetryPanel/PanelStack/PrimaryObjective as Label).text = L10n.t(
		"title.primary_objective"
	)
	($TelemetryPanel/PanelStack/ObjectiveOne as Label).text = L10n.t("title.objective_one")
	($TelemetryPanel/PanelStack/ObjectiveTwo as Label).text = L10n.t("title.objective_two")
	($TelemetryPanel/PanelStack/ObjectiveThree as Label).text = L10n.t("title.objective_three")
	($TelemetryPanel/PanelStack/EnemyHeading as Label).text = L10n.t("title.enemy_heading")
	(%EnemyIntel as Label).text = L10n.t("title.enemy_intel")
	(%RunRule as Label).text = L10n.t("title.run_protocol")
	($TelemetryPanel/PanelStack/MissionStateRow/SystemKey as Label).text = L10n.t(
		"title.mission_state"
	)
	system_value.text = L10n.t("title.deploying" if initialized else "title.awaiting_pilot")


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.y > viewport_size.x:
		_apply_portrait_layout(viewport_size)
	else:
		_apply_landscape_layout()
	queue_redraw()


func _apply_landscape_layout() -> void:
	_set_rect($TopRail, Rect2(56.0, 26.0, 1168.0, 44.0))
	_set_rect($AccentRule, Rect2(56.0, 76.0, 5.0, 584.0))
	_set_rect($HeroStack, Rect2(82.0, 82.0, 638.0, 574.0))
	_set_rect($TelemetryPanel, Rect2(752.0, 82.0, 470.0, 574.0))
	_set_rect($BottomRail, Rect2(56.0, 672.0, 1168.0, 40.0))
	_set_title_font_sizes(24, 56)
	(%TitleLabel as Label).text = L10n.t("title.heading")
	($BottomRail/BuildLabel as Label).text = L10n.t("title.footer_landscape")
	($BottomRail/CoordinatesLabel as Label).text = L10n.t("title.coordinates_landscape")
	($BottomRail/CoordinatesLabel as Label).visible = true


func _apply_portrait_layout(viewport_size: Vector2) -> void:
	var content_width: float = viewport_size.x - 56.0
	_set_rect($TopRail, Rect2(28.0, 24.0, content_width, 44.0))
	_set_rect($AccentRule, Rect2(28.0, 76.0, 5.0, 1068.0))
	_set_rect($HeroStack, Rect2(52.0, 82.0, viewport_size.x - 104.0, 554.0))
	_set_rect($TelemetryPanel, Rect2(52.0, 650.0, viewport_size.x - 104.0, 488.0))
	_set_rect($BottomRail, Rect2(28.0, viewport_size.y - 62.0, content_width, 40.0))
	_set_title_font_sizes(24, 48)
	(%TitleLabel as Label).text = L10n.t("title.heading")
	($BottomRail/BuildLabel as Label).text = L10n.t("title.footer_portrait")
	($BottomRail/CoordinatesLabel as Label).text = L10n.t("title.coordinates_portrait")
	($BottomRail/CoordinatesLabel as Label).visible = false


func _set_title_font_sizes(body_size: int, title_size: int) -> void:
	for label_node: Node in find_children("*", "Label", true, false):
		var label: Label = label_node as Label
		label.add_theme_font_size_override(&"font_size", body_size)
	(%TitleLabel as Label).add_theme_font_size_override(&"font_size", title_size)
	initialize_button.add_theme_font_size_override(&"font_size", body_size)


func _set_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
	control.set_deferred(&"position", rect.position)
	control.set_deferred(&"size", rect.size)


func _draw() -> void:
	var canvas_size: Vector2 = size
	var band_count: int = 28
	var band_height: float = canvas_size.y / float(band_count)
	for band_index: int in range(band_count):
		var blend: float = float(band_index) / float(band_count - 1)
		var band_color: Color = BG_TOP.lerp(BG_BOTTOM, blend)
		draw_rect(
			Rect2(0.0, float(band_index) * band_height, canvas_size.x, band_height + 1.0),
			band_color
		)

	var x: float = fmod(scan_phase, GRID_SIZE)
	while x < canvas_size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, canvas_size.y), GRID_COLOR, 1.0)
		x += GRID_SIZE
	var y: float = fmod(scan_phase * 0.45, GRID_SIZE)
	while y < canvas_size.y:
		draw_line(Vector2(0.0, y), Vector2(canvas_size.x, y), GRID_COLOR, 1.0)
		y += GRID_SIZE

	var orbit_center: Vector2 = Vector2(canvas_size.x * 0.78, canvas_size.y * 0.49)
	draw_circle(orbit_center, 170.0, Color(0.02, 0.18, 0.19, 0.16), false, 2.0)
	draw_arc(orbit_center, 118.0, -1.4, 1.85, 96, ACCENT_COLOR, 2.0, true)
	draw_arc(
		orbit_center,
		150.0,
		1.7,
		4.9,
		96,
		Color(0.22, 0.73, 0.67, 0.28),
		1.0,
		true
	)
	draw_circle(orbit_center + Vector2(20.0, -116.0), 4.0, ACCENT_COLOR)

	var scan_y: float = fmod(scan_phase * 3.0, canvas_size.y)
	draw_rect(Rect2(0.0, scan_y, canvas_size.x, 2.0), Color(0.3, 1.0, 0.82, 0.08))
