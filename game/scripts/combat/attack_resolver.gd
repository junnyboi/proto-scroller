class_name AttackResolver
extends Node

@export_range(0.0, 1.0, 0.01) var jab_cross_speed_threshold: float = 0.70
@export var ground_anticipation_seconds: float = 0.10
@export var ground_active_seconds: float = 0.01
@export var ground_recovery_seconds: float = 0.22
@export var jab_cross_anticipation_seconds: float = 0.055
@export var jab_cross_active_seconds: float = 0.10
@export var jab_cross_recovery_seconds: float = 0.14
@export var jab_cross_actor_damage: float = 145.0
@export var jab_cross_structural_damage: float = 125.0
@export var jab_cross_impulse_per_mass: float = 1080.0
@export var jab_cross_hit_size: Vector2 = Vector2(190.0, 150.0)
@export var jab_cross_hit_offset: Vector2 = Vector2(105.0, 62.0)


func resolve(
	attack_id: int,
	facing: int,
	actual_speed_ratio: float,
	ground_damage: float,
	ground_impulse_per_mass: float,
	ground_radius: float,
	force_multiplier: float = 1.0,
	structure_multiplier: float = 1.0,
	opening_compression: bool = false
) -> AttackSpec:
	if actual_speed_ratio >= jab_cross_speed_threshold:
		return AttackSpec.new(
			AttackSpec.Mode.JAB_CROSS,
			attack_id,
			facing,
			actual_speed_ratio,
			jab_cross_anticipation_seconds,
			jab_cross_active_seconds,
			jab_cross_recovery_seconds,
			jab_cross_actor_damage,
			jab_cross_structural_damage * structure_multiplier,
			jab_cross_impulse_per_mass * force_multiplier,
			jab_cross_hit_size,
			jab_cross_hit_offset,
			opening_compression
		)
	return AttackSpec.new(
		AttackSpec.Mode.GROUND_SMASH,
		attack_id,
		facing,
		actual_speed_ratio,
		ground_anticipation_seconds,
		ground_active_seconds,
		ground_recovery_seconds,
		ground_damage,
		ground_damage * structure_multiplier,
		ground_impulse_per_mass * force_multiplier,
		Vector2.ONE * ground_radius * 2.0,
		Vector2.ZERO
	)
