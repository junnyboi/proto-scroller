class_name CityRunLifecycle
extends Node

var city: CitySlice


func setup(p_city: CitySlice) -> void:
	city = p_city
	city.rampage_session.momentum_meter.momentum_changed.connect(_on_momentum_changed)
	city.rampage_session.rare_event_tracker.tags_changed.connect(_on_rare_tags_changed)
	city.rampage_session.combo_tracker.combo_broken.connect(_on_combo_broken)
	city.overdrive_session.activated.connect(_on_overdrive_activated)
	city.overdrive_session.time_changed.connect(_on_overdrive_time_changed)
	city.overdrive_session.ended.connect(_on_overdrive_ended)
	city.encounter_director.phase_changed.connect(_on_encounter_phase_changed)
	if city.urban_siege != null:
		city.urban_siege.district_completed.connect(_on_district_completed)
		city.urban_siege.beat_changed.connect(_on_beat_changed)
		city.urban_siege.recovery_started.connect(_on_recovery_started)
		city.urban_siege.directives.selected.connect(_on_directive_selected)
		city.urban_siege.directives.choices_offered.connect(_on_directive_choices_offered)
		city.urban_siege.directives.progress_changed.connect(_on_directive_progress)
		city.urban_siege.directives.bank_changed.connect(
			city.gameplay_hud.set_directive_bank
		)
		city.urban_siege.directives.completed.connect(_on_directive_completed)
		city.urban_siege.directives.failed.connect(_on_directive_failed)
		city.gameplay_hud.directive_choice_overlay.profile_selected.connect(
			city.urban_siege.directives.select
		)
		city.gameplay_hud.extract_pressed.connect(_on_extract_pressed)
		city.gameplay_hud.continue_pressed.connect(_on_continue_pressed)
		city.urban_siege.boss_session.state_changed.connect(_on_boss_state_changed)
		city.urban_siege.boss_session.armor_changed.connect(_on_boss_armor_changed)
	else:
		city.encounter_director.district_completed.connect(_on_district_completed)
	_on_momentum_changed(
		city.rampage_session.momentum_value(),
		city.rampage_session.momentum_meter.band()
	)
	if city.encounter_director.running:
		_on_encounter_phase_changed(
			city.encounter_director.phase_index,
			city.encounter_director.current_phase_name()
		)


func robot_defeated() -> void:
	_finish_run(false)


func _on_momentum_changed(value: float, band: int) -> void:
	_apply_movement_modifier()
	city.gameplay_hud.set_momentum(value, band)


func _on_overdrive_activated(_attack_id: int) -> void:
	_apply_movement_modifier()
	city.impact_feedback_pool.play_cue(
		AudioCueRegistry.Cue.OVERDRIVE_ACTIVATION,
			city.robot.global_position,
			7
		)
	city.gameplay_hud.set_overdrive(true, city.overdrive_session.remaining)
	city.gameplay_hud.set_objective("objective.overdrive_breakthrough")


func _on_overdrive_time_changed(remaining: float) -> void:
	city.gameplay_hud.set_overdrive(true, remaining)


func _on_overdrive_ended() -> void:
	_apply_movement_modifier()
	city.gameplay_hud.set_overdrive(false, 0.0)
	city.gameplay_hud.set_momentum(
		city.rampage_session.momentum_value(),
		city.rampage_session.momentum_meter.band()
	)


func _apply_movement_modifier() -> void:
	city.robot.set_acceleration_multiplier(
		city.rampage_session.momentum_meter.acceleration_multiplier()
		* city.overdrive_session.acceleration_multiplier()
	)


func _on_rare_tags_changed(tags: PackedStringArray) -> void:
	city.gameplay_hud.set_rare_tags(tags)


func _on_combo_broken() -> void:
	city.impact_feedback_pool.play_cue(
		AudioCueRegistry.Cue.COMBO_BREAK,
		city.robot.global_position,
		6
	)


func _on_encounter_phase_changed(index: int, display_name: String) -> void:
	city.gameplay_hud.set_objective("objective.act", {
		"current": index + 1,
		"total": 6,
		"name": L10n.t(display_name),
	})
	city.gameplay_hud.set_siege_progress(index, 6, display_name, false)


func _on_beat_changed(act_index: int, _beat_index: int, _beat_id: StringName) -> void:
	city.gameplay_hud.set_siege_progress(
		act_index,
		6,
		city.encounter_director.current_phase_name(),
		false
	)


