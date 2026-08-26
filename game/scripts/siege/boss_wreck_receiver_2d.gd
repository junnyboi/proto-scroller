class_name BossWreckReceiver2D
extends Area2D

const HURTBOX_LAYER: int = 1 << 6

var outcome_id: int = BossOutcome.PURGE
var wreck: EnemyWreck2D
var active: bool = false
var receiver_callback: Callable


func configure(
	p_wreck: EnemyWreck2D,
	p_outcome_id: int,
	world_position: Vector2,
	p_receiver_callback: Callable = Callable()
) -> void:
	wreck = p_wreck
	outcome_id = p_outcome_id
	receiver_callback = p_receiver_callback
	global_position = world_position
	active = wreck != null
	collision_layer = HURTBOX_LAYER if active else 0
	monitorable = active
	var collision: CollisionShape2D = get_node(^"Collision") as CollisionShape2D
	collision.disabled = not active
	visible = active


func deactivate() -> void:
	wreck = null
	receiver_callback = Callable()
	active = false
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	visible = false
	var collision: CollisionShape2D = get_node_or_null(^"Collision") as CollisionShape2D
	if collision != null:
		collision.disabled = true


func receive_damage(event: DamageEvent) -> bool:
	if not active or wreck == null or not is_instance_valid(wreck):
		return false
	if receiver_callback.is_valid():
		return bool(receiver_callback.call(self, event))
	return wreck.receive_damage(event)
