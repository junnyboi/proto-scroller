class_name EnemySpawnTuning
extends RefCounted

const QUANTITY_MULTIPLIER: int = 2
const INTERVAL_SCALE: float = 0.5


static func scaled_count(base_count: int) -> int:
	return maxi(base_count, 0) * QUANTITY_MULTIPLIER


static func scaled_interval(seconds: float) -> float:
	return maxf(seconds, 0.0) * INTERVAL_SCALE


static func scaled_threat(base_threat: int) -> int:
	return maxi(base_threat, 0) * QUANTITY_MULTIPLIER


static func offset_for_copy(copy_index: int, spacing: float, direction: float = 1.0) -> Vector2:
	var centered_index: float = float(copy_index) - float(QUANTITY_MULTIPLIER - 1) * 0.5
	return Vector2(centered_index * spacing * direction, 0.0)
