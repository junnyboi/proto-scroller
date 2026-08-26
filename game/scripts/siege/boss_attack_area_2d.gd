class_name BossAttackArea2D
extends Area2D

enum VisualState {
	HIDDEN,
	TELEGRAPH,
	ARMED,
	DRY,
}

const ROBOT_LAYER: int = 1 << 1

var visual_state: VisualState = VisualState.HIDDEN
var footprint_size: Vector2 = Vector2(192.0, 96.0)
var attack_id: StringName = &""


func configure_footprint(
	world_position: Vector2,
	size_value: Vector2,
	state_value: VisualState,
	attack: StringName
) -> void:
	global_position = world_position
	footprint_size = size_value
	visual_state = state_value
	attack_id = attack
	var collision: CollisionShape2D = get_node(^"Collision") as CollisionShape2D
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	rectangle.size = footprint_size
	var armed: bool = visual_state == VisualState.ARMED
	collision.disabled = not armed
	collision_layer = 0
	collision_mask = ROBOT_LAYER if armed else 0
	monitoring = armed
	monitorable = false
	visible = visual_state != VisualState.HIDDEN
	queue_redraw()


func deactivate() -> void:
	configure_footprint(
		global_position,
		footprint_size,
		VisualState.HIDDEN,
		&""
	)


func contains_world_point(world_point: Vector2) -> bool:
	if visual_state != VisualState.ARMED:
		return false
	var local_point: Vector2 = to_local(world_point)
	return (
		absf(local_point.x) <= footprint_size.x * 0.5
		and absf(local_point.y) <= footprint_size.y * 0.5
	)


func _draw() -> void:
	if visual_state == VisualState.HIDDEN:
		return
	var rectangle: Rect2 = Rect2(-footprint_size * 0.5, footprint_size)
	var fill: Color = Color(0.08, 0.82, 0.92, 0.10)
	var edge: Color = Color(0.45, 0.96, 1.0, 0.88)
	var width: float = 3.0
	if visual_state == VisualState.ARMED:
		fill = Color(0.94, 0.08, 0.16, 0.28)
		edge = Color(1.0, 0.30, 0.24, 0.98)
		width = 6.0
	elif visual_state == VisualState.DRY:
		fill = Color(0.92, 0.96, 1.0, 0.08)
		edge = Color(0.94, 1.0, 1.0, 0.94)
		width = 4.0
	draw_rect(rectangle, fill, true)
	draw_rect(rectangle, edge, false, width)
	if visual_state == VisualState.TELEGRAPH:
		for stripe: int in range(4):
			var stripe_x: float = rectangle.position.x + 24.0 + float(stripe) * 48.0
			draw_line(
				Vector2(stripe_x, rectangle.position.y),
				Vector2(stripe_x + 32.0, rectangle.end.y),
				Color(1.0, 0.72, 0.16, 0.82),
				3.0
			)
