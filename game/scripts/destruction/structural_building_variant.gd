class_name StructuralBuildingVariant
extends Resource

const EXPECTED_MATERIAL_COUNT: int = 6

@export var variant_id: StringName = &"legacy"
@export var display_name: String = "Legacy Building"
@export var intact_texture: Texture2D:
	get:
		_intact_texture = _load_texture(intact_texture_path, _intact_texture)
		return _intact_texture
	set(value):
		_intact_texture = value
@export var damaged_texture: Texture2D:
	get:
		_damaged_texture = _load_texture(damaged_texture_path, _damaged_texture)
		return _damaged_texture
	set(value):
		_damaged_texture = value
@export var rubble_texture: Texture2D:
	get:
		_rubble_texture = _load_texture(rubble_texture_path, _rubble_texture)
		return _rubble_texture
	set(value):
		_rubble_texture = value
@export var display_size: Vector2 = Vector2(600.0, 534.0)
@export var material_ids: PackedStringArray = PackedStringArray([
	"concrete",
	"steel",
	"concrete",
	"glass",
	"concrete",
	"steel",
])
@export var visual_tint: Color = Color.WHITE
@export var destruction_signature: StringName = &"structural_cascade"

var intact_texture_path: String = ""
var damaged_texture_path: String = ""
var rubble_texture_path: String = ""
var _intact_texture: Texture2D
var _damaged_texture: Texture2D
var _rubble_texture: Texture2D


func configure_texture_paths(
	intact_path: String,
	damaged_path: String,
	rubble_path: String
) -> void:
	intact_texture_path = intact_path
	damaged_texture_path = damaged_path
	rubble_texture_path = rubble_path
	_intact_texture = null
	_damaged_texture = null
	_rubble_texture = null


func material_id_at(column: int, row: int) -> StringName:
	var index: int = row * 3 + column
	if index < 0 or index >= material_ids.size():
		return &"concrete"
	return StringName(material_ids[index])


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if variant_id.is_empty():
		errors.append("variant_id is empty")
	if display_name.is_empty():
		errors.append("display_name is empty for %s" % variant_id)
	if intact_texture == null:
		errors.append("intact texture missing for %s" % variant_id)
	if damaged_texture == null:
		errors.append("damaged texture missing for %s" % variant_id)
	if rubble_texture == null:
		errors.append("rubble texture missing for %s" % variant_id)
	if display_size.x <= 0.0 or display_size.y <= 0.0:
		errors.append("display_size is invalid for %s" % variant_id)
	if material_ids.size() != EXPECTED_MATERIAL_COUNT:
		errors.append(
			"material_ids=%d expected=%d for %s"
			% [material_ids.size(), EXPECTED_MATERIAL_COUNT, variant_id]
		)
	var steel_count: int = 0
	for material_id: String in material_ids:
		if material_id not in ["concrete", "glass", "steel"]:
			errors.append("unknown material %s for %s" % [material_id, variant_id])
		if material_id == "steel":
			steel_count += 1
	if steel_count == 0:
		errors.append("no steel support authored for %s" % variant_id)
	return errors


func _load_texture(texture_path: String, current: Texture2D) -> Texture2D:
	if current != null or texture_path.is_empty():
		return current
	return load(texture_path) as Texture2D
