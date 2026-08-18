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
	city.encounter_director.district_completed.connect(_on_district_completed)
	if city.urban_siege != null:
		city.urban_siege.beat_changed.connect(_on_beat_changed)
		city.urban_siege.recovery_started.connect(_on_recovery_started)
		city.urban_siege.directives.selected.connect(_on_directive_selected)
		city.urban_siege.directives.progress_changed.connect(_on_directive_progress)
		city.urban_siege.directives.bank_changed.connect(
			city.gameplay_hud.set_directive_bank
		)
		city.urban_siege.directives.completed.connect(_on_directive_completed)
		city.urban_siege.directives.failed.connect(_on_directive_failed)
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
	city.impact_feedback_pool.play_semantic(
		&"overdrive",
		city.robot.global_position,
		7
	)
	city.gameplay_hud.set_overdrive(true, city.overdrive_session.remaining)
	city.gameplay_hud.set_objective("KINETIC OVERDRIVE / FOUR SECOND BREAKTHROUGH")


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
	city.impact_feedback_pool.play_semantic(
		&"combo_break",
		city.robot.global_position,
		6
	)


func _on_encounter_phase_changed(index: int, display_name: String) -> void:
	city.gameplay_hud.set_objective("ACT %d / 6  %s" % [index + 1, display_name])
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
	city.gameplay_hud.show_directive(profile, 0, profile.target_count, 0)


func _on_directive_progress(current: int, target: int) -> void:
	city.gameplay_hud.set_directive_progress(
		city.urban_siege.directives.active_profile,
		current,
		target
	)


func _on_directive_completed(profile: DirectiveProfile, _banked_score: int) -> void:
	city.gameplay_hud.show_directive_result("%s COMPLETE" % profile.display_name, true)


func _on_directive_failed(profile: DirectiveProfile, _penalty: int) -> void:
	city.gameplay_hud.show_directive_result("%s FAILED" % profile.display_name, false)


func _on_district_completed() -> void:
	_finish_run(true)


func _finish_run(completed: bool) -> void:
	if city.game_over_active:
		return
	city.game_over_active = true
	if city.urban_siege != null:
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
		city.overdrive_session.activation_count
	)
	if completed:
		city.gameplay_hud.show_district_complete(summary)
	else:
		city.gameplay_hud.show_game_over(summary)
