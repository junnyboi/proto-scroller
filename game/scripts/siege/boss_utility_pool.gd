# gdlint: disable=max-public-methods
class_name BossUtilityPool
extends Node

const MARKER_CAPACITY: int = 8
const LANE_DAMAGE_AREA_CAPACITY: int = 3
const LINE_AREA_CAPACITY: int = 2
const COLLAPSE_LISTENER_CAPACITY: int = 2
const POD_VISUAL_CAPACITY: int = 4
const RECLAMATION_ANCHOR_CAPACITY: int = 3
const PYLON_PRESENTATION_CAPACITY: int = 5
const PROJECTION_SLOT_CAPACITY: int = 4
const WRECK_RECEIVER_CAPACITY: int = 2

var rig: Node2D
var controller: Node
var arena_adapter: Node2D
var markers: Array[Marker2D] = []
var lane_damage_areas: Array[Area2D] = []
var line_areas: Array[Area2D] = []
var collapse_listeners: Array[Node] = []
var pod_visuals: Array[Node2D] = []
var reclamation_anchor_records: Array[Node2D] = []
var pylon_presentations: Array[Node2D] = []
var projection_slots: Array[Node2D] = []
var wreck_receivers: Array[Area2D] = []
var default_wreck_receiver: Area2D
var royal_outcome_receiver: Area2D
var generation_token: int = 0
var post_warm_creation_count: int = 0
var warmed: bool = false
var denial_count: int = 0
var peak_reservations: int = 0

var _reservations: Dictionary[int, Dictionary] = {}
var _cleanup_callbacks: Array[Callable] = []
var _next_reservation_id: int = 1


func _init() -> void:
	_prewarm()


static func utility_capacities() -> Dictionary[StringName, int]:
	return {
		&"markers": MARKER_CAPACITY,
		&"lane_damage_areas": LANE_DAMAGE_AREA_CAPACITY,
		&"line_areas": LINE_AREA_CAPACITY,
		&"collapse_listeners": COLLAPSE_LISTENER_CAPACITY,
		&"pod_visuals": POD_VISUAL_CAPACITY,
		&"reclamation_anchors": RECLAMATION_ANCHOR_CAPACITY,
		&"pylon_presentations": PYLON_PRESENTATION_CAPACITY,
		&"projection_slots": PROJECTION_SLOT_CAPACITY,
		&"wreck_receivers": WRECK_RECEIVER_CAPACITY,
	}


func begin_generation() -> int:
	_cleanup_current_generation()
	generation_token += 1
	return generation_token


func cleanup_generation(token: int) -> bool:
	if token != generation_token:
		return false
	_cleanup_current_generation()
	return true


func is_current_generation(token: int) -> bool:
	return token == generation_token


func register_generation_cleanup(callback: Callable, token: int = -1) -> bool:
	var requested_generation: int = generation_token if token < 0 else token
	if not is_current_generation(requested_generation) or not callback.is_valid():
		return false
	_cleanup_callbacks.append(callback)
	return true


func reserve_requirements(requirements: Dictionary, token: int = -1) -> int:
	var requested_generation: int = generation_token if token < 0 else token
	if not is_current_generation(requested_generation):
		denial_count += 1
		return 0
	if requirements.is_empty() or not _can_reserve(requirements):
		denial_count += 1
		return 0
	var reservation_id: int = _next_reservation_id
	_next_reservation_id += 1
	_reservations[reservation_id] = {
		"generation": requested_generation,
		"remaining": requirements.duplicate(),
	}
	peak_reservations = maxi(peak_reservations, reservation_count())
	return reservation_id


func consume_reservation(reservation_id: int, key: StringName, count: int = 1) -> bool:
	if not _reservations.has(reservation_id) or count <= 0:
		return false
	var record: Dictionary = _reservations[reservation_id]
	if int(record.generation) != generation_token:
		return false
	var remaining: Dictionary = record.remaining
	if int(remaining.get(key, 0)) < count:
		return false
	remaining[key] = int(remaining[key]) - count
	if _dictionary_total(remaining) == 0:
		_reservations.erase(reservation_id)
	return true


func cancel_reservation(reservation_id: int) -> void:
	_reservations.erase(reservation_id)


func cancel_all_reservations() -> void:
	_reservations.clear()


func reservation_count() -> int:
	return _reservations.size()


func reserved_units(key: StringName = &"") -> int:
	var total: int = 0
	for record: Dictionary in _reservations.values():
		var remaining: Dictionary = record.remaining
		total += _dictionary_total(remaining) if key.is_empty() else int(remaining.get(key, 0))
	return total


func capture_reservation_state() -> Dictionary:
	return {
		"generation": generation_token,
		"next_id": _next_reservation_id,
		"reservations": _reservations.duplicate(true),
	}


func restore_reservation_state(state: Dictionary) -> void:
	_cleanup_current_generation()
	generation_token = int(state.get("generation", generation_token))
	_next_reservation_id = int(state.get("next_id", _next_reservation_id))
	_reservations = state.get("reservations", {}).duplicate(true)


