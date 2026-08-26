# gdlint: disable=max-public-methods
class_name GameplayHud
extends CanvasLayer

signal retry_pressed
signal title_pressed
signal extract_pressed
signal continue_pressed
signal purge_pressed
signal disentangle_pressed

const PANEL_COLOR: Color = Color(0.03, 0.05, 0.08, 0.86)
const ACCENT_COLOR: Color = Color("f1b36f")
const MUTED_COLOR: Color = Color("b7c4cb")
const COMBO_GRACE_SECONDS: float = 3.0
const FIRST_RUN_TUTORIAL_SCRIPT: Script = preload(
	"res://scripts/ui/first_run_combat_tutorial.gd"
)
const TRANSMISSION_TOAST_SCRIPT: Script = preload(
	"res://scripts/ui/transmission_toast.gd"
)

var health_label: Label
var status_label: Label
var objective_label: Label
var score_label: Label
var pending_score_label: Label
var combo_label: Label
var combo_ring: ComboDecayRing
var momentum_fill: ColorRect
var momentum_label: Label
var experience_label: Label
var experience_track: ColorRect
var experience_fill: ColorRect
var siege_progress: SiegeProgressStrip
var directive_card: DirectiveCard
var directive_choice_overlay: DirectiveChoiceOverlay
var upgrade_choice_overlay: UpgradeChoiceOverlay
var weapon_status_strip: WeaponStatusStrip
var first_run_tutorial: FirstRunCombatTutorial
var transmission_toast: TransmissionToast
var boss_label: Label
var game_over_overlay: Control
var overlay_title: Label
var overlay_summary: Label
var new_game_plus_badge: TextureRect
var retry_button: Button
var title_button: Button
var extract_button: Button
var continue_button: Button
var purge_button: Button
var disentangle_button: Button
var rare_labels: Array[Label] = []
var status_panel: ColorRect
var momentum_panel: ColorRect
var momentum_track: ColorRect
var score_panel: ColorRect
var score_caption: Label
var terminal_panel: ColorRect
var _robot: GiantRobotController
var _contextual_attacks: ContextualAttackController
var _pulse_age: float = 0.0
var _overdrive_active: bool = false
var _momentum_fill_width: float = 392.0
var _experience_fill_width: float = 254.0
var _experience_ratio: float = 0.0
var _displayed_combo_multiplier: int = -1
var _displayed_overdrive_key: String = ""
var _displayed_overdrive_seconds: String = ""
var _campaign_dossier_count: int = 0
var _continuity_generation: int = 0


func setup(
	robot: GiantRobotController,
	contextual_attacks: ContextualAttackController = null
) -> void:
	_robot = robot
	_contextual_attacks = contextual_attacks


func _ready() -> void:
	name = "HUD"
	layer = 20
	_build_status_panel()
	_build_momentum_panel()
	_build_experience_bar()
	_build_score_panel()
	_build_siege_progress()
	_build_directive_card()
	_build_directive_choice_overlay()
	_build_upgrade_ui()
	_build_boss_status()
	_build_transmission_toast()
	_build_first_run_tutorial()
	_build_game_over_overlay()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	L10n.apply_locale_font(self)
	if _robot != null:
		_robot.attack_mode_selected.connect(_on_attack_mode_selected)
		_robot.attack_committed.connect(_on_attack_committed)
		set_health(_robot.current_health, _robot.max_health)
	set_score(0)
	set_combo(1, 0.0)
	set_momentum(0.0, 0)
	_set_experience(1, 0, RunExperience.required_for_level(1))


func _process(delta: float) -> void:
	_pulse_age += delta
	if status_label != null:
		status_label.modulate.a = 0.86 + sin(_pulse_age * 2.2) * 0.14


func set_health(current: float, maximum: float) -> void:
	if health_label == null:
		return
	health_label.text = L10n.t("hud.health", {
		"current": "%03d" % roundi(current),
		"maximum": "%03d" % roundi(maximum),
	})


func set_score(value: int) -> void:
	if score_label != null:
		score_label.text = "%08d" % maxi(value, 0)


func _displayed_score() -> int:
	return int(score_label.text) if score_label != null else 0


func set_pending_score(value: int) -> void:
	pending_score_label.text = (
		L10n.t("hud.pending_score", {"value": "%05d" % maxi(value, 0)})
		if value > 0
		else L10n.t("hud.safe")
	)
	pending_score_label.modulate = Color("ff9a61") if value > 0 else MUTED_COLOR


func _set_experience(level: int, current: int, required: int) -> void:
	_experience_ratio = (
		clampf(float(current) / float(required), 0.0, 1.0) if required > 0 else 1.0
	)
	if experience_label != null:
		experience_label.text = L10n.t("hud.experience", {
			"level": "%02d" % maxi(level, 1),
			"current": maxi(current, 0),
			"required": maxi(required, 0),
		})
	_apply_experience_fill()


