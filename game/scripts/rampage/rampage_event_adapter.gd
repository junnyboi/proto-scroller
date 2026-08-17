class_name RampageEventAdapter
extends RefCounted

var _session: RampageSession


func _init(session: RampageSession) -> void:
	_session = session


func building_damage(
	amount: float,
	event: DamageEvent,
	building: StructuralBuilding2D,
	robot: GiantRobotController
) -> bool:
	return _session.publish(GameplayEvent.new(
		&"",
		event.attack_id,
		GameplayEvent.Kind.DAMAGE_APPLIED,
		&"",
		roundi(amount * 10.0),
		0.0,
		false,
		event.hit_position,
		&"",
		robot.get_instance_id(),
		building.get_instance_id(),
		event.damage_type
	))


func cell_destroyed(
	column: int,
	row: int,
	event: DamageEvent,
	building: StructuralBuilding2D,
	robot: GiantRobotController
) -> bool:
	var cell: Destructible2D = building.get_cell(column, row)
	var profile: StructuralMaterialProfile = building.get_material_profile(column, row)
	return _session.publish(GameplayEvent.new(
		StringName("cell:%d:%d" % [column, row]),
		event.attack_id,
		GameplayEvent.Kind.CELL_DESTROYED,
		GameplayEvent.CELL_BREACH,
		300,
		12.0,
		true,
		cell.global_position,
		profile.material_id,
		robot.get_instance_id(),
		cell.get_instance_id(),
		event.damage_type
	))


func chain_started(
	kind: StringName,
	building: StructuralBuilding2D,
	robot: GiantRobotController
) -> bool:
	return _session.publish(GameplayEvent.new(
		StringName("chain:%d" % building.chain_reaction_count),
		0,
		GameplayEvent.Kind.CHAIN_COLLAPSE,
		GameplayEvent.CHAIN_COLLAPSE,
		600,
		24.0,
		true,
		building.global_position,
		&"",
		robot.get_instance_id(),
		building.get_instance_id(),
		kind
	))


func building_destroyed(
	event: DamageEvent,
	building: StructuralBuilding2D,
	robot: GiantRobotController
) -> bool:
	return _session.publish(GameplayEvent.new(
		&"building_destroyed",
		event.attack_id,
		GameplayEvent.Kind.DAMAGE_APPLIED,
		&"",
		1000,
		0.0,
		false,
		building.global_position,
		&"",
		robot.get_instance_id(),
		building.get_instance_id(),
		event.damage_type
	))


func prop_destroyed(
	prop: DestructibleProp2D,
	points: int,
	robot: GiantRobotController,
	_is_car: bool
) -> bool:
	return _session.publish(GameplayEvent.new(
		StringName("prop:%d" % prop.get_instance_id()),
		0,
		GameplayEvent.Kind.PROP_DESTROYED,
		GameplayEvent.PROP_BREAK,
		points,
		6.0,
		true,
		prop.global_position,
		&"",
		robot.get_instance_id(),
		prop.get_instance_id(),
		&"destruction"
	))


func enemy_defeated(
	enemy: EnemyActor2D,
	event: DamageEvent,
	points: int,
	robot: GiantRobotController
) -> bool:
	var is_soldier: bool = enemy is SoldierEnemy
	return _session.publish(GameplayEvent.new(
		StringName("enemy:%d" % enemy.get_instance_id()),
		event.attack_id,
		GameplayEvent.Kind.ENEMY_DEFEATED,
		GameplayEvent.SOLDIER_LAUNCH if is_soldier else &"",
		points,
		_enemy_momentum_delta(enemy),
		is_soldier,
		enemy.global_position,
		&"",
		robot.get_instance_id(),
		enemy.get_instance_id(),
		event.damage_type
	))


func wreck_scrapped(
	wreck: EnemyWreck2D,
	event: DamageEvent,
	points: int,
	robot: GiantRobotController
) -> bool:
	var is_tank: bool = wreck.wreck_kind == &"tank"
	return _session.publish(GameplayEvent.new(
		StringName("wreck:%d:%d" % [wreck.get_instance_id(), event.attack_id]),
		event.attack_id,
		GameplayEvent.Kind.WRECK_SCRAPPED,
		GameplayEvent.TANK_SCRAP if is_tank else &"",
		points,
		0.0,
		is_tank,
		wreck.global_position,
		&"steel",
		robot.get_instance_id(),
		wreck.get_instance_id(),
		event.damage_type
	))


func aerial_hit(
	body: DebrisBody2D,
	event: DamageEvent,
	target: EnemyActor2D,
	robot: GiantRobotController
) -> bool:
	return _session.publish(GameplayEvent.new(
		StringName("air:%d:%d" % [event.attack_id, target.get_instance_id()]),
		event.attack_id,
		GameplayEvent.Kind.AIRBORNE_DEBRIS_HIT,
		GameplayEvent.AIR_DEBRIS_HIT,
		250,
		20.0,
		true,
		event.hit_position,
		body.material_id(),
		robot.get_instance_id(),
		target.get_instance_id(),
		event.damage_type
	))


func player_heavy_hit(
	event: DamageEvent,
	accepted_damage: float,
	robot: GiantRobotController
) -> bool:
	if accepted_damage < 30.0:
		return false
	var dedupe_key: StringName = (
		StringName("heavy_hit:%d" % event.attack_id)
		if event.attack_id != 0
		else &""
	)
	return _session.publish(GameplayEvent.new(
		dedupe_key,
		event.attack_id,
		GameplayEvent.Kind.PLAYER_HEAVY_HIT,
		&"",
		0,
		-12.0,
		false,
		event.hit_position,
		&"",
		event.source.get_instance_id() if event.source != null else 0,
		robot.get_instance_id(),
		event.damage_type
	))


func legacy_score(points: int) -> bool:
	if points <= 0:
		return false
	return _session.publish(GameplayEvent.new(
		&"",
		0,
		GameplayEvent.Kind.DAMAGE_APPLIED,
		&"",
		points
	))


func _enemy_momentum_delta(enemy: EnemyActor2D) -> float:
	if enemy is TankEnemy:
		return 16.0
	if enemy is HelicopterEnemy:
		return 0.0
	return 8.0
