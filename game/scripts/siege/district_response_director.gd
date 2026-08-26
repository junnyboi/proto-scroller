class_name DistrictResponseDirector
extends EncounterDirector

signal beat_changed(act_index: int, beat_index: int, beat_id: StringName)
signal act_completed(act_index: int, act_id: StringName, display_name: String)
signal recovery_started(duration: float)
signal milestone_reached(milestone: StringName)

const STATE_WAITING: int = 0
const STATE_PRESSURE: int = 1
const STATE_RECOVERY: int = 2
const MAX_PENDING_RECORDS: int = RuntimeBudget.PENDING_BEAT_RECORDS
const MAXIMUM_ACT_OVERRUN: float = 20.0
const LOW_THREAT_WEIGHT: int = 2
const RETALIATION_TRIGGER_SCALE: float = 0.75
const RETALIATION_MINIMUM_RECOVERY: float = 0.75
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
var progression_peak_tier: int = 0
var progression_copy_peak: int = 0
var progression_degradation_count: int = 0
var hazard_runtime: HazardRuntime
var hazard_pressure: HazardPressureController
var run_experience: RunExperience
var current_pressure_profile: DistrictPressureProfile
var peak_hazard_pending: int = 0
var progression_peak_threat: int = 0
var _elite_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _elite_seed: int = ELITE_SYSTEM_SALT
var _chaos_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _chaos_seed: int = CHAOS_SYSTEM_SALT
var _beat_reservation_id: int = 0
var _beat_pending: Array[Dictionary] = []
var _hazard_pending: Array[Dictionary] = []
var _act_completion_emitted: bool = false
var _act_advance_blocked: bool = false


func setup(p_runtime: EncounterRuntime, p_waves: Array[EnemyWave]) -> void:
	district = null
	super.setup(p_runtime, p_waves)


func setup_district(
	p_runtime: EncounterRuntime,
	p_district: DistrictDefinition,
	p_run_experience: RunExperience = null
) -> void:
	runtime = p_runtime
	district = p_district
	run_experience = p_run_experience
	configure_elite_affixes(0, 1)


func configure_hazards(
	p_hazard_runtime: HazardRuntime,
	p_hazard_pressure: HazardPressureController
) -> void:
	hazard_runtime = p_hazard_runtime
	hazard_pressure = p_hazard_pressure


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
	if hazard_pressure != null:
		hazard_pressure.reset_sequence()
	elite_assignments.clear()
	elite_roll_count = 0
	progression_peak_tier = 0
	progression_copy_peak = 0
	progression_degradation_count = 0
	progression_peak_threat = 0
	peak_hazard_pending = 0
	_act_completion_emitted = false
	_act_advance_blocked = false
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
	_hazard_pending.clear()
	_act_completion_emitted = false
	_act_advance_blocked = false
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
			_process_hazard_pending(delta)
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


func hazard_pending_count() -> int:
	return _hazard_pending.size()


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


func hold_act_advance() -> void:
	_act_advance_blocked = true


func resume_act_advance() -> void:
	_act_advance_blocked = false


func current_act_progress() -> float:
	if district == null or phase_index < 0 or phase_index >= district.acts.size():
		return 0.0
	var act: DistrictAct = district.acts[phase_index]
	return clampf(act_elapsed / maxf(_scaled_target_duration(act), 1.0), 0.0, 1.0)


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
	_act_completion_emitted = false
	phase_changed.emit(phase_index, act.display_name)
	state = STATE_WAITING


