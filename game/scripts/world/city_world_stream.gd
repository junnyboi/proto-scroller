class_name CityWorldStream
extends Node2D

signal origin_shift_requested(offset: Vector2, chunk_delta: int)
signal window_changed(current_chunk: int)
signal chunk_reassigning(chunk: CityStreetChunk, previous_index: int, next_index: int)
signal chunk_reassigned(
	chunk: CityStreetChunk,
	previous_index: int,
	next_index: int,
	blueprint: CityChunkBlueprint
)
signal run_configured(run_seed: int)
signal district_changed(
	previous_district_id: StringName,
	district_id: StringName,
	logical_chunk: int
)

const CHUNK_WIDTH: float = CityStreetChunk.CHUNK_WIDTH
const CHUNK_CAPACITY: int = 6
const BEHIND_CHUNKS: int = 2
const AHEAD_CHUNKS: int = 3
const PROGRESSION_CHUNKS_PER_TIER: int = 8
const MAX_PROGRESSION_TIER: int = 4
const CHUNK_SCRIPT: Script = preload("res://scripts/world/city_street_chunk.gd")

var robot: GiantRobotController
var run_seed: int = 0
var current_logical_chunk: int = 0
var current_district_id: StringName = &"BUSINESS"
var minimum_visited_chunk: int = 0
var maximum_visited_chunk: int = 0
var transition_count: int = 0
var post_warm_creation_count: int = 0
var floating_origin: FloatingOriginRuntime = FloatingOriginRuntime.new()
var chunks: Array[CityStreetChunk] = []
var landmark_root: Node2D


func setup(p_robot: GiantRobotController, p_run_seed: int = 0) -> void:
	robot = p_robot
	run_seed = p_run_seed


func _ready() -> void:
	for slot_index: int in range(CHUNK_CAPACITY):
		var chunk: CityStreetChunk = CHUNK_SCRIPT.new() as CityStreetChunk
		chunk.name = "StreetChunk%02d" % slot_index
		add_child(chunk)
		chunks.append(chunk)
	if robot != null:
		current_logical_chunk = logical_index_for_runtime_x(robot.global_position.x)
	current_district_id = CityDistrictCatalog.district_for_chunk(
		current_logical_chunk
	).district_id
	minimum_visited_chunk = current_logical_chunk
	maximum_visited_chunk = current_logical_chunk
	_refresh_window()


func _physics_process(_delta: float) -> void:
	advance_stream()


func advance_stream() -> void:
	if robot == null or chunks.is_empty():
		return
	var chunk_delta: int = floating_origin.required_chunk_shift(
		robot.global_position.x,
		CHUNK_WIDTH
	)
	if chunk_delta != 0:
		floating_origin.commit(chunk_delta)
		origin_shift_requested.emit(Vector2(-float(chunk_delta) * CHUNK_WIDTH, 0.0), chunk_delta)
	var next_chunk: int = logical_index_for_runtime_x(robot.global_position.x)
	if next_chunk == current_logical_chunk:
		if chunk_delta != 0:
			_refresh_window()
		return
	transition_count += absi(next_chunk - current_logical_chunk)
	var previous_district_id: StringName = current_district_id
	current_logical_chunk = next_chunk
	current_district_id = CityDistrictCatalog.district_for_chunk(
		current_logical_chunk
	).district_id
	minimum_visited_chunk = mini(minimum_visited_chunk, current_logical_chunk)
	maximum_visited_chunk = maxi(maximum_visited_chunk, current_logical_chunk)
	_refresh_window()
	if current_district_id != previous_district_id:
		district_changed.emit(
			previous_district_id,
			current_district_id,
			current_logical_chunk
		)
	window_changed.emit(current_logical_chunk)


func configure_run(p_run_seed: int) -> void:
	run_seed = p_run_seed
	run_configured.emit(run_seed)
	_refresh_window()


func set_landmark_root(p_landmark_root: Node2D) -> void:
	landmark_root = p_landmark_root
	_update_landmark_root()


