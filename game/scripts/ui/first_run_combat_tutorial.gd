class_name FirstRunCombatTutorial
extends Control

signal step_changed(step: int)
signal tutorial_completed(skipped: bool)

enum Step {
	MOVE,
	GROUND_SMASH,
	JAB_CROSS,
	RECOVERY_DODGE,
	COMPLETE,
}

const PREFERENCE_PATH: String = "user://combat_tutorial.cfg"
const PREFERENCE_SECTION: String = "combat_tutorial"
const PREFERENCE_KEY: String = "completed"
const FORCE_ENV: String = "PROTO_SCROLLER_FORCE_TUTORIAL"
const STEP_COUNT: int = 4
const PANEL_COLOR: Color = Color(0.018, 0.042, 0.055, 0.94)
const BORDER_COLOR: Color = Color("5dc9c2")
const ACCENT_COLOR: Color = Color("7ef4df")
const MUTED_COLOR: Color = Color("b7c4cb")
const COMPLETE_COLOR: Color = Color("f1b36f")
const COMPLETE_HOLD_SECONDS: float = 1.6

var current_step: Step = Step.MOVE
var tutorial_active: bool = false
var completed: bool = false
var skipped: bool = false
var panel: Panel
var accent_line: ColorRect
var progress_label: Label
var title_label: Label
var body_label: Label
var skip_button: Button
var _robot: GiantRobotController
var _attacks: ContextualAttackController
var _mobile_controls: MobileControls
var _preference_path: String = PREFERENCE_PATH
var _persist_completion: bool = true
var _completion_generation: int = 0


func setup(
	robot: GiantRobotController,
	attacks: ContextualAttackController,
	mobile_controls: MobileControls = null,
	preference_path: String = PREFERENCE_PATH
) -> void:
	_robot = robot
	_attacks = attacks
	_mobile_controls = mobile_controls
	_preference_path = preference_path
	_bind_mechanic_signals()
	if is_node_ready():
		_start_if_needed()


func _ready() -> void:
	name = "FirstRunCombatTutorial"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 12
	_build_card()
	get_viewport().size_changed.connect(_apply_viewport_layout)
	_apply_viewport_layout()
	L10n.apply_locale_font(self)
	_start_if_needed()


func start_for_test() -> void:
	_persist_completion = false
	_start_tutorial()


func observe_locomotion(state: int) -> void:
	if not tutorial_active or current_step != Step.MOVE:
		return
	if state == GiantRobotController.LocomotionState.WALK:
		_advance_to(Step.GROUND_SMASH)


func observe_attack_committed(mode: int, _attack_id: int) -> void:
	if not tutorial_active:
		return
	if current_step == Step.GROUND_SMASH and mode == AttackSpec.Mode.GROUND_SMASH:
		_advance_to(Step.JAB_CROSS)
	elif current_step == Step.JAB_CROSS and mode == AttackSpec.Mode.JAB_CROSS:
		_advance_to(Step.RECOVERY_DODGE)


func observe_dodge_started(_facing: int, _duration: float) -> void:
	if tutorial_active and current_step == Step.RECOVERY_DODGE:
		_finish_tutorial(false)


func observe_dodge_buffered(_attack_id: int) -> void:
	if tutorial_active and current_step == Step.RECOVERY_DODGE:
		_finish_tutorial(false)


func apply_responsive_layout(viewport_size: Vector2) -> void:
	if panel == null:
		return
	var portrait: bool = viewport_size.y > viewport_size.x
	if portrait:
		panel.position = Vector2(18.0, 226.0)
		panel.size = Vector2(maxf(viewport_size.x - 36.0, 360.0), 190.0)
	else:
		panel.position = Vector2(36.0, 166.0)
		panel.size = Vector2(520.0, 170.0)
	accent_line.position = Vector2.ZERO
	accent_line.size = Vector2(5.0, panel.size.y)
	progress_label.position = Vector2(24.0, 16.0)
	progress_label.size = Vector2(panel.size.x - 152.0, 24.0)
	title_label.position = Vector2(24.0, 43.0)
	title_label.size = Vector2(panel.size.x - 48.0, 34.0)
	body_label.position = Vector2(24.0, 82.0)
	body_label.size = Vector2(panel.size.x - 48.0, panel.size.y - 96.0)
	skip_button.position = Vector2(panel.size.x - 124.0, 12.0)
	skip_button.size = Vector2(104.0, 38.0)
	progress_label.add_theme_font_size_override(&"font_size", 16 if portrait else 15)
	title_label.add_theme_font_size_override(&"font_size", 25 if portrait else 23)
	body_label.add_theme_font_size_override(&"font_size", 20 if portrait else 18)
	skip_button.add_theme_font_size_override(&"font_size", 16)