func _on_recovery_started(_duration: float) -> void:
	city.gameplay_hud.set_siege_progress(
		city.encounter_director.phase_index,
		6,
		city.encounter_director.current_phase_name(),
		true
	)


func _on_directive_selected(profile: DirectiveProfile) -> void:
	city.upgrade_assembler.session.set_presentation_blocked(false)
	city.gameplay_hud.show_directive(profile, 0, profile.target_count, 0)


func _on_directive_choices_offered(profiles: Array[DirectiveProfile]) -> void:
	city.upgrade_assembler.session.set_presentation_blocked(true)
	city.gameplay_hud.directive_choice_overlay.show_choices(profiles)


func _on_boss_state_changed(state: StringName) -> void:
	var boss: CommandBossSession = city.urban_siege.boss_session
	var armor: float = boss.boss.boss_armor if boss.boss != null else 0.0
	city.gameplay_hud.set_boss_status(state, armor, CommandBossSession.ARMOR)
	city.gameplay_hud.set_objective("objective.command_unit", {
		"state": L10n.t("boss.state.%s" % String(state).to_lower()),
	})


func _on_boss_armor_changed(current: float, maximum: float) -> void:
	city.gameplay_hud.set_boss_status(city.urban_siege.boss_session.state, current, maximum)


func _on_directive_progress(current: int, target: int) -> void:
	city.gameplay_hud.set_directive_progress(
		city.urban_siege.directives.active_profile,
		current,
		target
	)


func _on_directive_completed(profile: DirectiveProfile, _banked_score: int) -> void:
	city.gameplay_hud.show_directive_result(L10n.t("directive.complete", {
		"name": L10n.t(profile.display_name),
	}), true)


func _on_directive_failed(profile: DirectiveProfile, _penalty: int) -> void:
	city.gameplay_hud.show_directive_result(L10n.t("directive.failed", {
		"name": L10n.t(profile.display_name),
	}), false)


func _on_district_completed() -> void:
	city.urban_siege.prepare_terminal_choice()
	city.gameplay_hud.show_cycle_choice(
		city.urban_siege.cycle_count,
		city.urban_siege.cycle_count < 2
	)


func _on_extract_pressed() -> void:
	city.urban_siege.release_terminal_choice()
	_finish_run(true)


func _on_continue_pressed() -> void:
	if city.urban_siege.continue_cycle():
		city.upgrade_assembler.session.continue_cycle()
		city.gameplay_hud.hide_terminal_overlay()
		var recipe_key: String = (
			"siege.recipe.%s" % String(city.urban_siege.selected_recipe.recipe_id).to_lower()
		)
		city.gameplay_hud.set_objective("objective.cycle", {
			"cycle": 2,
			"recipe": L10n.t(recipe_key),
		})


func _finish_run(completed: bool) -> void:
	if city.game_over_active:
		return
	city.game_over_active = true
	city.upgrade_assembler.session.stop_run()
	var run_metrics: Dictionary = {"completed": completed}
	if city.urban_siege != null:
		var directive: DirectiveProfile = city.urban_siege.directives.selected_profile
		run_metrics.directive_path = (
			directive.directive_id if directive != null else &"NONE"
		)
		run_metrics.boss_result = (
			&"WRECK_RESOLVED"
			if city.urban_siege.boss_session.state == CommandBossSession.STATE_COMPLETE
			else &"UNRESOLVED"
		)
		run_metrics.contract_succeeded = city.urban_siege.contract_succeeded()
		run_metrics.contract_result = (
			&"COMPLETE" if bool(run_metrics.contract_succeeded) else &"FAILED"
		)
		run_metrics.run_seed = city.urban_siege.run_seed
		run_metrics.cycle_count = city.urban_siege.cycle_count
		city.urban_siege.stop_run()
	else:
		city.encounter_director.stop()
	city.telegraph_presenter.cancel_all()
	city.encounter_runtime.release_all()
	city.projectile_root.release_all()
	city.impact_feedback_director.cancel_all()
	city.impact_feedback_pool.reset_runtime_state()
	city.overdrive_session.end_overdrive()
	city.mobile_controls.set_controls_enabled(false)
	var waves_cleared: int = 6 if completed else clampi(
		city.encounter_director.phase_index + 1,
		0,
		6
	)
	var summary: RunSummarySnapshot = city.rampage_session.freeze_summary(
		waves_cleared,
		city.overdrive_session.activation_count,
		run_metrics
	)
	if completed:
		city.gameplay_hud.show_district_complete(summary)
	else:
		city.gameplay_hud.show_game_over(summary)
