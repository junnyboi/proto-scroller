class_name GravityCrucibleRuntime
extends UpgradeRuntime

const CAPACITY: int = 3
const CAPTURE_THRESHOLD_SECONDS: float = 0.35
const CAPTURE_CAPS: Array[int] = [0, 1, 2, 3]
const CAPTURE_RADII: Array[float] = [0.0, 190.0, 230.0, 270.0]
const ORBIT_RADII: Array[float] = [0.0, 96.0, 108.0, 120.0]
const THROW_SPEEDS: Array[float] = [0.0, 760.0, 850.0, 940.0]
const IMPACT_DAMAGE: Array[float] = [0.0, 12.0, 16.0, 20.0]
const ORBIT_HEIGHT: float = -34.0
const ORBIT_SPEED: float = 3.8

var robot: GiantRobotController
var attacks: ContextualAttackController
var debris_pool: DebrisPool
var remains_factory: EnemyRemainsFactory
var captured: Array[Node2D] = []
var captured_categories: PackedInt32Array = PackedInt32Array()
var _candidates: Array[Dictionary] = []
var _charging: bool = false
var _capture_started: bool = false
var _charge_attack_id: int = 0
var _orbit_time: float = 0.0
var capture_count_total: int = 0
var release_count_total: int = 0


func _init() -> void:
	setup(&"GRAVITY_CRUCIBLE", 3)
	captured.resize(CAPACITY)
	captured_categories.resize(CAPACITY)


func setup_combat(
	p_robot: GiantRobotController,
	p_attacks: ContextualAttackController,
	p_debris_pool: DebrisPool,
	p_remains_factory: EnemyRemainsFactory
) -> void:
	robot = p_robot
	attacks = p_attacks
	debris_pool = p_debris_pool
	remains_factory = p_remains_factory
	if attacks != null:
		if not attacks.charge_started.is_connected(_on_charge_started):
			attacks.charge_started.connect(_on_charge_started)
		if not attacks.charge_updated.is_connected(_on_charge_updated):
			attacks.charge_updated.connect(_on_charge_updated)
		if not attacks.charge_released.is_connected(_on_charge_released):
			attacks.charge_released.connect(_on_charge_released)
		if not attacks.attack_cancelled.is_connected(_on_attack_cancelled):
			attacks.attack_cancelled.connect(_on_attack_cancelled)


func is_available(_context: Dictionary = {}) -> bool:
	return (
		not stopped
		and robot != null
		and attacks != null
		and debris_pool != null
		and remains_factory != null
	)


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var changed: bool = super.apply_rank(total_rank)
	if current_rank <= 0:
		_cancel_capture()
	return changed


func set_paused(value: bool) -> void:
	super.set_paused(value)


func stop_and_release() -> void:
	_cancel_capture()
	super.stop_and_release()


func reset_run() -> void:
	_cancel_capture()
	super.reset_run()
	capture_count_total = 0
	release_count_total = 0


func captured_count() -> int:
	var count: int = 0
	for body: Node2D in captured:
		if body != null:
			count += 1
	return count


func snapshot() -> Dictionary:
	var data: Dictionary = super.snapshot()
	data.merge({
		"capacity": CAPACITY,
		"captured": captured_count(),
		"capture_total": capture_count_total,
		"release_total": release_count_total,
		"capture_started": _capture_started,
	}, true)
	return data


func _process(delta: float) -> void:
	if paused or stopped or not _capture_started or robot == null:
		return
	_orbit_time += maxf(delta, 0.0)
	_update_orbits()


func _on_charge_started(spec: AttackSpec) -> void:
	_cancel_capture()
	if stopped or current_rank <= 0 or spec == null:
		return
	_charging = true
	_charge_attack_id = spec.attack_id
	_orbit_time = 0.0


func _on_charge_updated(
	spec: AttackSpec,
	duration: float,
	_progress: float,
	_multiplier: float
) -> void:
	if (
		paused
		or stopped
		or current_rank <= 0
		or not _charging
		or spec == null
		or spec.attack_id != _charge_attack_id
		or _capture_started
		or duration < CAPTURE_THRESHOLD_SECONDS
	):
		return
	_capture_started = true
	_capture_candidates()
	_update_orbits()


func _on_charge_released(
	spec: AttackSpec,
	_duration: float,
	_multiplier: float
) -> void:
	if spec == null or spec.attack_id != _charge_attack_id:
		_cancel_capture()
		return
	if _capture_started:
		_release_capture(spec)
	else:
		_clear_runtime_state()


func _on_attack_cancelled(_spec: AttackSpec) -> void:
	_cancel_capture()


