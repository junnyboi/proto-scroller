class_name LaserBeamVisual2D
extends Node2D

var active: bool = false
var paused: bool = false
var age: float = 0.0
var lifetime: float = 0.10
var beam_length: float = 1100.0


func _ready() -> void:
	z_index = 75
	visible = false
	set_process(false)


func activate(origin: Vector2, direction: Vector2, length: float) -> void:
	global_position = origin
	rotation = direction.angle()
	beam_length = length
	age = 0.0
	active = true
	visible = true
	set_process(true)
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not active or paused:
		return
	age += delta
	if age >= lifetime:
		deactivate()
		return
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var alpha: float = clampf(1.0 - age / lifetime, 0.0, 1.0)
	draw_line(Vector2.ZERO, Vector2(beam_length, 0.0), Color(0.18, 0.72, 1.0, alpha * 0.30), 14.0)
	draw_line(Vector2.ZERO, Vector2(beam_length, 0.0), Color(0.68, 0.96, 1.0, alpha), 5.0)
	draw_circle(Vector2.ZERO, 8.0, Color(0.86, 1.0, 1.0, alpha))
