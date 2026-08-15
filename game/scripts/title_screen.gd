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
	queue_redraw()


func _process(delta: float) -> void:
	scan_phase = fmod(scan_phase + delta * 22.0, GRID_SIZE)
	queue_redraw()


func initialize_game() -> bool:
	if initialized:
		return false
	initialized = true
	status_label.text = "SYSTEM READY"
	status_label.modulate = Color("72ffd6")
	instruction_label.text = "Scroller runtime standing by."
	system_value.text = "ONLINE"
	system_value.modulate = Color("72ffd6")
	initialize_button.text = "READY"
	initialize_button.disabled = true
	return true


func _on_initialize_pressed() -> void:
	if initialize_game():
		start_requested.emit()


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
	draw_arc(orbit_center, 150.0, 1.7, 4.9, 96, Color(0.22, 0.73, 0.67, 0.28), 1.0, true)
	draw_circle(orbit_center + Vector2(20.0, -116.0), 4.0, ACCENT_COLOR)

	var scan_y: float = fmod(scan_phase * 3.0, canvas_size.y)
	draw_rect(Rect2(0.0, scan_y, canvas_size.x, 2.0), Color(0.3, 1.0, 0.82, 0.08))
