class_name BossAnimationCatalog
extends RefCounted

const COLUMN_COUNT: int = 8
const ROW_COUNT: int = 4
const FRAME_COUNT: int = 8
const MOVING_FPS: float = 6.0
const TELEGRAPH_SECONDS: float = 0.85
const ACTIVE_SECONDS: float = 0.55
const RECOVERY_SECONDS: float = 0.75
const TELEGRAPH_FRAME_RANGE: Vector2i = Vector2i(0, 3)
const ACTIVE_FRAME_RANGE: Vector2i = Vector2i(3, 5)
const RECOVERY_FRAME_RANGE: Vector2i = Vector2i(5, 8)

const SETTLEMENT_ATLAS: Texture2D = preload(
	"res://art/bosses/animated/settlement-engine-s04-atlas.webp"
)
const SAMARITAN_ATLAS: Texture2D = preload(
	"res://art/bosses/animated/samaritan-15-atlas.webp"
)
const MIMESIS_ATLAS: Texture2D = preload(
	"res://art/bosses/animated/mimesis-04-atlas.webp"
)
const CANTOR_ATLAS: Texture2D = preload(
	"res://art/bosses/animated/cantor-31-atlas.webp"
)
const CHOIR_PRIME_ATLAS: Texture2D = preload(
	"res://art/bosses/animated/choir-prime-atlas.webp"
)


static func texture_for_preset(preset: StringName) -> Texture2D:
	match preset:
		&"SETTLEMENT_ENGINE":
			return SETTLEMENT_ATLAS
		&"SAMARITAN":
			return SAMARITAN_ATLAS
		&"MIMESIS":
			return MIMESIS_ATLAS
		&"CANTOR_PALE_ENGINE":
			return CANTOR_ATLAS
		&"CHOIR_PRIME":
			return CHOIR_PRIME_ATLAS
	return SETTLEMENT_ATLAS


static func sequence_row(direction: StringName, state: StringName) -> int:
	var west: bool = direction == &"W"
	if state == &"ATTACKING":
		return 3 if west else 2
	return 1 if west else 0


static func frame_range_for_stage(stage: StringName) -> Vector2i:
	match stage:
		&"ACTIVE":
			return ACTIVE_FRAME_RANGE
		&"RECOVERY":
			return RECOVERY_FRAME_RANGE
	return TELEGRAPH_FRAME_RANGE


static func stage_duration(stage: StringName) -> float:
	match stage:
		&"ACTIVE":
			return ACTIVE_SECONDS
		&"RECOVERY":
			return RECOVERY_SECONDS
	return TELEGRAPH_SECONDS


static func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var textures: Dictionary[StringName, Texture2D] = {
		&"SETTLEMENT_ENGINE": SETTLEMENT_ATLAS,
		&"SAMARITAN": SAMARITAN_ATLAS,
		&"MIMESIS": MIMESIS_ATLAS,
		&"CANTOR_PALE_ENGINE": CANTOR_ATLAS,
		&"CHOIR_PRIME": CHOIR_PRIME_ATLAS,
	}
	for preset: StringName in textures:
		var texture: Texture2D = textures[preset]
		if texture == null:
			errors.append("%s animation atlas missing" % preset)
			continue
		var size: Vector2 = texture.get_size()
		if int(size.x) % COLUMN_COUNT != 0 or int(size.y) % ROW_COUNT != 0:
			errors.append("%s atlas grid is not %dx%d" % [preset, COLUMN_COUNT, ROW_COUNT])
	return errors