func _capture_candidates() -> void:
	if robot == null:
		return
	_candidates.clear()
	var radius_squared: float = CAPTURE_RADII[current_rank] * CAPTURE_RADII[current_rank]
	for index: int in range(debris_pool.active_count()):
		var debris: DebrisBody2D = debris_pool.active_body_at(index)
		if debris == null or not debris.is_crucible_eligible():
			continue
		var distance_squared: float = robot.global_position.distance_squared_to(
			debris.global_position
		)
		if distance_squared <= radius_squared:
			_candidates.append({
				"body": debris,
				"distance": distance_squared,
				"category": 0,
				"id": debris.get_instance_id(),
			})
	for index: int in range(remains_factory.active_count()):
		var wreck: EnemyWreck2D = remains_factory.active_wreck_at(index)
		if wreck == null or not wreck.is_crucible_eligible():
			continue
		var distance_squared: float = robot.global_position.distance_squared_to(
			wreck.global_position
		)
		if distance_squared <= radius_squared:
			_candidates.append({
				"body": wreck,
				"distance": distance_squared,
				"category": 1,
				"id": wreck.get_instance_id(),
			})
	_candidates.sort_custom(_candidate_before)
	var slot_index: int = 0
	for candidate: Dictionary in _candidates:
		if slot_index >= CAPTURE_CAPS[current_rank]:
			break
		var body: Node2D = candidate.body as Node2D
		if not _begin_body_capture(body):
			continue
		captured[slot_index] = body
		captured_categories[slot_index] = int(candidate.category)
		capture_count_total += 1
		slot_index += 1
	_candidates.clear()


func _update_orbits() -> void:
	var count: int = captured_count()
	if count <= 0:
		return
	var valid_index: int = 0
	for slot_index: int in range(CAPACITY):
		var body: Node2D = captured[slot_index]
		if body == null:
			continue
		if not _is_body_captured(body):
			_cancel_capture()
			return
		var angle: float = (
			_orbit_time * ORBIT_SPEED
			+ TAU * float(valid_index) / float(count)
		)
		var horizontal: float = cos(angle) * ORBIT_RADII[current_rank]
		var vertical: float = sin(angle) * ORBIT_RADII[current_rank] * 0.42
		var orbit_position: Vector2 = robot.global_position + Vector2(
			horizontal,
			ORBIT_HEIGHT + vertical
		)
		body.call(&"update_crucible_capture", orbit_position, angle)
		valid_index += 1


func _release_capture(spec: AttackSpec) -> void:
	var direction: Vector2 = Vector2(float(spec.facing), -0.12).normalized()
	var source_event: DamageEvent = DamageEvent.new(
		spec.attack_id,
		robot,
		0.0,
		&"debris_impact",
		robot.global_position,
		direction,
		THROW_SPEEDS[current_rank],
		spec.attack_id,
		0,
		spec.effect_flags | DamageEvent.FLAG_GRAVITY_CRUCIBLE,
		spec.kinetic_debris_bonus
	)
	var release_index: int = 0
	var release_total: int = captured_count()
	for slot_index: int in range(CAPACITY):
		var body: Node2D = captured[slot_index]
		if body == null:
			continue
		var lane_offset: float = (
			float(release_index) - float(release_total - 1) * 0.5
		) * 52.0
		var launch_velocity: Vector2 = direction * THROW_SPEEDS[current_rank]
		launch_velocity.y += lane_offset
		var delivery_id: int = 3_000_000 + spec.attack_id * 10 + release_index + 1
		if bool(body.call(
			&"release_from_crucible",
			launch_velocity,
			float(spec.facing) * (4.0 + float(release_index)),
			source_event,
			IMPACT_DAMAGE[current_rank],
			delivery_id
		)):
			release_count_total += 1
		release_index += 1
	_clear_runtime_state()


func _cancel_capture() -> void:
	for slot_index: int in range(CAPACITY):
		var body: Node2D = captured[slot_index]
		if body != null and is_instance_valid(body):
			body.call(&"cancel_crucible_capture")
	_clear_runtime_state()


func _clear_runtime_state() -> void:
	for index: int in range(CAPACITY):
		captured[index] = null
		captured_categories[index] = 0
	_candidates.clear()
	_charging = false
	_capture_started = false
	_charge_attack_id = 0
	_orbit_time = 0.0


func _begin_body_capture(body: Node2D) -> bool:
	return body != null and bool(body.call(&"begin_crucible_capture"))


func _is_body_captured(body: Node2D) -> bool:
	return body != null and bool(body.call(&"is_crucible_captured"))


func _candidate_before(first: Dictionary, second: Dictionary) -> bool:
	var first_distance: float = float(first.distance)
	var second_distance: float = float(second.distance)
	if not is_equal_approx(first_distance, second_distance):
		return first_distance < second_distance
	var first_category: int = int(first.category)
	var second_category: int = int(second.category)
	if first_category != second_category:
		return first_category < second_category
	return int(first.id) < int(second.id)
