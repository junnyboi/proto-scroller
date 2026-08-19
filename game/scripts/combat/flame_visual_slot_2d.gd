class_name FlameVisualSlot2D
extends Node2D

var active: bool = false
var paused: bool = false
var age: float = 0.0
var lifetime: float = 0.24
var flame_range: float = 220.0
var half_angle: float = deg_to_rad(32.0)


func _ready() -> void:
	z_index = 74
	visible = false
	set_process(false)


func activate(
	origin: Vector2,
	direction: Vector2,
	p_range: float,
	p_half_angle: float
) -> void:
	global_position = origin
	rotation = direction.angle()
	flame_range = p_range
	half_angle = p_half_angle
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
	var points: PackedVector2Array = PackedVector2Array([
		Vector2.ZERO,
		Vector2.RIGHT.rotated(-half_angle) * flame_range,
		Vector2.RIGHT * flame_range * 0.82,
		Vector2.RIGHT.rotated(half_angle) * flame_range,
	])
	draw_colored_polygon(points, Color(1.0, 0.30, 0.06, alpha * 0.28))
	draw_polyline(points, Color(1.0, 0.78, 0.18, alpha * 0.84), 4.0, true)