func area_count() -> int:
	return lane_damage_areas.size() + line_areas.size() + wreck_receivers.size()


func marker_count() -> int:
	return markers.size()


func pylon_count() -> int:
	return pylon_presentations.size()


func projection_count() -> int:
	return projection_slots.size()


func pod_visual_count() -> int:
	return pod_visuals.size()


func reclamation_anchor_count() -> int:
	return reclamation_anchor_records.size()


func collapse_listener_count() -> int:
	return collapse_listeners.size()


func wreck_receiver_count() -> int:
	return wreck_receivers.size()


func rig_count() -> int:
	return 1 if rig != null else 0


func controller_count() -> int:
	return 1 if controller != null else 0


func arena_adapter_count() -> int:
	return 1 if arena_adapter != null else 0


func _prewarm() -> void:
	if warmed:
		return
	rig = Node2D.new()
	rig.name = "BossRig"
	add_child(rig)
	controller = Node.new()
	controller.name = "BossBehaviorController"
	add_child(controller)
	arena_adapter = Node2D.new()
	arena_adapter.name = "BossArenaAdapter"
	add_child(arena_adapter)
	for index: int in range(PYLON_PRESENTATION_CAPACITY):
		var pylon: Node2D = _make_record("PylonPresentation%02d" % index, rig)
		pylon_presentations.append(pylon)
	for index: int in range(PROJECTION_SLOT_CAPACITY):
		var projection: Node2D = _make_record("ProjectionSlot%02d" % index, rig)
		projection_slots.append(projection)
	for index: int in range(MARKER_CAPACITY):
		var marker: Marker2D = Marker2D.new()
		marker.name = "AttackMarker%02d" % index
		arena_adapter.add_child(marker)
		markers.append(marker)
	for index: int in range(LANE_DAMAGE_AREA_CAPACITY):
		lane_damage_areas.append(_make_area("LaneDamageArea%02d" % index))
	for index: int in range(LINE_AREA_CAPACITY):
		line_areas.append(_make_area("LineArea%02d" % index))
	for index: int in range(COLLAPSE_LISTENER_CAPACITY):
		var listener: Node = Node.new()
		listener.name = "CollapseListener%02d" % index
		arena_adapter.add_child(listener)
		collapse_listeners.append(listener)
	for index: int in range(POD_VISUAL_CAPACITY):
		pod_visuals.append(_make_record("ProtectedPodVisual%02d" % index, rig))
	for index: int in range(RECLAMATION_ANCHOR_CAPACITY):
		var anchor: Node2D = _make_record("ReclamationAnchor%02d" % index, arena_adapter)
		reclamation_anchor_records.append(anchor)
	default_wreck_receiver = _make_area("DefaultWreckReceiver")
	royal_outcome_receiver = _make_area("RoyalOutcomeReceiver")
	wreck_receivers.assign([default_wreck_receiver, royal_outcome_receiver])
	warmed = true
	_deactivate_records()


func _make_record(record_name: String, parent: Node) -> Node2D:
	var record: Node2D = Node2D.new()
	record.name = record_name
	parent.add_child(record)
	return record


func _make_area(area_name: String) -> Area2D:
	var area: Area2D = Area2D.new()
	area.name = area_name
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "Collision"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(192.0, 96.0)
	collision.shape = shape
	collision.disabled = true
	area.add_child(collision)
	arena_adapter.add_child(area)
	return area


func _cleanup_current_generation() -> void:
	for callback: Callable in _cleanup_callbacks:
		if callback.is_valid():
			callback.call()
	_cleanup_callbacks.clear()
	cancel_all_reservations()
	_deactivate_records()


func _deactivate_records() -> void:
	rig.visible = false
	arena_adapter.visible = false
	for record: Node2D in pylon_presentations:
		record.visible = false
	for record: Node2D in projection_slots:
		record.visible = false
	for record: Node2D in pod_visuals:
		record.visible = false
	for record: Node2D in reclamation_anchor_records:
		record.visible = false
	for area: Area2D in lane_damage_areas + line_areas + wreck_receivers:
		area.monitoring = false
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 0
		var collision: CollisionShape2D = area.get_node(^"Collision") as CollisionShape2D
		collision.disabled = true


func _can_reserve(requirements: Dictionary) -> bool:
	for key_value: Variant in requirements:
		var key: StringName = StringName(key_value)
		var requested: int = int(requirements[key_value])
		var capacity: int = _capacity_for(key)
		if requested <= 0 or capacity <= 0 or reserved_units(key) + requested > capacity:
			return false
	return true


func _capacity_for(key: StringName) -> int:
	var utility_capacity: int = int(utility_capacities().get(key, 0))
	if utility_capacity > 0:
		return utility_capacity
	match key:
		&"procedural_infantry":
			return 12
		&"procedural_light":
			return 3
		&"procedural_heavy", &"procedural_air":
			return 4
		&"procedural_siege":
			return 2
	return 0


func _dictionary_total(values: Dictionary) -> int:
	var total: int = 0
	for value: Variant in values.values():
		total += int(value)
	return total
