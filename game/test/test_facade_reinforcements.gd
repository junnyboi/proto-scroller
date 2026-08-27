extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")

var city: CitySlice
var director: DistrictResponseDirector


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	director = city.urban_siege.director
	director.start()
	director.hold_act_advance()


func test_held_district_recycles_authored_beats_after_long_idle() -> void:
	var authored_beat_count: int = director.district.acts[0].beats.size()
	for _second: int in range(900):
		director.advance(1.0)
		city.encounter_runtime.release_all()
	assert_true(director.running)
	assert_false(director.completed)
	assert_eq(director.phase_index, 0)
	assert_gt(director.started_beat_count(), authored_beat_count * 2)
	assert_lte(director.pending_count(), DistrictResponseDirector.MAX_PENDING_RECORDS)
	assert_eq(director.ledger.denial_count, 0)
	var started_at_boss_ready: int = director.started_beat_count()
	city.world_stream._pending_boss_district_index = 0
	for _second: int in range(120):
		director.advance(1.0)
		city.encounter_runtime.release_all()
	assert_gt(director.started_beat_count(), started_at_boss_ready)


func test_each_new_facade_queues_pressure_around_player_until_boss_contact() -> void:
	_cancel_current_beat()
	director.state = DistrictResponseDirector.STATE_RECOVERY
	director.recovery_remaining = 30.0
	var started_before: int = director.started_beat_count()
	assert_eq(director.facade_engagement_count(), 1)
	city.world_stream.window_changed.emit(1)
	assert_eq(director.facade_engagement_count(), 2)
	assert_eq(director.pending_facade_reinforcement_count(), 1)
	director.advance(0.0)
	assert_eq(director.state, DistrictResponseDirector.STATE_PRESSURE)
	assert_eq(director.pending_facade_reinforcement_count(), 0)
	assert_eq(director.started_beat_count(), started_before + 1)
	assert_gt(director.pending_count(), 0)
	director._process_pending(30.0)
	assert_gt(city.encounter_runtime.active_count(), 0)
	var bounds: Vector2 = city.world_stream.resident_bounds()
	for enemy: EnemyActor2D in city.encounter_runtime.all_actors():
		if enemy.active and not enemy.dead:
			assert_between(enemy.global_position.x, bounds.x, bounds.y)
	city.world_stream.window_changed.emit(1)
	city.world_stream.window_changed.emit(10)
	assert_eq(director.facade_engagement_count(), 2)
	var started_at_boss: int = director.started_beat_count()
	director.suspend_for_boss()
	city.world_stream.window_changed.emit(2)
	for _second: int in range(120):
		director.advance(1.0)
	assert_true(director.is_suspended_for_boss())
	assert_eq(director.pending_facade_reinforcement_count(), 0)
	assert_eq(director.started_beat_count(), started_at_boss)


func test_facade_arrival_interrupts_empty_stale_pressure_immediately() -> void:
	_cancel_current_beat()
	director.state = DistrictResponseDirector.STATE_PRESSURE
	director.pressure_remaining = 30.0
	var started_before: int = director.started_beat_count()
	city.world_stream.window_changed.emit(1)
	assert_eq(director.state, DistrictResponseDirector.STATE_PRESSURE)
	assert_gt(director.pressure_remaining, 0.0)
	assert_lt(director.pressure_remaining, 30.0)
	assert_eq(director.pending_facade_reinforcement_count(), 0)
	assert_eq(director.started_beat_count(), started_before + 1)
	assert_gt(director.pending_count(), 0)


func _cancel_current_beat() -> void:
	director._beat_pending.clear()
	if director._beat_reservation_id != 0:
		director.ledger.cancel(director._beat_reservation_id)
		director._beat_reservation_id = 0
