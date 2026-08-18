class_name DirectiveSession
extends Node

signal offered(profile: DirectiveProfile)
signal choices_offered(profiles: Array[DirectiveProfile])
signal selected(profile: DirectiveProfile)
signal progress_changed(current: int, target: int)
signal completed(profile: DirectiveProfile, banked_score: int)
signal failed(profile: DirectiveProfile, penalty: int)
signal bank_changed(value: int)

const AFTERSHOCK_DELAY: float = 0.14
const AFTERSHOCK_RADIUS: float = 180.0
const AFTERSHOCK_DAMAGE: float = 72.0
const AFTERSHOCK_IMPULSE: float = 760.0
const SKYBREAKER_RADIUS: float = 280.0
const SKYBREAKER_BODY_CAP: int = 3

var dependencies: UrbanSiegeDependencies
var profiles: Array[DirectiveProfile] = []
var active_profile: DirectiveProfile
var selected_profile: DirectiveProfile
var remaining: float = 0.0
var progress: int = 0
var pending_score: int = 0
var offer_count: int = 0
var completion_count: int = 0
var failure_count: int = 0
var _seen_aftershocks: Dictionary[int, bool] = {}


func setup(
	p_dependencies: UrbanSiegeDependencies,
	p_profiles: Array[DirectiveProfile]
) -> void:
	dependencies = p_dependencies
	profiles = p_profiles
	dependencies.rampage_session.event_hub.event_published.connect(_on_event_published)
	dependencies.rampage_session.run_score.score_changed.connect(_on_score_changed)


func _process(delta: float) -> void:
	if active_profile == null:
		return
	remaining = maxf(remaining - delta, 0.0)
	if is_zero_approx(remaining):
		_fail_active()


func offer(run_seed: int) -> DirectiveProfile:
	if profiles.is_empty() or active_profile != null:
		return active_profile
	var index: int = posmod(run_seed + offer_count, profiles.size())
	offer_count += 1
	var ordered: Array[DirectiveProfile] = []
	for offset: int in range(profiles.size()):
		ordered.append(profiles[(index + offset) % profiles.size()])
	offered.emit(ordered[0])
	choices_offered.emit(ordered)
	return ordered[0]


func select(profile: DirectiveProfile) -> bool:
	if profile == null or active_profile != null:
		return false
	active_profile = profile
	selected_profile = profile
	remaining = profile.duration_seconds
	progress = 0
	pending_score = 0
	selected.emit(profile)
	progress_changed.emit(progress, profile.target_count)
	return true


func decorate_attack(spec: AttackSpec) -> AttackSpec:
	if spec == null or active_profile == null:
		return spec
	var structure_multiplier: float = 1.0
	if (
		active_profile.directive_id == &"DEMOLITION_BREACH"
		and spec.is_shoulder_drive()
	):
		structure_multiplier = active_profile.structural_multiplier
	return AttackSpec.new(
		spec.mode,
		spec.attack_id,
		spec.facing,
		spec.speed_ratio,
		spec.anticipation_seconds,
		spec.active_seconds,
		spec.recovery_seconds,
		spec.actor_damage,
		spec.structural_damage * structure_multiplier,
		spec.impulse_per_mass,
		spec.hit_size,
		spec.hit_offset,
		spec.opening_compression,
		active_profile.effect_flag
	)


func attack_active(spec: AttackSpec) -> void:
	if spec == null or active_profile == null:
		return
	if active_profile.directive_id == &"AFTERSHOCK_BREAKS":
		_queue_aftershock(spec)
	elif active_profile.directive_id == &"SKYBREAKER":
		_apply_skybreaker(spec)


func stop() -> void:
	active_profile = null
	selected_profile = null
	remaining = 0.0
	progress = 0
	pending_score = 0
	_seen_aftershocks.clear()
	bank_changed.emit(0)


func is_active() -> bool:
	return active_profile != null


