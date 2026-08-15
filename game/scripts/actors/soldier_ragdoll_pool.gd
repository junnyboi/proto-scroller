class_name SoldierRagdollPool
extends Node2D

@export_range(1, 24, 1) var capacity: int = 8

var recycle_count: int = 0
var _free: Array[SoldierRagdoll2D] = []
var _active: Array[SoldierRagdoll2D] = []


func _ready() -> void:
	for index: int in range(capacity):
		var ragdoll: SoldierRagdoll2D = SoldierRagdoll2D.new()
		ragdoll.name = "SoldierRagdoll_%02d" % index
		ragdoll.recycle_requested.connect(_on_recycle_requested)
		add_child(ragdoll)
		_free.append(ragdoll)


func acquire(
	world_position: Vector2,
	facing: int,
	impact_event: DamageEvent
) -> SoldierRagdoll2D:
	if _free.is_empty():
		release(_active.front())
		recycle_count += 1
	var ragdoll: SoldierRagdoll2D = _free.pop_back()
	_active.append(ragdoll)
	ragdoll.activate(world_position, facing, impact_event)
	return ragdoll


func release(ragdoll: SoldierRagdoll2D) -> void:
	if ragdoll == null or not _active.has(ragdoll):
		return
	_active.erase(ragdoll)
	ragdoll.deactivate()
	_free.append(ragdoll)


func active_count() -> int:
	return _active.size()


func available_count() -> int:
	return _free.size()


func total_count() -> int:
	return _active.size() + _free.size()


func _on_recycle_requested(ragdoll: SoldierRagdoll2D) -> void:
	release(ragdoll)