func active_chunk_count() -> int:
	return chunks.size()


func logical_index_for_runtime_x(runtime_x: float) -> int:
	return floating_origin.origin_chunk + floori(runtime_x / CHUNK_WIDTH)


func runtime_x_for_logical_index(logical_index: int) -> float:
	return float(logical_index - floating_origin.origin_chunk) * CHUNK_WIDTH


func chunk_for_logical(logical_index: int) -> CityStreetChunk:
	for chunk: CityStreetChunk in chunks:
		if chunk.logical_index == logical_index:
			return chunk
	return null


func resident_bounds() -> Vector2:
	return Vector2(
		runtime_x_for_logical_index(current_logical_chunk - BEHIND_CHUNKS),
		runtime_x_for_logical_index(current_logical_chunk + AHEAD_CHUNKS + 1)
	)


func logical_distance_x(runtime_x: float) -> float:
	return float(floating_origin.origin_chunk) * CHUNK_WIDTH + runtime_x


func progression_distance_chunks() -> int:
	return maxi(absi(current_logical_chunk), maximum_visited_chunk)


func progression_tier() -> int:
	return mini(
		floori(
			float(progression_distance_chunks())
			/ float(PROGRESSION_CHUNKS_PER_TIER)
		),
		MAX_PROGRESSION_TIER
	)


func current_district() -> CityDistrictProfile:
	return CityDistrictCatalog.district_for_chunk(current_logical_chunk)


func reset_stream(p_run_seed: int = 0) -> void:
	run_seed = p_run_seed
	var previous_district_id: StringName = current_district_id
	floating_origin.reset()
	current_logical_chunk = logical_index_for_runtime_x(
		robot.global_position.x if robot != null else 0.0
	)
	current_district_id = CityDistrictCatalog.district_for_chunk(
		current_logical_chunk
	).district_id
	minimum_visited_chunk = current_logical_chunk
	maximum_visited_chunk = current_logical_chunk
	transition_count = 0
	run_configured.emit(run_seed)
	_refresh_window()
	if current_district_id != previous_district_id:
		district_changed.emit(
			previous_district_id,
			current_district_id,
			current_logical_chunk
		)


func _refresh_window() -> void:
	var desired: Array[int] = []
	for logical_index: int in range(
		current_logical_chunk - BEHIND_CHUNKS,
		current_logical_chunk + AHEAD_CHUNKS + 1
	):
		desired.append(logical_index)
	var reusable: Array[CityStreetChunk] = []
	for chunk: CityStreetChunk in chunks:
		if not desired.has(chunk.logical_index):
			reusable.append(chunk)
	for logical_index: int in desired:
		var chunk: CityStreetChunk = chunk_for_logical(logical_index)
		if chunk == null:
			if reusable.is_empty():
				post_warm_creation_count += 1
				continue
			chunk = reusable.pop_back()
		var blueprint: CityChunkBlueprint = CityChunkBlueprint.generate(
			run_seed,
			logical_index
		)
		var previous_index: int = chunk.logical_index
		if previous_index != logical_index:
			chunk_reassigning.emit(chunk, previous_index, logical_index)
		chunk.configure(blueprint, runtime_x_for_logical_index(logical_index))
		if previous_index != logical_index:
			chunk_reassigned.emit(chunk, previous_index, logical_index, blueprint)
	_update_landmark_root()


func _update_landmark_root() -> void:
	if landmark_root == null:
		return
	var landmarks_resident: bool = (
		absi(current_logical_chunk) <= AHEAD_CHUNKS
		or absi(current_logical_chunk - 1) <= AHEAD_CHUNKS
	)
	landmark_root.visible = landmarks_resident
	landmark_root.process_mode = (
		Node.PROCESS_MODE_INHERIT if landmarks_resident else Node.PROCESS_MODE_DISABLED
	)
	landmark_root.position = (
		Vector2(-float(floating_origin.origin_chunk) * CHUNK_WIDTH, 0.0)
		if landmarks_resident
		else Vector2(-8192.0, -8192.0)
	)