func _queue_aftershock(spec: AttackSpec) -> void:
	if _seen_aftershocks.has(spec.attack_id):
		return
	_seen_aftershocks[spec.attack_id] = true
	_run_aftershock(spec)


func _run_aftershock(spec: AttackSpec) -> void:
	await get_tree().create_timer(AFTERSHOCK_DELAY).timeout
	if dependencies == null or dependencies.city.game_over_active:
		return
	var options: DamageQueryOptions = DamageQueryOptions.new()
	options.root_attack_id = spec.attack_id
	options.causal_depth = 1
	options.effect_flags = DamageEvent.FLAG_DIRECTIVE_AFTERSHOCK
	options.result_limit = 12
	options.structural_limit = 1
	options.debris_limit = 2
	options.damage_type = &"directive_aftershock"
	dependencies.destruction_director.queue_explosion(
		dependencies.robot.global_position + Vector2(0.0, 60.0),
		AFTERSHOCK_RADIUS,
		AFTERSHOCK_DAMAGE,
		AFTERSHOCK_IMPULSE,
		spec.attack_id,
		dependencies.robot,
		options
	)


func _apply_skybreaker(spec: AttackSpec) -> void:
	var redirected: int = 0
	var helicopter: HelicopterEnemy = _nearest_active_helicopter()
	for body: DebrisBody2D in dependencies.debris_pool.active_bodies():
		if redirected >= SKYBREAKER_BODY_CAP:
			break
		if body.global_position.distance_to(dependencies.robot.global_position) > SKYBREAKER_RADIUS:
			continue
		body.sleeping = false
		body.linear_velocity = Vector2(float(spec.facing) * 620.0, -980.0)
		body.angular_velocity = clampf(body.angular_velocity + 4.0, -12.0, 12.0)
		if helicopter != null:
			body.arm_aerial_impact(dependencies.robot, spec.attack_id, 28.0, helicopter)
		redirected += 1


func _nearest_active_helicopter() -> HelicopterEnemy:
	var nearest: HelicopterEnemy
	var nearest_distance: float = INF
	for helicopter: HelicopterEnemy in dependencies.encounter_runtime.helicopters:
		if not helicopter.active:
			continue
		var distance: float = helicopter.global_position.distance_to(
			dependencies.robot.global_position
		)
		if distance < nearest_distance:
			nearest = helicopter
			nearest_distance = distance
	return nearest


func _on_event_published(event: GameplayEvent) -> void:
	if active_profile == null or event == null:
		return
	var accepted: bool = false
	match active_profile.directive_id:
		&"DEMOLITION_BREACH":
			accepted = event.kind == GameplayEvent.Kind.CELL_DESTROYED
		&"AFTERSHOCK_BREAKS":
			accepted = (
				event.qualifies_for_combo
				and event.cause == &"directive_aftershock"
			)
		&"SKYBREAKER":
			accepted = event.kind == GameplayEvent.Kind.AIRBORNE_DEBRIS_HIT
	if not accepted:
		return
	progress += 1
	progress_changed.emit(progress, active_profile.target_count)
	if progress >= active_profile.target_count:
		_complete_active()


func _on_score_changed(_score: int, awarded: int) -> void:
	if active_profile == null or awarded <= 0:
		return
	pending_score += roundi(float(awarded) * active_profile.pending_bank_fraction)
	bank_changed.emit(pending_score)


func _complete_active() -> void:
	var profile: DirectiveProfile = active_profile
	var banked: int = pending_score
	completion_count += 1
	active_profile = null
	remaining = 0.0
	pending_score = 0
	completed.emit(profile, banked)
	bank_changed.emit(0)


func _fail_active() -> void:
	var profile: DirectiveProfile = active_profile
	var penalty: int = roundi(float(pending_score) * profile.failure_penalty_fraction)
	failure_count += 1
	active_profile = null
	remaining = 0.0
	pending_score = 0
	if penalty > 0:
		dependencies.rampage_session.run_score.deduct(penalty)
	failed.emit(profile, penalty)
	bank_changed.emit(0)
