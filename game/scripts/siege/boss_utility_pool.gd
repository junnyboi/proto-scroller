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
const CHOIR_PYLON_TEXTURE: Texture2D = preload("res://art/finale/choir-pylon.png")
const CHOIR_PYLON_OFFSETS: Array[Vector2] = [
	Vector2(-360.0, -160.0), Vector2(-180.0, -245.0), Vector2(0.0, -280.0),
	Vector2(180.0, -245.0), Vector2(360.0, -160.0),
]

var rig: BossRig2D
var controller: BossPhaseRuntime
var vertical_slice: BossVerticalSliceController
var escalation: BossEscalationController
var motion_echo_recorder: MotionEchoRecorder
var arena_adapter: BossStructuralAdapter
var markers: Array[Marker2D] = []
var marker_presentations: Array[Sprite2D] = []
var lane_damage_areas: Array[BossAttackArea2D] = []
var line_areas: Array[BossAttackArea2D] = []
var collapse_listeners: Array[Node] = []
var pod_visuals: Array[BossPodVisual2D] = []
var reclamation_anchor_records: Array[Node2D] = []
var pylon_presentations: Array[Node2D] = []
var projection_slots: Array[Node2D] = []
var wreck_receivers: Array[BossWreckReceiver2D] = []
var default_wreck_receiver: BossWreckReceiver2D
var royal_outcome_receiver: BossWreckReceiver2D
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


func present_royal_pylons(center: Vector2) -> void:
	rig.visible = true
	for index: int in range(pylon_presentations.size()):
		var pylon: Node2D = pylon_presentations[index]
		pylon.global_position = center + CHOIR_PYLON_OFFSETS[index]
		pylon.visible = true


func configure_royal_pylon(index: int, pylon_id: StringName) -> bool:
	if index < 0 or index >= pylon_presentations.size() or pylon_id.is_empty():
		return false
	var pylon: Node2D = pylon_presentations[index]
	pylon.set_meta(&"pylon_id", pylon_id)
	pylon.name = "Pylon%s" % String(pylon_id).to_pascal_case()
	set_royal_pylon_active(index, false)
	return true


func set_royal_pylon_visible(index: int, visible_value: bool) -> bool:
	if index < 0 or index >= pylon_presentations.size():
		return false
	pylon_presentations[index].visible = visible_value
	return true


func set_royal_pylon_active(index: int, active: bool) -> bool:
	if index < 0 or index >= pylon_presentations.size():
		return false
	var pylon: Node2D = pylon_presentations[index]
	var sprite: Sprite2D = pylon.get_child(0) as Sprite2D
	if sprite != null:
		sprite.modulate = (
			Color(1.0, 0.78, 0.28, 1.0)
			if active
			else Color(0.72, 1.0, 0.95, 0.96)
		)
		sprite.scale = Vector2.ONE * (0.40 if active else 0.34)
	return true


