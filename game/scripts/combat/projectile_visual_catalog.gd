class_name ProjectileVisualCatalog
extends RefCounted

enum TrailMode {
	NONE,
	PROCEDURAL_LINE,
	EXHAUST_FLICKER,
}

const ENEMY_BULLET: StringName = &"enemy_bullet"
const ENEMY_SHELL: StringName = &"enemy_shell"
const ENEMY_ROCKET_DIRECT: StringName = &"enemy_rocket_direct"
const ENEMY_ROCKET_SALVO: StringName = &"enemy_rocket_salvo"

const SPECS: Dictionary = {
	ENEMY_BULLET: {
		"texture": preload("res://art/enemies/projectiles/straight_bullet_tracer.png"),
		"source_size": Vector2i(96, 32),
		"display_size": Vector2(36.0, 12.0),
		"collision_radius_contract": 5.0,
		"canonical_angle": 0.0,
		"trail_mode": TrailMode.NONE,
	},
	ENEMY_SHELL: {
		"texture": preload("res://art/combat/projectiles/straight_shell.png"),
		"source_size": Vector2i(256, 128),
		"display_size": Vector2(36.0, 18.0),
		"collision_radius_contract": 9.0,
		"canonical_angle": 0.0,
		"trail_mode": TrailMode.NONE,
	},
	ENEMY_ROCKET_DIRECT: {
		"texture": preload("res://art/city/projectiles/enemy_direct_rocket.png"),
		"source_size": Vector2i(256, 96),
		"display_size": Vector2(42.0, 16.0),
		"collision_radius_contract": 7.0,
		"canonical_angle": 0.0,
		"trail_mode": TrailMode.NONE,
	},
	ENEMY_ROCKET_SALVO: {
		"texture": preload("res://art/city/projectiles/hostile-spread-rocket.png"),
		"source_size": Vector2i(192, 72),
		"display_size": Vector2(36.0, 14.0),
		"collision_radius_contract": 7.0,
		"canonical_angle": 0.0,
		"trail_mode": TrailMode.NONE,
	},
}


static func has(visual_key: StringName) -> bool:
	return SPECS.has(visual_key)


static func spec(visual_key: StringName) -> Dictionary:
	return SPECS.get(visual_key, {})


static func default_key(damage_type: StringName) -> StringName:
	match damage_type:
		&"bullet":
			return ENEMY_BULLET
		&"shell":
			return ENEMY_SHELL
		&"rocket":
			return ENEMY_ROCKET_DIRECT
		_:
			return &""


static func debug_validate() -> bool:
	for visual_key: StringName in SPECS:
		var item: Dictionary = spec(visual_key)
		var texture: Texture2D = item.get("texture") as Texture2D
		var source_size: Vector2i = item.get("source_size", Vector2i.ZERO)
		var display_size: Vector2 = item.get("display_size", Vector2.ZERO)
		var radius: float = float(item.get("collision_radius_contract", 0.0))
		if texture == null or Vector2i(texture.get_size()) != source_size:
			return false
		if source_size.x <= 0 or source_size.y <= 0:
			return false
		if display_size.x <= 0.0 or display_size.y <= 0.0:
			return false
		if not is_equal_approx(radius, _expected_collision_radius(visual_key)):
			return false
	return true


static func _expected_collision_radius(visual_key: StringName) -> float:
	match visual_key:
		ENEMY_BULLET:
			return 5.0
		ENEMY_SHELL:
			return 9.0
		ENEMY_ROCKET_DIRECT, ENEMY_ROCKET_SALVO:
			return 7.0
		_:
			return 0.0
