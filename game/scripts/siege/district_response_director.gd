class_name DistrictResponseDirector
extends EncounterDirector

signal beat_changed(act_index: int, beat_index: int, beat_id: StringName)
signal recovery_started(duration: float)
signal milestone_reached(milestone: StringName)

const STATE_WAITING: int = 0
const STATE_PRESSURE: int = 1
const STATE_RECOVERY: int = 2
const MAX_PENDING_RECORDS: int = RuntimeBudget.PENDING_BEAT_RECORDS
const MAXIMUM_ACT_OVERRUN: float = 20.0
const LOW_THREAT_WEIGHT: int = 2
const ELITE_SYSTEM_SALT: int = 0x0E11E77
const CHAOS_SYSTEM_SALT: int = 0x0C4A05
const ELITE_AFFIXES: Array[StringName] = EnemyArchetypeCatalog.RANDOM_AFFIXES
const HUMAN_COPY_STAGGER: float = 0.14
const HUMAN_COPY_SPACING: float = 64.0

var district: DistrictDefinition
var ledger: CapacityReservationLedger = CapacityReservationLedger.new()
var beat_index: int = -1
var state: int = STATE_WAITING
var pressure_remaining: float = 0.0
var recovery_remaining: float = 0.0
var elapsed: float = 0.0
var act_elapsed: float = 0.0
var peak_pending_records: int = 0
var elite_assignments: Array[Dictionary] = []
var elite_roll_count: int = 0
var _elite_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _elite_seed: int = ELITE_SYSTEM_SALT
var _chaos_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _chaos_seed: int = CHAOS_SYSTEM_SALT
var _beat_reservation_id: int = 0
var _beat_pending: Array[Dictionary] = []


func setup(p_runtime: EncounterRuntime, p_waves: Array[EnemyWave]) -> void:
	district = null
	super.setup(p_runtime, p_waves)


func setup_district(p_runtime: EncounterRuntime, p_district: DistrictDefinition) -> void:
	runtime = p_runtime
	district = p_district
	configure_elite_affixes(0, 1)


func configure_elite_affixes(run_seed: int, cycle: int) -> void:
	_elite_seed = run_seed ^ ELITE_SYSTEM_SALT ^ maxi(cycle, 1) * 7919
	_chaos_seed = run_seed ^ CHAOS_SYSTEM_SALT ^ maxi(cycle, 1) * 3571
	_elite_rng.seed = _elite_seed
	_chaos_rng.seed = _chaos_seed
	elite_assignments.clear()
	elite_roll_count = 0


func start() -> void:
	if district == null:
		super.start()
		return
	stop()
	completed = false
	running = true
	phase_index = -1
	beat_index = -1
	elapsed = 0.0
	act_elapsed = 0.0
	_elite_rng.seed = _elite_seed
	_chaos_rng.seed = _chaos_seed
	elite_assignments.clear()
	elite_roll_count = 0
	_advance_act()


func stop() -> void:
	if district == null:
		super.stop()
		return
	running = false
	state = STATE_WAITING
	pressure_remaining = 0.0
	recovery_remaining = 0.0
	_beat_pending.clear()
	if _beat_reservation_id != 0:
		ledger.cancel(_beat_reservation_id)
	_beat_reservation_id = 0
	ledger.cancel_all()
	if runtime != null:
		runtime.set_attack_gate(true)


func reset_to_contact() -> void:
	stop()
	if runtime != null:
		runtime.release_all()
	start()


func _process(delta: float) -> void:
	if district == null:
		_process_legacy(delta)
		return
	advance(delta)


func advance(delta: float) -> void:
	if not running or completed or runtime == null or district == null:
		return
	elapsed += delta
	act_elapsed += delta
	match state:
		STATE_WAITING:
			_try_start_next_beat()
		STATE_PRESSURE:
			_process_pending(delta)
			pressure_remaining = maxf(pressure_remaining - delta, 0.0)
			if is_zero_approx(pressure_remaining) and _beat_pending.is_empty():
				_start_recovery()
		STATE_RECOVERY:
			recovery_remaining = maxf(recovery_remaining - delta, 0.0)
			if is_zero_approx(recovery_remaining):
				runtime.set_attack_gate(true)
				state = STATE_WAITING


func current_phase_name() -> String:
	if district == null:
		return super.current_phase_name()
	if phase_index < 0 or phase_index >= district.acts.size():
		return ""
	return district.acts[phase_index].display_name


