extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const DISTRICT: DistrictDefinition = preload("res://resources/siege/district_contact.tres")

var city: CitySlice


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()


func test_six_act_resource_matches_target_arc_and_duration() -> void:
	assert_eq(DISTRICT.acts.size(), 6)
	var beat_counts: Array[int] = []
	var target_duration: float = 0.0
	for act: DistrictAct in DISTRICT.acts:
		beat_counts.append(act.beats.size())
		target_duration += act.target_duration
	assert_eq(beat_counts, [4, 4, 5, 5, 5, 3])
	assert_between(target_duration, 360.0, 480.0)


func test_accelerated_arc_visits_every_act_and_completes() -> void:
	var director: DistrictResponseDirector = city.urban_siege.director
	var visited: Array[String] = []
	director.phase_changed.connect(
		func(_index: int, display_name: String) -> void: visited.append(display_name)
	)
	director.start()
	var guard: int = 0
	while not director.completed and guard < 600:
		director.advance(1.0)
		city.encounter_runtime.release_all()
		guard += 1
	assert_true(director.completed)
	assert_eq(visited, [
		"CONTACT",
		"CONTAINMENT",
		"ESCALATION",
		"COMMAND RESPONSE",
		"RETALIATION",
		"COMMAND TEST",
	])
	assert_lte(director.elapsed, 600.0)


func test_hud_progress_strip_has_six_fixed_segments() -> void:
	var strip: SiegeProgressStrip = city.gameplay_hud.siege_progress
	assert_not_null(strip)
	assert_eq(strip.segments.size(), 6)
	city.gameplay_hud.set_siege_progress(3, 6, "COMMAND RESPONSE", true)
	assert_eq(strip.current_index, 3)
	assert_true(strip.recovery_active)
	assert_string_contains(strip.label.text, "ACT 4 / 6")
	assert_string_contains(strip.label.text, "RECOVERY")


func test_bounded_overrun_advances_with_surviving_low_threat() -> void:
	var director: DistrictResponseDirector = city.urban_siege.director
	director.start()
	director.beat_index = DISTRICT.acts[0].beats.size() - 1
	director.state = DistrictResponseDirector.STATE_WAITING
	director.act_elapsed = DISTRICT.acts[0].target_duration
	city.encounter_runtime.acquire(&"soldier", Vector2(1200.0, 542.5))
	director.advance(0.1)
	assert_eq(director.phase_index, 1)
	assert_eq(city.encounter_runtime.active_count(&"soldier"), 1)
