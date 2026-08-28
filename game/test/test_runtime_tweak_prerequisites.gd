extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")

var city: CitySlice


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	city.urban_siege.hazards.release_all()


func test_due_pending_hazard_activates_and_leaves_queue() -> void:
	var director: DistrictResponseDirector = city.urban_siege.director
	var runtime: HazardRuntime = city.urban_siege.hazards
	director.stop()
	director._hazard_pending.clear()
	director._hazard_pending.append({
		"remaining": 0.01,
		"hazard_id": &"steam_main",
		"position": Vector2(880.0, CitySlice.LAND_VISUAL_BASELINE_Y),
		"facing": -1,
		"auto_trigger": false,
	})
	var active_before: int = runtime.active_count()
	director._process_hazard_pending(0.02)
	assert_eq(director.hazard_pending_count(), 0)
	assert_eq(runtime.active_count(), active_before + 1)
	assert_eq(runtime.last_hazard_id, &"steam_main")


func test_power_box_repair_authority_is_fixed_fifty_points() -> void:
	assert_eq(ChassisRepairPickup2D.REPAIR_AMOUNT, 50.0)
	var pickup: ChassisRepairPickup2D = city.urban_siege.catalysts.repair_pickups[0]
	pickup.activate(Vector2(900.0, CitySlice.LAND_VISUAL_BASELINE_Y))
	assert_eq(pickup.repair_amount, 50.0)
	city.robot.current_health = city.robot.max_health - 80.0
	assert_true(pickup.try_collect(city.robot))
	assert_eq(city.robot.current_health, city.robot.max_health - 30.0)
