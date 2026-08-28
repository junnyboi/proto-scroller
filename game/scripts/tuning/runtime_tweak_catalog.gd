class_name RuntimeTweakCatalog
extends RefCounted

const DEFAULT_PATH: String = "res://config/runtime_tweaks/catalog.json"
const EXPECTED_SCHEMA_VERSION: int = 1
const EXPECTED_ENABLED_COUNT: int = 50

var schema_version: int = 0
var catalog_revision: String = ""
var errors: PackedStringArray = []
var _descriptors: Dictionary[StringName, RuntimeTweakDescriptor] = {}
var _ordered_ids: Array[StringName] = []


static func load_catalog(path: String = DEFAULT_PATH) -> RuntimeTweakCatalog:
	var catalog: RuntimeTweakCatalog = RuntimeTweakCatalog.new()
	catalog._load(path)
	return catalog


func is_valid() -> bool:
	return errors.is_empty()


func enabled_count() -> int:
	return _ordered_ids.size()


func ids() -> Array[StringName]:
	return _ordered_ids.duplicate()


func descriptors() -> Array[RuntimeTweakDescriptor]:
	var result: Array[RuntimeTweakDescriptor] = []
	for identifier: StringName in _ordered_ids:
		result.append(_descriptors[identifier])
	return result


func descriptor(identifier: StringName) -> RuntimeTweakDescriptor:
	return _descriptors.get(identifier) as RuntimeTweakDescriptor


func descriptors_for_category(category: StringName) -> Array[RuntimeTweakDescriptor]:
	var result: Array[RuntimeTweakDescriptor] = []
	for entry: RuntimeTweakDescriptor in descriptors():
		if entry.category == category:
			result.append(entry)
	return result


func categories() -> Array[StringName]:
	var seen: Dictionary[StringName, bool] = {}
	for entry: RuntimeTweakDescriptor in descriptors():
		seen[entry.category] = true
	var result: Array[StringName] = []
	result.assign(seen.keys())
	result.sort_custom(func(first: StringName, second: StringName) -> bool:
		return String(first) < String(second)
	)
	return result


func baseline_values() -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = {}
	for identifier: StringName in _ordered_ids:
		result[identifier] = _descriptors[identifier].default_value
	return result


func validate_value(identifier: StringName, candidate: Variant) -> Dictionary:
	var entry: RuntimeTweakDescriptor = descriptor(identifier)
	if entry == null:
		return {"ok": false, "error": "unknown parameter", "value": null}
	var checked: Dictionary = entry.sanitize(candidate)
	if not bool(checked.get("ok", false)):
		return {"ok": false, "error": "invalid value", "value": entry.default_value}
	return {"ok": true, "error": "", "value": checked.value}


func validate_transaction(candidates: Dictionary) -> Dictionary:
	var sanitized: Dictionary[StringName, Variant] = {}
	for raw_identifier: Variant in candidates:
		var identifier: StringName = StringName(raw_identifier)
		var checked: Dictionary = validate_value(identifier, candidates[raw_identifier])
		if not bool(checked.ok):
			return {"ok": false, "error": "%s: %s" % [identifier, checked.error], "values": {}}
		sanitized[identifier] = checked.value
	return {"ok": true, "error": "", "values": sanitized}


func _load(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("cannot open tuning catalog: %s" % path)
		return
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		errors.append("cannot parse tuning catalog: %s" % parser.get_error_message())
		return
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		errors.append("tuning catalog root must be an object")
		return
	var root: Dictionary = parsed as Dictionary
	schema_version = int(root.get("schema_version", 0))
	catalog_revision = String(root.get("catalog_revision", ""))
	if schema_version != EXPECTED_SCHEMA_VERSION:
		errors.append("unsupported tuning catalog schema %d" % schema_version)
	if catalog_revision.is_empty():
		errors.append("tuning catalog revision is empty")
	var raw_descriptors: Variant = root.get("descriptors", [])
	if not raw_descriptors is Array:
		errors.append("tuning catalog descriptors must be an array")
		return
	for raw_entry: Variant in raw_descriptors as Array:
		if not raw_entry is Dictionary:
			errors.append("tuning catalog descriptor must be an object")
			continue
		var entry: RuntimeTweakDescriptor = RuntimeTweakDescriptor.from_dictionary(
			raw_entry as Dictionary,
			errors
		)
		if not entry.enabled:
			continue
		if _descriptors.has(entry.id):
			errors.append("duplicate tuning id %s" % entry.id)
			continue
		_descriptors[entry.id] = entry
		_ordered_ids.append(entry.id)
	_ordered_ids.sort_custom(func(first: StringName, second: StringName) -> bool:
		return String(first) < String(second)
	)
	if _ordered_ids.size() != EXPECTED_ENABLED_COUNT:
		errors.append(
			"expected %d enabled tuning descriptors, found %d"
			% [EXPECTED_ENABLED_COUNT, _ordered_ids.size()]
		)
