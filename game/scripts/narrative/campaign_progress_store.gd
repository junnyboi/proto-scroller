class_name CampaignProgressStore
extends Node

signal dossier_changed(dossier_id: StringName, total: int)
signal evidence_changed(evidence_id: StringName, total: int)
signal continuity_changed(generation: int)
signal ending_changed(ending_id: StringName)

const SCHEMA_VERSION: int = 1
const DEFAULT_PATH: String = "user://choir_campaign.cfg"
const SECTION_META: String = "meta"
const SECTION_PROGRESS: String = "progress"
const SECTION_ENDING: String = "ending"

var save_path: String = DEFAULT_PATH
var last_error: Error = OK
var save_count: int = 0
var _dossiers: Dictionary[StringName, bool] = {}
var _evidence: Dictionary[StringName, bool] = {}
var _reveals: Dictionary[StringName, bool] = {}
var _seen_endings: Dictionary[StringName, bool] = {}
var _continuity_generation: int = 0


func setup(path: String = DEFAULT_PATH) -> void:
	save_path = path
	load_progress()


func load_progress() -> bool:
	_clear_memory()
	last_error = OK
	if not FileAccess.file_exists(save_path):
		return true
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(save_path)
	if error != OK:
		last_error = error
		push_warning("Unable to load Project CHOIR campaign progress: %s" % save_path)
		return false
	if (
		not config.has_section(SECTION_META)
		and not config.has_section(SECTION_PROGRESS)
		and not config.has_section(SECTION_ENDING)
	):
		last_error = ERR_INVALID_DATA
		push_warning("Project CHOIR campaign progress has no recognized sections")
		return false
	var schema_version: int = int(config.get_value(SECTION_META, "schema_version", 0))
	if schema_version < 0 or schema_version > SCHEMA_VERSION:
		last_error = ERR_INVALID_DATA
		push_warning("Unsupported Project CHOIR campaign schema: %d" % schema_version)
		return false
	_load_valid_dossiers(
		config.get_value(SECTION_PROGRESS, "collected_dossiers", PackedStringArray())
	)
	_load_string_set(
		config.get_value(SECTION_PROGRESS, "preserved_evidence", PackedStringArray()),
		_evidence
	)
	_load_string_set(
		config.get_value(SECTION_PROGRESS, "unlocked_reveals", PackedStringArray()),
		_reveals
	)
	_load_string_set(
		config.get_value(SECTION_ENDING, "seen_endings", PackedStringArray()),
		_seen_endings
	)
	_continuity_generation = maxi(
		int(config.get_value(SECTION_PROGRESS, "continuity_generation", 0)),
		0
	)
	return true


func save_progress() -> bool:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION_META, "schema_version", SCHEMA_VERSION)
	config.set_value(SECTION_PROGRESS, "collected_dossiers", _sorted_keys(_dossiers))
	config.set_value(SECTION_PROGRESS, "preserved_evidence", _sorted_keys(_evidence))
	config.set_value(SECTION_PROGRESS, "unlocked_reveals", _sorted_keys(_reveals))
	config.set_value(SECTION_PROGRESS, "continuity_generation", _continuity_generation)
	config.set_value(SECTION_ENDING, "seen_endings", _sorted_keys(_seen_endings))
	last_error = config.save(save_path)
	if last_error != OK:
		push_warning("Unable to save Project CHOIR campaign progress: %s" % save_path)
		return false
	save_count += 1
	return true


func collect_dossier(dossier_id: StringName) -> bool:
	if not DossierCatalog.has_dossier(dossier_id) or _dossiers.has(dossier_id):
		return false
	_dossiers[dossier_id] = true
	var definition: DossierDefinition = DossierCatalog.definition_for_dossier(dossier_id)
	if definition != null:
		_reveals[definition.reveal_id] = true
	save_progress()
	dossier_changed.emit(dossier_id, dossier_count())
	return true


func preserve_evidence(evidence_id: StringName) -> bool:
	if evidence_id.is_empty() or _evidence.has(evidence_id):
		return false
	_evidence[evidence_id] = true
	save_progress()
	evidence_changed.emit(evidence_id, evidence_count())
	return true


func increment_continuity() -> int:
	_continuity_generation += 1
	save_progress()
	continuity_changed.emit(_continuity_generation)
	return _continuity_generation


func mark_ending_seen(ending_id: StringName) -> bool:
	if ending_id.is_empty() or _seen_endings.has(ending_id):
		return false
	_seen_endings[ending_id] = true
	save_progress()
	ending_changed.emit(ending_id)
	return true


func has_dossier(dossier_id: StringName) -> bool:
	return _dossiers.has(dossier_id)


func has_reveal(reveal_id: StringName) -> bool:
	return _reveals.has(reveal_id)


func has_ending(ending_id: StringName) -> bool:
	return _seen_endings.has(ending_id)


func dossier_count() -> int:
	return _dossiers.size()


func district_dossier_count(district_id: StringName) -> int:
	var count: int = 0
	for definition: DossierDefinition in DossierCatalog.district_definitions(district_id):
		if _dossiers.has(definition.dossier_id):
			count += 1
	return count


func evidence_count() -> int:
	return _evidence.size()


func continuity_generation() -> int:
	return _continuity_generation


func collected_dossier_ids() -> PackedStringArray:
	return _sorted_keys(_dossiers)


func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"dossiers": collected_dossier_ids(),
		"dossier_count": dossier_count(),
		"evidence": _sorted_keys(_evidence),
		"evidence_count": evidence_count(),
		"reveals": _sorted_keys(_reveals),
		"continuity_generation": _continuity_generation,
		"seen_endings": _sorted_keys(_seen_endings),
	}


func reset_memory() -> void:
	_clear_memory()


func _clear_memory() -> void:
	_dossiers.clear()
	_evidence.clear()
	_reveals.clear()
	_seen_endings.clear()
	_continuity_generation = 0


func _load_valid_dossiers(value: Variant) -> void:
	var ids: PackedStringArray = _coerce_ids(value)
	for raw_id: String in ids:
		var dossier_id: StringName = StringName(raw_id)
		if DossierCatalog.has_dossier(dossier_id):
			_dossiers[dossier_id] = true
			var definition: DossierDefinition = DossierCatalog.definition_for_dossier(
				dossier_id
			)
			if definition != null:
				_reveals[definition.reveal_id] = true


func _load_string_set(value: Variant, target: Dictionary[StringName, bool]) -> void:
	for raw_id: String in _coerce_ids(value):
		if not raw_id.is_empty():
			target[StringName(raw_id)] = true


func _coerce_ids(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value as PackedStringArray
	var ids: PackedStringArray = PackedStringArray()
	if value is Array:
		for raw_id: Variant in value as Array:
			if raw_id is String or raw_id is StringName:
				ids.append(String(raw_id))
	return ids


func _sorted_keys(source: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for raw_id: Variant in source.keys():
		result.append(String(raw_id))
	result.sort()
	return result
