class_name AerialDebrisLauncher
extends RefCounted

const AIRBORNE_GROUP: StringName = &"airborne_enemy"
const LAUNCH_COUNT: int = 3
const IMPACT_DAMAGE: float = 4.0
const GRAVITY: float = 980.0


static func launch(
	tree: SceneTree,
	pool: DebrisPool,
	source: Node,
	origin: Vector2,
	impulse_per_mass: float,
	attack_id: int
) -> int:
	if tree == null or pool == null or source == null:
		return 0
	var target: EnemyActor2D = _nearest_target(tree, origin)
	if target == null:
		return 0
	var launched: int = 0
	for debris_index: int in range(LAUNCH_COUNT):
		var spawn_position: Vector2 = origin + Vector2(
			float(debris_index - 1) * 18.0,
			-10.0
		)
		var body_mass: float = 3.5 + float(debris_index) * 1.25
		var target_offset: Vector2 = Vector2(
			float(debris_index - 1) * 42.0,
			float(abs(debris_index - 1)) * 8.0
		)
		var launch_velocity: Vector2 = _ballistic_velocity(
			spawn_position,
			target,
			target_offset,
			impulse_per_mass
		)
		var debris: DebrisBody2D = pool.acquire(
			Transform2D(0.0, spawn_position),
			launch_velocity * body_mass,
			float(debris_index - 1) * body_mass * 7.0,
			body_mass,
			Vector2(30.0 + float(debris_index) * 5.0, 18.0),
			&"concrete"
		)
		debris.arm_aerial_impact(
			source,
			attack_id * 10 + debris_index + 1,
			IMPACT_DAMAGE,
			target
		)
		launched += 1
	return launched


static func _nearest_target(tree: SceneTree, origin: Vector2) -> EnemyActor2D:
	var nearest: EnemyActor2D
	var nearest_distance: float = INF
	for candidate: Node in tree.get_nodes_in_group(AIRBORNE_GROUP):
		if not candidate is EnemyActor2D:
			continue
		var enemy: EnemyActor2D = candidate as EnemyActor2D
		if enemy.dead or enemy.global_position.y > origin.y - 100.0:
			continue
		var distance: float = origin.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


static func _ballistic_velocity(
	origin: Vector2,
	target: EnemyActor2D,
	target_offset: Vector2,
	impulse_per_mass: float
) -> Vector2:
	var horizontal_distance: float = absf(target.global_position.x - origin.x)
	var flight_time: float = clampf(horizontal_distance / 620.0, 0.65, 1.15)
	var predicted_target: Vector2 = (
		target.global_position
		+ target.velocity * flight_time * 0.65
		+ target_offset
	)
	var gravity_drop: Vector2 = Vector2(0.0, 0.5 * GRAVITY * flight_time * flight_time)
	var velocity: Vector2 = (predicted_target - origin - gravity_drop) / flight_time
	var force_scale: float = clampf(impulse_per_mass / 1020.0, 0.85, 1.35)
	return velocity * force_scale