func configure_royal_echo_presentation(
	index: int,
	texture: Texture2D,
	world_position: Vector2,
	display_size: Vector2
) -> bool:
	if index < 0 or index >= marker_presentations.size() or texture == null:
		return false
	var presentation: Sprite2D = marker_presentations[index]
	presentation.texture = texture
	presentation.global_position = world_position
	var texture_size: Vector2 = texture.get_size()
	var fit: float = minf(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	presentation.scale = Vector2.ONE * fit
	presentation.modulate = Color(0.35, 0.98, 1.0, 0.42)
	presentation.visible = true
	return true


func hide_royal_echo_presentations() -> void:
	for presentation: Sprite2D in marker_presentations:
		presentation.visible = false


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


func configure_runtime(
	encounter_runtime: EncounterRuntime,
	projectile_pool: ProjectilePool
) -> void:
	controller.setup(self, encounter_runtime, projectile_pool)
	vertical_slice.setup(self, encounter_runtime)
	escalation.setup(self, encounter_runtime)


func configure_wreck_receivers(
	wreck: EnemyWreck2D,
	definition: BossEncounterDefinition,
	receiver_callback: Callable = Callable()
) -> void:
	for receiver: BossWreckReceiver2D in wreck_receivers:
		receiver.deactivate()
	if wreck == null or definition == null:
		return
	var offsets: PackedVector2Array = definition.wreck_receiver_offsets
	default_wreck_receiver.configure(
		wreck,
		BossOutcome.PURGE,
		wreck.global_position + offsets[0],
		receiver_callback
	)
	if offsets.size() > 1:
		royal_outcome_receiver.configure(
			wreck,
			BossOutcome.DISENTANGLE,
			wreck.global_position + offsets[1],
			receiver_callback
		)
	# Campaign finishers are reachable only through the authored receiver areas.
	wreck.collision_layer = 0


func rig_count() -> int:
	return 1 if rig != null else 0


func controller_count() -> int:
	return 1 if controller != null else 0


func arena_adapter_count() -> int:
	return 1 if arena_adapter != null else 0


func _prewarm() -> void:
	if warmed:
		return
	rig = BossRig2D.new()
	add_child(rig)
	controller = BossPhaseRuntime.new()
	controller.name = "BossBehaviorController"
	add_child(controller)
	vertical_slice = BossVerticalSliceController.new()
	vertical_slice.name = "BossVerticalSliceController"
	add_child(vertical_slice)
	escalation = BossEscalationController.new()
	escalation.name = "BossEscalationController"
	add_child(escalation)
	arena_adapter = BossStructuralAdapter.new()
	add_child(arena_adapter)
	for index: int in range(PYLON_PRESENTATION_CAPACITY):
		var pylon: Node2D = _make_record("PylonPresentation%02d" % index, rig)
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = CHOIR_PYLON_TEXTURE
		sprite.scale = Vector2(0.34, 0.34)
		sprite.modulate = Color(0.72, 1.0, 0.95, 0.96)
		pylon.add_child(sprite)
		pylon_presentations.append(pylon)
	for index: int in range(PROJECTION_SLOT_CAPACITY):
		var projection: Node2D = _make_record("ProjectionSlot%02d" % index, rig)
		projection_slots.append(projection)
	for index: int in range(MARKER_CAPACITY):
		var marker: Marker2D = Marker2D.new()
		marker.name = "AttackMarker%02d" % index
		arena_adapter.add_child(marker)
		markers.append(marker)
		var presentation: Sprite2D = Sprite2D.new()
		presentation.name = "MarkerPresentation%02d" % index
		presentation.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		presentation.z_index = 5
		presentation.visible = false
		marker.add_child(presentation)
		marker_presentations.append(presentation)
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
		var pod: BossPodVisual2D = BossPodVisual2D.new()
		pod.name = "ProtectedPodVisual%02d" % index
		rig.add_child(pod)
		pod_visuals.append(pod)
	for index: int in range(RECLAMATION_ANCHOR_CAPACITY):
		var anchor: Node2D = _make_record("ReclamationAnchor%02d" % index, arena_adapter)
		reclamation_anchor_records.append(anchor)
	motion_echo_recorder = MotionEchoRecorder.new()
	motion_echo_recorder.name = "MotionEchoRecorder"
	arena_adapter.add_child(motion_echo_recorder)
	motion_echo_recorder.setup(markers, lane_damage_areas[2])
	escalation.attach_recorder(motion_echo_recorder)
	default_wreck_receiver = _make_wreck_receiver("DefaultWreckReceiver")
	royal_outcome_receiver = _make_wreck_receiver("RoyalOutcomeReceiver")
	wreck_receivers.assign([default_wreck_receiver, royal_outcome_receiver])
	warmed = true
	_deactivate_records()


func _make_record(record_name: String, parent: Node) -> Node2D:
	var record: Node2D = Node2D.new()
	record.name = record_name
	parent.add_child(record)
	return record


func _make_area(area_name: String) -> BossAttackArea2D:
	var area: BossAttackArea2D = BossAttackArea2D.new()
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
	area.deactivate()
	return area


func _make_wreck_receiver(area_name: String) -> BossWreckReceiver2D:
	var receiver: BossWreckReceiver2D = BossWreckReceiver2D.new()
	receiver.name = area_name
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "Collision"
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = BossEncounterDefinition.DEFAULT_GROUND_SMASH_RADIUS * 0.42
	collision.shape = shape
	receiver.add_child(collision)
	arena_adapter.add_child(receiver)
	receiver.deactivate()
	return receiver


func _cleanup_current_generation() -> void:
	for callback: Callable in _cleanup_callbacks:
		if callback.is_valid():
			callback.call()
	_cleanup_callbacks.clear()
	cancel_all_reservations()
	_deactivate_records()


func _deactivate_records() -> void:
	rig.deactivate()
	motion_echo_recorder.deactivate()
	arena_adapter.unbind()
	for record: Node2D in pylon_presentations:
		record.visible = false
	hide_royal_echo_presentations()
	for record: Node2D in projection_slots:
		record.visible = false
	for record: Node2D in pod_visuals:
		record.visible = false
	for record: Node2D in reclamation_anchor_records:
		record.visible = false
	for receiver: BossWreckReceiver2D in wreck_receivers:
		receiver.deactivate()
	for area: BossAttackArea2D in lane_damage_areas + line_areas:
		area.deactivate()


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
