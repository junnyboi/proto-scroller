class_name CosmeticDebrisField2D
extends MultiMeshInstance2D

const CAPACITY: int = 64

var active: Array[bool] = []
var positions: Array[Vector2] = []
var velocities: Array[Vector2] = []
var rotations: Array[float] = []
var angular_velocities: Array[float] = []
var ages: Array[float] = []
var lifetimes: Array[float] = []
var priorities: Array[int] = []
var scales: Array[float] = []
var recycle_count: int = 0
var peak_active_count: int = 0
var paused: bool = false


func _ready() -> void:
	name = "CosmeticDebrisField2D"
	z_index = 65
	_build_multimesh()
	_resize_state()
	set_process(true)


func _process(delta: float) -> void:
	if paused:
		return
	var active_total: int = 0
	for index: int in range(CAPACITY):
		if not active[index]:
			continue
		ages[index] += delta
		if ages[index] >= lifetimes[index]:
			_deactivate(index)
			continue
		velocities[index] += Vector2(0.0, 560.0) * delta
		positions[index] += velocities[index] * delta
		rotations[index] += angular_velocities[index] * delta
		var fade: float = clampf(1.0 - ages[index] / lifetimes[index], 0.0, 1.0)
		var instance_transform: Transform2D = Transform2D(
			rotations[index],
			Vector2.ONE * scales[index],
			0.0,
			positions[index]
		)
		multimesh.set_instance_transform_2d(index, instance_transform)
		var color: Color = multimesh.get_instance_color(index)
		color.a = minf(fade * 2.5, 1.0)
		multimesh.set_instance_color(index, color)
		active_total += 1
	peak_active_count = maxi(peak_active_count, active_total)


func spawn_counterparts(event: GameplayEvent) -> int:
	if event == null or event.debris_units <= 0:
		return 0
	var count: int = mini(event.debris_units, CAPACITY)
	for unit_index: int in range(count):
		var slot: int = _acquire_slot(_priority(event.material_id))
		var seed_value: int = event.event_id * 1103515245 + unit_index * 12345
		var jitter: float = _noise(seed_value) * 2.0 - 1.0
		var angle: float = deg_to_rad(jitter * 14.0)
		var direction: Vector2 = event.presentation_direction.rotated(angle)
		var speed_scale: float = lerpf(0.70, 0.90, _noise(seed_value + 17))
		positions[slot] = event.world_position + direction * (8.0 + unit_index * 3.0)
		velocities[slot] = direction * event.presentation_speed * speed_scale
		velocities[slot].y -= 80.0 + 45.0 * _noise(seed_value + 31)
		rotations[slot] = angle
		angular_velocities[slot] = lerpf(-7.0, 7.0, _noise(seed_value + 47))
		ages[slot] = 0.0
		lifetimes[slot] = _lifetime(event.material_id)
		priorities[slot] = _priority(event.material_id)
		scales[slot] = lerpf(0.55, 0.80, _noise(seed_value + 61))
		active[slot] = true
		multimesh.set_instance_color(slot, _color(event.material_id))
	return count


func active_count() -> int:
	var total: int = 0
	for is_active: bool in active:
		if is_active:
			total += 1
	return total


func reset_field() -> void:
	for index: int in range(CAPACITY):
		_deactivate(index)
	recycle_count = 0
	peak_active_count = 0
	paused = false


func _build_multimesh() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(18.0, 11.0)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.instance_count = CAPACITY
	multimesh.mesh = quad
	for index: int in range(CAPACITY):
		multimesh.set_instance_transform_2d(index, Transform2D(0.0, Vector2.ZERO, 0.0,
			Vector2(-10000.0, -10000.0)))


func _resize_state() -> void:
	for values: Array in [
		active,
		positions,
		velocities,
		rotations,
		angular_velocities,
		ages,
		lifetimes,
		priorities,
		scales,
	]:
		values.resize(CAPACITY)
	for index: int in range(CAPACITY):
		active[index] = false
		positions[index] = Vector2.ZERO
		velocities[index] = Vector2.ZERO
		rotations[index] = 0.0
		angular_velocities[index] = 0.0
		ages[index] = 0.0
		lifetimes[index] = 1.0
		priorities[index] = 1
		scales[index] = 1.0


func _acquire_slot(incoming_priority: int) -> int:
	for index: int in range(CAPACITY):
		if not active[index]:
			return index
	var chosen: int = 0
	var lowest_priority: int = priorities[0]
	var oldest_age: float = ages[0]
	for index: int in range(1, CAPACITY):
		if priorities[index] < lowest_priority:
			chosen = index
			lowest_priority = priorities[index]
			oldest_age = ages[index]
		elif priorities[index] == lowest_priority and ages[index] > oldest_age:
			chosen = index
			oldest_age = ages[index]
	if incoming_priority < lowest_priority:
		chosen = 0
	recycle_count += 1
	return chosen


func _deactivate(index: int) -> void:
	active[index] = false
	multimesh.set_instance_transform_2d(index, Transform2D(0.0, Vector2.ZERO, 0.0,
		Vector2(-10000.0, -10000.0)))


func _priority(material_id: StringName) -> int:
	if material_id == &"steel" or material_id == &"scrap":
		return 3
	if material_id == &"concrete":
		return 2
	return 1


func _lifetime(material_id: StringName) -> float:
	if material_id == &"glass":
		return 0.75
	if material_id == &"steel" or material_id == &"scrap":
		return 1.15
	return 1.0


func _color(material_id: StringName) -> Color:
	if material_id == &"glass":
		return Color(0.58, 0.88, 0.96, 0.76)
	if material_id == &"steel" or material_id == &"scrap":
		return Color(0.42, 0.48, 0.51, 0.96)
	return Color(0.36, 0.32, 0.29, 0.96)


func _noise(value: int) -> float:
	var mixed: int = value
	mixed = (mixed ^ (mixed >> 16)) * 0x45D9F3B
	mixed = (mixed ^ (mixed >> 16)) * 0x45D9F3B
	mixed = mixed ^ (mixed >> 16)
	return float(abs(mixed % 10001)) / 10000.0