func _try_start_next_beat() -> void:
	var act: DistrictAct = district.acts[phase_index]
	if beat_index >= act.beats.size() - 1:
		var target_duration: float = _scaled_target_duration(act)
		if act_elapsed < target_duration:
			return
		var overrun_expired: bool = act_elapsed >= target_duration + MAXIMUM_ACT_OVERRUN
		if _threat_weight() > LOW_THREAT_WEIGHT:
			if not overrun_expired:
				return
			runtime.release_all()
		if not _act_completion_emitted:
			_act_completion_emitted = true
			act_completed.emit(phase_index, act.act_id, act.display_name)
		if _act_advance_blocked:
			return
		if not act.milestone_after.is_empty():
			milestone_reached.emit(act.milestone_after)
		_advance_act()
		return
	var next_beat: DistrictBeat = act.beats[beat_index + 1]
	current_pressure_profile = _effective_pressure_profile()
	var beat_threat_ceiling: int = maxi(
		current_pressure_profile.live_threat_ceiling,
		_authored_threat(next_beat)
	)
	if _planned_threat(next_beat, {}) > beat_threat_ceiling:
		return
	var progression_tier: int = current_pressure_profile.district_index
	var progression_copies: Dictionary[int, int] = _progression_copy_plan(
		next_beat,
		current_pressure_profile
	)
	var counts: Dictionary[StringName, int] = ledger.counts_for_beat(next_beat)
	for entry_index: int in progression_copies:
		var extra_entry: EnemySpawnEntry = next_beat.spawns[entry_index]
		var extra_kind: StringName = StringName(extra_entry.kind)
		var key: StringName = EnemyArchetypeCatalog.reservation_key(extra_kind)
		counts[key] = int(counts.get(key, 0)) + int(progression_copies[entry_index])
	var reservation_id: int = ledger.reserve_counts(counts, runtime)
	if reservation_id == 0 and not progression_copies.is_empty():
		progression_degradation_count += 1
		progression_copies.clear()
		counts = ledger.counts_for_beat(next_beat)
		reservation_id = ledger.reserve_counts(counts, runtime)
	if reservation_id == 0:
		return
	progression_peak_tier = maxi(progression_peak_tier, progression_tier)
	progression_copy_peak = maxi(progression_copy_peak, _dictionary_total(progression_copies))
	progression_peak_threat = maxi(
		progression_peak_threat,
		_planned_threat(next_beat, progression_copies)
	)
	beat_index += 1
	_beat_reservation_id = reservation_id
	_beat_pending.clear()
	var elite_plan: Dictionary[int, StringName] = _roll_elite_plan(
		act,
		next_beat,
		current_pressure_profile
	)
	var pending_index: int = 0
	var cadence_scale: float = current_pressure_profile.cadence_scale
	for entry_index: int in range(next_beat.spawns.size()):
		var entry: EnemySpawnEntry = next_beat.spawns[entry_index]
		var kind: StringName = StringName(entry.kind)
		var spawn_count: int = (
			EnemyArchetypeCatalog.spawn_multiplier(kind)
			+ int(progression_copies.get(entry_index, 0))
		)
		for copy_index: int in range(spawn_count):
			if _beat_pending.size() >= MAX_PENDING_RECORDS:
				break
			var stagger: float = float(copy_index) * HUMAN_COPY_STAGGER * cadence_scale
			if act.chaos_enabled:
				stagger += float(pending_index) * act.spawn_stagger_seconds * cadence_scale
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
	_hazard_pending.clear()
	if hazard_pressure != null and hazard_runtime != null:
		var robot_x: float = runtime.robot.global_position.x if runtime.robot != null else 760.0
		_hazard_pending = hazard_pressure.plan_for_beat(
			phase_index,
			beat_index,
			act,
			next_beat,
			robot_x,
				current_pressure_profile
		)
		peak_hazard_pending = maxi(peak_hazard_pending, _hazard_pending.size())
	peak_pending_records = maxi(peak_pending_records, _beat_pending.size())
	var trigger_scale: float = _trigger_scale(act)
	pressure_remaining = next_beat.pressure_seconds * trigger_scale
	recovery_remaining = maxf(
		RETALIATION_MINIMUM_RECOVERY if _is_retaliation(act) else 1.0,
		next_beat.recovery_seconds
		* trigger_scale
		* current_pressure_profile.recovery_scale
	)
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


func _process_hazard_pending(delta: float) -> void:
	if hazard_runtime == null:
		_hazard_pending.clear()
		return
	for index: int in range(_hazard_pending.size() - 1, -1, -1):
		var record: Dictionary = _hazard_pending[index]
		record.remaining = maxf(float(record.remaining) - delta, 0.0)
		if not is_zero_approx(float(record.remaining)):
			continue
			var activated: EnvironmentalHazard2D = hazard_runtime.activate(
				StringName(record.hazard_id),
				record.position as Vector2,
				int(record.facing),
				bool(record.get("auto_trigger", true))
			)
			_hazard_pending.remove_at(index)
			if activated == null:
				continue


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
	return runtime.resolve_spawn_position(
		entry.position,
		StringName(resolved_anchor),
		entry.offset + extra_offset
	)


