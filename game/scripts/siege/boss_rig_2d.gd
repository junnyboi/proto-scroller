class_name BossRig2D
extends Node2D

signal damage_forwarded(event: DamageEvent, accepted: bool)

const HURTBOX_LAYER: int = 1 << 6
const PART_CAPACITY: int = 6
const SOCKET_CAPACITY: int = 8
const HURT_REGION_CAPACITY: int = 3
const DEFAULT_DISPLAY_SIZE: Vector2 = Vector2(520.0, 390.0)
const SOCKET_NAMES: Array[StringName] = [
	&"CORE",
	&"WEAK_POINT",
	&"LEFT_EMITTER",
	&"RIGHT_EMITTER",
	&"UPPER",
	&"LOWER",
	&"SUPPORT_LEFT",
	&"SUPPORT_RIGHT",
]
const SETTLEMENT_TEXTURE: Texture2D = preload(
	"res://art/bosses/settlement-engine-s04.webp"
)
const SAMARITAN_TEXTURE: Texture2D = preload("res://art/bosses/samaritan-15.webp")
const MIMESIS_TEXTURE: Texture2D = preload("res://art/bosses/mimesis-04.webp")
const CANTOR_TEXTURE: Texture2D = preload("res://art/bosses/cantor-31.webp")
const CHOIR_PRIME_TEXTURE: Texture2D = preload("res://art/bosses/choir-prime.webp")
const WEAK_POINT_TEXTURE: Texture2D = preload("res://art/finale/choir-pylon.png")

var parts: Array[Sprite2D] = []
var sockets: Array[Marker2D] = []
var hurt_regions: Array[Area2D] = []
var host: EnemyActor2D
var active_definition: BossEncounterDefinition
var portrait: bool = false
var active_part_count: int = 0
var active_hurt_region_count: int = 0

var _presentation_root: Node2D
var _socket_root: Node2D
var _socket_indices: Dictionary[StringName, int] = {}


func _init() -> void:
	_prewarm()


func configure(
	definition: BossEncounterDefinition,
	p_host: EnemyActor2D,
	use_portrait: bool = false
) -> bool:
	deactivate()
	if definition == null or p_host == null:
		return false
	active_definition = definition
	host = p_host
	portrait = use_portrait
	global_position = host.global_position
	_configure_art(definition.rig_preset)
	_configure_sockets(definition.rig_preset, definition.portrait_socket_overrides)
	_configure_hurt_regions(definition.rig_preset)
	set_armor_target_active(host.boss_armor > 0.0)
	visible = true
	return true


func deactivate() -> void:
	active_definition = null
	host = null
	portrait = false
	active_part_count = 0
	active_hurt_region_count = 0
	visible = false
	for part: Sprite2D in parts:
		part.visible = false
		part.texture = null
		part.region_enabled = false
		part.position = Vector2.ZERO
		part.scale = Vector2.ONE
		part.rotation = 0.0
	for socket: Marker2D in sockets:
		socket.position = Vector2.ZERO
	for area: Area2D in hurt_regions:
		_set_hurt_region_active(area, false)


func receive_damage(event: DamageEvent) -> bool:
	if host == null or not is_instance_valid(host):
		return false
	var accepted: bool = host.receive_damage(event)
	damage_forwarded.emit(event, accepted)
	return accepted


