extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const DISTRICT: DistrictDefinition = preload("res://resources/siege/district_contact.tres")
const TRANSFORMER: CatalystProfile = preload("res://resources/catalysts/transformer.tres")

var city: CitySlice


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame


func test_contact_resource_has_bounded_pressure_and_recovery() -> void:
	assert_eq(DISTRICT.acts.size(), 6)
	assert_eq(DISTRICT.acts[0].beats.size(), 4)
	for act: DistrictAct in DISTRICT.acts:
		for beat: DistrictBeat in act.beats:
			assert_between(beat.pressure_seconds, 8.0, 15.0)
			assert_between(beat.recovery_seconds, 1.0, 4.0)


func test_reservation_is_atomic_and_cancels_without_growth() -> void:
	city.encounter_runtime.release_all()
	var ledger: CapacityReservationLedger = CapacityReservationLedger.new()
	var beat: DistrictBeat = DISTRICT.acts[0].beats[0]
	var reservation_id: int = ledger.reserve_beat(beat, city.encounter_runtime)
	assert_gt(reservation_id, 0)
	assert_eq(ledger.pending_count(&"needle"), EnemySpawnTuning.QUANTITY_MULTIPLIER)
	assert_eq(city.encounter_runtime.total_count(), RuntimeBudget.ROLE_BADGES)
	ledger.cancel(reservation_id)
	assert_eq(ledger.pending_count(), 0)
	assert_eq(city.encounter_runtime.total_count(), RuntimeBudget.ROLE_BADGES)


func test_timed_director_reinforces_then_opens_recovery_gate() -> void:
	city.encounter_runtime.release_all()
	var director: DistrictResponseDirector = city.urban_siege.director
	director.start()
	director.advance(0.01)
	assert_eq(director.current_beat_id(), &"SCOUT_PROBE")
	director.advance(0.01)
	assert_eq(city.encounter_runtime.active_count(&"needle"), 1)
	director.advance(9.1)
	assert_eq(director.state, DistrictResponseDirector.STATE_RECOVERY)
	assert_false(city.encounter_runtime.attack_gate_enabled)
	director.advance(3.1)
	assert_true(city.encounter_runtime.attack_gate_enabled)


func test_damage_event_lineage_survives_scaled_derivative() -> void:
	var source_event: DamageEvent = DamageEvent.new(
		81,
		city.robot,
		90.0,
		&"ground_smash",
		Vector2.ZERO,
		Vector2.RIGHT,
		200.0,
		17,
		1,
		DamageEvent.FLAG_CATALYST
	)
	var derived: DamageEvent = source_event.scaled(0.5)
	assert_eq(derived.root_attack_id, 17)
	assert_eq(derived.causal_depth, 1)
	assert_eq(derived.effect_flags, DamageEvent.FLAG_CATALYST)


func test_transformer_is_prewarmed_once_and_triggers_from_damage() -> void:
	var catalysts: CatalystRuntime = city.urban_siege.catalysts
	assert_eq(catalysts.total_count(), 2)
	assert_eq(catalysts.repair_pickup_count(), RuntimeBudget.REPAIR_PICKUP_SLOTS)
	var transformer: Catalyst2D = catalysts.activate(0, TRANSFORMER, Vector2(1100.0, 590.0))
	assert_eq(catalysts.active_count(), 1)
	var event: DamageEvent = DamageEvent.new(
		901,
		city.robot,
		100.0,
		&"ground_smash",
		transformer.global_position,
		Vector2.RIGHT,
		400.0
	)
	assert_true(transformer.receive_damage(event))
	assert_true(transformer.spent)
	assert_eq(transformer.trigger_count, 1)
	assert_false(transformer.receive_damage(event))
	assert_eq(catalysts.active_repair_pickup_count(), 1)
	var pickup: ChassisRepairPickup2D = catalysts.repair_pickups[0]
	assert_true(pickup.active)
	assert_eq(pickup.global_position, transformer.global_position + Vector2(0.0, -96.0))
	city.robot.current_health = city.robot.max_health - 100.0
	assert_true(pickup.try_collect(city.robot))
	assert_almost_eq(city.robot.current_health, city.robot.max_health - 60.0, 0.001)
	assert_false(pickup.active)
	assert_eq(catalysts.active_repair_pickup_count(), 0)
	await get_tree().create_timer(0.5).timeout
	assert_eq(catalysts.pulse_count, 1)
	assert_eq(catalysts.total_count(), 2)
	assert_eq(catalysts.repair_pickup_count(), RuntimeBudget.REPAIR_PICKUP_SLOTS)


func test_full_health_does_not_waste_the_transformer_repair_pickup() -> void:
	var catalysts: CatalystRuntime = city.urban_siege.catalysts
	var transformer: Catalyst2D = catalysts.activate(0, TRANSFORMER, Vector2(900.0, 590.0))
	var event: DamageEvent = DamageEvent.new(
		902,
		city.robot,
		100.0,
		&"ground_smash",
		transformer.global_position,
		Vector2.RIGHT,
		400.0
	)
	assert_true(transformer.receive_damage(event))
	var pickup: ChassisRepairPickup2D = catalysts.repair_pickups[0]
	assert_false(pickup.try_collect(city.robot))
	assert_true(pickup.active)
	catalysts.deactivate_all()
	assert_eq(catalysts.active_repair_pickup_count(), 0)


func test_runtime_budget_includes_fixed_catalyst_and_beat_caps() -> void:
	var snapshot: Dictionary = RuntimeBudget.snapshot(city)
	assert_eq(snapshot.catalyst_total, RuntimeBudget.CATALYST_SLOTS)
	assert_eq(snapshot.repair_pickup_slots, RuntimeBudget.REPAIR_PICKUP_SLOTS)
	assert_lte(snapshot.catalyst_active, RuntimeBudget.ACTIVE_CATALYSTS)
	assert_eq(RuntimeBudget.validation_errors(city).size(), 0)
