class_name ProjectilePool
extends Node2D

const PROJECTILE_SCRIPT: Script = preload("res://scripts/combat/projectile_2d.gd")

@export_range(1, 64, 1) var capacity: int = 24
@export_range(1, 32, 1) var bullet_capacity: int = RuntimeBudget.BULLETS
@export_range(1, 8, 1) var shell_capacity: int = RuntimeBudget.SHELLS
@export_range(1, 8, 1) var rocket_capacity: int = RuntimeBudget.ROCKETS

var recycle_count: int = 0
var denial_count: int = 0
var last_acquired: Projectile2D
var _projectiles: Array[Projectile2D] = []
var _active_order: Array[Projectile2D] = []
var _reservations: Dictionary[int, StringName] = {}
var _next_reservation_id: int = 1


func _ready() -> void:
	capacity = bullet_capacity + shell_capacity + rocket_capacity
	_prewarm_partition(&"bullet", bullet_capacity)
	_prewarm_partition(&"shell", shell_capacity)
	_prewarm_partition(&"rocket", rocket_capacity)


func acquire(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	source: Node,
	target_mask: int,
	kind: StringName
) -> Projectile2D:
	return _acquire_internal(origin, direction, speed, damage, source, target_mask, kind, false)


func reserve(kind: StringName) -> int:
	var partition: StringName = _partition_for_kind(kind)
	if available_count(partition) - reservation_count(partition) <= 0:
		denial_count += 1
		return 0
	var reservation_id: int = _next_reservation_id
	_next_reservation_id += 1
	_reservations[reservation_id] = partition
	return reservation_id


func cancel_reservation(reservation_id: int) -> void:
	_reservations.erase(reservation_id)


func acquire_reserved(
	reservation_id: int,
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	source: Node,
	target_mask: int,
	kind: StringName
) -> Projectile2D:
	if not _reservations.has(reservation_id):
		denial_count += 1
		return null
	var partition: StringName = _reservations[reservation_id]
	if partition != _partition_for_kind(kind):
		denial_count += 1
		return null
	_reservations.erase(reservation_id)
	return _acquire_internal(origin, direction, speed, damage, source, target_mask, kind, true)


func _acquire_internal(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	source: Node,
	target_mask: int,
	kind: StringName,
	reserved: bool
) -> Projectile2D:
	var partition: StringName = _partition_for_kind(kind)
	var available: int = available_count(partition)
	if not reserved and available > 0 and available <= reservation_count(partition):
		denial_count += 1
		return null
	var projectile: Projectile2D = _find_available(partition)
	if projectile == null:
		projectile = _oldest_active(partition)
		if projectile == null:
			denial_count += 1
			return null
		release(projectile)
		recycle_count += 1
	_active_order.append(projectile)
	projectile.activate(origin, direction, speed, damage, source, target_mask, kind)
	last_acquired = projectile
	return projectile


func release(projectile: Projectile2D) -> void:
	if projectile == null or not projectile.active:
		return
	_active_order.erase(projectile)
	projectile.deactivate()


func release_all() -> void:
	var active_copy: Array[Projectile2D] = _active_order.duplicate()
	for projectile: Projectile2D in active_copy:
		release(projectile)
	_reservations.clear()


func active_count(kind: StringName = &"") -> int:
	if kind.is_empty():
		return _active_order.size()
	var partition: StringName = _partition_for_kind(kind)
	var count: int = 0
	for projectile: Projectile2D in _active_order:
		if projectile.get_meta(&"partition", &"bullet") == partition:
			count += 1
	return count


func available_count(kind: StringName = &"") -> int:
	if kind.is_empty():
		return capacity - _active_order.size()
	return partition_capacity(kind) - active_count(kind)


func partition_capacity(kind: StringName) -> int:
	match _partition_for_kind(kind):
		&"shell":
			return shell_capacity
		&"rocket":
			return rocket_capacity
		_:
			return bullet_capacity


func reservation_count(kind: StringName = &"") -> int:
	if kind.is_empty():
		return _reservations.size()
	var partition: StringName = _partition_for_kind(kind)
	var count: int = 0
	for reserved_partition: StringName in _reservations.values():
		if reserved_partition == partition:
			count += 1
	return count


func total_count() -> int:
	return _projectiles.size()


func _prewarm_partition(partition: StringName, count: int) -> void:
	for partition_index: int in range(count):
		var projectile: Projectile2D = PROJECTILE_SCRIPT.new() as Projectile2D
		projectile.name = "%s_%02d" % [partition.capitalize(), partition_index]
		projectile.set_meta(&"partition", partition)
		projectile.recycle_requested.connect(_on_recycle_requested)
		add_child(projectile)
		projectile.deactivate()
		_projectiles.append(projectile)


func _find_available(partition: StringName) -> Projectile2D:
	for projectile: Projectile2D in _projectiles:
		if not projectile.active and projectile.get_meta(&"partition") == partition:
			return projectile
	return null


func _oldest_active(partition: StringName) -> Projectile2D:
	for projectile: Projectile2D in _active_order:
		if projectile.get_meta(&"partition") == partition:
			return projectile
	return null


func _partition_for_kind(kind: StringName) -> StringName:
	if kind == &"shell":
		return &"shell"
	if kind == &"rocket":
		return &"rocket"
	return &"bullet"


func _on_recycle_requested(projectile: Projectile2D) -> void:
	release(projectile)
