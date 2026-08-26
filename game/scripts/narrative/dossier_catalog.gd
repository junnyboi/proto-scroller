class_name DossierCatalog
extends RefCounted

const EVIDENCE_NODE: Texture2D = preload("res://art/narrative/memory-glass-node.png")
const TRIGGERS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(2, 0),
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(2, 0),
]

static var _definitions: Array[DossierDefinition] = []
static var _by_dossier_id: Dictionary[StringName, DossierDefinition] = {}
static var _by_variant_id: Dictionary[StringName, DossierDefinition] = {}


static func definitions() -> Array[DossierDefinition]:
	_ensure_catalog()
	return _definitions.duplicate()


static func definition_for_variant(variant_id: StringName) -> DossierDefinition:
	_ensure_catalog()
	return _by_variant_id.get(variant_id) as DossierDefinition


static func definition_for_dossier(dossier_id: StringName) -> DossierDefinition:
	_ensure_catalog()
	return _by_dossier_id.get(dossier_id) as DossierDefinition


static func has_dossier(dossier_id: StringName) -> bool:
	_ensure_catalog()
	return _by_dossier_id.has(dossier_id)


static func district_definitions(district_id: StringName) -> Array[DossierDefinition]:
	_ensure_catalog()
	var result: Array[DossierDefinition] = []
	for definition: DossierDefinition in _definitions:
		if definition.district_id == district_id:
			result.append(definition)
	return result


static func validation_errors() -> PackedStringArray:
	_ensure_catalog()
	var errors: PackedStringArray = PackedStringArray()
	if _definitions.size() != CityDistrictCatalog.BUILDING_VARIANT_COUNT:
		errors.append(
			"dossier_count=%d expected=%d"
			% [_definitions.size(), CityDistrictCatalog.BUILDING_VARIANT_COUNT]
		)
	var district_counts: Dictionary[StringName, int] = {}
	var dossier_ids: Dictionary[StringName, bool] = {}
	var variant_ids: Dictionary[StringName, bool] = {}
	for definition: DossierDefinition in _definitions:
		if dossier_ids.has(definition.dossier_id):
			errors.append("duplicate dossier_id %s" % definition.dossier_id)
		dossier_ids[definition.dossier_id] = true
		if variant_ids.has(definition.building_variant_id):
			errors.append("duplicate dossier variant %s" % definition.building_variant_id)
		variant_ids[definition.building_variant_id] = true
		if CityDistrictCatalog.variant_by_id(definition.building_variant_id) == null:
			errors.append("unknown dossier variant %s" % definition.building_variant_id)
		if not definition.trigger_column in range(StructuralBuilding2D.COLUMNS):
			errors.append("invalid dossier column %s" % definition.dossier_id)
		if not definition.trigger_row in range(StructuralBuilding2D.ROWS):
			errors.append("invalid dossier row %s" % definition.dossier_id)
		if definition.image == null:
			errors.append("missing dossier image %s" % definition.dossier_id)
		district_counts[definition.district_id] = int(
			district_counts.get(definition.district_id, 0)
		) + 1
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		if int(district_counts.get(district.district_id, 0)) != 5:
			errors.append("district dossier count mismatch %s" % district.district_id)
	var opening: DossierDefinition = definition_for_variant(
		&"business_mercy_exchange_annex"
	)
	if opening == null or opening.reveal_id != &"reveal_business_mercy_exchange_annex":
		errors.append("opening black-lab dossier missing")
	return errors


static func _ensure_catalog() -> void:
	if not _definitions.is_empty():
		return
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		for variant_index: int in range(district.building_variants.size()):
			var variant: StructuralBuildingVariant = district.building_variants[variant_index]
			var trigger: Vector2i = TRIGGERS[variant_index]
			var definition: DossierDefinition = DossierDefinition.create(
				variant.variant_id,
				district.district_id,
				trigger.x,
				trigger.y,
				EVIDENCE_NODE
			)
			_definitions.append(definition)
			_by_dossier_id[definition.dossier_id] = definition
			_by_variant_id[definition.building_variant_id] = definition
