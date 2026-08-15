class_name DamageEvent
extends RefCounted

var attack_id: int
var source: Node
var amount: float
var damage_type: StringName
var hit_position: Vector2
var direction: Vector2
var impulse_per_mass: float


func _init(
	p_attack_id: int = 0,
	p_source: Node = null,
	p_amount: float = 0.0,
	p_damage_type: StringName = &"impact",
	p_hit_position: Vector2 = Vector2.ZERO,
	p_direction: Vector2 = Vector2.RIGHT,
	p_impulse_per_mass: float = 0.0
) -> void:
	attack_id = p_attack_id
	source = p_source
	amount = maxf(p_amount, 0.0)
	damage_type = p_damage_type
	hit_position = p_hit_position
	direction = p_direction.normalized() if not p_direction.is_zero_approx() else Vector2.RIGHT
	impulse_per_mass = maxf(p_impulse_per_mass, 0.0)


func scaled(factor: float) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		source,
		amount * factor,
		damage_type,
		hit_position,
		direction,
		impulse_per_mass * factor
	)
