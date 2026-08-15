class_name DestructionDirector
extends Node2D

signal explosion_resolved(origin: Vector2, accepted_targets: int)

@export_flags_2d_physics var blast_mask: int = 0
@export_range(1, 64, 1) var max_results: int = 32
@export_range(1, 8, 1) var max_explosions_per_tick: int = 4

var _queue: Array[Dictionary] = []
var _blast_shape: CircleShape2D = CircleShape2D.new()


func queue_explosion(
	origin: Vector2,
	radius: float,
	peak_damage: float,
	impulse_per_mass: float,
	attack_id: int,
	source: Node = null
) -> void:
	if radius <= 0.0 or peak_damage <= 0.0:
		return
	_queue.append({
		"origin": origin,
		"radius": radius,
		"peak_damage": peak_damage,
		"impulse_per_mass": maxf(impulse_per_mass, 0.0),
		"attack_id": attack_id,
		"source": source,
	})


func _physics_process(_delta: float) -> void:
	var count: int = mini(max_explosions_per_tick, _queue.size())
	for explosion_index: int in range(count):
		_resolve_explosion(_queue.pop_front())


func _resolve_explosion(data: Dictionary) -> void:
	var origin: Vector2 = data["origin"] as Vector2
	var radius: float = data["radius"] as float
	_blast_shape.radius = radius
	var parameters: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	parameters.shape = _blast_shape
	parameters.transform = Transform2D(0.0, origin)
	parameters.collision_mask = blast_mask
	parameters.collide_with_areas = true
	parameters.collide_with_bodies = true
	if is_instance_valid(data["source"] as Node):
		var source_object: CollisionObject2D = data["source"] as CollisionObject2D
		if source_object != null:
			parameters.exclude = [source_object.get_rid()]
	var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(
		parameters,
		max_results
	)
	var seen: Dictionary[int, bool] = {}
	var accepted_targets: int = 0
	for result: Dictionary in results:
		var collider: Object = result.get("collider") as Object
		if collider == null:
			continue
		var collider_id: int = collider.get_instance_id()
		if seen.has(collider_id):
			continue
		seen[collider_id] = true
		var target_node: Node2D = collider as Node2D
		if target_node == null:
			continue
		var offset: Vector2 = target_node.global_position - origin
		var distance: float = offset.length()
		var direction: Vector2 = offset.normalized()
		if direction.is_zero_approx():
			direction = Vector2.UP
		var normalized_distance: float = clampf(distance / radius, 0.0, 1.0)
		var falloff: float = pow(1.0 - normalized_distance, 2.0)
		if falloff <= 0.0:
			continue
		var event: DamageEvent = DamageEvent.new(
			data["attack_id"] as int,
			data["source"] as Node,
			(data["peak_damage"] as float) * falloff,
			&"explosive",
			origin,
			direction,
			(data["impulse_per_mass"] as float) * falloff
		)
		var accepted: bool = _deliver_damage(target_node, event)
		_apply_rigid_impulse(target_node, event)
		if accepted:
			accepted_targets += 1
	explosion_resolved.emit(origin, accepted_targets)


func _deliver_damage(start_node: Node, event: DamageEvent) -> bool:
	var receiver: Node = start_node
	while receiver != null:
		if receiver.has_method("receive_damage"):
			return bool(receiver.call("receive_damage", event))
		receiver = receiver.get_parent()
	return false


func _apply_rigid_impulse(start_node: Node, event: DamageEvent) -> void:
	var body: RigidBody2D = start_node as RigidBody2D
	if body == null:
		body = start_node.get_parent() as RigidBody2D
	if body == null or event.impulse_per_mass <= 0.0:
		return
	var impulse: Vector2 = event.direction * event.impulse_per_mass * body.mass
	var impact_offset: Vector2 = event.hit_position - body.global_position
	body.apply_impulse(impulse, impact_offset)
