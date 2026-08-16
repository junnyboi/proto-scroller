class_name AttackResolver
extends Node

@export_range(0.0, 1.0, 0.01) var drive_speed_threshold: float = 0.70
@export var ground_anticipation_seconds: float = 0.10
@export var ground_active_seconds: float = 0.01
@export var ground_recovery_seconds: float = 0.22
@export var drive_anticipation_seconds: float = 0.08
@export var drive_active_seconds: float = 0.12
@export var drive_recovery_seconds: float = 0.18
@export var drive_actor_damage: float = 130.0
@export var drive_structural_damage: float = 180.0
@export var drive_impulse_per_mass: float = 920.0
@export var drive_hit_size: Vector2 = Vector2(190.0, 150.0)
@export var drive_hit_offset: Vector2 = Vector2(105.0, 62.0)


func resolve(
	attack_id: int,
	facing: int,
	actual_speed_ratio: float,
	ground_damage: float,
	ground_impulse_per_mass: float,
	ground_radius: float
) -> AttackSpec:
	if actual_speed_ratio >= drive_speed_threshold:
		return AttackSpec.new(
			AttackSpec.Mode.SHOULDER_DRIVE,
			attack_id,
			facing,
			actual_speed_ratio,
			drive_anticipation_seconds,
			drive_active_seconds,
			drive_recovery_seconds,
			drive_actor_damage,
			drive_structural_damage,
			drive_impulse_per_mass,
			drive_hit_size,
			drive_hit_offset
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
		ground_damage,
		ground_impulse_per_mass,
		Vector2.ONE * ground_radius * 2.0,
		Vector2.ZERO
	)
