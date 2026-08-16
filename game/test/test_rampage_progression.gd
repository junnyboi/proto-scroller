extends GutTest

const TEST_COUNT_PATH: String = "res://artifacts/unit-tests-ran.txt"


func test_event_hub_deduplicates_and_keeps_scene_local_ids() -> void:
	var hub: GameplayEventHub = GameplayEventHub.new()
	add_child_autofree(hub)
	var first: GameplayEvent = _event(&"shared")
	var repeated: GameplayEvent = _event(&"shared")
	var unkeyed: GameplayEvent = _event()
	assert_true(hub.accept(first))
	assert_eq(first.event_id, 1)
	assert_false(hub.accept(repeated))
	assert_eq(repeated.event_id, 0)
	assert_true(hub.accept(unkeyed))
	assert_eq(unkeyed.event_id, 2)
	hub.reset_run()
	var next_run: GameplayEvent = _event(&"shared")
	assert_true(hub.accept(next_run))
	assert_eq(next_run.event_id, 3)
	_record_test_execution()


func test_session_scores_before_combo_growth() -> void:
	var session: RampageSession = _session()
	assert_true(session.publish(_event(&"a1", &"smash", 100, 0.0, true)))
	assert_eq(session.current_score(), 100)
	assert_eq(session.current_multiplier(), 1)
	assert_true(session.publish(_event(&"a2", &"smash", 100, 0.0, true)))
	assert_eq(session.current_score(), 200)
	assert_eq(session.current_multiplier(), 2)
	assert_true(session.publish(_event(&"a3", &"smash", 100, 0.0, true)))
	assert_eq(session.current_score(), 400)
	assert_eq(session.current_multiplier(), 2)
	assert_true(session.publish(_event(&"b1", &"stomp", 100, 0.0, true)))
	assert_eq(session.current_score(), 600)
	assert_eq(session.current_multiplier(), 3)
	_record_test_execution()


func test_nonqualifying_score_ignores_active_multiplier() -> void:
	var session: RampageSession = _session()
	session.publish(_event(&"a1", &"smash", 10, 0.0, true))
	session.publish(_event(&"a2", &"smash", 10, 0.0, true))
	assert_eq(session.current_multiplier(), 2)
	assert_true(session.publish(_event(&"prop", &"", 75, 0.0, false)))
	assert_eq(session.current_score(), 95)
	assert_eq(session.current_multiplier(), 2)
	assert_true(session.publish(_event(&"zero", &"", 0, 0.0, false)))
	assert_eq(session.current_score(), 95)
	_record_test_execution()


func test_combo_grace_breaks_at_exactly_three_seconds() -> void:
	var combo: ComboTracker = ComboTracker.new()
	add_child_autofree(combo)
	assert_true(combo.register_event(_event(&"a", &"smash", 0, 0.0, true)))
	combo.advance(2.999)
	assert_eq(combo.current_chain_count, 1)
	assert_gt(combo.grace_remaining, 0.0)
	combo.advance(0.001)
	assert_eq(combo.grace_remaining, 0.0)
	assert_eq(combo.current_chain_count, 0)
	assert_eq(combo.current_multiplier, 1)
	assert_eq(combo.best_chain_count, 1)
	_record_test_execution()


func test_combo_caps_suppresses_third_repeat_and_restores_variety_growth() -> void:
	var combo: ComboTracker = ComboTracker.new()
	add_child_autofree(combo)
	combo.register_event(_event(&"a1", &"smash", 0, 0.0, true))
	combo.register_event(_event(&"a2", &"smash", 0, 0.0, true))
	assert_eq(combo.current_multiplier, 2)
	combo.register_event(_event(&"a3", &"smash", 0, 0.0, true))
	assert_eq(combo.current_multiplier, 2)
	combo.register_event(_event(&"b1", &"stomp", 0, 0.0, true))
	assert_eq(combo.current_multiplier, 3)
	combo.register_event(_event(&"b2", &"stomp", 0, 0.0, true))
	assert_eq(combo.current_multiplier, 4)
	combo.register_event(_event(&"b3", &"stomp", 0, 0.0, true))
	assert_eq(combo.current_multiplier, 4)
	combo.register_event(_event(&"c1", &"throw", 0, 0.0, true))
	assert_eq(combo.current_multiplier, 5)
	combo.register_event(_event(&"d1", &"scrap", 0, 0.0, true))
	assert_eq(combo.current_multiplier, 5)
	assert_eq(combo.peak_multiplier, 5)
	assert_eq(combo.best_chain_count, 8)
	_record_test_execution()


