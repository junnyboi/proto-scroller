class_name CatalystRuntime
extends Node2D

signal catalyst_triggered(catalyst: Catalyst2D, event: DamageEvent)
signal catalyst_resolved(catalyst: Catalyst2D, affected_count: int)
signal repair_pickup_spawned(pickup: ChassisRepairPickup2D)
signal repair_pickup_collected(repaired_health: float)

const SLOT_COUNT: int = 2
const CATALYST_SCRIPT: Script = preload("res://scripts/destruction/catalysts/catalyst_2d.gd")
const REPAIR_PICKUP_SCRIPT: Script = preload(
	"res://scripts/destruction/catalysts/chassis_repair_pickup_2d.gd"
)

var dependencies: UrbanSiegeDependencies
var slots: Array[Catalyst2D] = []
var repair_pickups: Array[ChassisRepairPickup2D] = []
var pulse_count: int = 0
var _next_pulse_attack_id: int = 1_000_000


func setup(p_dependencies: UrbanSiegeDependencies) -> void:
	dependencies = p_dependencies


func _ready() -> void:
	for index: int in range(SLOT_COUNT):
		var catalyst: Catalyst2D = CATALYST_SCRIPT.new() as Catalyst2D
		catalyst.name = "CatalystSlot%d" % index
		catalyst.z_index = 24
		var visual: Sprite2D = Sprite2D.new()
		visual.name = "Visual"
		catalyst.add_child(visual)
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(74.0, 70.0)
		collision.shape = shape
		catalyst.add_child(collision)
		catalyst.triggered.connect(_on_catalyst_triggered)
		add_child(catalyst)
		catalyst.reset_catalyst()
		slots.append(catalyst)
		var pickup: ChassisRepairPickup2D = REPAIR_PICKUP_SCRIPT.new()
		pickup.name = "ChassisRepairPickupSlot%d" % index
		pickup.z_index = 40
		pickup.collected.connect(_on_repair_pickup_collected)
		add_child(pickup)
		repair_pickups.append(pickup)


func activate(slot: int, profile: CatalystProfile, world_position: Vector2) -> Catalyst2D:
	if slot < 0 or slot >= slots.size() or profile == null:
		return null
	var catalyst: Catalyst2D = slots[slot]
	catalyst.arm(profile, world_position)
	return catalyst


func deactivate_all() -> void:
	for catalyst: Catalyst2D in slots:
		catalyst.reset_catalyst()
	for pickup: ChassisRepairPickup2D in repair_pickups:
		pickup.reset_pickup()


func active_count() -> int:
	var count: int = 0
	for catalyst: Catalyst2D in slots:
		if catalyst.armed:
			count += 1
	return count


func total_count() -> int:
	return slots.size()


func active_repair_pickup_count() -> int:
	var count: int = 0
	for pickup: ChassisRepairPickup2D in repair_pickups:
		count += 1 if pickup.active else 0
	return count


func repair_pickup_count() -> int:
	return repair_pickups.size()


func _on_catalyst_triggered(catalyst: Catalyst2D, event: DamageEvent) -> void:
	catalyst_triggered.emit(catalyst, event)
	if catalyst.profile != null and catalyst.profile.catalyst_id == &"TRANSFORMER":
		_spawn_repair_pickup(catalyst.global_position + Vector2(0.0, -96.0))
	_resolve_after_delay(catalyst, event)


func _spawn_repair_pickup(world_position: Vector2) -> void:
	var selected: ChassisRepairPickup2D
	for pickup: ChassisRepairPickup2D in repair_pickups:
		if not pickup.active:
			selected = pickup
			break
	if selected == null and not repair_pickups.is_empty():
		selected = repair_pickups[0]
	if selected == null:
		return
	selected.activate(world_position)
	repair_pickup_spawned.emit(selected)


func _on_repair_pickup_collected(
	_pickup: ChassisRepairPickup2D,
	repaired_health: float
) -> void:
	repair_pickup_collected.emit(repaired_health)


func _resolve_after_delay(catalyst: Catalyst2D, event: DamageEvent) -> void:
	await get_tree().create_timer(catalyst.profile.delay_seconds).timeout
	if not is_instance_valid(catalyst) or not catalyst.spent or dependencies == null:
		return
	var pulse_attack_id: int = event.root_attack_id
	if pulse_attack_id == 0:
		pulse_attack_id = _next_pulse_attack_id
		_next_pulse_attack_id += 1
	pulse_count += 1
	var options: DamageQueryOptions = DamageQueryOptions.new()
	options.root_attack_id = event.root_attack_id
	options.causal_depth = event.causal_depth + 1
	options.effect_flags = DamageEvent.FLAG_CATALYST
	options.result_limit = catalyst.profile.max_results
	options.structural_limit = catalyst.profile.max_structural_cells
	options.debris_limit = catalyst.profile.max_debris
	dependencies.destruction_director.queue_explosion(
		catalyst.global_position,
		catalyst.profile.pulse_radius,
		catalyst.profile.pulse_damage,
		catalyst.profile.impulse_per_mass,
		pulse_attack_id,
		catalyst,
		options
	)
	var gameplay_event: GameplayEvent = GameplayEvent.new(
		StringName("catalyst:%d:%d" % [catalyst.get_instance_id(), catalyst.trigger_count]),
		pulse_attack_id,
		GameplayEvent.Kind.CATALYST_TRIGGERED,
		&"CATALYST_TRIGGER",
		600,
		12.0,
		true,
		catalyst.global_position,
		&"steel",
		catalyst.get_instance_id(),
		0,
			catalyst.profile.catalyst_id.to_lower()
	)
	gameplay_event.root_attack_id = event.root_attack_id
	gameplay_event.causal_depth = event.causal_depth + 1
	dependencies.rampage_session.publish(gameplay_event)
	catalyst.mark_resolved(0)
	catalyst_resolved.emit(catalyst, 0)
