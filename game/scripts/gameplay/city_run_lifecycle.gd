class_name CityRunLifecycle
extends Node

var city: CitySlice


func setup(p_city: CitySlice) -> void:
	city = p_city
	city.rampage_session.momentum_meter.momentum_changed.connect(_on_momentum_changed)
	city.rampage_session.rare_event_tracker.tags_changed.connect(_on_rare_tags_changed)
	city.overdrive_session.activated.connect(_on_overdrive_activated)
	city.overdrive_session.time_changed.connect(_on_overdrive_time_changed)
	city.overdrive_session.ended.connect(_on_overdrive_ended)
	city.encounter_director.phase_changed.connect(_on_encounter_phase_changed)
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


func _on_encounter_phase_changed(index: int, display_name: String) -> void:
	city.gameplay_hud.set_objective("WAVE %d / 4  %s" % [index + 1, display_name])


func _on_district_completed() -> void:
	_finish_run(true)


func _finish_run(completed: bool) -> void:
	if city.game_over_active:
		return
	city.game_over_active = true
	city.encounter_director.stop()
	city.telegraph_presenter.cancel_all()
	city.encounter_runtime.release_all()
	city.projectile_root.release_all()
	city.impact_feedback_director.cancel_all()
	city.impact_feedback_pool.reset_runtime_state()
	city.overdrive_session.end_overdrive()
	city.mobile_controls.set_controls_enabled(false)
	var waves_cleared: int = 4 if completed else clampi(
		city.encounter_director.phase_index,
		0,
		4
	)
	var summary: RunSummarySnapshot = city.rampage_session.freeze_summary(
		waves_cleared,
		city.overdrive_session.activation_count
	)
	if completed:
		city.gameplay_hud.show_district_complete(summary)
	else:
		city.gameplay_hud.show_game_over(summary)