func set_combo(multiplier: int, grace_remaining: float) -> void:
	if combo_label == null:
		return
	var clamped_multiplier: int = clampi(multiplier, 1, 5)
	if _displayed_combo_multiplier != clamped_multiplier:
		combo_label.text = L10n.t("hud.combo", {"multiplier": clamped_multiplier})
		_displayed_combo_multiplier = clamped_multiplier
	var should_show_combo: bool = clamped_multiplier > 1
	if combo_label.visible != should_show_combo:
		combo_label.visible = should_show_combo
	combo_label.modulate.a = clampf(grace_remaining / 0.55, 0.55, 1.0)
	if combo_ring != null:
		combo_ring.set_ratio(
			grace_remaining / COMBO_GRACE_SECONDS if multiplier > 1 else 0.0
		)


func set_momentum(value: float, band: int) -> void:
	var clamped_value: float = clampf(value, 0.0, 100.0)
	if momentum_fill != null:
		var next_width: float = _momentum_fill_width * clamped_value / 100.0
		if not is_equal_approx(momentum_fill.size.x, next_width):
			momentum_fill.size.x = next_width
		var next_color: Color = _momentum_color(band)
		if momentum_fill.color != next_color:
			momentum_fill.color = next_color
	if momentum_label != null:
		momentum_label.text = (
			(
				L10n.t("hud.overdrive_ready_portrait")
				if _is_portrait_layout()
				else L10n.t("hud.overdrive_ready_landscape")
			)
			if band == MomentumMeter.Band.READY
			else L10n.t("hud.momentum", {"percent": "%03d" % roundi(clamped_value)})
		)


func set_overdrive(active: bool, remaining: float) -> void:
	_overdrive_active = active
	if momentum_label != null and active:
		var key: String = (
			"hud.overdrive_portrait" if _is_portrait_layout() else "hud.overdrive_landscape"
		)
		var displayed_seconds: String = "%.1f" % maxf(remaining, 0.0)
		if key != _displayed_overdrive_key or displayed_seconds != _displayed_overdrive_seconds:
			momentum_label.text = L10n.t(key, {"seconds": displayed_seconds})
			_displayed_overdrive_key = key
			_displayed_overdrive_seconds = displayed_seconds
	elif not active:
		_displayed_overdrive_key = ""
		_displayed_overdrive_seconds = ""
	if momentum_fill != null and active:
		var next_width: float = _momentum_fill_width * clampf(remaining / 4.0, 0.0, 1.0)
		if not is_equal_approx(momentum_fill.size.x, next_width):
			momentum_fill.size.x = next_width
		var overdrive_color: Color = Color("ff8a42")
		if momentum_fill.color != overdrive_color:
			momentum_fill.color = overdrive_color


func set_rare_tags(tags: PackedStringArray) -> void:
	for index: int in range(rare_labels.size()):
		rare_labels[index].text = tags[index] if index < tags.size() else ""
		rare_labels[index].visible = index < tags.size()


func set_status(key: String, placeholders: Dictionary = {}) -> void:
	if status_label != null:
		status_label.text = L10n.t(key, placeholders)


func set_objective(key: String, placeholders: Dictionary = {}) -> void:
	if objective_label != null:
		objective_label.text = L10n.t(key, placeholders)


func set_district_clear_progress(
	_district_id: StringName,
	cleared_buildings: int,
	required_buildings: int
) -> void:
	set_objective("objective.district_clear", {
		"current": cleared_buildings,
		"total": required_buildings,
	})


func set_district_exit_unlocked(
	_district_id: StringName,
	_next_district_id: StringName
) -> void:
	set_objective("objective.district_unlocked")


func _set_campaign_summary(dossier_count: int, continuity_generation: int) -> void:
	_campaign_dossier_count = maxi(dossier_count, 0)
	_continuity_generation = maxi(continuity_generation, 0)


func set_siege_progress(
	index: int,
	total: int,
	display_name: String,
	recovery: bool
) -> void:
	if siege_progress != null:
		siege_progress.set_progress(index, total, display_name, recovery)


func show_directive(
	profile: DirectiveProfile,
	current: int,
	target: int,
	bank: int,
	session: DirectiveSession = null
) -> void:
	directive_card.show_directive(profile, current, target, bank, session)


func set_directive_progress(profile: DirectiveProfile, current: int, target: int) -> void:
	directive_card.set_progress(profile, current, target)


func set_directive_bank(points: int) -> void:
	directive_card.set_bank(points)


func set_boss_status(
	state: StringName,
	current: float = 0.0,
	maximum: float = 1.0,
	boss_id: StringName = &""
) -> void:
	if state == &"IDLE" or state == &"COMPLETE":
		hide_boss_status()
		return
	boss_label.visible = true
	var ratio: int = roundi(clampf(current / maxf(maximum, 1.0), 0.0, 1.0) * 100.0)
	var state_key: String = "boss.state.%s" % String(state).to_lower()
	var key: String = "hud.choir_prime_status" if boss_id == &"CHOIR_PRIME" else "hud.command_status"
	boss_label.text = L10n.t(key, {
		"state": L10n.t(state_key),
		"ratio": "%03d" % ratio,
	})