func pending_count() -> int:
	if district == null:
		return super.pending_count()
	return _beat_pending.size()


func current_beat_id() -> StringName:
	if district == null or phase_index < 0 or beat_index < 0:
		return &""
	var act: DistrictAct = district.acts[phase_index]
	if beat_index >= act.beats.size():
		return &""
	return act.beats[beat_index].beat_id


func phase_count() -> int:
	return district.acts.size() if district != null else waves.size()


func is_recovery_active() -> bool:
	return district != null and state == STATE_RECOVERY


func current_act_progress() -> float:
	if district == null or phase_index < 0 or phase_index >= district.acts.size():
		return 0.0
	return clampf(act_elapsed / maxf(district.acts[phase_index].target_duration, 1.0), 0.0, 1.0)


func _advance_act() -> void:
	phase_index += 1
	beat_index = -1
	if district == null or phase_index >= district.acts.size():
		completed = true
		running = false
		district_completed.emit()
		return
	var act: DistrictAct = district.acts[phase_index]
	act_elapsed = 0.0
	phase_changed.emit(phase_index, act.display_name)
	state = STATE_WAITING


func _try_start_next_beat() -> void:
	var act: DistrictAct = district.acts[phase_index]
	if beat_index >= act.beats.size() - 1:
		if act_elapsed < act.target_duration:
			return
		var overrun_expired: bool = act_elapsed >= act.target_duration + MAXIMUM_ACT_OVERRUN
		if _threat_weight() > LOW_THREAT_WEIGHT and not overrun_expired:
			return
		if not act.milestone_after.is_empty():
			milestone_reached.emit(act.milestone_after)
		_advance_act()
		return
	var next_beat: DistrictBeat = act.beats[beat_index + 1]
	var reservation_id: int = ledger.reserve_beat(next_beat, runtime)
	if reservation_id == 0:
		return
	beat_index += 1
	_beat_reservation_id = reservation_id
	_beat_pending.clear()
	var elite_plan: Dictionary[int, StringName] = _roll_elite_plan(act, next_beat)
	var pending_index: int = 0
	for entry_index: int in range(next_beat.spawns.size()):
		var entry: EnemySpawnEntry = next_beat.spawns[entry_index]
		var kind: StringName = StringName(entry.kind)
		for copy_index: int in range(EnemyArchetypeCatalog.spawn_multiplier(kind)):
			if _beat_pending.size() >= MAX_PENDING_RECORDS:
				break
			var stagger: float = float(copy_index) * HUMAN_COPY_STAGGER
			if act.chaos_enabled:
				stagger += float(pending_index) * act.spawn_stagger_seconds
				stagger += _chaos_rng.randf_range(0.0, act.spawn_jitter_seconds)
			var spawn_anchor: String = entry.spawn_anchor
			if act.chaos_enabled and _chaos_rng.randf() < act.mirrored_flank_chance:
				spawn_anchor = _mirrored_anchor(spawn_anchor)
			var copy_direction: float = -1.0 if spawn_anchor in ["BEHIND", "CAMERA_LEFT"] else 1.0
			_beat_pending.append({
				"entry": entry,
				"remaining": maxf(entry.delay + stagger, 0.0),
				"trait_id": elite_plan.get(entry_index, entry.trait_id),
				"spawn_anchor": spawn_anchor,
				"offset": Vector2(copy_direction * float(copy_index) * HUMAN_COPY_SPACING, 0.0),
			})
			pending_index += 1
	peak_pending_records = maxi(peak_pending_records, _beat_pending.size())
	pressure_remaining = next_beat.pressure_seconds
	recovery_remaining = next_beat.recovery_seconds
	runtime.set_attack_gate(true)
	state = STATE_PRESSURE
	beat_changed.emit(phase_index, beat_index, next_beat.beat_id)


func _start_recovery() -> void:
	if _beat_reservation_id != 0:
		ledger.cancel(_beat_reservation_id)
	_beat_reservation_id = 0
	runtime.set_attack_gate(false)
	state = STATE_RECOVERY
	recovery_started.emit(recovery_remaining)


func _process_pending(delta: float) -> void:
	for index: int in range(_beat_pending.size() - 1, -1, -1):
		var record: Dictionary = _beat_pending[index]
		record.remaining = maxf(float(record.remaining) - delta, 0.0)
		if not is_zero_approx(float(record.remaining)):
			continue
		var entry: EnemySpawnEntry = record.entry
		var kind: StringName = StringName(entry.kind)
		if runtime.acquire(
			kind,
			_resolve_position(
				entry,
				String(record.spawn_anchor),
				record.offset as Vector2
			),
			entry.role_id,
			StringName(record.trait_id)
		) == null:
			continue
		ledger.consume_actor(_beat_reservation_id, kind)
		_beat_pending.remove_at(index)


