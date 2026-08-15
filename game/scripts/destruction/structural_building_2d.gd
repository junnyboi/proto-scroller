class_name StructuralBuilding2D
extends Node2D

signal damage_applied(amount: float, event: DamageEvent)
signal cell_destroyed(column: int, row: int, event: DamageEvent)
signal destroyed(event: DamageEvent)

const COLUMNS: int = 3
const ROWS: int = 2
const CELL_COUNT: int = COLUMNS * ROWS
const CELL_SCRIPT: Script = preload("res://scripts/destruction/destructible_2d.gd")

@export var intact_texture: Texture2D
@export var damaged_texture: Texture2D
@export var rubble_texture: Texture2D
@export var display_size: Vector2 = Vector2(500.0, 445.0)
@export var cell_health: float = 85.0
@export var collision_layer_value: int = 0
@export var collision_mask_value: int = 0
@export var hurtbox_layer_value: int = 0
@export var debris_pool_path: NodePath
@export_range(1, 6, 1) var chunks_per_cell: int = 3

var _cells: Array[Destructible2D] = []
var _destroyed_cells: int = 0
var _last_destruction_event: DamageEvent


func _ready() -> void:
	_build_cells()


func receive_damage(event: DamageEvent) -> bool:
	var cell: Destructible2D = cell_at_world_point(event.hit_position)
	if cell == null:
		return false
	return cell.receive_damage(event)


func cell_at_world_point(world_point: Vector2) -> Destructible2D:
	var local_point: Vector2 = to_local(world_point)
	var cell_size: Vector2 = _cell_size()
	var column: int = clampi(
		floori((local_point.x + display_size.x * 0.5) / cell_size.x),
		0,
		COLUMNS - 1
	)
	var row: int = clampi(
		floori((local_point.y + display_size.y) / cell_size.y),
		0,
		ROWS - 1
	)
	return get_cell(column, row)


func get_cell(column: int, row: int) -> Destructible2D:
	if column < 0 or column >= COLUMNS or row < 0 or row >= ROWS:
		return null
	var index: int = row * COLUMNS + column
	if index >= _cells.size():
		return null
	return _cells[index]


func destroyed_cell_count() -> int:
	return _destroyed_cells


func is_cell_destroyed(column: int, row: int) -> bool:
	var cell: Destructible2D = get_cell(column, row)
	return cell != null and cell.is_destroyed()


func is_destroyed() -> bool:
	return _destroyed_cells >= CELL_COUNT


func _build_cells() -> void:
	if intact_texture == null or damaged_texture == null or rubble_texture == null:
		push_error("StructuralBuilding2D requires intact, damaged, and rubble textures")
		return
	for row: int in range(ROWS):
		for column: int in range(COLUMNS):
			var cell: Destructible2D = _create_cell(column, row)
			_cells.append(cell)
			add_child(cell)


func _create_cell(column: int, row: int) -> Destructible2D:
	var cell: Destructible2D = CELL_SCRIPT.new() as Destructible2D
	cell.name = "Cell_%d_%d" % [column, row]
	cell.position = _cell_center(column, row)
	cell.max_health = cell_health
	cell.damaged_stage_ratio = 0.65
	cell.gameplay_chunk_count = chunks_per_cell
	cell.debris_pool_path = NodePath("../" + str(debris_pool_path))
	cell.intact_visual_path = ^"IntactVisual"
	cell.damaged_visual_path = ^"DamagedVisual"
	cell.rubble_visual_path = ^"RubbleVisual"
	cell.intact_collision_path = ^"IntactBody/CollisionShape2D"
	cell.damage_applied.connect(_on_cell_damage_applied)
	cell.destroyed.connect(_on_cell_destroyed.bind(column, row))
	cell.set_meta(&"structural_column", column)
	cell.set_meta(&"structural_row", row)
	cell.add_child(_create_cell_sprite("IntactVisual", intact_texture, column, row))
	cell.add_child(_create_cell_sprite("DamagedVisual", damaged_texture, column, row))
	cell.add_child(_create_rubble_sprite(column, row))
	cell.add_child(_create_intact_body(row))
	cell.add_child(_create_hurtbox())
	return cell


