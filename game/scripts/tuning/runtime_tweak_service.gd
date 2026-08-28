class_name RuntimeTweakService
extends Node

signal value_changed(identifier: StringName, requested_value: Variant, active_value: Variant)
signal persistence_state_changed(state: StringName, message: String)
signal run_provenance_changed(snapshot: Dictionary)
signal city_bound(city: CitySlice)

const SAVE_DEBOUNCE_SECONDS: float = 0.40

var catalog: RuntimeTweakCatalog
var persistence: RuntimeTweakPersistence
var provenance: RunTuningProvenance = RunTuningProvenance.new()
var requested_values: Dictionary[StringName, Variant] = {}
var run_values: Dictionary[StringName, Variant] = {}
var district_values: Dictionary[StringName, Variant] = {}
var active_values: Dictionary[StringName, Variant] = {}
var current_city: CitySlice
var persistence_state: StringName = &"SAVED"
var persistence_message: String = ""
var run_active: bool = false
var last_error: String = ""
var _save_remaining_seconds: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func setup(
	catalog_path: String = RuntimeTweakCatalog.DEFAULT_PATH,
	save_path: String = RuntimeTweakPersistence.DEFAULT_PATH
) -> PackedStringArray:
	catalog = RuntimeTweakCatalog.load_catalog(catalog_path)
	if not catalog.is_valid():
		last_error = "; ".join(catalog.errors)
		return catalog.errors.duplicate()
	persistence = RuntimeTweakPersistence.new(save_path)
	requested_values = catalog.baseline_values()
	var overlay: Dictionary[StringName, Variant] = persistence.load_overlay(catalog)
	for identifier: StringName in overlay:
		requested_values[identifier] = overlay[identifier]
	run_values = requested_values.duplicate(true)
	district_values = run_values.duplicate(true)
	active_values = run_values.duplicate(true)
	provenance.start_run(0, configuration_hash(run_values), catalog.catalog_revision)
	RuntimeTweakAccess.bind_service(self)
	_set_persistence_state(
		&"NOT_SAVED" if not persistence.last_error.is_empty() else &"SAVED",
		persistence.last_error
	)
	return []


func _exit_tree() -> void:
	flush_now()
	RuntimeTweakAccess.unbind_service(self)


func _process(delta: float) -> void:
	if _save_remaining_seconds < 0.0:
		return
	_save_remaining_seconds = maxf(_save_remaining_seconds - maxf(delta, 0.0), 0.0)
	if not is_zero_approx(_save_remaining_seconds):
		return
	flush_now()


func descriptor(identifier: StringName) -> RuntimeTweakDescriptor:
	return catalog.descriptor(identifier) if catalog != null else null


func requested_value(identifier: StringName, fallback: Variant = null) -> Variant:
	return requested_values.get(identifier, fallback)


func live_value(identifier: StringName, fallback: Variant = null) -> Variant:
	return requested_values.get(identifier, fallback)


func run_value(identifier: StringName, fallback: Variant = null) -> Variant:
	return run_values.get(identifier, fallback)


func district_value(identifier: StringName, fallback: Variant = null) -> Variant:
	return district_values.get(identifier, run_values.get(identifier, fallback))


func active_value(identifier: StringName, fallback: Variant = null) -> Variant:
	var entry: RuntimeTweakDescriptor = descriptor(identifier)
	if entry == null:
		return fallback
	if entry.apply_mode == &"LIVE":
		return requested_values.get(identifier, fallback)
	return active_values.get(identifier, run_values.get(identifier, fallback))


func set_value(identifier: StringName, candidate: Variant) -> Dictionary:
	if catalog == null:
		return {"ok": false, "error": "service is not initialized", "value": null}
	var checked: Dictionary = catalog.validate_value(identifier, candidate)
	if not bool(checked.ok):
		last_error = String(checked.error)
		return checked
	var entry: RuntimeTweakDescriptor = descriptor(identifier)
	var next_value: Variant = checked.value
	var previous: Variant = requested_values[identifier]
	if entry.values_equal(previous, next_value):
		return {"ok": true, "error": "", "value": previous, "changed": false}
	requested_values[identifier] = next_value
	if entry.apply_mode == &"LIVE":
		active_values[identifier] = next_value
		_mark_applied_if_tuned(entry, next_value)
	value_changed.emit(identifier, next_value, active_value(identifier, next_value))
	_schedule_save()
	return {"ok": true, "error": "", "value": next_value, "changed": true}


func set_values(candidates: Dictionary) -> Dictionary:
	var checked: Dictionary = catalog.validate_transaction(candidates)
	if not bool(checked.ok):
		last_error = String(checked.error)
		return checked
	var changed: int = 0
	for identifier: StringName in checked.values:
		var result: Dictionary = set_value(identifier, checked.values[identifier])
		if bool(result.get("changed", false)):
			changed += 1
	return {"ok": true, "error": "", "values": checked.values, "changed": changed}