func rebase_cached_world_state(offset: Vector2) -> void:
	for record: Dictionary in _hazard_pending:
		record.position = (record.position as Vector2) + offset


func _roll_elite_plan(
	act: DistrictAct,
	beat: DistrictBeat,
	pressure_source: Variant = 0
) -> Dictionary[int, StringName]:
	var plan: Dictionary[int, StringName] = {}
	if not act.elite_allowed:
		return plan
	var eligible: Array[int] = []
	for entry_index: int in range(beat.spawns.size()):
		if beat.spawns[entry_index].trait_id.is_empty():
			eligible.append(entry_index)
	if eligible.is_empty():
		return plan
	var profile: DistrictPressureProfile = DistrictPressureCatalog.coerce_profile(
		pressure_source
	)
	var elite_count: int = mini(
		act.elite_units_per_beat + profile.elite_bonus,
		mini(eligible.size(), 3)
	)
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


func _progression_tier() -> int:
	return _effective_pressure_profile().district_index


func _is_retaliation(act: DistrictAct) -> bool:
	return act != null and act.act_id == &"RETALIATION"


func _trigger_scale(act: DistrictAct) -> float:
	return RETALIATION_TRIGGER_SCALE if _is_retaliation(act) else 1.0


func _scaled_target_duration(act: DistrictAct) -> float:
	return act.target_duration * _trigger_scale(act) if act != null else 0.0


func _progression_copy_plan(
	beat: DistrictBeat,
	pressure_source: Variant
) -> Dictionary[int, int]:
	var plan: Dictionary[int, int] = {}
	var profile: DistrictPressureProfile = DistrictPressureCatalog.coerce_profile(
		pressure_source
	)
	if beat == null or beat.spawns.is_empty() or profile.threat_allowance <= 0:
		return plan
	var available_threat: int = mini(
		profile.threat_allowance,
		profile.live_threat_ceiling - _threat_weight() - _planned_threat(beat, {})
	)
	if available_threat <= 0:
		return plan
	var start_index: int = wrapi(
		absi(runtime.world_stream.current_logical_chunk) + beat_index + 1,
		0,
		beat.spawns.size()
	)
	var candidates: Array[Dictionary] = []
	for offset: int in range(beat.spawns.size()):
		var entry_index: int = wrapi(start_index + offset, 0, beat.spawns.size())
		var entry: EnemySpawnEntry = beat.spawns[entry_index]
		candidates.append({
			"entry_index": entry_index,
			"cost": EnemyArchetypeCatalog.threat_cost(StringName(entry.kind)),
			"rotation": offset,
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.cost) == int(b.cost):
			return int(a.rotation) < int(b.rotation)
		return int(a.cost) < int(b.cost)
	)
	for candidate: Dictionary in candidates:
		var cost: int = int(candidate.cost)
		if cost <= 0 or cost > available_threat:
			continue
		plan[int(candidate.entry_index)] = 1
		available_threat -= cost
	return plan


func _effective_pressure_profile() -> DistrictPressureProfile:
	if runtime == null or runtime.world_stream == null:
		return DistrictPressureCatalog.profile_by_index(0)
	var player_level: int = run_experience.level if run_experience != null else 1
	return DistrictPressureCatalog.effective_profile(
		runtime.world_stream.current_district_id,
		player_level
	)


func _planned_threat(beat: DistrictBeat, extra_copies: Dictionary) -> int:
	var threat: int = _threat_weight()
	for entry_index: int in range(beat.spawns.size()):
		var entry: EnemySpawnEntry = beat.spawns[entry_index]
		var kind: StringName = StringName(entry.kind)
		var count: int = (
			EnemyArchetypeCatalog.spawn_multiplier(kind)
			+ int(extra_copies.get(entry_index, 0))
		)
		threat += EnemyArchetypeCatalog.threat_cost(kind) * count
	return threat


func _authored_threat(beat: DistrictBeat) -> int:
	var threat: int = 0
	for entry: EnemySpawnEntry in beat.spawns:
		var kind: StringName = StringName(entry.kind)
		threat += (
			EnemyArchetypeCatalog.threat_cost(kind)
			* EnemyArchetypeCatalog.spawn_multiplier(kind)
		)
	return threat


func _dictionary_total(values: Dictionary) -> int:
	var total: int = 0
	for value: int in values.values():
		total += value
	return total
