extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_severe_damage_enables_fixed_fire_and_electrical_arc_renderer() -> void:
	var city: CitySlice = await _spawn_city()
	var cell: Destructible2D = city.building.get_cell(0, 0)
	var pattern: BuildingDamagePattern2D = cell.get_node(^"DamagedVisual") as BuildingDamagePattern2D
	var severe_fx: BuildingSevereDamageFx2D = pattern.get_node(
		^"SevereDamageFx"
	) as BuildingSevereDamageFx2D
	assert_not_null(severe_fx)
	assert_false(severe_fx.is_active())
	var baseline_children: int = pattern.get_child_count()
	assert_true(cell.receive_damage(_event(
		910_001,
		cell,
		cell.max_health * 0.70,
		&"jab_cross",
		Vector2.RIGHT
	)))
	assert_true(severe_fx.is_active())
	assert_gt(severe_fx.fire_intensity, 0.0)
	assert_gt(severe_fx.arc_intensity, 0.0)
	assert_eq(pattern.get_child_count(), baseline_children)
	assert_true(cell.receive_damage(_event(
		910_002,
		cell,
		cell.max_health,
		&"missile",
		Vector2.LEFT
	)))
	assert_true(cell.is_destroyed())
	assert_true(severe_fx.is_active())
	assert_almost_eq(severe_fx.fire_intensity, 1.0, 0.0001)
	assert_eq(pattern.get_child_count(), baseline_children)


func test_attack_families_select_distinct_persistent_cavity_profiles() -> void:
	var city: CitySlice = await _spawn_city()
	var punch: Destructible2D = city.building.get_cell(0, 0)
	var missile: Destructible2D = city.building.get_cell(1, 0)
	var ground_slam: Destructible2D = city.building.get_cell(2, 0)
	assert_true(punch.receive_damage(_event(
		920_001, punch, punch.max_health * 0.24, &"jab_cross", Vector2.LEFT
	)))
	assert_true(missile.receive_damage(_event(
		920_002, missile, missile.max_health * 0.24, &"missile", Vector2.RIGHT
	)))
	assert_true(ground_slam.receive_damage(_event(
		920_003, ground_slam, ground_slam.max_health * 0.24, &"ground_smash", Vector2.UP
	)))
	var punch_material: ShaderMaterial = _material(punch)
	var missile_material: ShaderMaterial = _material(missile)
	var slam_material: ShaderMaterial = _material(ground_slam)
	assert_eq(
		int(punch_material.get_shader_parameter("impact_profile")),
		BuildingDamagePattern2D.ImpactProfile.PUNCH
	)
	assert_eq(
		int(missile_material.get_shader_parameter("impact_profile")),
		BuildingDamagePattern2D.ImpactProfile.MISSILE
	)
	assert_eq(
		int(slam_material.get_shader_parameter("impact_profile")),
		BuildingDamagePattern2D.ImpactProfile.GROUND_SLAM
	)
	assert_almost_eq(
		(punch_material.get_shader_parameter("hollow_center_uv") as Vector2).y,
		0.54,
		0.0001
	)
	assert_almost_eq(
		(missile_material.get_shader_parameter("hollow_center_uv") as Vector2).y,
		0.52,
		0.0001
	)
	assert_almost_eq(
		(slam_material.get_shader_parameter("hollow_center_uv") as Vector2).y,
		0.68,
		0.0001
	)
	assert_almost_eq(
		float(punch_material.get_shader_parameter("impact_direction")),
		-1.0,
		0.0001
	)
	var state: Dictionary = missile.capture_stream_state()
	missile.restore_stream_state({})
	assert_eq(
		int(_material(missile).get_shader_parameter("impact_profile")),
		BuildingDamagePattern2D.ImpactProfile.GENERIC
	)
	missile.restore_stream_state(state)
	assert_eq(
		int(_material(missile).get_shader_parameter("impact_profile")),
		BuildingDamagePattern2D.ImpactProfile.MISSILE
	)
	var shader_code: String = missile_material.shader.code
	assert_true(shader_code.contains("impact_profile == 1"))
	assert_true(shader_code.contains("impact_profile == 2"))
	assert_true(shader_code.contains("impact_profile == 3"))


func test_destroyed_section_restarts_fragments_falling_debris_and_dust_once() -> void:
	var city: CitySlice = await _spawn_city()
	var cell: Destructible2D = city.building.get_cell(0, 0)
	var baseline_nodes: int = RuntimeBudget.snapshot(city).node_count
	assert_true(cell.receive_damage(_event(
		930_001,
		cell,
		cell.max_health + 1.0,
		&"ground_smash",
		Vector2.UP
	)))
	var active: Array[BuildingSectionBurst2D] = city.building_section_burst_pool.active_slots()
	assert_eq(active.size(), 1)
	var burst: BuildingSectionBurst2D = active[0]
	assert_true(burst.fragments.emitting)
	assert_true(burst.falling_debris.emitting)
	assert_true(burst.dust.emitting)
	assert_gt(burst.falling_debris.lifetime, burst.fragments.lifetime)
	assert_gt(burst.dust.scale_amount_max, 0.60)
	assert_eq(RuntimeBudget.snapshot(city).node_count, baseline_nodes)
	assert_false(cell.receive_damage(_event(
		930_002,
		cell,
		10.0,
		&"jab_cross",
		Vector2.RIGHT
	)))
	assert_eq(city.building_section_burst_pool.spawn_count, 1)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	city.encounter_director.process_mode = Node.PROCESS_MODE_DISABLED
	return city


func _event(
	attack_id: int,
	cell: Destructible2D,
	amount: float,
	damage_type: StringName,
	direction: Vector2
) -> DamageEvent:
	return DamageEvent.new(
		attack_id,
		null,
		amount,
		damage_type,
		cell.global_position,
		direction,
		520.0
	)


func _material(cell: Destructible2D) -> ShaderMaterial:
	var pattern: BuildingDamagePattern2D = cell.get_node(
		^"DamagedVisual"
	) as BuildingDamagePattern2D
	return pattern.cavity_material()