func _process_legacy(delta: float) -> void:
	if not running or runtime == null or completed:
		return
	_process_legacy_pending(delta)
	if not _pending.is_empty() or runtime.active_count() > 0:
		return
	if _respite_remaining <= 0.0:
		_respite_remaining = waves[phase_index].minimum_respite
	_respite_remaining = maxf(_respite_remaining - delta, 0.0)
	if not is_zero_approx(_respite_remaining):
		return
	if phase_index >= waves.size() - 1:
		completed = true
		running = false
		district_completed.emit()
	else:
		_advance_phase()


func _process_legacy_pending(delta: float) -> void:
	for index: int in range(_pending.size() - 1, -1, -1):
		var record: Dictionary = _pending[index]
		record.remaining = maxf(float(record.remaining) - delta, 0.0)
		if not is_zero_approx(float(record.remaining)):
			continue
		var entry: EnemySpawnEntry = record.entry
		if runtime.acquire(StringName(entry.kind), entry.position) != null:
			_pending.remove_at(index)


func _resolve_position(
	entry: EnemySpawnEntry,
	spawn_anchor: String = "",
	extra_offset: Vector2 = Vector2.ZERO
) -> Vector2:
	var resolved_anchor: String = entry.spawn_anchor if spawn_anchor.is_empty() else spawn_anchor
	if resolved_anchor == "WORLD":
		return entry.position + entry.offset + extra_offset
	var robot_x: float = runtime.robot.global_position.x if runtime.robot != null else 760.0
	var position_value: Vector2 = entry.position
	match resolved_anchor:
		"AHEAD":
			position_value.x = robot_x + 620.0
		"BEHIND":
			position_value.x = robot_x - 620.0
		"CAMERA_LEFT":
			position_value.x = robot_x - 720.0
		"CAMERA_RIGHT":
			position_value.x = robot_x + 720.0
	position_value += entry.offset + extra_offset
	position_value.x = clampf(position_value.x, 80.0, 2480.0)
	return position_value


func _roll_elite_plan(act: DistrictAct, beat: DistrictBeat) -> Dictionary[int, StringName]:
	var plan: Dictionary[int, StringName] = {}
	if not act.elite_allowed:
		return plan
	var eligible: Array[int] = []
	for entry_index: int in range(beat.spawns.size()):
		if beat.spawns[entry_index].trait_id.is_empty():
			eligible.append(entry_index)
	if eligible.is_empty():
		return plan
	var elite_count: int = mini(act.elite_units_per_beat, eligible.size())
	for elite_index: int in range(elite_count):
		var eligible_draw: int = _elite_rng.randi_range(0, eligible.size() - 1)
		var entry_index: int = eligible.pop_at(eligible_draw)
		var affix_limit: int = 2 if phase_index == 3 else ELITE_AFFIXES.size()
		var trait_id: StringName = ELITE_AFFIXES[_elite_rng.randi_range(0, affix_limit - 1)]
		elite_roll_count += 2
		plan[entry_index] = trait_id
		var entry: EnemySpawnEntry = beat.spawns[entry_index]
		elite_assignments.append({
			"act_index": phase_index,
			"beat_id": beat.beat_id,
			"entry_index": entry_index,
			"kind": StringName(entry.kind),
			"trait_id": trait_id,
		})
	return plan


func _mirrored_anchor(spawn_anchor: String) -> String:
	match spawn_anchor:
		"AHEAD":
			return "BEHIND"
		"BEHIND":
			return "AHEAD"
		"CAMERA_LEFT":
			return "CAMERA_RIGHT"
		"CAMERA_RIGHT":
			return "CAMERA_LEFT"
		_:
			return spawn_anchor


func _threat_weight() -> int:
	var weight: int = 0
	for actor: EnemyActor2D in runtime.all_actors():
		if not actor.active or actor.dead:
			continue
		var kind: StringName = &"soldier"
		if actor is ProceduralEnemy:
			kind = (actor as ProceduralEnemy).archetype_id
		elif actor is TankEnemy:
			kind = &"tank"
		elif actor is HelicopterEnemy:
			kind = &"helicopter"
		weight += EnemyArchetypeCatalog.threat_cost(kind)
	return weight
