class_name PlayerAttackReactionRuntime
extends Node

const GROUND_REACTION_RADIUS: float = 360.0
const JAB_FORWARD_RANGE: float = 330.0
const JAB_VERTICAL_RANGE: float = 180.0

var attacks: ContextualAttackController
var robot: GiantRobotController
var encounter: EncounterRuntime
var anticipation_dispatch_count: int = 0
var strike_dispatch_count: int = 0
var last_anticipated_attack_id: int = 0
var last_strike_attack_id: int = 0


func setup(
	p_attacks: ContextualAttackController,
	p_robot: GiantRobotController,
	p_encounter: EncounterRuntime
) -> void:
	attacks = p_attacks
	robot = p_robot
	encounter = p_encounter
	attacks.attack_started.connect(_on_attack_started)
	attacks.attack_active.connect(_on_attack_active)


func _on_attack_started(spec: AttackSpec) -> void:
	if spec == null:
		return
	last_anticipated_attack_id = spec.attack_id
	for enemy: EnemyActor2D in _eligible_enemies(spec):
		enemy.begin_player_attack_reaction(
			spec.attack_id,
			robot.global_position,
			spec.anticipation_seconds
		)
		anticipation_dispatch_count += 1


func _on_attack_active(spec: AttackSpec) -> void:
	if spec == null:
		return
	last_strike_attack_id = spec.attack_id
	for enemy: EnemyActor2D in encounter.all_actors():
		var previous_count: int = enemy.player_strike_reaction_count
		enemy.commit_player_attack_reaction(spec.attack_id, robot.global_position)
		if enemy.player_strike_reaction_count > previous_count:
			strike_dispatch_count += 1


func _eligible_enemies(spec: AttackSpec) -> Array[EnemyActor2D]:
	var eligible: Array[EnemyActor2D] = []
	if encounter == null or robot == null:
		return eligible
	for enemy: EnemyActor2D in encounter.all_actors():
		if not enemy.active or enemy.dead:
			continue
		var offset: Vector2 = enemy.global_position - robot.global_position
		if spec.is_ground_smash():
			if offset.length() <= GROUND_REACTION_RADIUS:
				eligible.append(enemy)
			continue
		var forward: float = offset.x * float(spec.facing)
		if (
			forward > 0.0
			and forward <= JAB_FORWARD_RANGE
			and absf(offset.y) <= JAB_VERTICAL_RANGE
		):
			eligible.append(enemy)
	eligible.sort_custom(_sort_by_instance_id)
	return eligible


func _sort_by_instance_id(first: EnemyActor2D, second: EnemyActor2D) -> bool:
	return first.get_instance_id() < second.get_instance_id()
