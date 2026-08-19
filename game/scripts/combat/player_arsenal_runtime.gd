class_name PlayerArsenalRuntime
extends Node

const MIN_RANGE: float = 180.0
const MAX_RANGE: float = 700.0
const RELEASE_RANGE: float = 740.0
const OBSTRUCTION_MASK: int = (1 << 0) | (1 << 3)

var robot: GiantRobotController
var projectile_pool: ProjectilePool
var actors: Array[EnemyActor2D] = []


func setup(
	p_robot: GiantRobotController,
	p_projectile_pool: ProjectilePool,
	encounters: EncounterRuntime
) -> void:
	robot = p_robot
	projectile_pool = p_projectile_pool
	actors.clear()
	actors.append_array(encounters.soldiers)
	actors.append_array(encounters.tanks)
	actors.append_array(encounters.helicopters)


func acquire_target(maximum_range: float = MAX_RANGE) -> EnemyActor2D:
	var best: EnemyActor2D = null
	var best_distance: float = INF
	var minimum_squared: float = MIN_RANGE * MIN_RANGE
	var maximum_squared: float = maximum_range * maximum_range
	for enemy: EnemyActor2D in actors:
		if enemy == null or not enemy.active or enemy.dead:
			continue
		var distance_squared: float = robot.global_position.distance_squared_to(
			enemy.global_position
		)
		if distance_squared < minimum_squared or distance_squared > maximum_squared:
			continue
		if not _has_line_of_sight(enemy):
			continue
		if (
			distance_squared < best_distance
			or (
				is_equal_approx(distance_squared, best_distance)
				and (best == null or enemy.get_instance_id() < best.get_instance_id())
			)
		):
			best = enemy
			best_distance = distance_squared
	return best


func target_is_current(target: EnemyActor2D, generation: int) -> bool:
	if target == null or not target.active or target.dead:
		return false
	if target.activation_generation != generation:
		return false
	return robot.global_position.distance_squared_to(target.global_position) <= (
		RELEASE_RANGE * RELEASE_RANGE
	)


func reserve_attack_id() -> int:
	return robot.reserve_attack_id()


func _has_line_of_sight(target: EnemyActor2D) -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		robot.global_position,
		target.global_position,
		OBSTRUCTION_MASK,
		[robot.get_rid()]
	)
	return robot.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
