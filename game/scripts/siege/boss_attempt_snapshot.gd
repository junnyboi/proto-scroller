class_name BossAttemptSnapshot
extends RefCounted

var valid: bool = false
var structural_states: Array[Dictionary] = []
var boss_state: Dictionary = {}
var score_state: Dictionary = {}
var experience_state: Dictionary = {}
var event_history_state: Dictionary = {}
var recorder_state: Dictionary = {}
var reservation_state: Dictionary = {}
var gate_state: Dictionary = {}
var robot_state: Dictionary = {}


func capture(
	lease: ArenaLease,
	session: CommandBossSession,
	rampage: RampageSession,
	gate: BossGateMarker,
	robot: GiantRobotController,
	world_stream: CityWorldStream
) -> bool:
	if (
		lease == null
		or not lease.active
		or session == null
		or rampage == null
		or gate == null
		or robot == null
		or world_stream == null
	):
		return false
	structural_states = lease.capture_structural_state()
	if structural_states.size() != CityWorldStream.CHUNK_CAPACITY:
		return false
	boss_state = session.capture_attempt_state()
	score_state = rampage.run_score.capture_attempt_state()
	experience_state = rampage.run_experience.capture_attempt_state()
	event_history_state = rampage.event_hub.capture_attempt_state()
	recorder_state = rampage.causal_chain_tracker.capture_attempt_state()
	reservation_state = session.utility_pool.capture_reservation_state()
	gate_state = gate.capture_state()
	robot_state = {
		"logical_x": world_stream.logical_distance_x(robot.global_position.x),
		"y": robot.global_position.y,
		"health": robot.current_health,
		"maximum": robot.max_health,
		"facing": robot.facing,
	}
	valid = true
	return true


func restore(
	lease: ArenaLease,
	session: CommandBossSession,
	rampage: RampageSession,
	gate: BossGateMarker,
	robot: GiantRobotController,
	world_stream: CityWorldStream
) -> bool:
	if not valid or lease == null or not lease.active:
		return false
	session.restore_attempt_state(boss_state)
	if not lease.restore_structural_state(structural_states):
		return false
	rampage.run_score.restore_attempt_state(score_state)
	rampage.run_experience.restore_attempt_state(experience_state)
	rampage.event_hub.restore_attempt_state(event_history_state)
	rampage.causal_chain_tracker.restore_attempt_state(recorder_state)
	session.utility_pool.restore_reservation_state(reservation_state)
	var runtime_x: float = (
		float(robot_state.logical_x)
		- float(world_stream.floating_origin.origin_chunk) * CityWorldStream.CHUNK_WIDTH
	)
	robot.global_position = Vector2(runtime_x, float(robot_state.y))
	robot.velocity = Vector2.ZERO
	robot.max_health = float(robot_state.maximum)
	robot.current_health = float(robot_state.health)
	robot.facing = int(robot_state.facing)
	robot._seen_attacks.clear()
	robot.set_disabled(false)
	robot.set_control_enabled(true)
	robot.health_changed.emit(robot.current_health, robot.max_health)
	var gate_anchor: Vector2 = Vector2(
		world_stream.runtime_x_for_logical_index(gate.gate_chunk()) - 80.0,
		0.0
	)
	gate.restore_ownership(gate_state, gate_anchor)
	return true


func clear() -> void:
	valid = false
	structural_states.clear()
	boss_state.clear()
	score_state.clear()
	experience_state.clear()
	event_history_state.clear()
	recorder_state.clear()
	reservation_state.clear()
	gate_state.clear()
	robot_state.clear()
