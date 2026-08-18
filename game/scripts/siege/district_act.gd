class_name DistrictAct
extends Resource

@export var act_id: StringName = &"CONTACT"
@export var display_name: String = "CONTACT"
@export_range(15.0, 120.0, 1.0) var target_duration: float = 75.0
@export var beats: Array[DistrictBeat] = []
@export var milestone_after: StringName = &""
@export var elite_allowed: bool = false
