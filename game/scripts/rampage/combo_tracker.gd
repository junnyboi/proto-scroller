class_name ComboTracker
extends Node

signal combo_changed(multiplier: int, grace_remaining: float)
signal combo_broken

const GRACE_SECONDS: float = 3.0
const MAX_MULTIPLIER: int = 5

var current_multiplier: int = 1
var grace_remaining: float = 0.0
var peak_multiplier: int = 1
var best_chain_count: int = 0
var current_chain_count: int = 0


func register_event(event: GameplayEvent) -> bool:
	if (
		event == null
		or event.kind != GameplayEvent.Kind.ENEMY_DEFEATED
		or not event.qualifies_for_combo
	):
		return false
	current_chain_count += 1
	current_multiplier = mini(current_chain_count, MAX_MULTIPLIER)
	grace_remaining = GRACE_SECONDS
	peak_multiplier = maxi(peak_multiplier, current_multiplier)
	best_chain_count = maxi(best_chain_count, current_chain_count)
	combo_changed.emit(current_multiplier, grace_remaining)
	return true


func advance(delta: float) -> void:
	if current_chain_count == 0 or delta <= 0.0:
		return
	if delta >= grace_remaining:
		grace_remaining = 0.0
		_break_combo()
		return
	grace_remaining -= delta
	combo_changed.emit(current_multiplier, grace_remaining)


func break_on_damage() -> bool:
	if current_chain_count == 0:
		return false
	grace_remaining = 0.0
	_break_combo()
	return true


func reset_run() -> void:
	current_multiplier = 1
	grace_remaining = 0.0
	peak_multiplier = 1
	best_chain_count = 0
	current_chain_count = 0


func _break_combo() -> void:
	current_multiplier = 1
	current_chain_count = 0
	combo_changed.emit(current_multiplier, grace_remaining)
	combo_broken.emit()
