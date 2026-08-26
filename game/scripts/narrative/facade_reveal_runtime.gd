class_name FacadeRevealRuntime
extends Node

const LAB_TEXTURE: Texture2D = preload("res://art/narrative/choir-black-lab.jpg")
const REVEAL_MODULATE: Color = Color(0.72, 0.94, 1.0, 0.92)

var streamed_destructibles: StreamedDestructibleRuntime
var campaign_progress: CampaignProgressStore
var _slots: Dictionary[int, Sprite2D] = {}


func setup(
	runtime: StreamedDestructibleRuntime,
	progress: CampaignProgressStore
) -> void:
	streamed_destructibles = runtime
	campaign_progress = progress
	if not runtime.building_configured.is_connected(_on_building_configured):
		runtime.building_configured.connect(_on_building_configured)
	for building: StructuralBuilding2D in runtime.buildings:
		_build_slot(building)
		_refresh_slot(building)


func reveal(building: StructuralBuilding2D, _definition: DossierDefinition) -> void:
	if building == null:
		return
	_build_slot(building)
	var sprite: Sprite2D = _slots[building.get_instance_id()]
	sprite.visible = true


func slot_count() -> int:
	return _slots.size()


func visible_count() -> int:
	var count: int = 0
	for sprite: Sprite2D in _slots.values():
		if sprite.visible:
			count += 1
	return count


func _build_slot(building: StructuralBuilding2D) -> void:
	if _slots.has(building.get_instance_id()):
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "ChoirLabReveal"
	sprite.texture = LAB_TEXTURE
	sprite.centered = true
	sprite.z_index = -6
	sprite.z_as_relative = true
	sprite.modulate = REVEAL_MODULATE
	sprite.visible = false
	building.add_child(sprite)
	_slots[building.get_instance_id()] = sprite
	_layout_slot(building, sprite)


func _on_building_configured(
	building: StructuralBuilding2D,
	_logical_chunk: int,
	_variant_id: StringName
) -> void:
	_build_slot(building)
	_refresh_slot(building)


func _refresh_slot(building: StructuralBuilding2D) -> void:
	var sprite: Sprite2D = _slots.get(building.get_instance_id()) as Sprite2D
	if sprite == null:
		return
	_layout_slot(building, sprite)
	var definition: DossierDefinition = DossierCatalog.definition_for_variant(
		building.current_variant_id()
	)
	sprite.visible = (
		definition != null
		and campaign_progress != null
		and campaign_progress.has_dossier(definition.dossier_id)
		and building.is_cell_destroyed(definition.trigger_column, definition.trigger_row)
	)


func _layout_slot(building: StructuralBuilding2D, sprite: Sprite2D) -> void:
	var texture_size: Vector2 = LAB_TEXTURE.get_size()
	var display_size: Vector2 = building.display_size
	sprite.position = Vector2(0.0, -display_size.y * 0.5)
	sprite.scale = Vector2(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
