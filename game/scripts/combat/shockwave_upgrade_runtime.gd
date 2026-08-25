class_name ShockwaveUpgradeRuntime
extends UpgradeRuntime

const CAPACITY: int = 10
const CAMERA_IMPULSE: float = 9.0
const DAMAGE_RADIUS: float = ShockwaveRing2D.END_RADIUS
const MAX_DAMAGE_RESULTS: int = 24
const TARGET_MASK: int = (1 << 2) | (1 << 6)
const DAMAGE_BY_RANK: Array[float] = [0.0, 35.0, 55.0, 75.0]
const IMPULSE_BY_RANK: Array[float] = [0.0, 320.0, 440.0, 560.0]

var rings: Array[ShockwaveRing2D] = []
var rampage_session: RampageSession
var robot: GiantRobotController
var camera_rig: CameraRig
var spawn_count: int = 0
var denial_count: int = 0
var last_damage_count: int = 0
var _damage_shape: CircleShape2D = CircleShape2D.new()
var _damage_parameters: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()


func _init() -> void:
	setup(&"SHOCKWAVE", 3)
	_damage_shape.radius = DAMAGE_RADIUS
	_damage_parameters.shape = _damage_shape
	_damage_parameters.collision_mask = TARGET_MASK
	_damage_parameters.collide_with_areas = true
	_damage_parameters.collide_with_bodies = true
	for index: int in range(CAPACITY):
		var ring: ShockwaveRing2D = ShockwaveRing2D.new()
		ring.name = "ShockwaveRing%02d" % index
		add_child(ring)
		rings.append(ring)


func setup_combat(
	attacks: ContextualAttackController,
	p_rampage_session: RampageSession,
	p_robot: GiantRobotController,
	p_camera_rig: CameraRig
) -> void:
	rampage_session = p_rampage_session
	robot = p_robot
	camera_rig = p_camera_rig
	if attacks != null:
		attacks.attack_active.connect(_on_attack_active)


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var next_rank: int = clampi(total_rank, 0, runtime_max_rank)
	if current_rank == next_rank:
		return false
	current_rank = next_rank
	return true


func set_paused(value: bool) -> void:
	super.set_paused(value)
	for ring: ShockwaveRing2D in rings:
		ring.paused = value


func stop_and_release() -> void:
	super.stop_and_release()
	for ring: ShockwaveRing2D in rings:
		ring.deactivate()


func reset_run() -> void:
	super.reset_run()
	spawn_count = 0
	denial_count = 0
	last_damage_count = 0
	for ring: ShockwaveRing2D in rings:
		ring.paused = false
		ring.deactivate()


func active_count() -> int:
	var total: int = 0
	for ring: ShockwaveRing2D in rings:
		if ring.active:
			total += 1
	return total


func snapshot() -> Dictionary:
	var data: Dictionary = super.snapshot()
	data.merge({
		"capacity": CAPACITY,
			"active": active_count(),
			"spawned": spawn_count,
			"denied": denial_count,
			"last_damage_count": last_damage_count,
	}, true)
	return data


func _on_attack_active(spec: AttackSpec) -> void:
	if stopped or current_rank <= 0 or spec == null or not spec.is_ground_smash():
		return
	var visual_ground: Node2D = robot.get_node_or_null(
		^"VisualRoot/VisualGroundOrigin"
	) as Node2D
	var origin: Vector2 = (
		visual_ground.global_position
		if visual_ground != null
		else robot.global_position + Vector2(0.0, 126.0)
	)
	var event: GameplayEvent = GameplayEvent.new(
		StringName("shockwave:%d" % spec.attack_id),
		spec.attack_id,
		GameplayEvent.Kind.GROUND_SMASH_SHOCKWAVE,
		GameplayEvent.SHOCKWAVE_CUE,
		0,
		0.0,
		false,
		origin,
		&""
	)
	event.root_attack_id = spec.attack_id
	event.source_id = robot.get_instance_id()
	if not rampage_session.publish(event):
		return
	_resolve_damage(spec, origin)
	if camera_rig != null:
		camera_rig.add_impact_impulse(Vector2(0.0, -CAMERA_IMPULSE))
	for ring: ShockwaveRing2D in rings:
		if not ring.active:
			ring.activate(origin, float(current_rank))
			spawn_count += 1
			return
	denial_count += 1


func _resolve_damage(spec: AttackSpec, origin: Vector2) -> void:
	last_damage_count = 0
	_damage_parameters.transform = Transform2D(0.0, origin)
	_damage_parameters.exclude = [robot.get_rid()]
	var results: Array[Dictionary] = robot.get_world_2d().direct_space_state.intersect_shape(
		_damage_parameters,
		MAX_DAMAGE_RESULTS
	)
	if results.size() > 1:
		results.sort_custom(_sort_damage_result.bind(origin))
	var delivery_id: int = robot.reserve_attack_id()
	var seen: Dictionary[int, bool] = {}
	for result: Dictionary in results:
		var collider: Node2D = result.get("collider") as Node2D
		if collider == null or collider == robot or robot.is_ancestor_of(collider):
			continue
		var receiver: Node = DamageReceiverLookup.find(collider)
		if receiver == null or receiver == robot:
			continue
		var receiver_id: int = receiver.get_instance_id()
		if seen.has(receiver_id):
			continue
		seen[receiver_id] = true
		var direction: Vector2 = origin.direction_to(collider.global_position)
		if direction.is_zero_approx():
			direction = Vector2.UP
		var damage_event: DamageEvent = DamageEvent.new(
			delivery_id,
			robot,
			DAMAGE_BY_RANK[current_rank],
			&"ground_smash",
			collider.global_position,
			direction,
			IMPULSE_BY_RANK[current_rank],
			spec.attack_id,
			1
		)
		if bool(receiver.call("receive_damage", damage_event)):
			last_damage_count += 1


func _sort_damage_result(a: Dictionary, b: Dictionary, origin: Vector2) -> bool:
	var a_node: Node2D = a.get("collider") as Node2D
	var b_node: Node2D = b.get("collider") as Node2D
	var a_distance: float = origin.distance_squared_to(a_node.global_position)
	var b_distance: float = origin.distance_squared_to(b_node.global_position)
	if not is_equal_approx(a_distance, b_distance):
		return a_distance < b_distance
	return a_node.get_instance_id() < b_node.get_instance_id()
