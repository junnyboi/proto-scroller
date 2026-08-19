class_name DodgeCooldownIndicator
extends Control

const PANEL_COLOR: Color = Color(0.03, 0.05, 0.08, 0.86)
const READY_COLOR: Color = Color("5de6dc")
const RECHARGE_COLOR: Color = Color("f1b36f")
const TRACK_COLOR: Color = Color(0.11, 0.15, 0.18, 0.95)

var robot: GiantRobotController
var panel: ColorRect
var label: Label
var track: ColorRect
var fill: ColorRect
var _fill_width: float = 100.0
var _readiness_ratio: float = 1.0


func setup(p_robot: GiantRobotController) -> void:
	robot = p_robot


func _ready() -> void:
	name = "DodgeCooldownIndicator"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_nodes()
	get_viewport().size_changed.connect(apply_responsive_layout)
	apply_responsive_layout()
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func readiness_ratio() -> float:
	return _readiness_ratio


func apply_responsive_layout() -> void:
	if label == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.y > viewport_size.x:
		var panel_width: float = minf(300.0, viewport_size.x * 0.46)
		position = Vector2(0.0, 226.0)
		size = Vector2(panel_width, 18.0)
		label.position = Vector2(8.0, 1.0)
		label.size = Vector2(70.0, 16.0)
		label.add_theme_font_size_override(&"font_size", 9)
		track.position = Vector2(80.0, 5.0)
		track.size = Vector2(panel_width - 88.0, 8.0)
		fill.position = Vector2(82.0, 7.0)
		_fill_width = panel_width - 92.0
	else:
		position = Vector2(24.0, 142.0)
		size = Vector2(210.0, 26.0)
		label.position = Vector2(8.0, 3.0)
		label.size = Vector2(94.0, 20.0)
		label.add_theme_font_size_override(&"font_size", 12)
		track.position = Vector2(104.0, 7.0)
		track.size = Vector2(98.0, 12.0)
		fill.position = Vector2(107.0, 10.0)
		_fill_width = 92.0
	panel.size = size
	_apply_fill()


func _build_nodes() -> void:
	panel = ColorRect.new()
	panel.name = "Panel"
	panel.color = PANEL_COLOR
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	label = Label.new()
	label.name = "Label"
	label.modulate = READY_COLOR
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	track = ColorRect.new()
	track.name = "Track"
	track.color = TRACK_COLOR
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(track)
	fill = ColorRect.new()
	fill.name = "Fill"
	fill.color = READY_COLOR
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)


func _refresh() -> void:
	if robot == null or label == null:
		return
	_readiness_ratio = 1.0 - robot.dodge_cooldown_ratio
	var is_ready: bool = robot.dodge_ready
	label.text = (
		L10n.t("hud.dodge_ready")
		if is_ready
		else L10n.t("hud.dodge_recharging", {
			"seconds": "%.1f" % robot.dodge_cooldown_remaining,
		})
	)
	label.modulate = READY_COLOR if is_ready else RECHARGE_COLOR
	fill.color = READY_COLOR if is_ready else RECHARGE_COLOR
	_apply_fill()


func _apply_fill() -> void:
	if fill != null:
		fill.size = Vector2(_fill_width * clampf(_readiness_ratio, 0.0, 1.0), 4.0)
