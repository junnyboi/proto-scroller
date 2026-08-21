class_name PlayerLaserWeapon
extends UpgradeRuntime

const RANGE: float = 1100.0
const PHYSICS_WIDTH: float = 10.0
const IMPULSE: float = 90.0
const QUERY_LIMIT: int = 32
const TARGET_MASK: int = (1 << 2) | (1 << 3) | (1 << 6)
const ACTOR_DAMAGE: Array[float] = [0.0, 18.0, 20.0, 22.0, 24.0, 26.0]
const STRUCTURAL_DAMAGE: Array[float] = [0.0, 12.0, 13.5, 15.0, 16.5, 18.0]
const COOLDOWNS: Array[float] = [0.0, 1.35, 1.25, 1.15, 1.05, 0.95]
const TARGET_COUNTS: Array[int] = [0, 3, 3, 4, 4, 5]
const BEAM_CAPACITY: int = 2

var arsenal: PlayerArsenalRuntime
var emitter: Node2D
var beams: Array[LaserBeamVisual2D] = []
var cooldown_remaining: float = 0.0
var shots_fired: int = 0
var last_query_count: int = 0
var last_accepted_count: int = 0
var _beam_cursor: int = 0
var _shape: RectangleShape2D = RectangleShape2D.new()
var _parameters: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()


func _init() -> void:
	setup(&"LASER", 5)
	_shape.size = Vector2(RANGE, PHYSICS_WIDTH)
	_parameters.shape = _shape
	_parameters.collision_mask = TARGET_MASK
	_parameters.collide_with_areas = true
	_parameters.collide_with_bodies = true
	for index: int in range(BEAM_CAPACITY):
		var beam: LaserBeamVisual2D = LaserBeamVisual2D.new()
		beam.name = "LaserBeam%02d" % index
		add_child(beam)
		beams.append(beam)


func setup_arsenal(p_arsenal: PlayerArsenalRuntime, p_emitter: Node2D) -> void:
	arsenal = p_arsenal
	emitter = p_emitter
	_parameters.exclude = [arsenal.robot.get_rid()]


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if stopped or paused or current_rank <= 0 or arsenal == null or emitter == null:
		return
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if cooldown_remaining > 0.0:
		return
	var target: EnemyActor2D = _nearest_target()
	if target == null:
		return
	_fire((target.global_position - emitter.global_position).normalized())


func apply_rank(total_rank: int, _context: Dictionary = {}) -> bool:
	var next_rank: int = clampi(total_rank, 0, runtime_max_rank)
	if current_rank == next_rank:
		return false
	current_rank = next_rank
	return true


func set_paused(value: bool) -> void:
	super.set_paused(value)
	for beam: LaserBeamVisual2D in beams:
		beam.paused = value


func stop_and_release() -> void:
	super.stop_and_release()
	for beam: LaserBeamVisual2D in beams:
		beam.deactivate()


func reset_run() -> void:
	super.reset_run()
	cooldown_remaining = 0.0
	shots_fired = 0
	last_query_count = 0
	last_accepted_count = 0
	_beam_cursor = 0
	for beam: LaserBeamVisual2D in beams:
		beam.paused = false
		beam.deactivate()


func active_beam_count() -> int:
	var total: int = 0
	for beam: LaserBeamVisual2D in beams:
		if beam.active:
			total += 1
	return total


func _nearest_target() -> EnemyActor2D:
	return arsenal.acquire_target(
		RANGE,
		0.0,
		PlayerArsenalRuntime.TargetClass.AIR,
		false
	)


func _fire(direction: Vector2) -> void:
	var origin: Vector2 = emitter.global_position
	_parameters.transform = Transform2D(
		direction.angle(),
		origin + direction * RANGE * 0.5
	)
	var space_state: PhysicsDirectSpaceState2D = (
		arsenal.robot.get_world_2d().direct_space_state
	)
	var results: Array[Dictionary] = space_state.intersect_shape(
		_parameters,
		QUERY_LIMIT
	)
	if results.size() > 1:
		results.sort_custom(_sort_result.bind(origin, direction))
	last_query_count = results.size()
	last_accepted_count = 0
	var seen_receivers: Dictionary[int, bool] = {}
	var attack_id: int = arsenal.reserve_attack_id()
	for result: Dictionary in results:
		var collider: Node = result.get("collider") as Node
		var receiver: Node = DamageReceiverLookup.find(collider)
		if receiver == null or receiver == arsenal.robot:
			continue
		var receiver_id: int = receiver.get_instance_id()
		if seen_receivers.has(receiver_id):
			continue
		seen_receivers[receiver_id] = true
		var event: DamageEvent = DamageEvent.new(
			attack_id,
			arsenal.robot,
			_damage_for(receiver),
			&"laser",
			(collider as Node2D).global_position,
			direction,
			IMPULSE,
			attack_id
		)
		if bool(receiver.call("receive_damage", event)):
			last_accepted_count += 1
		if last_accepted_count >= TARGET_COUNTS[current_rank]:
			break
	beams[_beam_cursor].activate(origin, direction, RANGE)
	_beam_cursor = (_beam_cursor + 1) % beams.size()
	shots_fired += 1
	cooldown_remaining = COOLDOWNS[current_rank]


func _damage_for(receiver: Node) -> float:
	if receiver is Destructible2D or receiver is StructuralBuilding2D:
		return STRUCTURAL_DAMAGE[current_rank]
	return ACTOR_DAMAGE[current_rank]


func _sort_result(a: Dictionary, b: Dictionary, origin: Vector2, direction: Vector2) -> bool:
	var a_node: Node2D = a.get("collider") as Node2D
	var b_node: Node2D = b.get("collider") as Node2D
	var a_projection: float = (a_node.global_position - origin).dot(direction)
	var b_projection: float = (b_node.global_position - origin).dot(direction)
	if not is_equal_approx(a_projection, b_projection):
		return a_projection < b_projection
	return a_node.get_instance_id() < b_node.get_instance_id()
