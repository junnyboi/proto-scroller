class_name BossCampaignDirector
extends Node

signal gate_triggered(definition: BossEncounterDefinition, marker: BossGateMarker)
signal attempt_started(definition: BossEncounterDefinition)
signal attempt_retried(definition: BossEncounterDefinition)
signal boss_completed(definition: BossEncounterDefinition)

const GATE_APPROACH_FRACTION: float = 0.62
const GATE_INSET: float = 80.0

var siege: UrbanSiegeRuntime
var world_stream: CityWorldStream
var destructibles: StreamedDestructibleRuntime
var gates: Array[BossGateMarker] = []
var arena_lease: ArenaLease = ArenaLease.new()
var interlock: BossSiegeInterlock = BossSiegeInterlock.new()
var attempt_snapshot: BossAttemptSnapshot = BossAttemptSnapshot.new()
var active_definition: BossEncounterDefinition
var active_gate: BossGateMarker
var attempt_failed: bool = false
var _triggered_ids: Dictionary[StringName, bool] = {}
var _completed_ids: Dictionary[StringName, bool] = {}


func setup(p_siege: UrbanSiegeRuntime) -> void:
	siege = p_siege
	world_stream = siege.dependencies.city.world_stream
	destructibles = siege.dependencies.city.streamed_destructibles
	arena_lease.setup(world_stream, destructibles)
	interlock.setup(siege)
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		var marker: BossGateMarker = BossGateMarker.new()
		marker.configure(definition)
		add_child(marker)
		gates.append(marker)
	siege.boss_session.completed.connect(_on_boss_completed)
	siege.boss_session.state_changed.connect(_refresh_hud)
	siege.boss_session.armor_changed.connect(_on_boss_durability_changed)
	siege.boss_session.body_changed.connect(_on_boss_durability_changed)
	siege.boss_session.utility_pool.vertical_slice.attack_changed.connect(_on_slice_feedback_changed)
	siege.boss_session.utility_pool.vertical_slice.archive_revealed.connect(_on_slice_feedback_changed)
	siege.boss_session.utility_pool.vertical_slice.rescue_tally_changed.connect(
		_on_slice_feedback_changed
	)


func _process(_delta: float) -> void:
	advance()


func advance() -> void:
	if siege == null or not siege.run_active or active_definition != null:
		return
	if siege.is_simulation_paused() or siege.boss_session.active():
		return
	var logical_distance: float = world_stream.logical_distance_x(
		siege.dependencies.robot.global_position.x
	)
	for definition: BossEncounterDefinition in BossCampaignCatalog.definitions():
		if _triggered_ids.has(definition.boss_id) or _completed_ids.has(definition.boss_id):
			continue
		var threshold: float = (
			float(definition.trigger_chunk) + GATE_APPROACH_FRACTION
		) * CityWorldStream.CHUNK_WIDTH
		if logical_distance >= threshold:
			_begin_attempt(definition)
		break


func reset_run() -> void:
	stop()
	_triggered_ids.clear()
	_completed_ids.clear()
	for gate: BossGateMarker in gates:
		gate.reset_gate()


func stop() -> void:
	if siege != null and siege.boss_session != null:
		siege.boss_session.stop()
	if active_gate != null:
		active_gate.release()
	arena_lease.release()
	interlock.discard()
	attempt_snapshot.clear()
	active_definition = null
	active_gate = null
	attempt_failed = false
	if siege != null and siege.dependencies.gameplay_hud != null:
		siege.dependencies.gameplay_hud.hide_boss_status()


func owns_combat() -> bool:
	return active_definition != null and active_gate != null and active_gate.owned


func fail_attempt() -> bool:
	if not owns_combat() or attempt_failed:
		return false
	if not attempt_snapshot.capture_boss_runtime(siege.boss_session):
		return false
	attempt_failed = true
	siege.boss_session.stop()
	interlock.clear_competing_combat()
	return true


