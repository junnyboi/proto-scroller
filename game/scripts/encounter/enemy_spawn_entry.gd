class_name EnemySpawnEntry
extends Resource

@export_enum(
	"soldier", "tank", "helicopter",
	"needle", "bulwark", "jackal", "lobber", "sapper",
	"hound", "mule", "basilisk", "lancer", "static",
	"kestrel", "rainmaker", "shrike", "cinder", "aegis",
	"longbow", "hive", "goliath", "nemesis", "leviathan"
) var kind: String = "soldier"
@export var delay: float = 0.0
@export var position: Vector2 = Vector2.ZERO
@export_enum(
	"WORLD",
	"AHEAD",
	"BEHIND",
	"CAMERA_LEFT",
	"CAMERA_RIGHT"
) var spawn_anchor: String = "WORLD"
@export var offset: Vector2 = Vector2.ZERO
@export var role_id: StringName = &"BASE"
@export var trait_id: StringName = &""