func configure_part(
	index: int,
	texture: Texture2D,
	position_value: Vector2,
	display_size: Vector2,
	modulate_value: Color = Color.WHITE
) -> bool:
	if index < 0 or index >= parts.size() or texture == null:
		return false
	var part: Sprite2D = parts[index]
	part.texture = texture
	part.position = position_value
	part.modulate = modulate_value
	var texture_size: Vector2 = texture.get_size()
	var fit: float = minf(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	part.scale = Vector2.ONE * fit
	part.visible = true
	active_part_count = maxi(active_part_count, index + 1)
	return true


func socket(socket_name: StringName) -> Marker2D:
	var index: int = int(_socket_indices.get(socket_name, -1))
	return sockets[index] if index >= 0 and index < sockets.size() else null


func configure_orientation(use_portrait: bool) -> void:
	portrait = use_portrait
	if active_definition == null:
		return
	_configure_sockets(
		active_definition.rig_preset,
		active_definition.portrait_socket_overrides
	)


func mechanical_signature() -> Dictionary:
	var regions: Array[Dictionary] = []
	for area: Area2D in hurt_regions:
		var collision: CollisionShape2D = area.get_node(^"Collision") as CollisionShape2D
		var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
		regions.append({
			"position": area.position,
			"size": rectangle.size,
			"enabled": not collision.disabled,
		})
	return {
		"hurt_regions": regions,
		"active_hurt_regions": active_hurt_region_count,
	}


func presentation_signature() -> Dictionary:
	var socket_positions: Dictionary[StringName, Vector2] = {}
	for index: int in range(sockets.size()):
		socket_positions[SOCKET_NAMES[index]] = sockets[index].position
	return {
		"portrait": portrait,
		"scale": _presentation_root.scale,
		"sockets": socket_positions,
	}


func _prewarm() -> void:
	name = "BossRig2D"
	z_index = 31
	_presentation_root = Node2D.new()
	_presentation_root.name = "Presentation"
	add_child(_presentation_root)
	for index: int in range(PART_CAPACITY):
		var part: Sprite2D = Sprite2D.new()
		part.name = "Part%02d" % index
		part.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_presentation_root.add_child(part)
		parts.append(part)
	_socket_root = Node2D.new()
	_socket_root.name = "PresentationSockets"
	_presentation_root.add_child(_socket_root)
	for index: int in range(SOCKET_CAPACITY):
		var marker: Marker2D = Marker2D.new()
		marker.name = String(SOCKET_NAMES[index]).to_pascal_case()
		_socket_root.add_child(marker)
		sockets.append(marker)
		_socket_indices[SOCKET_NAMES[index]] = index
	for index: int in range(HURT_REGION_CAPACITY):
		var area: Area2D = Area2D.new()
		area.name = "HurtRegion%02d" % index
		area.collision_layer = 0
		area.collision_mask = 0
		area.monitoring = false
		area.monitorable = false
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.name = "Collision"
		collision.shape = RectangleShape2D.new()
		collision.disabled = true
		area.add_child(collision)
		add_child(area)
		hurt_regions.append(area)
	deactivate()


func _configure_art(preset: StringName) -> void:
	var texture: Texture2D = _texture_for_preset(preset)
	configure_part(0, texture, Vector2(0.0, -116.0), DEFAULT_DISPLAY_SIZE)
	configure_part(
		1,
		WEAK_POINT_TEXTURE,
		_socket_position_for(preset, &"WEAK_POINT"),
		Vector2(72.0, 72.0),
		Color(1.0, 1.0, 1.0, 0.94)
	)


func _configure_sockets(preset: StringName, portrait_overrides: Dictionary) -> void:
	_presentation_root.scale = Vector2.ONE
	for index: int in range(sockets.size()):
		sockets[index].position = _socket_position_for(preset, SOCKET_NAMES[index])
	if not portrait:
		return
	var presentation_scale: Vector2 = portrait_overrides.get(
		&"presentation_scale",
		Vector2(0.82, 1.0)
	) as Vector2
	_presentation_root.scale = presentation_scale
	var socket_overrides: Dictionary = portrait_overrides.get(&"sockets", {}) as Dictionary
	for key_value: Variant in socket_overrides:
		var marker: Marker2D = socket(StringName(key_value))
		if marker != null:
			marker.position = socket_overrides[key_value] as Vector2


func set_armor_target_active(active: bool) -> void:
	if parts.size() < 2:
		return
	var weak_point: Sprite2D = parts[1]
	weak_point.visible = active
	weak_point.modulate = Color(1.0, 0.78, 0.18, 1.0) if active else Color.WHITE


func _configure_hurt_regions(preset: StringName) -> void:
	var positions: Array[Vector2] = [
		Vector2(0.0, -112.0),
		Vector2(-172.0, -72.0),
		Vector2(172.0, -72.0),
	]
	var sizes: Array[Vector2] = [
		Vector2(292.0, 210.0),
		Vector2(150.0, 118.0),
		Vector2(150.0, 118.0),
	]
	if preset == &"SAMARITAN":
		positions = [
			Vector2(0.0, -78.0),
			Vector2(-188.0, -48.0),
			Vector2(188.0, -48.0),
		]
		sizes = [
			Vector2(150.0, 120.0),
			Vector2(112.0, 90.0),
			Vector2(112.0, 90.0),
		]
	for index: int in range(hurt_regions.size()):
		var area: Area2D = hurt_regions[index]
		area.position = positions[index]
		var collision: CollisionShape2D = area.get_node(^"Collision") as CollisionShape2D
		(collision.shape as RectangleShape2D).size = sizes[index]
		_set_hurt_region_active(area, true)
	active_hurt_region_count = hurt_regions.size()


func _set_hurt_region_active(area: Area2D, enabled: bool) -> void:
	area.collision_layer = HURTBOX_LAYER if enabled else 0
	area.monitorable = enabled
	area.monitoring = false
	var collision: CollisionShape2D = area.get_node(^"Collision") as CollisionShape2D
	collision.disabled = not enabled


func _texture_for_preset(preset: StringName) -> Texture2D:
	match preset:
		&"SETTLEMENT_ENGINE":
			return SETTLEMENT_TEXTURE
		&"SAMARITAN":
			return SAMARITAN_TEXTURE
		&"MIMESIS":
			return MIMESIS_TEXTURE
		&"CANTOR_PALE_ENGINE":
			return CANTOR_TEXTURE
		&"CHOIR_PRIME":
			return CHOIR_PRIME_TEXTURE
	return SETTLEMENT_TEXTURE


func _socket_position_for(preset: StringName, socket_name: StringName) -> Vector2:
	var horizontal_scale: float = 1.0
	var vertical_shift: float = 0.0
	match preset:
		&"SAMARITAN":
			horizontal_scale = 0.92
			vertical_shift = -12.0
		&"MIMESIS":
			horizontal_scale = 0.86
			vertical_shift = 8.0
		&"CANTOR_PALE_ENGINE":
			horizontal_scale = 0.78
			vertical_shift = -34.0
		&"CHOIR_PRIME":
			horizontal_scale = 1.08
			vertical_shift = -18.0
	var base_positions: Dictionary[StringName, Vector2] = {
		&"CORE": Vector2(0.0, -116.0),
		&"WEAK_POINT": Vector2(0.0, -138.0),
		&"LEFT_EMITTER": Vector2(-196.0, -116.0),
		&"RIGHT_EMITTER": Vector2(196.0, -116.0),
		&"UPPER": Vector2(0.0, -280.0),
		&"LOWER": Vector2(0.0, -22.0),
		&"SUPPORT_LEFT": Vector2(-270.0, -8.0),
		&"SUPPORT_RIGHT": Vector2(270.0, -8.0),
	}
	var position_value: Vector2 = base_positions.get(socket_name, Vector2.ZERO) as Vector2
	position_value.x *= horizontal_scale
	position_value.y += vertical_shift
	return position_value
