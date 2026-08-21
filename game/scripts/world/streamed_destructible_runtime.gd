class_name StreamedDestructibleRuntime
extends Node

signal building_damage_applied(building: StructuralBuilding2D, amount: float, event: DamageEvent)
signal building_cell_destroyed(
	building: StructuralBuilding2D,
	column: int,
	row: int,
	event: DamageEvent
)
signal building_chain_started(
	building: StructuralBuilding2D,
	kind: StringName,
	event: DamageEvent
)
signal building_chain_step(
	building: StructuralBuilding2D,
	kind: StringName,
	column: int,
	row: int,
	event: DamageEvent
)
signal building_chain_completed(building: StructuralBuilding2D, kind: StringName)
signal building_destroyed(building: StructuralBuilding2D, event: DamageEvent)
signal prop_destroyed(
	prop: DestructibleProp2D,
	event: DamageEvent,
	points: int,
	is_car: bool
)

const BUILDING_INTACT: Texture2D = preload(
	"res://art/city/destructibles/building_intact.png"
)
const BUILDING_DAMAGED: Texture2D = preload(
	"res://art/city/destructibles/building_damaged.png"
)
const BUILDING_RUBBLE: Texture2D = preload(
	"res://art/city/destructibles/building_rubble.png"
)
const LAMP_INTACT: Texture2D = preload(
	"res://art/city/destructibles/streetlamp_intact.png"
)
const LAMP_BROKEN: Texture2D = preload(
	"res://art/city/destructibles/streetlamp_broken.png"
)
const CAR_INTACT: Texture2D = preload("res://art/city/destructibles/car_intact.png")
const CAR_WRECK: Texture2D = preload("res://art/city/destructibles/car_wreck.png")
const BUILDING_SCRIPT: Script = preload(
	"res://scripts/destruction/structural_building_2d.gd"
)
const PROP_SCRIPT: Script = preload("res://scripts/destruction/destructible_prop_2d.gd")
const BUILDING_LAYER: int = 1 << 3
const ROBOT_LAYER: int = 1 << 1
const HURTBOX_LAYER: int = 1 << 6
const PROP_LAYER: int = 1 << 7
const WORLD_LAYER: int = 1 << 0
const BUILDING_SLOTS: int = CityWorldStream.CHUNK_CAPACITY
const PROP_SLOTS: int = CityWorldStream.CHUNK_CAPACITY * 2

var world_stream: CityWorldStream
var ledger: WorldMutationLedger = WorldMutationLedger.new()
var buildings: Array[StructuralBuilding2D] = []
var props: Array[DestructibleProp2D] = []
var post_warm_creation_count: int = 0
var _slot_buildings: Dictionary[int, StructuralBuilding2D] = {}
var _slot_props: Dictionary[int, Array] = {}


func setup(p_world_stream: CityWorldStream) -> void:
	world_stream = p_world_stream


func _ready() -> void:
	assert(world_stream != null, "StreamedDestructibleRuntime requires CityWorldStream")
	ledger.reset(world_stream.run_seed)
	world_stream.chunk_reassigning.connect(_on_chunk_reassigning)
	world_stream.chunk_reassigned.connect(_on_chunk_reassigned)
	world_stream.run_configured.connect(_on_run_configured)
	for chunk: CityStreetChunk in world_stream.chunks:
		_build_slot(chunk)
		_configure_slot(
			chunk,
			CityChunkBlueprint.generate(world_stream.run_seed, chunk.logical_index)
		)


func primary_building() -> StructuralBuilding2D:
	var current_chunk: CityStreetChunk = world_stream.chunk_for_logical(
		world_stream.current_logical_chunk
	)
	if current_chunk == null:
		return null
	return _slot_buildings[current_chunk.get_instance_id()]


func primary_car() -> DestructibleProp2D:
	return _primary_prop(&"car")


func primary_streetlamp() -> DestructibleProp2D:
	return _primary_prop(&"streetlamp")


func nearest_intact_building(
	runtime_x: float,
	include_destroyed: bool = false
) -> StructuralBuilding2D:
	var nearest: StructuralBuilding2D
	var nearest_distance: float = INF
	for building: StructuralBuilding2D in buildings:
		if not building.visible or (building.is_destroyed() and not include_destroyed):
			continue
		var distance: float = absf(building.global_position.x - runtime_x)
		if distance < nearest_distance:
			nearest = building
			nearest_distance = distance
	return nearest


