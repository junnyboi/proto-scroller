class_name StructuralBuilding2D
extends Node2D

signal damage_applied(amount: float, event: DamageEvent)
signal cell_destroyed(column: int, row: int, event: DamageEvent)
signal chain_reaction_started(kind: StringName, event: DamageEvent)
signal chain_reaction_step(
	kind: StringName,
	column: int,
	row: int,
	event: DamageEvent
)
signal chain_reaction_completed(kind: StringName)
signal destroyed(event: DamageEvent)

const COLUMNS: int = 3
const ROWS: int = 2
const CELL_COUNT: int = COLUMNS * ROWS
const CELL_SCRIPT: Script = preload("res://scripts/destruction/destructible_2d.gd")

@export var intact_texture: Texture2D
@export var damaged_texture: Texture2D
@export var rubble_texture: Texture2D
@export var display_size: Vector2 = Vector2(500.0, 445.0)
@export var collision_layer_value: int = 0
@export var collision_mask_value: int = 0
@export var hurtbox_layer_value: int = 0
@export var debris_pool_path: NodePath

var last_chain_reaction_kind: StringName = &""
var chain_reaction_count: int = 0
var _cells: Array[Destructible2D] = []
var _destroyed_cells: int = 0
var _last_destruction_event: DamageEvent
var _chain_reaction_active: bool = false
var _steel_chain_triggered: bool = false
var _triggered_floor_rows: Dictionary[int, bool] = {}


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


func get_material_profile(column: int, row: int) -> StructuralMaterialProfile:
	var cell: Destructible2D = get_cell(column, row)
	return cell.get_material_profile() if cell != null else null


func destroyed_cell_count() -> int:
	return _destroyed_cells


func is_cell_destroyed(column: int, row: int) -> bool:
	var cell: Destructible2D = get_cell(column, row)
	return cell != null and cell.is_destroyed()


func is_destroyed() -> bool:
	return _destroyed_cells >= CELL_COUNT


func is_chain_reaction_active() -> bool:
	return _chain_reaction_active


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
	var profile: StructuralMaterialProfile = _material_for_cell(column, row)
	cell.name = "Cell_%d_%d" % [column, row]
	cell.position = _cell_center(column, row)
	cell.material_profile = profile
	cell.max_health = profile.max_health
	cell.damaged_stage_ratio = 0.65
	cell.gameplay_chunk_count = profile.chunk_count
	cell.debris_pool_path = NodePath("../" + str(debris_pool_path))
	cell.intact_visual_path = ^"IntactVisual"
	cell.damaged_visual_path = ^"DamagedVisual"
	cell.rubble_visual_path = ^"RubbleVisual"
	cell.intact_collision_path = ^"IntactBody/CollisionShape2D"
	cell.damage_applied.connect(_on_cell_damage_applied)
	cell.destroyed.connect(_on_cell_destroyed.bind(column, row))
	cell.set_meta(&"structural_column", column)
	cell.set_meta(&"structural_row", row)
	cell.set_meta(&"structural_material", profile.material_id)
	cell.add_child(
		_create_cell_sprite("IntactVisual", intact_texture, column, row, profile)
	)
	cell.add_child(
		_create_cell_sprite("DamagedVisual", damaged_texture, column, row, profile)
	)
	cell.add_child(_create_rubble_sprite(column, row, profile))
	cell.add_child(_create_intact_body(row))
	cell.add_child(_create_hurtbox())
	return cell


