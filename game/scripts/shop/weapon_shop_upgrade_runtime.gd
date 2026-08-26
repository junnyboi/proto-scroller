class_name WeaponShopUpgradeRuntime
extends Node

var robot: GiantRobotController
var all_damage_multiplier: float = 1.0
var melee_damage_multiplier: float = 1.0
var weapon_damage_multiplier: float = 1.0
var ballistic_damage_multiplier: float = 1.0
var structural_damage_multiplier: float = 1.0
var elite_damage_multiplier: float = 1.0
var debris_bonus_damage: float = 0.0
var melee_radius_multiplier: float = 1.0
var weapon_cooldown_multiplier: float = 1.0
var critical_chance: float = 0.0
var incoming_damage_multiplier: float = 1.0


func setup(p_robot: GiantRobotController) -> void:
	robot = p_robot
	robot.set_shop_incoming_damage_multiplier(incoming_damage_multiplier)


func apply_product(product: WeaponShopProduct) -> bool:
	if product == null or robot == null:
		return false
	match product.effect_key:
		&"repair":
			_repair(product.repair_ratio)
		&"aegis":
			_repair(product.repair_ratio)
			incoming_damage_multiplier *= 1.0 - product.effect_value
			robot.set_shop_incoming_damage_multiplier(incoming_damage_multiplier)
		&"all_damage":
			all_damage_multiplier *= 1.0 + product.effect_value
		&"weapon_damage":
			weapon_damage_multiplier *= 1.0 + product.effect_value
		&"ballistic_damage":
			ballistic_damage_multiplier *= 1.0 + product.effect_value
		&"structural_damage":
			structural_damage_multiplier *= 1.0 + product.effect_value
		&"elite_damage":
			elite_damage_multiplier *= 1.0 + product.effect_value
		&"debris_damage":
			debris_bonus_damage += AerialDebrisLauncher.IMPACT_DAMAGE * product.effect_value
		&"melee_radius":
			melee_radius_multiplier *= 1.0 + product.effect_value
		&"weapon_cooldown":
			weapon_cooldown_multiplier *= 1.0 - product.effect_value
		&"critical_chance":
			critical_chance = clampf(critical_chance + product.effect_value, 0.0, 0.8)
		_:
			return false
	return true


func decorate_attack(spec: AttackSpec) -> AttackSpec:
	if spec == null:
		return null
	return spec.with_shop_modifiers(
		all_damage_multiplier * melee_damage_multiplier,
		structural_damage_multiplier,
		melee_radius_multiplier,
		debris_bonus_damage
	)


func scale_weapon_damage(
	base_damage: float,
	damage_kind: StringName,
	target: Node,
	attack_id: int
) -> float:
	var multiplier: float = all_damage_multiplier * weapon_damage_multiplier
	if damage_kind == &"machine_gun":
		multiplier *= ballistic_damage_multiplier
	if target is Destructible2D or target is StructuralBuilding2D:
		multiplier *= structural_damage_multiplier
	if target is EnemyActor2D:
		var enemy: EnemyActor2D = target as EnemyActor2D
		if enemy.trait_id != &"" or enemy.boss_mode:
			multiplier *= elite_damage_multiplier
	if critical_chance > 0.0 and _critical_roll(attack_id, damage_kind):
		multiplier *= 2.0
	return maxf(base_damage, 0.0) * multiplier


func scale_weapon_cooldown(base_seconds: float) -> float:
	return maxf(base_seconds, 0.02) * weapon_cooldown_multiplier


func _critical_roll(attack_id: int, damage_kind: StringName) -> bool:
	var threshold: int = roundi(critical_chance * 10_000.0)
	return posmod(hash("%d:%s:shop-critical" % [attack_id, damage_kind]), 10_000) < threshold


func _repair(ratio: float) -> float:
	var previous: float = robot.current_health
	robot.current_health = minf(robot.max_health, robot.current_health + robot.max_health * ratio)
	robot.health_changed.emit(robot.current_health, robot.max_health)
	return robot.current_health - previous
