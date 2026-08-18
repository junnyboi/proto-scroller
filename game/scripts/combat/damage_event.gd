class_name DamageEvent
extends RefCounted

const FLAG_NONE: int = 0
const FLAG_CATALYST: int = 1 << 0
const FLAG_DIRECTIVE_BREACH: int = 1 << 1
const FLAG_DIRECTIVE_AFTERSHOCK: int = 1 << 2
const FLAG_DIRECTIVE_SKYBREAKER: int = 1 << 3
const FLAG_VOLATILE: int = 1 << 4
const MAX_CAUSAL_DEPTH: int = 3

var attack_id: int
var source: Node
var amount: float
var damage_type: StringName
var hit_position: Vector2
var direction: Vector2
var impulse_per_mass: float
var root_attack_id: int
var causal_depth: int
var effect_flags: int


func _init(
	p_attack_id: int = 0,
	p_source: Node = null,
	p_amount: float = 0.0,
	p_damage_type: StringName = &"impact",
	p_hit_position: Vector2 = Vector2.ZERO,
	p_direction: Vector2 = Vector2.RIGHT,
	p_impulse_per_mass: float = 0.0,
	p_root_attack_id: int = 0,
	p_causal_depth: int = 0,
	p_effect_flags: int = FLAG_NONE
) -> void:
	attack_id = p_attack_id
	source = p_source
	amount = maxf(p_amount, 0.0)
	damage_type = p_damage_type
	hit_position = p_hit_position
	direction = p_direction.normalized() if not p_direction.is_zero_approx() else Vector2.RIGHT
	impulse_per_mass = maxf(p_impulse_per_mass, 0.0)
	root_attack_id = p_root_attack_id if p_root_attack_id != 0 else p_attack_id
	causal_depth = maxi(p_causal_depth, 0)
	effect_flags = p_effect_flags


func scaled(factor: float) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		source,
		amount * factor,
		damage_type,
		hit_position,
		direction,
		impulse_per_mass * factor,
		root_attack_id,
		causal_depth,
		effect_flags
	)
