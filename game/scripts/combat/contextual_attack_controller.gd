class_name ContextualAttackController
extends Node

signal attack_started(spec: AttackSpec)
signal attack_active(spec: AttackSpec)
signal attack_finished(spec: AttackSpec)
signal dodge_buffered(attack_id: int)

enum Phase {
	READY,
	ANTICIPATION,
	ACTIVE,
	RECOVERY,
}

var current_spec: AttackSpec
var resolver: AttackResolver
var jab_cross_impact: JabCrossImpact
var overdrive_session: OverdriveSession
var directive_session: DirectiveSession
var kinetic_field_runtime: KineticFieldRuntime
var phase: Phase = Phase.READY
var buffered_dodge_count: int = 0
var _robot: GiantRobotController
var _visual_root: Node2D
var _rest_position: Vector2
var _rest_scale: Vector2 = Vector2.ONE
var _rest_rotation: float = 0.0
var _busy: bool = false
var _dodge_buffered: bool = false


func setup(robot: GiantRobotController) -> void:
	_robot = robot


func set_overdrive_session(session: OverdriveSession) -> void:
	overdrive_session = session


func set_directive_session(session: DirectiveSession) -> void:
	directive_session = session


func set_kinetic_field_runtime(runtime: KineticFieldRuntime) -> void:
	kinetic_field_runtime = runtime


func _ready() -> void:
	resolver = AttackResolver.new()
	resolver.name = "AttackResolver"
	add_child(resolver)
	jab_cross_impact = JabCrossImpact.new()
	jab_cross_impact.name = "JabCrossImpact"
	add_child(jab_cross_impact)
	if _robot != null:
		_robot.set_attack_controller(self)
		_robot.defeated.connect(cancel_attack)
		_visual_root = _robot.get_node_or_null(_robot.visual_root_path) as Node2D
		if _visual_root != null:
			_rest_position = _visual_root.position
			_rest_scale = _visual_root.scale
			_rest_rotation = _visual_root.rotation
		var presenter: RobotAnimationPresenter = (
			_robot.get_node_or_null(^"RobotAnimationPresenter") as RobotAnimationPresenter
		)
		if presenter != null:
			presenter.bind_attacks(self)


func request_attack() -> int:
	if _busy:
		if (
			phase == Phase.RECOVERY
			and not _dodge_buffered
			and _robot.can_request_attack()
			and _robot.dodge_ready
		):
			_dodge_buffered = true
			buffered_dodge_count += 1
			dodge_buffered.emit(current_spec.attack_id)
		return 0
	if _robot == null or not _robot.can_request_attack():
		return 0
	var attack_id: int = _robot.reserve_attack_id()
	var overdrive_started: bool = (
		overdrive_session.consume_ready_for_attack(attack_id)
		if overdrive_session != null
		else false
	)
	var speed_ratio: float = absf(_robot.velocity.x) / maxf(_robot.max_speed, 1.0)
	var force_multiplier: float = (
		overdrive_session.force_multiplier() if overdrive_session != null else 1.0
	)
	var structure_multiplier: float = (
		overdrive_session.structure_multiplier() if overdrive_session != null else 1.0
	)
	current_spec = resolver.resolve(
		attack_id,
		_robot.facing,
		speed_ratio,
		_robot.stomp_damage,
		_robot.stomp_impulse_per_mass,
		_robot.stomp_radius,
		force_multiplier,
		structure_multiplier,
		overdrive_started
	)
	if kinetic_field_runtime != null:
		current_spec = kinetic_field_runtime.decorate_attack(current_spec)
	if directive_session != null:
		current_spec = directive_session.decorate_attack(current_spec)
	_busy = true
	_dodge_buffered = false
	phase = Phase.ANTICIPATION
	_robot._set_attack_locked(true)
	_robot.notify_attack_selected(current_spec.mode, current_spec.attack_id)
	attack_started.emit(current_spec)
	_run_attack(current_spec)
	return attack_id


func is_busy() -> bool:
	return _busy


func cancel_attack() -> void:
	current_spec = null
	_busy = false
	_dodge_buffered = false
	phase = Phase.READY
	if _robot != null:
		_robot._set_attack_locked(false)
	_restore_pose()


func _run_attack(spec: AttackSpec) -> void:
	_apply_windup_pose(spec)
	if spec.anticipation_seconds > 0.0:
		await get_tree().create_timer(spec.anticipation_seconds).timeout
	if current_spec != spec:
		return
	phase = Phase.ACTIVE
	_apply_active_pose(spec)
	if spec.is_ground_smash():
		_robot.velocity.x = 0.0
		_robot.execute_ground_smash(spec.attack_id)
	else:
		_robot.velocity.x = 0.0
		jab_cross_impact.resolve(spec, _robot)
	if directive_session != null:
		directive_session.attack_active(spec)
	_robot.notify_attack_committed(spec.mode, spec.attack_id)
	attack_active.emit(spec)
	if spec.active_seconds > 0.0:
		await get_tree().create_timer(spec.active_seconds).timeout
	if current_spec != spec:
		return
	phase = Phase.RECOVERY
	_apply_recovery_pose(spec)
	if spec.recovery_seconds > 0.0:
		await get_tree().create_timer(spec.recovery_seconds).timeout
	if current_spec != spec:
		return
	_restore_pose()
	current_spec = null
	_busy = false
	phase = Phase.READY
	_robot._set_attack_locked(false)
	attack_finished.emit(spec)
	if _dodge_buffered:
		_dodge_buffered = false
		_robot._start_dodge()

func _apply_windup_pose(spec: AttackSpec) -> void:
	if _visual_root == null:
		return
	var facing_scale: float = _visual_scale_x(spec.facing)
	_visual_root.position = _rest_position + Vector2(-5.0 * float(spec.facing), 5.0)
	_visual_root.scale = Vector2(facing_scale * 0.98, _rest_scale.y * 0.94)
	_visual_root.rotation = 0.045 * float(spec.facing) if spec.is_jab_cross() else 0.0


func _apply_active_pose(spec: AttackSpec) -> void:
	if _visual_root == null:
		return
	var facing_scale: float = _visual_scale_x(spec.facing)
	if spec.is_jab_cross():
		_visual_root.position = _rest_position + Vector2(16.0 * float(spec.facing), 9.0)
		_visual_root.scale = Vector2(facing_scale * 1.05, _rest_scale.y * 0.90)
		_visual_root.rotation = 0.095 * float(spec.facing)
	else:
		_visual_root.position = _rest_position + Vector2(0.0, 8.0)
		_visual_root.scale = Vector2(facing_scale * 1.04, _rest_scale.y * 0.88)
		_visual_root.rotation = 0.0


func _apply_recovery_pose(spec: AttackSpec) -> void:
	if _visual_root == null:
		return
	var facing_scale: float = _visual_scale_x(_robot.facing)
	_visual_root.position = _rest_position + Vector2(4.0 * float(spec.facing), 3.0)
	_visual_root.scale = Vector2(facing_scale, _rest_scale.y * 0.97)
	_visual_root.rotation = 0.025 * float(spec.facing)


func _restore_pose() -> void:
	if _visual_root == null:
		return
	_visual_root.position = _rest_position
	_visual_root.scale = Vector2(
		_visual_scale_x(_robot.facing),
		_rest_scale.y
	)
	_visual_root.rotation = _rest_rotation


func _visual_scale_x(facing: int) -> float:
	var baked_facing: bool = bool(
		_visual_root.get_meta(&"baked_directional_art", false)
	)
	return absf(_rest_scale.x) * (1.0 if baked_facing else float(facing))
