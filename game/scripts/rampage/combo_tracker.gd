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
var _last_action_tag: StringName = &""
var _same_tag_streak: int = 0


func register_event(event: GameplayEvent) -> bool:
	if event == null or not event.qualifies_for_combo or event.action_tag.is_empty():
		return false
	current_chain_count += 1
	if current_chain_count == 1:
		current_multiplier = 1
		_same_tag_streak = 1
	elif event.action_tag == _last_action_tag:
		_same_tag_streak += 1
		if _same_tag_streak == 2:
			_grow_multiplier()
	else:
		_same_tag_streak = 1
		_grow_multiplier()
	_last_action_tag = event.action_tag
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


func reset_run() -> void:
	current_multiplier = 1
	grace_remaining = 0.0
	peak_multiplier = 1
	best_chain_count = 0
	current_chain_count = 0
	_last_action_tag = &""
	_same_tag_streak = 0


func apply_heavy_hit_penalty() -> int:
	var previous: int = current_multiplier
	current_multiplier = maxi(current_multiplier - 1, 1)
	if current_chain_count > 0:
		grace_remaining = maxf(grace_remaining, 0.75)
	combo_changed.emit(current_multiplier, grace_remaining)
	return previous - current_multiplier


func _grow_multiplier() -> void:
	current_multiplier = mini(current_multiplier + 1, MAX_MULTIPLIER)


func _break_combo() -> void:
	current_multiplier = 1
	current_chain_count = 0
	_last_action_tag = &""
	_same_tag_streak = 0
	combo_changed.emit(current_multiplier, grace_remaining)
	combo_broken.emit()
