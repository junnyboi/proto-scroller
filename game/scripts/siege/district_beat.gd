class_name DistrictBeat
extends Resource

@export var beat_id: StringName = &"BEAT"
@export_range(8.0, 15.0, 0.5) var pressure_seconds: float = 10.0
@export_range(2.0, 4.0, 0.5) var recovery_seconds: float = 3.0
@export var spawns: Array[EnemySpawnEntry] = []
@export_range(-1, 1, 1) var catalyst_slot: int = -1