func retry_attempt() -> bool:
	if not owns_combat() or not attempt_failed or not attempt_snapshot.valid:
		return false
	var definition: BossEncounterDefinition = active_definition
	if not attempt_snapshot.restore(
		arena_lease,
		siege.boss_session,
		siege.dependencies.rampage_session,
		active_gate,
		siege.dependencies.robot,
		world_stream
	):
		return false
	if not arena_lease.restore_structural_state(attempt_snapshot.structural_states):
		return false
	interlock.clear_competing_combat()
	attempt_failed = false
	var city: CitySlice = siege.dependencies.city
	city.game_over_active = false
	city.mobile_controls.set_controls_enabled(true)
	city.gameplay_hud.hide_terminal_overlay()
	if not siege.boss_session.start_definition(definition):
		attempt_failed = true
		return false
	attempt_retried.emit(definition)
	attempt_started.emit(definition)
	return true


func gate_for_trigger(trigger_chunk: int) -> BossGateMarker:
	for gate: BossGateMarker in gates:
		if gate.definition.trigger_chunk == trigger_chunk:
			return gate
	return null


func completed_count() -> int:
	return _completed_ids.size()


func _begin_attempt(definition: BossEncounterDefinition) -> bool:
	var gate: BossGateMarker = gate_for_trigger(definition.trigger_chunk)
	if gate == null or not arena_lease.acquire(definition):
		return false
	var gate_anchor: Vector2 = Vector2(
		world_stream.runtime_x_for_logical_index(gate.gate_chunk()) - GATE_INSET,
		0.0
	)
	if not gate.acquire(gate_anchor):
		arena_lease.release()
		return false
	active_definition = definition
	active_gate = gate
	_triggered_ids[definition.boss_id] = true
	if not interlock.acquire():
		_rollback_attempt_start()
		return false
	if not attempt_snapshot.capture(
		arena_lease,
		siege.boss_session,
		siege.dependencies.rampage_session,
		gate,
		siege.dependencies.robot,
		world_stream
	):
		_rollback_attempt_start()
		return false
	if not siege.boss_session.start_definition(definition):
		_rollback_attempt_start()
		return false
	_refresh_hud()
	gate_triggered.emit(definition, gate)
	attempt_started.emit(definition)
	return true


func _rollback_attempt_start() -> void:
	_triggered_ids.erase(active_definition.boss_id if active_definition != null else &"")
	attempt_snapshot.clear()
	interlock.discard()
	arena_lease.release()
	if active_gate != null:
		active_gate.release()
	active_definition = null
	active_gate = null


func _on_boss_completed(_elapsed_seconds: float) -> void:
	if not owns_combat():
		return
	var completed_definition: BossEncounterDefinition = active_definition
	var choir: ProjectChoirRuntime = siege.dependencies.city.project_choir_runtime
	if choir != null and not choir.commit_boss_completion(
		completed_definition,
		siege.boss_session.completion_payload()
	):
		return
	_completed_ids[completed_definition.boss_id] = true
	active_gate.consume()
	arena_lease.release()
	interlock.resume_after_success()
	attempt_snapshot.clear()
	active_definition = null
	active_gate = null
	attempt_failed = false
	siege.dependencies.gameplay_hud.hide_boss_status()
	boss_completed.emit(completed_definition)


func _refresh_hud(_state: StringName = &"") -> void:
	if active_definition == null:
		return
	var session: CommandBossSession = siege.boss_session
	var armor: float = session.boss.boss_armor if session.boss != null else 0.0
	var armor_maximum: float = (
		session.boss.boss_max_armor if session.boss != null else active_definition.armor
	)
	var body: float = session.boss.current_health if session.boss != null else 0.0
	siege.dependencies.gameplay_hud.set_campaign_boss_status(
		active_definition,
		session.state,
		armor,
		armor_maximum,
		body,
		active_definition.health,
		active_definition.evidence_flag_id,
		session.live_boss_feedback()
	)


func _on_boss_durability_changed(_current: float, _maximum: float) -> void:
	_refresh_hud()


func _on_slice_feedback_changed(_first: Variant = null, _second: Variant = null) -> void:
	_refresh_hud()
