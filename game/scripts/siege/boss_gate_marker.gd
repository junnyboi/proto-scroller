class_name BossGateMarker
extends Node2D

const WORLD_LAYER: int = 1 << 0
const ROBOT_LAYER: int = 1 << 1
const BLOCKER_SIZE: Vector2 = Vector2(72.0, 900.0)

var definition: BossEncounterDefinition
var owned: bool = false
var consumed: bool = false
var trigger_count: int = 0
var logical_anchor_x: float = 0.0
var cached_world_anchor: Vector2 = Vector2.ZERO
var blocker: StaticBody2D
var blocker_collision: CollisionShape2D


func _init() -> void:
	blocker = StaticBody2D.new()
	blocker.name = "RouteBlocker"
	blocker.collision_layer = WORLD_LAYER
	blocker.collision_mask = ROBOT_LAYER
	add_child(blocker)
	blocker_collision = CollisionShape2D.new()
	blocker_collision.name = "Collision"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = BLOCKER_SIZE
	blocker_collision.shape = shape
	blocker_collision.position = Vector2(0.0, 360.0)
	blocker_collision.disabled = true
	blocker.add_child(blocker_collision)
	visible = false
	z_index = 42


func configure(p_definition: BossEncounterDefinition) -> void:
	definition = p_definition
	name = "BossGate_%02d" % definition.trigger_chunk
	logical_anchor_x = float(gate_chunk()) * CityWorldStream.CHUNK_WIDTH


func gate_chunk() -> int:
	return definition.unlock_chunk if definition.unlock_chunk >= 0 else definition.trigger_chunk + 1


func acquire(world_anchor: Vector2) -> bool:
	if definition == null or consumed or owned:
		return false
	owned = true
	trigger_count += 1
	cached_world_anchor = world_anchor
	global_position = world_anchor
	visible = true
	blocker_collision.disabled = false
	queue_redraw()
	return true


func restore_ownership(state: Dictionary, world_anchor: Vector2) -> void:
	owned = bool(state.get("owned", true))
	consumed = bool(state.get("consumed", false))
	trigger_count = int(state.get("trigger_count", trigger_count))
	cached_world_anchor = world_anchor
	global_position = world_anchor
	visible = owned and not consumed
	blocker_collision.disabled = not visible
	queue_redraw()


func consume() -> void:
	owned = false
	consumed = true
	visible = false
	blocker_collision.disabled = true
	queue_redraw()


func release() -> void:
	owned = false
	visible = false
	blocker_collision.disabled = true
	queue_redraw()


func reset_gate() -> void:
	owned = false
	consumed = false
	trigger_count = 0
	visible = false
	blocker_collision.disabled = true
	queue_redraw()


func capture_state() -> Dictionary:
	return {
		"owned": owned,
		"consumed": consumed,
		"trigger_count": trigger_count,
	}


func rebase_cached_world_state(offset: Vector2) -> void:
	if not owned:
		return
	cached_world_anchor += offset


func _draw() -> void:
	if not owned or consumed:
		return
	draw_rect(
		Rect2(Vector2(-28.0, -80.0), Vector2(56.0, 690.0)),
		Color(0.08, 0.16, 0.19, 0.78)
	)
	for stripe_y: float in range(-50, 600, 52):
		draw_line(
			Vector2(-24.0, stripe_y),
			Vector2(24.0, stripe_y + 30.0),
			Color(0.96, 0.49, 0.24, 0.88),
			6.0
		)
