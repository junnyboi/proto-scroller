class_name DirectiveProfile
extends Resource

@export var directive_id: StringName = &""
@export var display_name: String = "DIRECTIVE"
@export var instruction: String = ""
@export_range(1.0, 30.0, 0.5) var duration_seconds: float = 12.0
@export_range(1, 20, 1) var target_count: int = 1
@export_range(1.0, 1.5, 0.05) var structural_multiplier: float = 1.0
@export_range(0.0, 0.5, 0.05) var pending_bank_fraction: float = 0.25
@export_range(0.0, 0.5, 0.05) var failure_penalty_fraction: float = 0.20
@export var effect_flag: int = DamageEvent.FLAG_NONE
@export var icon: Texture2D
