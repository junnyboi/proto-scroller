class_name RampageSession
extends Node

var event_hub: GameplayEventHub
var run_score: RunScore
var combo_tracker: ComboTracker
var momentum_meter: MomentumMeter
var rare_event_tracker: RareEventTracker
var frozen_summary: RunSummarySnapshot


func _init() -> void:
	event_hub = GameplayEventHub.new()
	event_hub.name = &"GameplayEventHub"
	add_child(event_hub)
	run_score = RunScore.new()
	run_score.name = &"RunScore"
	add_child(run_score)
	combo_tracker = ComboTracker.new()
	combo_tracker.name = &"ComboTracker"
	add_child(combo_tracker)
	momentum_meter = MomentumMeter.new()
	momentum_meter.name = &"MomentumMeter"
	add_child(momentum_meter)
	rare_event_tracker = RareEventTracker.new()
	rare_event_tracker.name = &"RareEventTracker"
	add_child(rare_event_tracker)


func publish(event: GameplayEvent) -> bool:
	if not event_hub.accept(event):
		return false
	var score_multiplier: int = combo_tracker.current_multiplier
	run_score.apply_event(event, score_multiplier)
	combo_tracker.register_event(event)
	momentum_meter.apply_event(event)
	rare_event_tracker.register_event(event)
	event_hub.broadcast(event)
	return true


func advance(speed_ratio: float, delta: float) -> void:
	combo_tracker.advance(delta)
	momentum_meter.advance_motion(speed_ratio, delta)


func reset_run() -> void:
	event_hub.reset_run()
	run_score.reset_run()
	combo_tracker.reset_run()
	momentum_meter.reset_run()
	rare_event_tracker.reset_run()
	frozen_summary = null


func current_score() -> int:
	return run_score.score


func current_multiplier() -> int:
	return combo_tracker.current_multiplier


func momentum_value() -> float:
	return momentum_meter.value


func freeze_summary(
	waves_cleared: int,
	overdrive_activations: int
) -> RunSummarySnapshot:
	if frozen_summary == null:
		frozen_summary = RunSummarySnapshot.new(
			run_score.score,
			combo_tracker.peak_multiplier,
			combo_tracker.best_chain_count,
			waves_cleared,
			overdrive_activations,
			rare_event_tracker.snapshot_counts()
		)
	return frozen_summary
