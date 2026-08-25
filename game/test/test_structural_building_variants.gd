extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_all_twenty_five_variants_reconfigure_one_cell_tree_in_place() -> void:
	var bootstrap: StructuralBuildingVariant = CityDistrictCatalog.districts()[0].building_variants[0]
	var building: StructuralBuilding2D = StructuralBuilding2D.new()
	building.intact_texture = bootstrap.intact_texture
	building.damaged_texture = bootstrap.damaged_texture
	building.rubble_texture = bootstrap.rubble_texture
	building.display_size = bootstrap.display_size
	add_child_autofree(building)
	await get_tree().process_frame
	var cell_ids: PackedInt64Array = PackedInt64Array()
	for row: int in range(StructuralBuilding2D.ROWS):
		for column: int in range(StructuralBuilding2D.COLUMNS):
			cell_ids.append(building.get_cell(column, row).get_instance_id())
	var baseline_child_count: int = building.get_child_count()
	var configured_count: int = 0
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		for variant: StructuralBuildingVariant in district.building_variants:
			assert_true(building.apply_variant(variant))
			assert_eq(building.current_variant_id(), variant.variant_id)
			assert_eq(building.display_size, variant.display_size)
			assert_eq(building.get_child_count(), baseline_child_count)
			var cell_index: int = 0
			for row: int in range(StructuralBuilding2D.ROWS):
				for column: int in range(StructuralBuilding2D.COLUMNS):
					var cell: Destructible2D = building.get_cell(column, row)
					assert_eq(cell.get_instance_id(), cell_ids[cell_index])
					assert_eq(
						cell.get_material_profile().material_id,
						variant.material_id_at(column, row)
					)
					var sprite: Sprite2D = cell.get_node(^"IntactVisual") as Sprite2D
					assert_eq(sprite.texture, variant.intact_texture)
					assert_lt(
						(
							sprite.region_rect.size * sprite.scale
							- variant.display_size / Vector2(3.0, 2.0)
						).length(),
						0.01
					)
					cell_index += 1
			configured_count += 1
	assert_eq(configured_count, CityDistrictCatalog.BUILDING_VARIANT_COUNT)


func test_streaming_reuses_six_buildings_across_all_district_boundaries() -> void:
	var city: CitySlice = await _spawn_city()
	var building_ids: PackedInt64Array = PackedInt64Array()
	for building: StructuralBuilding2D in city.streamed_destructibles.buildings:
		building_ids.append(building.get_instance_id())
	var baseline_nodes: int = int(RuntimeBudget.snapshot(city).node_count)
	var live_facade_paths: Dictionary[String, bool] = {}
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		var district_facade_paths: Dictionary[String, bool] = {}
		for local_index: int in range(CityDistrictCatalog.VARIANTS_PER_DISTRICT):
			var logical_index: int = district.start_chunk + local_index
			await _move_to_logical_chunk(city, logical_index)
			var blueprint: CityChunkBlueprint = CityChunkBlueprint.generate(
				city.world_stream.run_seed,
				logical_index
			)
			var building: StructuralBuilding2D = city.building
			var sprite: Sprite2D = building.get_cell(0, 0).get_node(
				^"IntactVisual"
			) as Sprite2D
			assert_eq(building.current_variant_id(), blueprint.building_variant_id)
			assert_eq(building.get_meta(&"district_id"), blueprint.district_id)
			assert_eq(building.get_meta(&"district_index"), blueprint.district_index)
			assert_eq(building.display_size, blueprint.building_variant.display_size)
			assert_eq(sprite.texture, blueprint.building_variant.intact_texture)
			assert_eq(
				sprite.texture.resource_path,
				blueprint.building_variant.intact_texture.resource_path
			)
			district_facade_paths[sprite.texture.resource_path] = true
			live_facade_paths[sprite.texture.resource_path] = true
			for row: int in range(StructuralBuilding2D.ROWS):
				for column: int in range(StructuralBuilding2D.COLUMNS):
					assert_eq(
						building.get_material_profile(column, row).material_id,
						blueprint.building_variant.material_id_at(column, row)
					)
			assert_eq(int(RuntimeBudget.snapshot(city).node_count), baseline_nodes)
		assert_eq(
			district_facade_paths.size(),
			CityDistrictCatalog.VARIANTS_PER_DISTRICT,
			String(district.district_id)
		)
	assert_eq(live_facade_paths.size(), CityDistrictCatalog.BUILDING_VARIANT_COUNT)
	assert_eq(city.streamed_destructibles.active_building_count(), 6)
	assert_eq(city.streamed_destructibles.post_warm_creation_count, 0)
	for index: int in range(building_ids.size()):
		assert_eq(
			city.streamed_destructibles.buildings[index].get_instance_id(),
			building_ids[index]
		)