func test_momentum_motion_thresholds_and_idle_grace() -> void:
	var meter: MomentumMeter = MomentumMeter.new()
	add_child_autofree(meter)
	meter.apply_event(_event(&"seed", &"", 0, 50.0))
	meter.advance_motion(0.699, 1.0)
	assert_eq(meter.value, 50.0)
	meter.advance_motion(0.700, 1.0)
	assert_eq(meter.value, 62.0)
	meter.advance_motion(0.199, 0.999)
	assert_eq(meter.value, 62.0)
	meter.advance_motion(0.199, 0.001)
	assert_eq(meter.value, 62.0)
	meter.advance_motion(0.199, 0.1)
	assert_almost_eq(meter.value, 61.0, 0.0001)
	meter.advance_motion(0.200, 1.0)
	assert_almost_eq(meter.value, 61.0, 0.0001)
	meter.advance_motion(0.199, 1.0)
	assert_almost_eq(meter.value, 61.0, 0.0001)
	_record_test_execution()


func test_momentum_applies_generic_discrete_values() -> void:
	var session: RampageSession = _session()
	var deltas: Array[float] = [5.0, 10.0, 15.0, 20.0, -10.0, -5.0]
	var expected: float = 0.0
	for index: int in range(deltas.size()):
		var delta: float = deltas[index]
		expected = clampf(expected + delta, 0.0, 100.0)
		assert_true(session.publish(_event(StringName("m%d" % index), &"", 0, delta)))
		assert_almost_eq(session.momentum_value(), expected, 0.0001)
	assert_false(session.publish(_event(&"m0", &"", 0, 99.0)))
	assert_almost_eq(session.momentum_value(), expected, 0.0001)
	_record_test_execution()


func test_ready_momentum_locks_gain_decay_and_event_loss() -> void:
	var meter: MomentumMeter = MomentumMeter.new()
	add_child_autofree(meter)
	meter.apply_event(_event(&"ready", &"", 0, 100.0))
	assert_true(meter.is_ready())
	assert_eq(meter.band(), MomentumMeter.Band.READY)
	meter.apply_event(_event(&"loss", &"", 0, -100.0))
	meter.advance_motion(0.0, 5.0)
	meter.advance_motion(1.0, 5.0)
	assert_eq(meter.value, 100.0)
	assert_true(meter.is_ready())
	_record_test_execution()


func test_session_reset_clears_all_run_state() -> void:
	var session: RampageSession = _session()
	var event: GameplayEvent = _event(&"run-key", &"smash", 100, 40.0, true)
	assert_true(session.publish(event))
	assert_gt(session.current_score(), 0)
	assert_gt(session.momentum_value(), 0.0)
	assert_gt(session.combo_tracker.current_chain_count, 0)
	session.reset_run()
	assert_eq(session.current_score(), 0)
	assert_eq(session.current_multiplier(), 1)
	assert_eq(session.momentum_value(), 0.0)
	assert_eq(session.combo_tracker.current_chain_count, 0)
	assert_eq(session.combo_tracker.peak_multiplier, 1)
	assert_eq(session.combo_tracker.best_chain_count, 0)
	var next_event: GameplayEvent = _event(&"run-key")
	assert_true(session.publish(next_event))
	assert_eq(next_event.event_id, event.event_id + 1)
	_record_test_execution()


func _session() -> RampageSession:
	var session: RampageSession = RampageSession.new()
	add_child_autofree(session)
	return session


func _event(
	dedupe_key: StringName = &"",
	action_tag: StringName = &"",
	base_points: int = 0,
	momentum_delta: float = 0.0,
	qualifies_for_combo: bool = false
) -> GameplayEvent:
	return GameplayEvent.new(
		dedupe_key,
		0,
		GameplayEvent.Kind.DAMAGE_APPLIED,
		action_tag,
		base_points,
		momentum_delta,
		qualifies_for_combo
	)


func _record_test_execution() -> void:
	var previous_count: int = 0
	if FileAccess.file_exists(TEST_COUNT_PATH):
		var read_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.READ)
		previous_count = int(read_file.get_as_text())
	var write_file: FileAccess = FileAccess.open(TEST_COUNT_PATH, FileAccess.WRITE)
	write_file.store_string(str(previous_count + 1))