func active_building_count() -> int:
	return buildings.size()


func active_prop_count() -> int:
	return props.size()


func mutation_count() -> int:
	return ledger.state_count()


func reset_run(run_seed: int) -> void:
	ledger.reset(run_seed)
	for chunk: CityStreetChunk in world_stream.chunks:
		_configure_slot(chunk, CityChunkBlueprint.generate(run_seed, chunk.logical_index))


func _build_slot(chunk: CityStreetChunk) -> void:
	var building: StructuralBuilding2D = BUILDING_SCRIPT.new() as StructuralBuilding2D
	building.name = "StreamedBuilding"
	building.z_index = 5
	building.intact_texture = BUILDING_INTACT
	building.damaged_texture = BUILDING_DAMAGED
	building.rubble_texture = BUILDING_RUBBLE
	building.display_size = Vector2(500.0, 445.0)
	building.collision_layer_value = BUILDING_LAYER
	building.collision_mask_value = ROBOT_LAYER
	building.hurtbox_layer_value = HURTBOX_LAYER
	building.debris_pool_path = ^"../../../BuildingDebrisPool"
	building.damage_applied.connect(_emit_building_damage.bind(building))
	building.cell_destroyed.connect(_emit_building_cell.bind(building))
	building.chain_reaction_started.connect(_emit_chain_started.bind(building))
	building.chain_reaction_step.connect(_emit_chain_step.bind(building))
	building.chain_reaction_completed.connect(_emit_chain_completed.bind(building))
	building.destroyed.connect(_emit_building_destroyed.bind(building))
	chunk.add_child(building)
	buildings.append(building)
	_slot_buildings[chunk.get_instance_id()] = building
	var car: DestructibleProp2D = _create_prop("StreamedCar", {
		"intact": CAR_INTACT,
		"broken": CAR_WRECK,
		"intact_size": Vector2(165.0, 78.0),
		"broken_size": Vector2(175.0, 76.0),
		"collision": Vector2(150.0, 62.0),
		"broken_collision": Vector2(160.0, 58.0),
		"health": 260.0,
		"wreck_health": 165.0,
		"chunks": 5,
		"mass": 12.0,
		"points": 300,
		"is_car": true,
	})
	var lamp: DestructibleProp2D = _create_prop("StreamedStreetlamp", {
		"intact": LAMP_INTACT,
		"broken": LAMP_BROKEN,
		"intact_size": Vector2(70.0, 235.0),
		"broken_size": Vector2(185.0, 90.0),
		"collision": Vector2(42.0, 220.0),
		"broken_collision": Vector2(170.0, 55.0),
		"health": 160.0,
		"wreck_health": 95.0,
		"chunks": 3,
		"mass": 4.0,
		"points": 150,
		"is_car": false,
	})
	chunk.add_child(car)
	chunk.add_child(lamp)
	props.append(car)
	props.append(lamp)
	_slot_props[chunk.get_instance_id()] = [car, lamp]


func _create_prop(
	prop_name: String,
	spec: Dictionary
) -> DestructibleProp2D:
	var prop: DestructibleProp2D = PROP_SCRIPT.new() as DestructibleProp2D
	prop.name = prop_name
	prop.z_index = 25
	prop.max_health = float(spec.health)
	prop.wreck_health = float(spec.wreck_health)
	prop.gameplay_chunk_count = int(spec.chunks)
	prop.debris_pool_path = ^"../../../BuildingDebrisPool"
	prop.mass = float(spec.mass)
	prop.collision_layer = PROP_LAYER
	prop.collision_mask = WORLD_LAYER | ROBOT_LAYER
	prop.intact_texture = spec.intact as Texture2D
	prop.destroyed_texture = spec.broken as Texture2D
	prop.intact_display_size = spec.intact_size as Vector2
	prop.destroyed_display_size = spec.broken_size as Vector2
	prop.destroyed_collision_size = spec.broken_collision as Vector2
	prop.destroyed.connect(
		_emit_prop_destroyed.bind(int(spec.points), bool(spec.is_car))
	)
	var visual: Sprite2D = Sprite2D.new()
	visual.name = "Visual"
	prop.add_child(visual)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = spec.collision as Vector2
	collision.shape = rectangle
	prop.add_child(collision)
	return prop