func _create_cell_sprite(
	sprite_name: String,
	texture: Texture2D,
	column: int,
	row: int,
	profile: StructuralMaterialProfile
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
	sprite.modulate = profile.visual_tint
	return sprite


func _create_rubble_sprite(
	column: int,
	row: int,
	profile: StructuralMaterialProfile
) -> Sprite2D:
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
	sprite.modulate = profile.visual_tint
	return sprite


func _material_for_cell(column: int, row: int) -> StructuralMaterialProfile:
	var material_grid: Array[Array] = [
		[concrete_profile(), steel_profile(), concrete_profile()],
		[glass_profile(), concrete_profile(), steel_profile()],
	]
	return material_grid[row][column] as StructuralMaterialProfile


func concrete_profile() -> StructuralMaterialProfile:
	return StructuralMaterialProfile.concrete()


func glass_profile() -> StructuralMaterialProfile:
	return StructuralMaterialProfile.glass()


func steel_profile() -> StructuralMaterialProfile:
	return StructuralMaterialProfile.steel()


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
	call_deferred("_evaluate_chain_reactions")


func _evaluate_chain_reactions() -> void:
	if _chain_reaction_active or is_destroyed():
		return
	if not _steel_chain_triggered and _all_steel_cells_destroyed():
		_steel_chain_triggered = true
		_start_chain_reaction(&"steel_support_chain", -1)
		return
	for row: int in range(ROWS):
		if _triggered_floor_rows.has(row) or not _is_floor_destroyed(row):
			continue
		_triggered_floor_rows[row] = true
		_start_chain_reaction(&"floor_chain", row)
		return


func _all_steel_cells_destroyed() -> bool:
	var steel_count: int = 0
	for cell: Destructible2D in _cells:
		var profile: StructuralMaterialProfile = cell.get_material_profile()
		if profile == null or profile.material_id != &"steel":
			continue
		steel_count += 1
		if not cell.is_destroyed():
			return false
	return steel_count > 0


func _is_floor_destroyed(row: int) -> bool:
	for column: int in range(COLUMNS):
		if not is_cell_destroyed(column, row):
			return false
	return true


func _start_chain_reaction(kind: StringName, destroyed_floor: int) -> void:
	_chain_reaction_active = true
	last_chain_reaction_kind = kind
	chain_reaction_count += 1
	chain_reaction_started.emit(kind, _last_destruction_event)
	_run_chain_reaction(kind, destroyed_floor)


func _run_chain_reaction(kind: StringName, destroyed_floor: int) -> void:
	var impulse_per_mass: float = 340.0
	var step_delay: float = 0.11
	if kind == &"steel_support_chain":
		impulse_per_mass = 470.0
		step_delay = 0.075
	var origin_column: int = _last_impact_column()
	var column_order: Array[int] = _column_order(origin_column)
	for row: int in range(ROWS - 1, -1, -1):
		if row == destroyed_floor:
			continue
		for column: int in column_order:
			var cell: Destructible2D = get_cell(column, row)
			if cell == null or cell.is_destroyed():
				continue
			await get_tree().create_timer(step_delay, false).timeout
			var event: DamageEvent = _chain_event(
				cell,
				kind,
				impulse_per_mass,
				origin_column
			)
			if cell.receive_damage(event):
				chain_reaction_step.emit(kind, column, row, event)
	_chain_reaction_active = false
	chain_reaction_completed.emit(kind)
	call_deferred("_evaluate_chain_reactions")


func _chain_event(
	cell: Destructible2D,
	kind: StringName,
	impulse_per_mass: float,
	origin_column: int
) -> DamageEvent:
	var cell_column: int = int(cell.get_meta(&"structural_column", 0))
	var horizontal_direction: float = signf(float(cell_column - origin_column))
	if is_zero_approx(horizontal_direction):
		horizontal_direction = 1.0 if origin_column <= 1 else -1.0
	var direction: Vector2 = Vector2(horizontal_direction * 0.48, 1.0).normalized()
	return DamageEvent.new(
		0,
		_last_destruction_event.source if _last_destruction_event != null else null,
		cell.max_health + 1.0,
		kind,
		cell.global_position,
		direction,
		impulse_per_mass
	)


func _last_impact_column() -> int:
	if _last_destruction_event == null:
		return 1
	var local_x: float = to_local(_last_destruction_event.hit_position).x
	return clampi(
		floori((local_x + display_size.x * 0.5) / _cell_size().x),
		0,
		COLUMNS - 1
	)


func _column_order(origin_column: int) -> Array[int]:
	var order: Array[int] = [origin_column]
	for distance: int in range(1, COLUMNS):
		var left: int = origin_column - distance
		var right: int = origin_column + distance
		if left >= 0:
			order.append(left)
		if right < COLUMNS:
			order.append(right)
	return order
