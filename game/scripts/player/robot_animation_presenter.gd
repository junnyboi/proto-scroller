class_name RobotAnimationPresenter
extends Node

const ATTACK_EVENT_FRAME: int = 11
const WALK_REFERENCE_SPEED: float = 260.0

var robot: GiantRobotController
var sprite: AnimatedSprite2D
var attacking: bool = false
var selected_attack_id: int = 0


func setup(p_robot: GiantRobotController, p_sprite: AnimatedSprite2D) -> void:
	robot = p_robot
	sprite = p_sprite
	robot.facing_changed.connect(_on_facing_changed)
	robot.locomotion_changed.connect(_on_locomotion_changed)
	robot.attack_mode_selected.connect(_on_attack_selected)
	robot.attack_committed.connect(_on_attack_committed)
	_show_idle()


func bind_attacks(controller: ContextualAttackController) -> void:
	controller.attack_finished.connect(_on_attack_finished)


func _process(_delta: float) -> void:
	if robot == null or sprite == null or attacking:
		return
	if robot.locomotion_state == GiantRobotController.LocomotionState.WALK:
		sprite.speed_scale = clampf(
			absf(robot.velocity.x) / WALK_REFERENCE_SPEED,
			0.45,
			1.35
		)


func _on_facing_changed(_facing: int) -> void:
	_update_emitter_facing()
	if attacking:
		return
	if robot.locomotion_state == GiantRobotController.LocomotionState.WALK:
		_play_walk()
	else:
		_show_idle()


func _on_locomotion_changed(state: int) -> void:
	if attacking:
		return
	if state == GiantRobotController.LocomotionState.WALK:
		_play_walk()
	else:
		_show_idle()


func _on_attack_selected(mode: int, attack_id: int) -> void:
	attacking = true
	selected_attack_id = attack_id
	sprite.speed_scale = 1.0
	sprite.play(_attack_animation(mode), 1.0, true)


func _on_attack_committed(_mode: int, attack_id: int) -> void:
	if not attacking or attack_id != selected_attack_id:
		return
	sprite.pause()
	sprite.set_frame_and_progress(ATTACK_EVENT_FRAME, 0.0)


func _on_attack_finished(spec: AttackSpec) -> void:
	if spec == null or spec.attack_id != selected_attack_id:
		return
	attacking = false
	selected_attack_id = 0
	if robot.locomotion_state == GiantRobotController.LocomotionState.WALK:
		_play_walk()
	else:
		_show_idle()


func _play_walk() -> void:
	var animation: StringName = &"walk_e" if robot.facing >= 0 else &"walk_w"
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)


func _show_idle() -> void:
	if sprite == null or robot == null:
		return
	var animation: StringName = &"idle_s" if robot.facing >= 0 else &"idle_n"
	sprite.speed_scale = 1.0
	sprite.play(animation)
	sprite.pause()
	sprite.set_frame_and_progress(0, 0.0)


func _attack_animation(mode: int) -> StringName:
	if mode == AttackSpec.Mode.JAB_CROSS:
		return &"attack_e" if robot.facing >= 0 else &"attack_w"
	return &"attack_se" if robot.facing >= 0 else &"attack_sw"


func _update_emitter_facing() -> void:
	var emitter: Node2D = robot.get_node_or_null(^"VisualRoot/LaserEmitter") as Node2D
	if emitter != null:
		emitter.position.x = absf(emitter.position.x) * float(robot.facing)