func set_campaign_boss_status(
	definition: BossEncounterDefinition,
	state: StringName,
	armor: float,
	armor_maximum: float,
	body: float,
	body_maximum: float,
	evidence_id: StringName,
	live_feedback: Dictionary = {}
) -> void:
	if definition == null or state == &"IDLE" or state == &"COMPLETE":
		hide_boss_status()
		return
	boss_label.visible = true
	boss_label.text = L10n.t("hud.campaign_boss_status", {
		"name": L10n.t(definition.display_name_key),
		"phase": L10n.t("boss.state.%s" % String(state).to_lower()),
		"armor": "%03d" % roundi(clampf(armor / maxf(armor_maximum, 1.0), 0.0, 1.0) * 100.0),
		"body": "%03d" % roundi(clampf(body / maxf(body_maximum, 1.0), 0.0, 1.0) * 100.0),
		"objective": String(live_feedback.get(
			"objective", L10n.t("boss.objective.finish")
		)),
		"evidence": String(live_feedback.get(
			"consequence",
			L10n.t("boss.evidence.%s" % String(evidence_id).to_lower())
		)),
		"attack": String(live_feedback.get("attack", L10n.t("boss.attack.none"))),
	})


func hide_boss_status() -> void:
	if boss_label != null:
		boss_label.visible = false


func show_directive_result(
	text: String,
	success: bool,
	score_delta: int = 0
) -> void:
	directive_card.show_result(text, success, score_delta)


func show_game_over(summary: RunSummarySnapshot = null) -> void:
	_hide_terminal_choices()
	set_status("hud.city_response_lost")
	set_objective("hud.chassis_signal_terminated")
	_show_summary(summary, false)


func show_district_complete(summary: RunSummarySnapshot) -> void:
	_hide_terminal_choices()
	set_status("hud.district_response_broken")
	set_objective("hud.extraction_open")
	_show_summary(summary, true)


func _show_summary(summary: RunSummarySnapshot, completed: bool) -> void:
	overlay_title.text = L10n.t("hud.district_cleared" if completed else "hud.game_over")
	if summary != null:
		var tokens: Dictionary = {
			"grade": summary.grade,
			"points": "%03d" % summary.mastery_points,
			"score": "%08d" % summary.score,
			"acts": summary.waves_cleared,
			"hits": summary.heavy_hits,
			"variety": summary.unique_actions,
			"depth": summary.causal_depth,
			"objective": L10n.t(summary.retry_objective),
		}
		if completed:
			tokens.strongest = L10n.t(
				"summary.metric.%s" % String(summary.strongest_metric).to_lower()
			)
			tokens.weakest = L10n.t(
				"summary.metric.%s" % String(summary.weakest_metric).to_lower()
			)
			var summary_key: String = "hud.summary" if completed else "hud.summary_game_over"
			overlay_summary.text = L10n.t(summary_key, tokens)
		else:
			overlay_summary.text = L10n.t("hud.chassis_signal_lost")
		if completed and summary.ending_id != &"NONE":
			var ending_key: String = String(summary.ending_id).to_lower()
			overlay_title.text = L10n.t("finale.ending.%s.title" % ending_key)
			overlay_summary.text = L10n.t("finale.ending.%s.body" % ending_key)
	overlay_summary.text += "\n" + L10n.t("narrative.summary.progress", {
		"dossiers": _campaign_dossier_count,
		"total": CityDistrictCatalog.BUILDING_VARIANT_COUNT,
		"generation": _continuity_generation,
	})
	game_over_overlay.visible = true
	retry_button.grab_focus()


func show_cycle_choice(cycle: int, can_continue: bool) -> void:
	overlay_title.text = L10n.t(
		"hud.new_game_plus_ready" if can_continue else "hud.district_secured"
	)
	overlay_summary.text = L10n.t(
		"hud.new_game_plus_summary" if can_continue else "hud.cycle_complete",
		{"cycle": cycle, "score": "%08d" % maxi(_displayed_score(), 0)}
	)
	retry_button.visible = false
	title_button.visible = false
	extract_button.visible = true
	continue_button.visible = can_continue
	continue_button.text = L10n.t("hud.new_game_plus")
	new_game_plus_badge.visible = can_continue
	_apply_responsive_layout()
	game_over_overlay.visible = true
	if can_continue:
		continue_button.grab_focus()
	else:
		extract_button.grab_focus()


func _show_finale_choice(snapshot: FinaleEligibilitySnapshot) -> void:
	overlay_title.text = L10n.t("finale.choice.title")
	overlay_summary.text = L10n.t(
		"finale.choice.summary" if snapshot.disentangle_eligible else "finale.choice.summary_ineligible",
		snapshot.as_dictionary()
	)
	retry_button.visible = false
	extract_button.visible = false
	continue_button.visible = false
	purge_button.visible = true
	disentangle_button.visible = true
	disentangle_button.text = L10n.t(
		"finale.choice.disentangle"
		if snapshot.disentangle_eligible
		else "finale.choice.ascension_warning"
	)
	disentangle_button.modulate = (
		Color.WHITE if snapshot.disentangle_eligible else Color(1.0, 0.54, 0.42, 1.0)
	)
	game_over_overlay.visible = true
	purge_button.grab_focus() if not snapshot.disentangle_eligible else disentangle_button.grab_focus()


