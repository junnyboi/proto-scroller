class_name RampageSession
extends Node

var event_hub: GameplayEventHub
var run_score: RunScore
var combo_tracker: ComboTracker
var momentum_meter: MomentumMeter


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


func publish(event: GameplayEvent) -> bool:
	if not event_hub.accept(event):
		return false
	var score_multiplier: int = combo_tracker.current_multiplier
	run_score.apply_event(event, score_multiplier)
	combo_tracker.register_event(event)
	momentum_meter.apply_event(event)
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


func current_score() -> int:
	return run_score.score


func current_multiplier() -> int:
	return combo_tracker.current_multiplier


func momentum_value() -> float:
	return momentum_meter.value