func _configure_slot(chunk: CityStreetChunk, blueprint: CityChunkBlueprint) -> void:
	var building: StructuralBuilding2D = _slot_buildings[chunk.get_instance_id()]
	var slot_props: Array = _slot_props[chunk.get_instance_id()]
	var car: DestructibleProp2D = slot_props[0] as DestructibleProp2D
	var lamp: DestructibleProp2D = slot_props[1] as DestructibleProp2D
	var building_id: StringName = ledger.make_object_id(blueprint.logical_index, &"building")
	var car_id: StringName = ledger.make_object_id(blueprint.logical_index, &"car")
	var lamp_id: StringName = ledger.make_object_id(blueprint.logical_index, &"streetlamp")
	building.set_meta(&"stream_object_id", building_id)
	car.set_meta(&"stream_object_id", car_id)
	lamp.set_meta(&"stream_object_id", lamp_id)
	building.position = Vector2(blueprint.building_x, CitySlice.LAND_VISUAL_BASELINE_Y)
	building.restore_stream_state(ledger.restore(building_id))
	car.visual_ground_offset = CitySlice.LAND_VISUAL_BASELINE_Y - blueprint.car_y
	car.restore_stream_state(
		Vector2(blueprint.car_x, blueprint.car_y),
		ledger.restore(car_id)
	)
	lamp.visual_ground_offset = CitySlice.LAND_VISUAL_BASELINE_Y - blueprint.lamp_y
	lamp.restore_stream_state(
		Vector2(blueprint.lamp_x, blueprint.lamp_y),
		ledger.restore(lamp_id)
	)


func _save_slot(chunk: CityStreetChunk) -> void:
	var building: StructuralBuilding2D = _slot_buildings[chunk.get_instance_id()]
	ledger.store(
		StringName(building.get_meta(&"stream_object_id", &"")),
		building.capture_stream_state()
	)
	for value: Variant in _slot_props[chunk.get_instance_id()]:
		var prop: DestructibleProp2D = value as DestructibleProp2D
		ledger.store(
			StringName(prop.get_meta(&"stream_object_id", &"")),
			prop.capture_stream_state()
		)


func _on_chunk_reassigning(
	chunk: CityStreetChunk,
	_previous_index: int,
	_next_index: int
) -> void:
	if _slot_buildings.has(chunk.get_instance_id()):
		_save_slot(chunk)


func _on_chunk_reassigned(
	chunk: CityStreetChunk,
	_previous_index: int,
	_next_index: int,
	blueprint: CityChunkBlueprint
) -> void:
	if _slot_buildings.has(chunk.get_instance_id()):
		_configure_slot(chunk, blueprint)


func _on_run_configured(run_seed_value: int) -> void:
	reset_run(run_seed_value)


func _primary_prop(role: StringName) -> DestructibleProp2D:
	var current_chunk: CityStreetChunk = world_stream.chunk_for_logical(
		world_stream.current_logical_chunk
	)
	if current_chunk == null:
		return null
	var slot_props: Array = _slot_props[current_chunk.get_instance_id()]
	return (
		slot_props[0] as DestructibleProp2D
		if role == &"car"
		else slot_props[1] as DestructibleProp2D
	)


func _emit_building_damage(
	amount: float,
	event: DamageEvent,
	building: StructuralBuilding2D
) -> void:
	building_damage_applied.emit(building, amount, event)


func _emit_building_cell(
	column: int,
	row: int,
	event: DamageEvent,
	building: StructuralBuilding2D
) -> void:
	building_cell_destroyed.emit(building, column, row, event)


func _emit_chain_started(
	kind: StringName,
	event: DamageEvent,
	building: StructuralBuilding2D
) -> void:
	building_chain_started.emit(building, kind, event)


func _emit_chain_step(
	kind: StringName,
	column: int,
	row: int,
	event: DamageEvent,
	building: StructuralBuilding2D
) -> void:
	building_chain_step.emit(building, kind, column, row, event)


func _emit_chain_completed(
	kind: StringName,
	building: StructuralBuilding2D
) -> void:
	building_chain_completed.emit(building, kind)


func _emit_building_destroyed(
	event: DamageEvent,
	building: StructuralBuilding2D
) -> void:
	building_destroyed.emit(building, event)


func _emit_prop_destroyed(
	prop: DestructibleProp2D,
	event: DamageEvent,
	points: int,
	is_car: bool
) -> void:
	prop_destroyed.emit(prop, event, points, is_car)