func _show_finale_result(outcome: int, cycle: int, can_continue: bool) -> void:
	var ending_key: String = String(BossOutcome.id_for(outcome)).to_lower()
	overlay_title.text = L10n.t("finale.ending.%s.title" % ending_key)
	overlay_summary.text = (
		L10n.t("finale.ending.%s.body" % ending_key)
		+ "\n\n"
		+ L10n.t(
			"hud.new_game_plus_summary" if can_continue else "hud.cycle_complete",
			{"cycle": cycle, "score": "%08d" % maxi(_displayed_score(), 0)}
		)
	)
	retry_button.visible = false
	title_button.visible = false
	purge_button.visible = false
	disentangle_button.visible = false
	extract_button.visible = true
	continue_button.visible = can_continue
	continue_button.text = L10n.t("hud.new_game_plus")
	new_game_plus_badge.visible = can_continue
	_apply_responsive_layout()
	game_over_overlay.visible = true
	if can_continue:
		continue_button.grab_focus()
	else:
		extract_button.grab_focus()


func hide_terminal_overlay() -> void:
	game_over_overlay.visible = false
	_hide_terminal_choices()


func _on_attack_mode_selected(mode: int, _attack_id: int) -> void:
	set_objective(
		"hud.jab_cross_locked"
		if mode == AttackSpec.Mode.JAB_CROSS
		else "hud.ground_locked"
	)


func _on_attack_committed(mode: int, _attack_id: int) -> void:
	if mode == AttackSpec.Mode.JAB_CROSS:
		set_objective("hud.jab_cross_committed")


func _build_status_panel() -> void:
	status_panel = ColorRect.new()
	status_panel.position = Vector2(24.0, 22.0)
	status_panel.size = Vector2(420.0, 112.0)
	status_panel.color = PANEL_COLOR
	add_child(status_panel)
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.position = Vector2(48.0, 34.0)
	status_label.text = L10n.t("hud.city_response_active")
	status_label.add_theme_font_size_override(&"font_size", 24)
	status_label.modulate = ACCENT_COLOR
	add_child(status_label)
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.position = Vector2(48.0, 68.0)
	health_label.add_theme_font_size_override(&"font_size", 25)
	add_child(health_label)
	objective_label = Label.new()
	objective_label.name = "ObjectiveLabel"
	objective_label.position = Vector2(48.0, 100.0)
	objective_label.text = L10n.t(
		"hud.move_hint",
		InputBindingSettings.display_placeholders()
	)
	objective_label.add_theme_font_size_override(&"font_size", 20)
	objective_label.modulate = MUTED_COLOR
	add_child(objective_label)


func _build_momentum_panel() -> void:
	momentum_panel = ColorRect.new()
	momentum_panel.position = Vector2(466.0, 22.0)
	momentum_panel.size = Vector2(500.0, 88.0)
	momentum_panel.color = PANEL_COLOR
	add_child(momentum_panel)
	momentum_label = Label.new()
	momentum_label.name = "MomentumLabel"
	momentum_label.position = Vector2(490.0, 30.0)
	momentum_label.size = Vector2(260.0, 28.0)
	momentum_label.add_theme_font_size_override(&"font_size", 18)
	momentum_label.modulate = MUTED_COLOR
	add_child(momentum_label)
	combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.position = Vector2(764.0, 28.0)
	combo_label.size = Vector2(176.0, 32.0)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.add_theme_font_size_override(&"font_size", 22)
	combo_label.modulate = ACCENT_COLOR
	add_child(combo_label)
	combo_ring = ComboDecayRing.new()
	combo_ring.name = "ComboDecayRing"
	combo_ring.position = Vector2(712.0, 24.0)
	combo_ring.size = Vector2(38.0, 38.0)
	combo_ring.visible = false
	add_child(combo_ring)
	momentum_track = ColorRect.new()
	momentum_track.name = "MomentumTrack"
	momentum_track.position = Vector2(490.0, 66.0)
	momentum_track.size = Vector2(452.0, 18.0)
	momentum_track.color = Color(0.11, 0.15, 0.18, 0.95)
	add_child(momentum_track)
	momentum_fill = ColorRect.new()
	momentum_fill.name = "MomentumFill"
	momentum_fill.position = Vector2(496.0, 71.0)
	momentum_fill.size = Vector2(0.0, 8.0)
	momentum_fill.color = Color("5dc9c2")
	add_child(momentum_fill)


func _build_experience_bar() -> void:
	experience_label = Label.new()
	experience_label.name = "ExperienceLabel"
	experience_label.position = Vector2(490.0, 88.0)
	experience_label.size = Vector2(184.0, 20.0)
	experience_label.add_theme_font_size_override(&"font_size", 14)
	experience_label.modulate = MUTED_COLOR
	add_child(experience_label)
	experience_track = ColorRect.new()
	experience_track.name = "ExperienceTrack"
	experience_track.position = Vector2(680.0, 92.0)
	experience_track.size = Vector2(262.0, 12.0)
	experience_track.color = Color(0.11, 0.15, 0.18, 0.95)
	add_child(experience_track)
	experience_fill = ColorRect.new()
	experience_fill.name = "ExperienceFill"
	experience_fill.position = Vector2(684.0, 95.0)
	experience_fill.size = Vector2(0.0, 6.0)
	experience_fill.color = Color("7ae4ff")
	add_child(experience_fill)


