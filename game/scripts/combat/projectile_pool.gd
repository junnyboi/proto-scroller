class_name ProjectilePool
extends Node2D

const PROJECTILE_SCRIPT: Script = preload("res://scripts/combat/projectile_2d.gd")
const MACHINE_GUN_IMPACT_TEXTURE: Texture2D = preload(
	"res://art/player/weapons/machine_gun_impact.png"
)
const MACHINE_GUN_IMPACT_CAPACITY: int = 4
const HOSTILE_IMPACT_CAPACITY: int = 8

@export_range(1, 64, 1) var capacity: int = 24
@export_range(1, 32, 1) var bullet_capacity: int = RuntimeBudget.BULLETS
@export_range(1, 8, 1) var shell_capacity: int = RuntimeBudget.SHELLS
@export_range(1, 8, 1) var rocket_capacity: int = RuntimeBudget.ROCKETS
@export_range(1, 16, 1) var player_bullet_capacity: int = RuntimeBudget.PLAYER_BULLETS

var recycle_count: int = 0
var denial_count: int = 0
var last_acquired: Projectile2D
var machine_gun_impacts: Array[WeaponImpactEffect2D] = []
var hostile_impacts: Array[WeaponImpactEffect2D] = []
var last_machine_gun_impact_position: Vector2 = Vector2.ZERO
var _projectiles: Array[Projectile2D] = []
var _active_order: Array[Projectile2D] = []
var _reservations: Dictionary[int, StringName] = {}
var _next_reservation_id: int = 1
var _machine_gun_impact_cursor: int = 0
var _hostile_impact_cursor: int = 0


func _ready() -> void:
	capacity = bullet_capacity + shell_capacity + rocket_capacity + player_bullet_capacity
	_prewarm_partition(&"bullet", bullet_capacity)
	_prewarm_partition(&"shell", shell_capacity)
	_prewarm_partition(&"rocket", rocket_capacity)
	_prewarm_partition(&"player_bullet", player_bullet_capacity)
	for index: int in range(MACHINE_GUN_IMPACT_CAPACITY):
		var impact: WeaponImpactEffect2D = WeaponImpactEffect2D.new()
		impact.name = "MachineGunImpact%02d" % index
		add_child(impact)
		impact.setup(MACHINE_GUN_IMPACT_TEXTURE, Vector2(54.0, 54.0), 0.20, 84, 7)
		machine_gun_impacts.append(impact)
	for index: int in range(HOSTILE_IMPACT_CAPACITY):
		var impact: WeaponImpactEffect2D = WeaponImpactEffect2D.new()
		impact.name = "HostileImpact%02d" % index
		add_child(impact)
		impact.setup(MACHINE_GUN_IMPACT_TEXTURE, Vector2(64.0, 64.0), 0.24, 83, 1)
		hostile_impacts.append(impact)


func acquire(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	source: Node,
	target_mask: int,
	kind: StringName,
	visual_key: StringName = &""
) -> Projectile2D:
	return _acquire_internal(
		origin, direction, speed, damage, source, target_mask, kind, false, visual_key
	)


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
	kind: StringName,
	visual_key: StringName = &""
) -> Projectile2D:
	if not _reservations.has(reservation_id):
		denial_count += 1
		return null
	var partition: StringName = _reservations[reservation_id]
	if partition != _partition_for_kind(kind):
		denial_count += 1
		return null
	_reservations.erase(reservation_id)
	return _acquire_internal(
		origin, direction, speed, damage, source, target_mask, kind, true, visual_key
	)


func _acquire_internal(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	source: Node,
	target_mask: int,
	kind: StringName,
	reserved: bool,
	visual_key: StringName
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
	projectile.activate(
		origin, direction, speed, damage, source, target_mask, kind, visual_key
	)
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
	_release_machine_gun_impacts()
	_release_hostile_impacts()


func release_hostile(player_root: Node) -> void:
	var active_copy: Array[Projectile2D] = _active_order.duplicate()
	for projectile: Projectile2D in active_copy:
		var source: Node = projectile.source
		var player_owned: bool = (
			player_root != null
			and is_instance_valid(source)
			and (source == player_root or player_root.is_ancestor_of(source))
		)
		if not player_owned:
			release(projectile)
	for reservation_id: int in _reservations.keys():
		if _reservations[reservation_id] != &"player_bullet":
			_reservations.erase(reservation_id)
	_release_hostile_impacts()


func release_partition(kind: StringName) -> void:
	var partition: StringName = _partition_for_kind(kind)
	var active_copy: Array[Projectile2D] = _active_order.duplicate()
	for projectile: Projectile2D in active_copy:
		if projectile.get_meta(&"partition", &"bullet") == partition:
			release(projectile)
	if partition == &"player_bullet":
		_release_machine_gun_impacts()


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
		&"player_bullet":
			return player_bullet_capacity
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


func active_machine_gun_impact_count() -> int:
	var total: int = 0
	for impact: WeaponImpactEffect2D in machine_gun_impacts:
		if impact.active:
			total += 1
	return total


func active_hostile_impact_count() -> int:
	var total: int = 0
	for impact: WeaponImpactEffect2D in hostile_impacts:
		if impact.active:
			total += 1
	return total


func _prewarm_partition(partition: StringName, count: int) -> void:
	for partition_index: int in range(count):
		var projectile: Projectile2D = PROJECTILE_SCRIPT.new() as Projectile2D
		projectile.name = "%s_%02d" % [partition.capitalize(), partition_index]
		projectile.set_meta(&"partition", partition)
		projectile.recycle_requested.connect(_on_recycle_requested)
		projectile.impact_requested.connect(_on_impact_requested)
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


func _release_machine_gun_impacts() -> void:
	for impact: WeaponImpactEffect2D in machine_gun_impacts:
		impact.deactivate()
	_machine_gun_impact_cursor = 0


func _release_hostile_impacts() -> void:
	for impact: WeaponImpactEffect2D in hostile_impacts:
		impact.deactivate()
	_hostile_impact_cursor = 0


func _partition_for_kind(kind: StringName) -> StringName:
	if kind == &"shell":
		return &"shell"
	if kind == &"rocket":
		return &"rocket"
	if kind == &"machine_gun" or kind == &"player_bullet":
		return &"player_bullet"
	return &"bullet"


func _on_recycle_requested(projectile: Projectile2D) -> void:
	release(projectile)


func _on_impact_requested(
	_projectile: Projectile2D,
	world_position: Vector2,
	direction: Vector2,
	kind: StringName,
	impact_key: StringName
) -> void:
	if kind == &"machine_gun" and not machine_gun_impacts.is_empty():
		machine_gun_impacts[_machine_gun_impact_cursor].activate(world_position, direction)
		_machine_gun_impact_cursor = (
			(_machine_gun_impact_cursor + 1) % machine_gun_impacts.size()
		)
		last_machine_gun_impact_position = world_position
		return
	if impact_key.is_empty() or hostile_impacts.is_empty():
		return
	var impact_spec: Dictionary = EnemyAttackVfxCatalog.impact_spec_for_key(impact_key)
	if impact_spec.is_empty():
		return
	var impact: WeaponImpactEffect2D = hostile_impacts[_hostile_impact_cursor]
	if not impact.configure_from_spec(impact_spec):
		return
	impact.activate(world_position, direction)
	_hostile_impact_cursor = (_hostile_impact_cursor + 1) % hostile_impacts.size()