func _create_cell_sprite(
	sprite_name: String,
	texture: Texture2D,
	column: int,
	row: int
) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	var source_size: Vector2 = texture.get_size()
	var source_cell_size: Vector2 = Vector2(
		source_size.x / float(COLUMNS),
		source_size.y / float(ROWS)
	)
	sprite.region_rect = Rect2(
		Vector2(source_cell_size.x * float(column), source_cell_size.y * float(row)),
		source_cell_size
	)
	sprite.scale = _cell_size() / source_cell_size
	return sprite


func _create_rubble_sprite(column: int, row: int) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "RubbleVisual"
	sprite.texture = rubble_texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	var source_size: Vector2 = rubble_texture.get_size()
	var source_width: float = source_size.x / float(COLUMNS)
	sprite.region_rect = Rect2(
		Vector2(source_width * float(column), 0.0),
		Vector2(source_width, source_size.y)
	)
	var rubble_height: float = 64.0 if row == ROWS - 1 else 44.0
	sprite.scale = Vector2(
		_cell_size().x / source_width,
		rubble_height / maxf(source_size.y, 1.0)
	)
	sprite.position.y = -_cell_center(column, row).y - rubble_height * 0.5
	return sprite


func _create_intact_body(row: int) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "IntactBody"
	body.collision_layer = collision_layer_value
	body.collision_mask = collision_mask_value
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	var cell_size: Vector2 = _cell_size()
	if row == ROWS - 1:
		rectangle.size = Vector2(cell_size.x - 8.0, cell_size.y - 6.0)
	else:
		rectangle.size = Vector2(cell_size.x - 8.0, 118.0)
		collision.position.y = -cell_size.y * 0.5 + 59.0
	collision.shape = rectangle
	body.add_child(collision)
	return body


func _create_hurtbox() -> Area2D:
	var hurtbox: Area2D = Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = hurtbox_layer_value
	hurtbox.collision_mask = 0
	var collision: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = _cell_size() - Vector2(4.0, 4.0)
	collision.shape = rectangle
	hurtbox.add_child(collision)
	return hurtbox


func _cell_size() -> Vector2:
	return Vector2(
		display_size.x / float(COLUMNS),
		display_size.y / float(ROWS)
	)


func _cell_center(column: int, row: int) -> Vector2:
	var cell_size: Vector2 = _cell_size()
	return Vector2(
		-display_size.x * 0.5 + cell_size.x * (float(column) + 0.5),
		-display_size.y + cell_size.y * (float(row) + 0.5)
	)


func _on_cell_damage_applied(amount: float, event: DamageEvent) -> void:
	damage_applied.emit(amount, event)


func _on_cell_destroyed(event: DamageEvent, column: int, row: int) -> void:
	_destroyed_cells += 1
	_last_destruction_event = event
	cell_destroyed.emit(column, row, event)
	if is_destroyed():
		destroyed.emit(event)
		return
	call_deferred("_evaluate_support")


func _evaluate_support() -> void:
	var supported: Dictionary[int, bool] = {}
	var frontier: Array[int] = []
	for column: int in range(COLUMNS):
		if is_cell_destroyed(column, ROWS - 1):
			continue
		var upper: Destructible2D = get_cell(column, 0)
		if upper != null and not upper.is_destroyed():
			supported[column] = true
			frontier.append(column)
	while not frontier.is_empty():
		var column: int = frontier.pop_front()
		for neighbor: int in [column - 1, column + 1]:
			if neighbor < 0 or neighbor >= COLUMNS or supported.has(neighbor):
				continue
			var neighbor_cell: Destructible2D = get_cell(neighbor, 0)
			if neighbor_cell != null and not neighbor_cell.is_destroyed():
				supported[neighbor] = true
				frontier.append(neighbor)
	for column: int in range(COLUMNS):
		var upper: Destructible2D = get_cell(column, 0)
		if upper == null or upper.is_destroyed() or supported.has(column):
			continue
		_collapse_unsupported(upper)


func _collapse_unsupported(cell: Destructible2D) -> void:
	var direction: Vector2 = Vector2.DOWN
	if _last_destruction_event != null:
		direction = (_last_destruction_event.direction + Vector2.DOWN).normalized()
	var event: DamageEvent = DamageEvent.new(
		0,
		_last_destruction_event.source if _last_destruction_event != null else null,
		cell.max_health + 1.0,
		&"support_collapse",
		cell.global_position,
		direction,
		180.0
	)
	cell.receive_damage(event)
