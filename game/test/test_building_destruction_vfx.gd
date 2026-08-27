extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_section_burst_pool_is_fixed_and_recycles_oldest_slot() -> void:
	var pool: BuildingSectionBurstPool = BuildingSectionBurstPool.new()
	pool.capacity = 2
	add_child_autofree(pool)
	await get_tree().process_frame
	var child_count: int = pool.get_child_count()
	var concrete: StructuralMaterialProfile = StructuralMaterialProfile.concrete()
	var glass: StructuralMaterialProfile = StructuralMaterialProfile.glass()
	var steel: StructuralMaterialProfile = StructuralMaterialProfile.steel()
	var first: BuildingSectionBurst2D = pool.spawn(
		Vector2(10.0, 20.0), Vector2.RIGHT, 420.0, concrete
	)
	var second: BuildingSectionBurst2D = pool.spawn(
		Vector2(30.0, 40.0), Vector2.LEFT, 520.0, glass
	)
	var third: BuildingSectionBurst2D = pool.spawn(
		Vector2(50.0, 60.0), Vector2.UP, 620.0, steel
	)
	assert_not_null(first)
	assert_not_null(second)
	assert_same(first, third)
	assert_eq(pool.slot_count(), 2)
	assert_eq(pool.active_count(), 2)
	assert_eq(pool.recycle_count, 1)
	assert_eq(pool.spawn_count, 3)
	assert_eq(pool.get_child_count(), child_count)
	assert_eq(pool.last_material_id, &"steel")
	assert_eq(pool.last_origin, Vector2(50.0, 60.0))
	assert_same(third.fragments.texture, BuildingSectionBurst2D.STEEL_TEXTURE)
	assert_eq(third.fragments.amount, 6)
	assert_eq(third.falling_debris.amount, 5)
	assert_eq(third.dust.amount, 5)
	assert_true(third.falling_debris.emitting)
	assert_true(third.dust.emitting)
	assert_true(third.flash.visible)
	pool.reset_all()
	assert_eq(pool.active_count(), 0)
	assert_eq(pool.spawn_count, 0)
	assert_eq(pool.recycle_count, 0)


func test_material_profiles_select_distinct_generated_fragment_textures() -> void:
	var pool: BuildingSectionBurstPool = BuildingSectionBurstPool.new()
	pool.capacity = 3
	add_child_autofree(pool)
	await get_tree().process_frame
	var concrete: BuildingSectionBurst2D = pool.spawn(
		Vector2.ZERO, Vector2.RIGHT, 400.0, StructuralMaterialProfile.concrete()
	)
	var glass: BuildingSectionBurst2D = pool.spawn(
		Vector2.ZERO, Vector2.RIGHT, 400.0, StructuralMaterialProfile.glass()
	)
	var steel: BuildingSectionBurst2D = pool.spawn(
		Vector2.ZERO, Vector2.RIGHT, 400.0, StructuralMaterialProfile.steel()
	)
	assert_same(concrete.fragments.texture, BuildingSectionBurst2D.CONCRETE_TEXTURE)
	assert_same(glass.fragments.texture, BuildingSectionBurst2D.GLASS_TEXTURE)
	assert_same(steel.fragments.texture, BuildingSectionBurst2D.STEEL_TEXTURE)
	assert_eq(concrete.fragments.amount, 9)
	assert_eq(glass.fragments.amount, 12)
	assert_eq(steel.fragments.amount, 6)
	assert_eq(concrete.falling_debris.amount, 6)
	assert_eq(glass.falling_debris.amount, 8)
	assert_eq(steel.falling_debris.amount, 5)
	assert_eq(concrete.dust.amount, 9)
	assert_eq(glass.dust.amount, 5)
	assert_eq(steel.dust.amount, 5)
	assert_lt(concrete.dust.color.a, 0.60)
	assert_lt(glass.dust.color.a, 0.30)
	assert_ne(concrete.fragments.spread, glass.fragments.spread)
	assert_ne(glass.fragments.gravity, steel.fragments.gravity)


func test_destroyed_streamed_cell_emits_once_and_restore_does_not_replay() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	city.encounter_director.process_mode = Node.PROCESS_MODE_DISABLED
	assert_eq(
		city.building_section_burst_pool.slot_count(),
		RuntimeBudget.BUILDING_SECTION_BURST_SLOTS
	)
	assert_false(city.enemy_scrap_pool.use_generated_visuals)
	var cell: Destructible2D = city.building.get_cell(0, 0)
	assert_not_null(cell)
	assert_same(cell._section_burst_pool, city.building_section_burst_pool)
	var event: DamageEvent = DamageEvent.new(
		880_001,
		city.robot,
		cell.max_health + 1.0,
		&"jab_cross",
		cell.global_position,
		Vector2.RIGHT,
		520.0
	)
	assert_true(cell.receive_damage(event))
	assert_true(cell.is_destroyed())
	assert_eq(city.building_section_burst_pool.spawn_count, 1)
	assert_eq(city.building_section_burst_pool.active_count(), 1)
	assert_false(cell.receive_damage(event))
	assert_eq(city.building_section_burst_pool.spawn_count, 1)
	assert_gt(city.debris_pool.active_count(), 0)
	var macro_chunk: DebrisBody2D = city.debris_pool.active_bodies()[0]
	assert_true(macro_chunk._generated_visual.visible)
	assert_same(
		macro_chunk._generated_visual.texture,
		DebrisBody2D.CONCRETE_DEBRIS_TEXTURE
	)
	var state: Dictionary = city.building.capture_stream_state()
	city.building_section_burst_pool.reset_all()
	city.building.restore_stream_state(state)
	assert_eq(city.building_section_burst_pool.spawn_count, 0)
	assert_eq(city.building_section_burst_pool.active_count(), 0)
	city.building.restore_stream_state({})
	cell = city.building.get_cell(0, 0)
	var repeat_event: DamageEvent = DamageEvent.new(
		880_002,
		city.robot,
		cell.max_health + 1.0,
		&"jab_cross",
		cell.global_position,
		Vector2.LEFT,
		520.0
	)
	assert_true(cell.receive_damage(repeat_event))
	assert_eq(city.building_section_burst_pool.spawn_count, 1)
	assert_eq(city.building_section_burst_pool.active_count(), 1)
	NewGamePlusWorldReset.execute(city)
	assert_eq(city.building_section_burst_pool.active_count(), 0)
	assert_eq(city.building_section_burst_pool.spawn_count, 0)
