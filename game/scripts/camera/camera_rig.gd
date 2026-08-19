class_name CameraRig
extends Node2D

@export var look_ahead: float = 180.0
@export var look_ahead_speed: float = 700.0
@export var follow_speed: float = 850.0
@export var fixed_y: float = 360.0
@export var portrait_fixed_y: float = 427.0
@export var minimum_x: float = 640.0
@export var maximum_x: float = 2560.0
@export var impact_spring_strength: float = 145.0
@export var impact_spring_damping: float = 24.0
@export var maximum_impact_offset: float = 24.0
@export var portrait_visible_world_height: float = 854.0

var target: GiantRobotController
var impact_offset: Vector2 = Vector2.ZERO
var impact_velocity: Vector2 = Vector2.ZERO
var _current_look_ahead: float = 0.0
var _look_ahead_scale: float = 1.0
@onready var _camera: Camera2D = get_node_or_null(^"Camera2D") as Camera2D


func _ready() -> void:
	get_viewport().size_changed.connect(_apply_responsive_framing)
	_apply_responsive_framing()


func _physics_process(delta: float) -> void:
	_update_impact_spring(delta)
	if target == null:
		return
	var desired_look_ahead: float = (
		look_ahead * _look_ahead_scale * float(target.facing)
	)
	_current_look_ahead = move_toward(
		_current_look_ahead,
		desired_look_ahead,
		look_ahead_speed * delta
	)
	var desired_x: float = clampf(
		target.global_position.x + _current_look_ahead,
		minimum_x,
		maximum_x
	)
	global_position.x = move_toward(global_position.x, desired_x, follow_speed * delta)
	global_position.y = portrait_fixed_y if is_portrait_framing() else fixed_y


func add_impact_impulse(impulse: Vector2) -> void:
	impact_velocity += impulse * 42.0
	impact_velocity = impact_velocity.limit_length(maximum_impact_offset * 30.0)


func reset_presentation() -> void:
	impact_offset = Vector2.ZERO
	impact_velocity = Vector2.ZERO
	if _camera != null:
		_camera.offset = Vector2.ZERO


func is_portrait_framing() -> bool:
	var viewport_size: Vector2 = get_viewport_rect().size
	return viewport_size.y > viewport_size.x


func visible_world_size() -> Vector2:
	if _camera == null:
		return get_viewport_rect().size
	return get_viewport_rect().size / _camera.zoom


func _apply_responsive_framing() -> void:
	if _camera == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.y > viewport_size.x:
		var portrait_zoom: float = clampf(
			viewport_size.y / portrait_visible_world_height,
			1.35,
			1.60
		)
		_camera.zoom = Vector2.ONE * portrait_zoom
		_look_ahead_scale = 0.78
	else:
		_camera.zoom = Vector2.ONE
		_look_ahead_scale = 1.0


func _update_impact_spring(delta: float) -> void:
	impact_velocity += -impact_offset * impact_spring_strength * delta
	impact_velocity *= exp(-impact_spring_damping * delta)
	impact_offset += impact_velocity * delta
	impact_offset = impact_offset.limit_length(maximum_impact_offset)
	if impact_offset.length_squared() < 0.0025 and impact_velocity.length_squared() < 0.04:
		impact_offset = Vector2.ZERO
		impact_velocity = Vector2.ZERO
	if _camera != null:
		_camera.offset = impact_offset
