class_name BossPodVisual2D
extends Node2D

enum PodState {
	SEALED,
	OCCUPIED,
	TARGETED,
	LOST,
	RESCUED,
}

const GLASS_SIZE: Vector2 = Vector2(74.0, 116.0)

var pod_index: int = 0
var state: PodState = PodState.SEALED


func configure(index: int, state_value: PodState, local_position: Vector2) -> void:
	pod_index = index
	state = state_value
	position = local_position
	visible = true
	queue_redraw()


func set_state(state_value: PodState) -> void:
	state = state_value
	visible = true
	queue_redraw()


func glass_rect() -> Rect2:
	return Rect2(global_position - GLASS_SIZE * 0.5, GLASS_SIZE)


func _draw() -> void:
	if not visible:
		return
	var glass: Rect2 = Rect2(-GLASS_SIZE * 0.5, GLASS_SIZE)
	var fill: Color = Color(0.28, 0.84, 0.92, 0.15)
	var edge: Color = Color(0.75, 0.96, 1.0, 0.90)
	if state == PodState.TARGETED:
		fill = Color(1.0, 0.52, 0.10, 0.24)
		edge = Color(1.0, 0.72, 0.20, 1.0)
	elif state == PodState.LOST:
		fill = Color(0.16, 0.18, 0.22, 0.35)
		edge = Color(0.46, 0.48, 0.52, 0.72)
	elif state == PodState.RESCUED:
		fill = Color(0.28, 1.0, 0.62, 0.16)
		edge = Color(0.55, 1.0, 0.72, 0.96)
	draw_rect(glass, fill, true)
	draw_rect(glass, edge, false, 4.0)
	draw_line(Vector2(-22.0, 44.0), Vector2(22.0, 44.0), edge, 5.0)
	if state in [PodState.OCCUPIED, PodState.TARGETED, PodState.RESCUED]:
		var life: Color = Color(0.82, 1.0, 0.82, 0.96)
		draw_circle(Vector2(0.0, -20.0), 11.0, life)
		draw_line(Vector2(0.0, -8.0), Vector2(0.0, 28.0), life, 7.0)
		draw_circle(Vector2(23.0, -45.0), 5.0, life)
	elif state == PodState.SEALED:
		draw_line(Vector2(-24.0, -8.0), Vector2(24.0, -8.0), edge, 3.0)
