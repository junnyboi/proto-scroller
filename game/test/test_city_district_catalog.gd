extends GutTest


func test_catalog_has_five_districts_and_twenty_five_unique_buildings() -> void:
	var districts: Array[CityDistrictProfile] = CityDistrictCatalog.districts()
	assert_eq(districts.size(), CityDistrictCatalog.DISTRICT_COUNT)
	var district_ids: Dictionary[StringName, bool] = {}
	var variant_ids: Dictionary[StringName, bool] = {}
	for district: CityDistrictProfile in districts:
		assert_false(district_ids.has(district.district_id))
		district_ids[district.district_id] = true
		assert_eq(district.variant_count(), CityDistrictCatalog.VARIANTS_PER_DISTRICT)
		assert_eq(district.validation_errors().size(), 0)
		for variant: StructuralBuildingVariant in district.building_variants:
			assert_false(variant_ids.has(variant.variant_id))
			variant_ids[variant.variant_id] = true
			assert_eq(variant.material_ids.size(), StructuralBuilding2D.CELL_COUNT)
	assert_eq(variant_ids.size(), CityDistrictCatalog.BUILDING_VARIANT_COUNT)
	assert_eq(CityDistrictCatalog.validation_errors().size(), 0)


func test_forward_chunk_boundaries_select_the_authored_districts() -> void:
	var expectations: Dictionary[int, StringName] = {
		-64: &"BUSINESS",
		0: &"BUSINESS",
		6: &"BUSINESS",
		7: &"RESIDENTIAL",
		13: &"RESIDENTIAL",
		14: &"ENTERTAINMENT",
		20: &"ENTERTAINMENT",
		21: &"MILITARY",
		27: &"MILITARY",
		28: &"ROYAL",
		96: &"ROYAL",
	}
	for logical_index: int in expectations:
		var blueprint: CityChunkBlueprint = CityChunkBlueprint.generate(731, logical_index)
		assert_eq(blueprint.district_id, expectations[logical_index])
		assert_eq(
			blueprint.district_index,
			CityDistrictCatalog.district_index_for_chunk(logical_index)
		)


func test_blueprint_selection_is_replayable_and_order_independent() -> void:
	var indices: Array[int] = [-12, -1, 0, 4, 6, 7, 13, 14, 21, 28, 48]
	var forward: Dictionary[int, StringName] = {}
	for logical_index: int in indices:
		var blueprint: CityChunkBlueprint = CityChunkBlueprint.generate(917, logical_index)
		forward[logical_index] = blueprint.building_variant_id
	indices.reverse()
	for logical_index: int in indices:
		var replay: CityChunkBlueprint = CityChunkBlueprint.generate(917, logical_index)
		assert_eq(replay.building_variant_id, forward[logical_index])
		assert_eq(replay.district_id, replay.district_profile.district_id)
		assert_eq(replay.building_variant_id, replay.building_variant.variant_id)


func test_each_district_guarantees_its_complete_five_facade_roster() -> void:
	for run_seed: int in [0, 731, 917, 4401]:
		for district: CityDistrictProfile in CityDistrictCatalog.districts():
			var selected_ids: Dictionary[StringName, bool] = {}
			var selected_paths: Dictionary[String, bool] = {}
			for local_index: int in range(CityDistrictCatalog.VARIANTS_PER_DISTRICT):
				var logical_index: int = district.start_chunk + local_index
				var variant: StructuralBuildingVariant = (
					CityDistrictCatalog.variant_for_chunk(run_seed, logical_index)
				)
				assert_true(district.building_variants.has(variant))
				selected_ids[variant.variant_id] = true
				selected_paths[variant.intact_texture.resource_path] = true
			assert_eq(
				selected_ids.size(),
				CityDistrictCatalog.VARIANTS_PER_DISTRICT,
				"seed=%d district=%s" % [run_seed, district.district_id]
			)
			assert_eq(
				selected_paths.size(),
				CityDistrictCatalog.VARIANTS_PER_DISTRICT,
					"seed=%d district=%s" % [run_seed, district.district_id]
				)
	assert_eq(
		CityDistrictCatalog.variant_for_chunk(0, 0).variant_id,
		&"business_mercy_exchange_annex"
	)
	assert_eq(CityDistrictCatalog.TRANSITION_CORRIDOR_CHUNKS, 2)
	assert_true(CityDistrictCatalog.chunk_hosts_facade(4))
	assert_false(CityDistrictCatalog.chunk_hosts_facade(5))
	assert_false(CityDistrictCatalog.chunk_hosts_facade(6))
	assert_true(CityDistrictCatalog.chunk_hosts_facade(7))


func test_nonzero_run_seeds_rotate_the_opening_facade_without_losing_rosters() -> void:
	var opening_ids: Dictionary[StringName, bool] = {}
	for run_seed: int in range(1, 33):
		opening_ids[
			CityDistrictCatalog.variant_for_chunk(run_seed, 0).variant_id
		] = true
	assert_gt(opening_ids.size(), 1)
	assert_lte(opening_ids.size(), CityDistrictCatalog.VARIANTS_PER_DISTRICT)


func test_all_buildings_are_directly_addressable() -> void:
	var addressed: Dictionary[StringName, bool] = {}
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		for variant: StructuralBuildingVariant in district.building_variants:
			assert_eq(
				CityDistrictCatalog.variant_by_id(variant.variant_id),
				variant
			)
			addressed[variant.variant_id] = true
	assert_eq(addressed.size(), CityDistrictCatalog.BUILDING_VARIANT_COUNT)


func test_every_building_has_one_unique_grid_safe_production_facade() -> void:
	var facade_paths: Dictionary[String, bool] = {}
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		for variant: StructuralBuildingVariant in district.building_variants:
			var texture: Texture2D = variant.intact_texture
			var resource_path: String = texture.resource_path
			assert_true(
				resource_path.begins_with(
					"res://art/city/destructibles/districts/"
				)
			)
			assert_false(facade_paths.has(resource_path))
			facade_paths[resource_path] = true
			assert_eq(posmod(texture.get_width(), 6), 0)
			assert_eq(posmod(texture.get_height(), 6), 0)
			assert_eq(variant.damaged_texture, variant.intact_texture)
	assert_eq(facade_paths.size(), CityDistrictCatalog.BUILDING_VARIANT_COUNT)
