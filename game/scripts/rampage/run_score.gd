class_name RunScore
extends Node

signal score_changed(score: int, awarded: int)

const MAX_SCORE: int = 2_000_000_000

var score: int = 0


func apply_event(event: GameplayEvent, active_multiplier: int) -> int:
	if event == null or event.base_points <= 0 or score >= MAX_SCORE:
		return 0
	var points: int = mini(event.base_points, MAX_SCORE)
	if event.qualifies_for_combo:
		points *= clampi(active_multiplier, 1, 5)
	var awarded: int = mini(points, MAX_SCORE - score)
	if awarded <= 0:
		return 0
	score += awarded
	score_changed.emit(score, awarded)
	return awarded


func reset_run() -> void:
	score = 0


func deduct(points: int) -> int:
	var deduction: int = mini(maxi(points, 0), score)
	if deduction <= 0:
		return 0
	score -= deduction
	score_changed.emit(score, -deduction)
	return deduction
