class_name ProjectilePool
extends Node2D

const PROJECTILE_SCRIPT: Script = preload("res://scripts/combat/projectile_2d.gd")

@export_range(1, 64, 1) var capacity: int = 24

var recycle_count: int = 0
var _free: Array[Projectile2D] = []
var _active: Array[Projectile2D] = []


func _ready() -> void:
	for index: int in range(capacity):
		var projectile: Projectile2D = PROJECTILE_SCRIPT.new() as Projectile2D
		projectile.name = "Projectile_%02d" % index
		projectile.recycle_requested.connect(_on_recycle_requested)
		add_child(projectile)
		projectile.deactivate()
		_free.append(projectile)


func acquire(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	source: Node,
	target_mask: int,
	kind: StringName
) -> Projectile2D:
	if _free.is_empty():
		release(_active.front())
		recycle_count += 1
	var projectile: Projectile2D = _free.pop_back()
	_active.append(projectile)
	projectile.activate(origin, direction, speed, damage, source, target_mask, kind)
	return projectile


func release(projectile: Projectile2D) -> void:
	if projectile == null or not _active.has(projectile):
		return
	_active.erase(projectile)
	projectile.deactivate()
	_free.append(projectile)


func active_count() -> int:
	return _active.size()


func available_count() -> int:
	return _free.size()


func _on_recycle_requested(projectile: Projectile2D) -> void:
	release(projectile)