func reset_value(identifier: StringName) -> bool:
	var entry: RuntimeTweakDescriptor = descriptor(identifier)
	if entry == null:
		return false
	return bool(set_value(identifier, entry.default_value).get("changed", false))


func reset_all() -> int:
	var changed: int = 0
	for entry: RuntimeTweakDescriptor in catalog.descriptors():
		if reset_value(entry.id):
			changed += 1
	return changed


func freeze_run(seed: int) -> Dictionary[StringName, Variant]:
	run_values = requested_values.duplicate(true)
	district_values = run_values.duplicate(true)
	active_values = run_values.duplicate(true)
	run_active = true
	provenance.start_run(seed, configuration_hash(run_values), catalog.catalog_revision)
	for entry: RuntimeTweakDescriptor in catalog.descriptors():
		if entry.apply_mode in [&"LIVE", &"NEXT_RUN"]:
			_mark_applied_if_tuned(entry, run_values[entry.id])
	run_provenance_changed.emit(provenance.snapshot())
	return run_values.duplicate(true)


func end_run() -> void:
	run_active = false
	current_city = null


func begin_district() -> Dictionary[StringName, Variant]:
	for entry: RuntimeTweakDescriptor in catalog.descriptors():
		if entry.apply_mode != &"NEXT_DISTRICT":
			continue
		district_values[entry.id] = requested_values[entry.id]
		active_values[entry.id] = requested_values[entry.id]
		_mark_applied_if_tuned(entry, requested_values[entry.id])
	return district_values.duplicate(true)


func next_attack_value(identifier: StringName, fallback: Variant = null) -> Variant:
	return _consume_boundary(identifier, &"NEXT_ATTACK", fallback)


func next_spawn_value(identifier: StringName, fallback: Variant = null) -> Variant:
	return _consume_boundary(identifier, &"NEXT_SPAWN", fallback)


func bind_city(city: CitySlice) -> void:
	current_city = city
	city_bound.emit(city)


func mark_sandbox(reason: StringName) -> void:
	if not run_active:
		return
	provenance.mark_sandbox(reason)
	run_provenance_changed.emit(provenance.snapshot())


func provenance_snapshot() -> Dictionary:
	return provenance.snapshot()


func requested_configuration_hash() -> String:
	return configuration_hash(requested_values)


func run_configuration_hash() -> String:
	return configuration_hash(run_values)


func pending_count() -> int:
	var count: int = 0
	for entry: RuntimeTweakDescriptor in catalog.descriptors():
		if entry.values_equal(requested_values[entry.id], active_value(entry.id)):
			continue
		count += 1
	return count


func delta_values() -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = {}
	for entry: RuntimeTweakDescriptor in catalog.descriptors():
		var value: Variant = requested_values[entry.id]
		if not entry.values_equal(value, entry.default_value):
			result[entry.id] = value
	return result


func flush_now() -> bool:
	if persistence == null or catalog == null:
		return false
	_save_remaining_seconds = -1.0
	var saved: bool = persistence.save_delta(delta_values(), catalog.catalog_revision)
	_set_persistence_state(
		&"SAVED" if saved else &"NOT_SAVED",
		"" if saved else persistence.last_error
	)
	return saved


func configuration_hash(values: Dictionary) -> String:
	if catalog == null:
		return ""
	var canonical: Array[Dictionary] = []
	for identifier: StringName in catalog.ids():
		canonical.append({
			"id": String(identifier),
			"value": values.get(identifier, catalog.descriptor(identifier).default_value),
		})
	return (JSON.stringify(canonical) + "\n").sha256_text()


func _consume_boundary(identifier: StringName, expected_mode: StringName, fallback: Variant) -> Variant:
	var entry: RuntimeTweakDescriptor = descriptor(identifier)
	if entry == null or entry.apply_mode != expected_mode:
		return requested_values.get(identifier, fallback)
	var value: Variant = requested_values.get(identifier, fallback)
	active_values[identifier] = value
	_mark_applied_if_tuned(entry, value)
	value_changed.emit(identifier, value, value)
	return value


func _mark_applied_if_tuned(entry: RuntimeTweakDescriptor, value: Variant) -> void:
	if not run_active or not entry.is_gameplay_affecting():
		return
	if entry.values_equal(value, entry.default_value):
		return
	var previous_status: StringName = provenance.status
	provenance.mark_tuned(entry.id)
	if provenance.status != previous_status or String(entry.id) in provenance.reasons:
		run_provenance_changed.emit(provenance.snapshot())


func _schedule_save() -> void:
	_save_remaining_seconds = SAVE_DEBOUNCE_SECONDS
	_set_persistence_state(&"SAVING", "")


func _set_persistence_state(state: StringName, message: String) -> void:
	persistence_state = state
	persistence_message = message
	persistence_state_changed.emit(state, message)