func _bind_mechanic_signals() -> void:
	if _robot != null:
		if not _robot.locomotion_changed.is_connected(observe_locomotion):
			_robot.locomotion_changed.connect(observe_locomotion)
		if not _robot.attack_committed.is_connected(observe_attack_committed):
			_robot.attack_committed.connect(observe_attack_committed)
		if not _robot.dodge_started.is_connected(observe_dodge_started):
			_robot.dodge_started.connect(observe_dodge_started)
	if _attacks != null and not _attacks.dodge_buffered.is_connected(observe_dodge_buffered):
		_attacks.dodge_buffered.connect(observe_dodge_buffered)


func _start_if_needed() -> void:
	if panel == null:
		return
	if OS.get_environment(FORCE_ENV) == "1" or not _completion_is_persisted():
		_start_tutorial()
	else:
		completed = true
		tutorial_active = false
		visible = false


func _start_tutorial() -> void:
	_completion_generation += 1
	current_step = Step.MOVE
	tutorial_active = true
	completed = false
	skipped = false
	visible = true
	_update_copy()
	step_changed.emit(current_step)


func _advance_to(next_step: Step) -> void:
	if not tutorial_active or next_step <= current_step or next_step >= Step.COMPLETE:
		return
	current_step = next_step
	_update_copy()
	step_changed.emit(current_step)


func _finish_tutorial(was_skipped: bool) -> void:
	if completed:
		return
	_completion_generation += 1
	var generation: int = _completion_generation
	current_step = Step.COMPLETE
	tutorial_active = false
	completed = true
	skipped = was_skipped
	if _persist_completion and not _save_completion():
		push_warning("Unable to persist combat tutorial completion: %s" % _preference_path)
	_update_copy()
	tutorial_completed.emit(skipped)
	_hold_completion_card(generation)


func _hold_completion_card(generation: int) -> void:
	await get_tree().create_timer(COMPLETE_HOLD_SECONDS).timeout
	if generation == _completion_generation and current_step == Step.COMPLETE:
		visible = false


func _update_copy() -> void:
	if progress_label == null:
		return
	var step_number: int = mini(int(current_step) + 1, STEP_COUNT)
	progress_label.text = L10n.t("tutorial.progress", {
		"current": "%02d" % step_number,
		"total": "%02d" % STEP_COUNT,
	})
	var key: String = ""
	match current_step:
		Step.MOVE:
			key = "move"
		Step.GROUND_SMASH:
			key = "ground_smash"
		Step.JAB_CROSS:
			key = "jab_cross"
		Step.RECOVERY_DODGE:
			key = "recovery_dodge"
		Step.COMPLETE:
			key = "complete"
	title_label.text = L10n.t("tutorial.%s.title" % key)
	body_label.text = L10n.t("tutorial.%s.body" % key)
	skip_button.text = L10n.t("tutorial.skip")
	skip_button.visible = current_step != Step.COMPLETE
	progress_label.modulate = COMPLETE_COLOR if current_step == Step.COMPLETE else ACCENT_COLOR
	title_label.modulate = COMPLETE_COLOR if current_step == Step.COMPLETE else Color.WHITE
	accent_line.color = COMPLETE_COLOR if current_step == Step.COMPLETE else BORDER_COLOR


func _build_card() -> void:
	panel = Panel.new()
	panel.name = "TutorialCard"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = PANEL_COLOR
	card_style.border_color = Color(0.36, 0.80, 0.76, 0.72)
	card_style.set_border_width_all(2)
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override(&"panel", card_style)
	add_child(panel)
	accent_line = ColorRect.new()
	accent_line.name = "AccentLine"
	accent_line.color = BORDER_COLOR
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent_line)
	progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.modulate = ACCENT_COLOR
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(progress_label)
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title_label)
	body_label = Label.new()
	body_label.name = "BodyLabel"
	body_label.modulate = MUTED_COLOR
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(body_label)
	skip_button = Button.new()
	skip_button.name = "SkipButton"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.pressed.connect(_finish_tutorial.bind(true))
	var button_style: StyleBoxFlat = StyleBoxFlat.new()
	button_style.bg_color = Color(0.05, 0.11, 0.14, 0.94)
	button_style.border_color = Color(0.36, 0.80, 0.76, 0.60)
	button_style.set_border_width_all(1)
	skip_button.add_theme_stylebox_override(&"normal", button_style)
	skip_button.add_theme_stylebox_override(&"hover", button_style)
	skip_button.add_theme_stylebox_override(&"pressed", button_style)
	panel.add_child(skip_button)


func _apply_viewport_layout() -> void:
	apply_responsive_layout(get_viewport().get_visible_rect().size)


func _completion_is_persisted() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(_preference_path) != OK:
		return false
	return bool(config.get_value(PREFERENCE_SECTION, PREFERENCE_KEY, false))


func _save_completion() -> bool:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(PREFERENCE_SECTION, PREFERENCE_KEY, true)
	return config.save(_preference_path) == OK