func test_stream_state_restores_only_to_the_matching_variant() -> void:
	var business: CityDistrictProfile = CityDistrictCatalog.districts()[0]
	var first: StructuralBuildingVariant = business.building_variants[0]
	var second: StructuralBuildingVariant = business.building_variants[1]
	var building: StructuralBuilding2D = StructuralBuilding2D.new()
	building.intact_texture = first.intact_texture
	building.damaged_texture = first.damaged_texture
	building.rubble_texture = first.rubble_texture
	building.display_size = first.display_size
	add_child_autofree(building)
	await get_tree().process_frame
	assert_true(building.apply_variant(first))
	var cell: Destructible2D = building.get_cell(0, 1)
	var event: DamageEvent = DamageEvent.new(
		92_001,
		null,
		20.0,
		&"jab_cross",
		cell.global_position,
		Vector2.RIGHT,
		250.0
	)
	assert_true(cell.receive_damage(event))
	var damaged_health: float = cell.current_health
	var pattern: BuildingDamagePattern2D = cell.get_node(^"DamagedVisual") as BuildingDamagePattern2D
	var signature: String = pattern.pattern_signature()
	var state: Dictionary = building.capture_stream_state()
	assert_eq(state.variant_id, first.variant_id)
	assert_true(building.apply_variant(first))
	building.restore_stream_state(state)
	assert_almost_eq(building.get_cell(0, 1).current_health, damaged_health, 0.01)
	var restored_pattern: BuildingDamagePattern2D = building.get_cell(0, 1).get_node(
		^"DamagedVisual"
	) as BuildingDamagePattern2D
	assert_eq(restored_pattern.pattern_signature(), signature)
	assert_true(building.apply_variant(second))
	building.restore_stream_state(state)
	assert_eq(
		building.get_cell(0, 1).current_health,
		building.get_cell(0, 1).max_health
	)
	assert_eq(building.destroyed_cell_count(), 0)


func test_forward_boundaries_emit_four_spatial_district_transitions() -> void:
	var city: CitySlice = await _spawn_city()
	var transitions: Array[Dictionary] = []
	city.world_stream.district_changed.connect(
		func(previous_id: StringName, district_id: StringName, chunk: int) -> void:
			transitions.append({
				"previous": previous_id,
				"district": district_id,
				"chunk": chunk,
			})
	)
	for logical_index: int in [8, 16, 24, 32]:
		await _move_to_logical_chunk(city, logical_index)
	assert_eq(transitions.size(), 4)
	assert_eq(transitions[0].previous, &"BUSINESS")
	assert_eq(transitions[0].district, &"RESIDENTIAL")
	assert_eq(transitions[0].chunk, 8)
	assert_eq(transitions[1].district, &"ENTERTAINMENT")
	assert_eq(transitions[2].district, &"MILITARY")
	assert_eq(transitions[3].district, &"ROYAL")
	assert_eq(transitions[3].chunk, 32)
	assert_eq(city.world_stream.current_district_id, &"ROYAL")
	assert_eq(city.world_stream.current_district().district_id, &"ROYAL")
	assert_eq(city.district_transition_banner.presentation_count, 4)
	assert_true(city.district_transition_banner.panel.visible)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	return city


func _move_to_logical_chunk(city: CitySlice, logical_index: int) -> void:
	city.robot.global_position.x = (
		city.world_stream.runtime_x_for_logical_index(logical_index) + 700.0
	)
	city.world_stream.advance_stream()
	await get_tree().physics_frame
	city.world_stream.advance_stream()
	await get_tree().process_frame