func _build_score_panel() -> void:
	score_panel = ColorRect.new()
	score_panel.position = Vector2(988.0, 22.0)
	score_panel.size = Vector2(268.0, 88.0)
	score_panel.color = PANEL_COLOR
	add_child(score_panel)
	score_caption = Label.new()
	score_caption.position = Vector2(1012.0, 30.0)
	score_caption.size = Vector2(220.0, 28.0)
	score_caption.text = L10n.t("hud.rampage_score")
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_caption.add_theme_font_size_override(&"font_size", 18)
	score_caption.modulate = ACCENT_COLOR
	add_child(score_caption)
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.position = Vector2(1012.0, 56.0)
	score_label.size = Vector2(220.0, 42.0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override(&"font_size", 30)
	add_child(score_label)
	pending_score_label = Label.new()
	pending_score_label.name = "PendingScoreLabel"
	pending_score_label.position = Vector2(1012.0, 91.0)
	pending_score_label.size = Vector2(220.0, 20.0)
	pending_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pending_score_label.add_theme_font_size_override(&"font_size", 14)
	pending_score_label.text = L10n.t("hud.safe")
	pending_score_label.modulate = MUTED_COLOR
	add_child(pending_score_label)
	for index: int in range(RuntimeBudget.RARE_TAG_ROWS):
		var rare_label: Label = Label.new()
		rare_label.name = "RareEvent%d" % index
		rare_label.position = Vector2(1012.0, 116.0 + float(index) * 23.0)
		rare_label.size = Vector2(220.0, 22.0)
		rare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rare_label.add_theme_font_size_override(&"font_size", 16)
		rare_label.modulate = ACCENT_COLOR
		rare_label.visible = false
		add_child(rare_label)
		rare_labels.append(rare_label)


func _build_siege_progress() -> void:
	siege_progress = SiegeProgressStrip.new()
	siege_progress.name = "SiegeProgressStrip"
	siege_progress.position = Vector2(466.0, 112.0)
	siege_progress.size = Vector2(500.0, 32.0)
	add_child(siege_progress)


func _build_directive_card() -> void:
	directive_card = DirectiveCard.new()
	directive_card.name = "DirectiveCard"
	directive_card.position = Vector2(808.0, 392.0)
	directive_card.size = DirectiveCard.LANDSCAPE_SIZE
	add_child(directive_card)


func _build_directive_choice_overlay() -> void:
	directive_choice_overlay = DirectiveChoiceOverlay.new()
	directive_choice_overlay.name = "DirectiveChoiceOverlay"
	add_child(directive_choice_overlay)


func _build_upgrade_ui() -> void:
	weapon_status_strip = WeaponStatusStrip.new()
	add_child(weapon_status_strip)
	upgrade_choice_overlay = UpgradeChoiceOverlay.new()
	add_child(upgrade_choice_overlay)


func _build_boss_status() -> void:
	boss_label = Label.new()
	boss_label.name = "BossStatus"
	boss_label.position = Vector2(400.0, 146.0)
	boss_label.size = Vector2(660.0, 58.0)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override(&"font_size", 21)
	boss_label.modulate = Color("ff8c64")
	boss_label.visible = false
	add_child(boss_label)


func _build_transmission_toast() -> void:
	transmission_toast = TRANSMISSION_TOAST_SCRIPT.new() as TransmissionToast
	add_child(transmission_toast)


func _build_first_run_tutorial() -> void:
	first_run_tutorial = FIRST_RUN_TUTORIAL_SCRIPT.new() as FirstRunCombatTutorial
	first_run_tutorial.setup(_robot, _contextual_attacks)
	add_child(first_run_tutorial)


func _build_game_over_overlay() -> void:
	game_over_overlay = Control.new()
	game_over_overlay.name = "GameOverOverlay"
	game_over_overlay.z_index = 20
	game_over_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.visible = false
	game_over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(game_over_overlay)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.02, 0.03, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	game_over_overlay.add_child(shade)
	terminal_panel = ColorRect.new()
	terminal_panel.position = Vector2(365.0, 188.0)
	terminal_panel.size = Vector2(550.0, 340.0)
	terminal_panel.color = Color(0.025, 0.05, 0.065, 0.97)
	game_over_overlay.add_child(terminal_panel)
	new_game_plus_badge = TextureRect.new()
	new_game_plus_badge.name = "NewGamePlusBadge"
	new_game_plus_badge.texture = WeaponShopVisualCatalog.NEW_GAME_PLUS
	new_game_plus_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	new_game_plus_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	new_game_plus_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	new_game_plus_badge.visible = false
	game_over_overlay.add_child(new_game_plus_badge)
	overlay_title = Label.new()
	overlay_title.position = Vector2(405.0, 218.0)
	overlay_title.size = Vector2(470.0, 72.0)
	overlay_title.text = L10n.t("hud.game_over")
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override(&"font_size", 48)
	overlay_title.modulate = ACCENT_COLOR
	game_over_overlay.add_child(overlay_title)
	overlay_summary = Label.new()
	overlay_summary.position = Vector2(405.0, 296.0)
	overlay_summary.size = Vector2(470.0, 128.0)
	overlay_summary.text = L10n.t("hud.chassis_signal_lost")
	overlay_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_summary.clip_text = true
	overlay_summary.add_theme_font_size_override(&"font_size", 20)
	overlay_summary.modulate = MUTED_COLOR
	game_over_overlay.add_child(overlay_summary)
	retry_button = Button.new()
	retry_button.name = "RetryButton"
	retry_button.position = Vector2(490.0, 430.0)
	retry_button.size = Vector2(300.0, 78.0)
	retry_button.text = L10n.t("hud.retry")
	retry_button.focus_mode = Control.FOCUS_ALL
	retry_button.add_theme_font_size_override(&"font_size", 30)
	retry_button.pressed.connect(retry_pressed.emit)
	game_over_overlay.add_child(retry_button)
	title_button = Button.new()
	title_button.name = "TitleButton"
	title_button.position = Vector2(650.0, 430.0)
	title_button.size = Vector2(225.0, 78.0)
	title_button.text = L10n.t("hud.title_screen")
	title_button.focus_mode = Control.FOCUS_ALL
	title_button.add_theme_font_size_override(&"font_size", 24)
	title_button.pressed.connect(title_pressed.emit)
	game_over_overlay.add_child(title_button)
	extract_button = Button.new()
	extract_button.name = "ExtractButton"
	extract_button.position = Vector2(445.0, 430.0)
	extract_button.size = Vector2(185.0, 78.0)
	extract_button.text = L10n.t("hud.extract")
	extract_button.add_theme_font_size_override(&"font_size", 25)
	extract_button.pressed.connect(extract_pressed.emit)
	extract_button.visible = false
	game_over_overlay.add_child(extract_button)
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.position = Vector2(650.0, 430.0)
	continue_button.size = Vector2(185.0, 78.0)
	continue_button.text = L10n.t("hud.continue")
	continue_button.add_theme_font_size_override(&"font_size", 25)
	continue_button.pressed.connect(continue_pressed.emit)
	continue_button.visible = false
	game_over_overlay.add_child(continue_button)
	purge_button = Button.new()
	purge_button.name = "PurgeButton"
	purge_button.position = Vector2(445.0, 430.0)
	purge_button.size = Vector2(185.0, 78.0)
	purge_button.text = L10n.t("finale.choice.purge")
	purge_button.add_theme_font_size_override(&"font_size", 23)
	purge_button.pressed.connect(purge_pressed.emit)
	purge_button.visible = false
	game_over_overlay.add_child(purge_button)
	disentangle_button = Button.new()
	disentangle_button.name = "DisentangleButton"
	disentangle_button.position = Vector2(650.0, 430.0)
	disentangle_button.size = Vector2(185.0, 78.0)
	disentangle_button.text = L10n.t("finale.choice.disentangle")
	disentangle_button.add_theme_font_size_override(&"font_size", 21)
	disentangle_button.pressed.connect(disentangle_pressed.emit)
	disentangle_button.visible = false
	game_over_overlay.add_child(disentangle_button)


func _is_portrait_layout() -> bool:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	return viewport_size.y > viewport_size.x


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.y > viewport_size.x:
		_apply_portrait_layout(viewport_size)
	else:
		_apply_landscape_layout()
	if directive_choice_overlay != null:
		directive_choice_overlay.apply_responsive_layout(viewport_size)
	if upgrade_choice_overlay != null:
		upgrade_choice_overlay.apply_responsive_layout()
	if weapon_status_strip != null:
		weapon_status_strip.apply_responsive_layout()
	if first_run_tutorial != null:
		first_run_tutorial.apply_responsive_layout(viewport_size)
	if directive_card != null:
		directive_card.apply_responsive_layout(viewport_size)
	if transmission_toast != null:
		transmission_toast.apply_responsive_layout(viewport_size)


func _apply_landscape_layout() -> void:
	status_panel.position = Vector2(24.0, 22.0)
	status_panel.size = Vector2(420.0, 112.0)
	status_label.position = Vector2(48.0, 34.0)
	status_label.size = Vector2(380.0, 30.0)
	status_label.add_theme_font_size_override(&"font_size", 24)
	health_label.position = Vector2(48.0, 68.0)
	health_label.size = Vector2(380.0, 30.0)
	health_label.add_theme_font_size_override(&"font_size", 25)
	objective_label.position = Vector2(48.0, 100.0)
	objective_label.size = Vector2(380.0, 26.0)
	objective_label.add_theme_font_size_override(&"font_size", 20)
	momentum_panel.position = Vector2(466.0, 22.0)
	momentum_panel.size = Vector2(500.0, 88.0)
	momentum_label.position = Vector2(490.0, 30.0)
	momentum_label.size = Vector2(260.0, 28.0)
	momentum_label.add_theme_font_size_override(&"font_size", 18)
	combo_label.position = Vector2(764.0, 28.0)
	combo_label.size = Vector2(176.0, 32.0)
	combo_label.add_theme_font_size_override(&"font_size", 22)
	combo_ring.custom_minimum_size = Vector2(38.0, 38.0)
	combo_ring.position = Vector2(712.0, 24.0)
	combo_ring.size = Vector2(38.0, 38.0)
	momentum_track.position = Vector2(490.0, 66.0)
	momentum_track.size = Vector2(452.0, 18.0)
	momentum_fill.position = Vector2(496.0, 71.0)
	_momentum_fill_width = 392.0
	experience_label.position = Vector2(490.0, 88.0)
	experience_label.size = Vector2(184.0, 20.0)
	experience_label.add_theme_font_size_override(&"font_size", 14)
	experience_track.position = Vector2(680.0, 92.0)
	experience_track.size = Vector2(262.0, 12.0)
	experience_fill.position = Vector2(684.0, 95.0)
	_experience_fill_width = 254.0
	_apply_experience_fill()
	score_panel.position = Vector2(988.0, 22.0)
	score_panel.size = Vector2(268.0, 88.0)
	_set_score_geometry(Vector2(1012.0, 30.0), Vector2(220.0, 28.0), true, false)
	score_caption.add_theme_font_size_override(&"font_size", 18)
	score_label.add_theme_font_size_override(&"font_size", 30)
	pending_score_label.add_theme_font_size_override(&"font_size", 14)
	for index: int in range(rare_labels.size()):
		rare_labels[index].position = Vector2(1012.0, 116.0 + float(index) * 23.0)
		rare_labels[index].size = Vector2(220.0, 22.0)
		rare_labels[index].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rare_labels[index].add_theme_font_size_override(&"font_size", 16)
	siege_progress.position = Vector2(466.0, 112.0)
	siege_progress.size = Vector2(500.0, 32.0)
	siege_progress.set_compact(false)
	siege_progress.apply_width(500.0)
	directive_card.position = Vector2(808.0, 382.0)
	boss_label.position = Vector2(400.0, 146.0)
	boss_label.size = Vector2(660.0, 58.0)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override(&"font_size", 18)
	_apply_landscape_terminal_layout()


func _apply_portrait_layout(viewport_size: Vector2) -> void:
	var panel_width: float = minf(300.0, viewport_size.x * 0.46)
	status_panel.position = Vector2.ZERO
	status_panel.size = Vector2(panel_width, 48.0)
	status_label.position = Vector2(8.0, 3.0)
	status_label.size = Vector2(panel_width - 16.0, 16.0)
	status_label.add_theme_font_size_override(&"font_size", 13)
	health_label.position = Vector2(8.0, 18.0)
	health_label.size = Vector2(panel_width - 16.0, 17.0)
	health_label.add_theme_font_size_override(&"font_size", 15)
	objective_label.position = Vector2(8.0, 34.0)
	objective_label.size = Vector2(panel_width - 16.0, 14.0)
	objective_label.add_theme_font_size_override(&"font_size", 10)
	objective_label.clip_text = true
	momentum_panel.position = Vector2(0.0, 54.0)
	momentum_panel.size = Vector2(panel_width, 44.0)
	momentum_label.position = Vector2(8.0, 57.0)
	momentum_label.size = Vector2(panel_width - 116.0, 16.0)
	momentum_label.add_theme_font_size_override(&"font_size", 11)
	combo_label.position = Vector2(panel_width - 102.0, 56.0)
	combo_label.size = Vector2(94.0, 18.0)
	combo_label.add_theme_font_size_override(&"font_size", 12)
	combo_ring.custom_minimum_size = Vector2(16.0, 16.0)
	combo_ring.position = Vector2(panel_width - 122.0, 57.0)
	combo_ring.size = Vector2(16.0, 16.0)
	momentum_track.position = Vector2(8.0, 73.0)
	momentum_track.size = Vector2(panel_width - 16.0, 8.0)
	momentum_fill.position = Vector2(10.0, 75.0)
	_momentum_fill_width = panel_width - 20.0
	experience_label.position = Vector2(8.0, 83.0)
	experience_label.size = Vector2(92.0, 14.0)
	experience_label.add_theme_font_size_override(&"font_size", 9)
	experience_track.position = Vector2(104.0, 86.0)
	experience_track.size = Vector2(panel_width - 112.0, 8.0)
	experience_fill.position = Vector2(108.0, 88.0)
	_experience_fill_width = panel_width - 120.0
	_apply_experience_fill()
	score_panel.position = Vector2(0.0, 104.0)
	score_panel.size = Vector2(panel_width, 68.0)
	_set_score_geometry(Vector2(8.0, 108.0), Vector2(136.0, 14.0), false, true)
	score_caption.add_theme_font_size_override(&"font_size", 10)
	score_label.add_theme_font_size_override(&"font_size", 20)
	pending_score_label.add_theme_font_size_override(&"font_size", 9)
	for index: int in range(rare_labels.size()):
		rare_labels[index].position = Vector2(152.0, 109.0 + float(index) * 18.0)
		rare_labels[index].size = Vector2(panel_width - 160.0, 16.0)
		rare_labels[index].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		rare_labels[index].add_theme_font_size_override(&"font_size", 9)
	siege_progress.position = Vector2(0.0, 178.0)
	siege_progress.size = Vector2(panel_width, 24.0)
	siege_progress.set_compact(true)
	siege_progress.apply_width(panel_width)
	directive_card.position = Vector2(18.0, viewport_size.y - 338.0)
	boss_label.position = Vector2(0.0, 226.0)
	boss_label.size = Vector2(panel_width, 42.0)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	boss_label.add_theme_font_size_override(&"font_size", 10)
	_apply_portrait_terminal_layout(viewport_size)


func _set_score_geometry(
	origin: Vector2,
	label_size: Vector2,
	align_right: bool,
	compact: bool
) -> void:
	score_caption.position = origin
	score_caption.size = label_size
	score_label.position = origin + Vector2(0.0, 16.0 if compact else 26.0)
	score_label.size = Vector2(label_size.x, 26.0 if compact else 42.0)
	pending_score_label.position = origin + Vector2(0.0, 42.0 if compact else 61.0)
	pending_score_label.size = Vector2(label_size.x, 14.0 if compact else 20.0)
	var alignment: HorizontalAlignment = (
		HORIZONTAL_ALIGNMENT_RIGHT if align_right else HORIZONTAL_ALIGNMENT_LEFT
	)
	score_caption.horizontal_alignment = alignment
	score_label.horizontal_alignment = alignment
	pending_score_label.horizontal_alignment = alignment


func _apply_experience_fill() -> void:
	if experience_fill != null:
		experience_fill.size.x = _experience_fill_width * _experience_ratio


func _apply_landscape_terminal_layout() -> void:
	terminal_panel.position = Vector2(315.0, 188.0)
	terminal_panel.size = Vector2(650.0, 340.0)
	new_game_plus_badge.position = Vector2(335.0, 218.0)
	new_game_plus_badge.size = Vector2(72.0, 72.0)
	overlay_title.position = (
		Vector2(425.0, 218.0) if new_game_plus_badge.visible else Vector2(345.0, 218.0)
	)
	overlay_title.size = (
		Vector2(480.0, 72.0) if new_game_plus_badge.visible else Vector2(590.0, 72.0)
	)
	overlay_summary.position = Vector2(345.0, 296.0)
	overlay_summary.size = Vector2(590.0, 128.0)
	retry_button.position = Vector2(365.0, 430.0)
	retry_button.size = Vector2(260.0, 78.0)
	title_button.position = Vector2(655.0, 430.0)
	title_button.size = Vector2(260.0, 78.0)
	extract_button.position = Vector2(365.0, 430.0)
	extract_button.size = Vector2(260.0, 78.0)
	continue_button.position = Vector2(655.0, 430.0)
	continue_button.size = Vector2(260.0, 78.0)
	purge_button.position = Vector2(365.0, 430.0)
	purge_button.size = Vector2(260.0, 78.0)
	disentangle_button.position = Vector2(655.0, 430.0)
	disentangle_button.size = Vector2(260.0, 78.0)


func _apply_portrait_terminal_layout(viewport_size: Vector2) -> void:
	var panel_width: float = viewport_size.x - 64.0
	terminal_panel.position = Vector2(32.0, 304.0)
	terminal_panel.size = Vector2(panel_width, 560.0)
	new_game_plus_badge.position = Vector2(viewport_size.x * 0.5 - 48.0, 324.0)
	new_game_plus_badge.size = Vector2(96.0, 96.0)
	overlay_title.position = (
		Vector2(52.0, 426.0) if new_game_plus_badge.visible else Vector2(52.0, 334.0)
	)
	overlay_title.size = Vector2(viewport_size.x - 104.0, 82.0)
	overlay_summary.position = (
		Vector2(52.0, 510.0) if new_game_plus_badge.visible else Vector2(52.0, 430.0)
	)
	overlay_summary.size = Vector2(
		viewport_size.x - 104.0,
		156.0 if new_game_plus_badge.visible else 236.0
	)
	retry_button.position = Vector2(82.0, 720.0)
	retry_button.size = Vector2(258.0, 88.0)
	title_button.position = Vector2(viewport_size.x - 340.0, 720.0)
	title_button.size = Vector2(258.0, 88.0)
	extract_button.position = Vector2(82.0, 720.0)
	extract_button.size = Vector2(258.0, 88.0)
	continue_button.position = Vector2(viewport_size.x - 340.0, 720.0)
	continue_button.size = Vector2(258.0, 88.0)
	purge_button.position = Vector2(82.0, 720.0)
	purge_button.size = Vector2(258.0, 88.0)
	disentangle_button.position = Vector2(viewport_size.x - 340.0, 720.0)
	disentangle_button.size = Vector2(258.0, 88.0)


func _hide_terminal_choices() -> void:
	retry_button.visible = true
	title_button.visible = true
	extract_button.visible = false
	continue_button.visible = false
	purge_button.visible = false
	disentangle_button.visible = false
	new_game_plus_badge.visible = false
	_apply_responsive_layout()


func _momentum_color(band: int) -> Color:
	match band:
		1:
			return Color("f1b36f")
		2:
			return Color("ff815c")
		3:
			return Color("fff0a8")
		_:
			return Color("5dc9c2")
