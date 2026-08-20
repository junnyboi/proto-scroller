class_name AirTargetReticle2D
extends Node2D

const OUTER_RADIUS: float = 30.0
const INNER_RADIUS: float = 21.0
const BRACKET_HALF_ANGLE: float = 0.34
const TRACK_COLOR: Color = Color("74e8ff")
const CORE_COLOR: Color = Color("d7fbff")
const SHADOW_COLOR: Color = Color(0.01, 0.07, 0.10, 0.78)
const PULSE_SPEED: float = 2.25

var _target: EnemyActor2D
var _age: float = 0.0


func _ready() -> void:
	z_index = 92
	visible = false
	set_process(false)


func acquire(target: EnemyActor2D) -> void:
	_target = target
	_age = 0.0
	visible = target != null
	set_process(visible)
	if visible:
		global_position = target.global_position
		queue_redraw()


func clear_lock() -> void:
	_target = null
	visible = false
	set_process(false)


func current_target() -> EnemyActor2D:
	return _target


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		clear_lock()
		return
	_age += delta
	global_position = _target.global_position
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var pulse: float = 0.5 + 0.5 * sin(_age * TAU * PULSE_SPEED)
	var radius: float = OUTER_RADIUS + pulse * 1.5
	var alpha: float = 0.78 + pulse * 0.20
	for quadrant: int in range(4):
		var center_angle: float = float(quadrant) * TAU * 0.25
		var start_angle: float = center_angle - BRACKET_HALF_ANGLE
		var end_angle: float = center_angle + BRACKET_HALF_ANGLE
		draw_arc(
			Vector2.ZERO,
			radius,
			start_angle,
			end_angle,
			8,
			SHADOW_COLOR,
			5.0,
			true
		)
		draw_arc(
			Vector2.ZERO,
			radius,
			start_angle,
			end_angle,
			8,
			Color(TRACK_COLOR, alpha),
			2.5,
			true
		)
		var direction: Vector2 = Vector2.from_angle(center_angle)
		draw_line(
			direction * INNER_RADIUS,
			direction * (INNER_RADIUS - 6.0),
			SHADOW_COLOR,
			5.0,
			true
		)
		draw_line(
			direction * INNER_RADIUS,
			direction * (INNER_RADIUS - 6.0),
			Color(TRACK_COLOR, alpha),
			2.5,
			true
		)
	draw_circle(Vector2.ZERO, 4.0 + pulse, SHADOW_COLOR)
	draw_circle(Vector2.ZERO, 2.0 + pulse * 0.5, Color(CORE_COLOR, alpha))
