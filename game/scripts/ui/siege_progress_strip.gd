class_name SiegeProgressStrip
extends Control

const ACTIVE_COLOR: Color = Color("f1b36f")
const COMPLETE_COLOR: Color = Color("5dc9c2")
const INACTIVE_COLOR: Color = Color(0.10, 0.14, 0.17, 0.92)
const RECOVERY_COLOR: Color = Color("8ad7ff")

var segments: Array[ColorRect] = []
var label: Label
var current_index: int = 0
var total_acts: int = 6
var recovery_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = Label.new()
	label.position = Vector2(0.0, 0.0)
	label.size = Vector2(500.0, 20.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 14)
	label.modulate = ACTIVE_COLOR
	add_child(label)
	for index: int in range(6):
		var segment: ColorRect = ColorRect.new()
		segment.position = Vector2(float(index) * 82.0 + 8.0, 22.0)
		segment.size = Vector2(72.0, 6.0)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(segment)
		segments.append(segment)
	_refresh()
	apply_width(size.x)


func set_progress(index: int, total: int, display_name: String, recovery: bool) -> void:
	current_index = clampi(index, 0, 5)
	total_acts = clampi(total, 1, 6)
	recovery_active = recovery
	if label != null:
		label.text = (
			"ACT %d / %d  %s  %s"
			% [current_index + 1, total_acts, display_name, "RECOVERY" if recovery else "PRESSURE"]
		)
	_refresh()


func apply_width(available_width: float) -> void:
	if label == null:
		return
	label.size.x = available_width
	var gap: float = 10.0
	var inset: float = 8.0
	var segment_width: float = (
		available_width - inset * 2.0 - gap * 5.0
	) / 6.0
	for index: int in range(segments.size()):
		segments[index].position = Vector2(
			inset + float(index) * (segment_width + gap),
			22.0
		)
		segments[index].size.x = segment_width


func _refresh() -> void:
	for index: int in range(segments.size()):
		if index >= total_acts:
			segments[index].visible = false
			continue
		segments[index].visible = true
		if index < current_index:
			segments[index].color = COMPLETE_COLOR
		elif index == current_index:
			segments[index].color = RECOVERY_COLOR if recovery_active else ACTIVE_COLOR
		else:
			segments[index].color = INACTIVE_COLOR
