class_name DossierDefinition
extends RefCounted

var dossier_id: StringName
var building_variant_id: StringName
var district_id: StringName
var trigger_column: int
var trigger_row: int
var title_key: String
var body_primary_key: String
var body_secondary_key: String
var image: Texture2D
var reveal_id: StringName


static func create(
	p_building_variant_id: StringName,
	p_district_id: StringName,
	p_trigger_column: int,
	p_trigger_row: int,
	p_image: Texture2D
) -> DossierDefinition:
	var definition: DossierDefinition = DossierDefinition.new()
	definition.building_variant_id = p_building_variant_id
	definition.district_id = p_district_id
	definition.dossier_id = StringName("dossier_%s" % p_building_variant_id)
	definition.trigger_column = p_trigger_column
	definition.trigger_row = p_trigger_row
	definition.title_key = "narrative.dossier.%s.title" % p_building_variant_id
	definition.body_primary_key = "narrative.dossier.%s.body_primary" % p_building_variant_id
	definition.body_secondary_key = "narrative.dossier.%s.body_secondary" % p_building_variant_id
	definition.image = p_image
	definition.reveal_id = StringName("reveal_%s" % p_building_variant_id)
	return definition


func trigger_matches(column: int, row: int) -> bool:
	return column == trigger_column and row == trigger_row
