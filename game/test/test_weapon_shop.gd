extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_catalog_has_three_unique_shop_only_products_per_district() -> void:
	assert_eq(WeaponShopCatalog.validation_errors(), PackedStringArray())
	var level_ids: Dictionary[StringName, bool] = {}
	var level_catalog: UpgradeCatalog = load(
		"res://resources/upgrades/upgrade_catalog.tres"
	) as UpgradeCatalog
	for profile: UpgradeProfile in level_catalog.profiles:
		level_ids[profile.upgrade_id] = true
	var product_ids: Dictionary[StringName, bool] = {}
	for district: CityDistrictProfile in CityDistrictCatalog.districts():
		var products: Array[WeaponShopProduct] = WeaponShopCatalog.products_for(
			district.district_id
		)
		assert_eq(products.size(), 3)
		for product: WeaponShopProduct in products:
			assert_false(product_ids.has(product.product_id))
			assert_false(level_ids.has(product.product_id))
			product_ids[product.product_id] = true
	assert_eq(product_ids.size(), CityDistrictCatalog.DISTRICT_COUNT * 3)


func test_transition_opens_shop_banks_pending_and_defers_banner() -> void:
	var city: CitySlice = await _spawn_city()
	var score: RunScore = city.rampage_session.run_score
	score.safe_score = 6000
	score.pending_bank.value = 1000
	city._on_score_changed(score.score, 0)
	var district: CityDistrictProfile = CityDistrictCatalog.district_for_chunk(8)
	var banner_count: int = city.district_transition_banner.presentation_count
	assert_true(city.weapon_shop_assembler.queue_transition(&"BUSINESS", district, 8))
	await get_tree().process_frame
	var session: WeaponShopSession = city.weapon_shop_assembler.session
	assert_true(session.active)
	assert_true(city.weapon_shop_assembler.overlay.visible)
	assert_true(city.urban_siege.pause_coordinator.is_paused())
	assert_eq(score.pending_bank.value, 0)
	assert_eq(score.safe_score, 7000)
	assert_eq(city.district_transition_banner.presentation_count, banner_count)
	assert_true(city.upgrade_assembler.session.presentation_blocked)
	assert_true(session.close_shop())
	assert_false(city.weapon_shop_assembler.overlay.visible)
	assert_false(city.urban_siege.pause_coordinator.is_paused())
	assert_eq(city.district_transition_banner.presentation_count, banner_count + 1)
	assert_false(city.upgrade_assembler.session.presentation_blocked)
	var business: CityDistrictProfile = CityDistrictCatalog.district_for_chunk(7)
	assert_false(
		city.weapon_shop_assembler.queue_transition(&"RESIDENTIAL", business, 7)
	)


func test_purchase_deducts_score_repairs_once_and_updates_hud() -> void:
	var city: CitySlice = await _spawn_city()
	var score: RunScore = city.rampage_session.run_score
	score.safe_score = 9000
	city._on_score_changed(score.score, 0)
	city.robot.current_health = 30.0
	city.robot.health_changed.emit(city.robot.current_health, city.robot.max_health)
	var expected_health: float = minf(
		city.robot.max_health,
		30.0 + city.robot.max_health * 0.50
	)
	var district: CityDistrictProfile = CityDistrictCatalog.district_for_chunk(8)
	assert_true(city.weapon_shop_assembler.queue_transition(&"BUSINESS", district, 8))
	await get_tree().process_frame
	var session: WeaponShopSession = city.weapon_shop_assembler.session
	assert_true(session.purchase(&"patchwork_nanoweld"))
	assert_eq(score.score, 6200)
	assert_almost_eq(city.robot.current_health, expected_health, 0.01)
	assert_eq(city.gameplay_hud.score_label.text, "00006200")
	assert_eq(session.product_status(session.active_products[0]), &"sold")
	assert_false(session.purchase(&"patchwork_nanoweld"))
	assert_eq(score.score, 6200)


func test_insufficient_score_and_full_health_reject_without_spending() -> void:
	var city: CitySlice = await _spawn_city()
	var score: RunScore = city.rampage_session.run_score
	score.safe_score = 1000
	var district: CityDistrictProfile = CityDistrictCatalog.district_for_chunk(8)
	assert_true(city.weapon_shop_assembler.queue_transition(&"BUSINESS", district, 8))
	await get_tree().process_frame
	var session: WeaponShopSession = city.weapon_shop_assembler.session
	assert_eq(session.product_status(session.active_products[0]), &"healthy")
	assert_eq(session.product_status(session.active_products[1]), &"funds")
	assert_false(session.purchase(&"patchwork_nanoweld"))
	assert_false(session.purchase(&"scrapheap_magnetics"))
	assert_eq(score.score, 1000)


func test_shop_effects_scale_melee_weapons_cooldowns_and_incoming_damage() -> void:
	var robot: GiantRobotController = GiantRobotController.new()
	add_child_autofree(robot)
	await get_tree().process_frame
	var effects: WeaponShopUpgradeRuntime = WeaponShopUpgradeRuntime.new()
	add_child_autofree(effects)
	effects.setup(robot)
	assert_true(effects.apply_product(_product(&"crownfire_protocol", &"ROYAL")))
	assert_true(effects.apply_product(_product(&"chronoseal_governor", &"ROYAL")))
	assert_true(effects.apply_product(_product(&"sovereign_aegis", &"ROYAL")))
	var base: AttackSpec = AttackSpec.new(
		AttackSpec.Mode.GROUND_SMASH,
		51,
		1,
		0.0,
		0.0,
		0.0,
		0.0,
		100.0,
		120.0,
		900.0,
		Vector2(200.0, 200.0),
		Vector2.ZERO
	)
	var decorated: AttackSpec = effects.decorate_attack(base)
	assert_almost_eq(decorated.actor_damage, 125.0, 0.01)
	assert_almost_eq(decorated.structural_damage, 150.0, 0.01)
	assert_almost_eq(effects.scale_weapon_cooldown(1.0), 0.80, 0.001)
	var before: float = robot.current_health
	assert_true(robot.receive_damage(DamageEvent.new(99, null, 40.0)))
	assert_almost_eq(robot.current_health, before - 34.0, 0.01)


func test_portrait_overlay_keeps_three_cards_and_continue_inside_viewport() -> void:
	var city: CitySlice = await _spawn_city()
	city.rampage_session.run_score.safe_score = 20_000
	var district: CityDistrictProfile = CityDistrictCatalog.district_for_chunk(16)
	assert_true(city.weapon_shop_assembler.queue_transition(&"RESIDENTIAL", district, 16))
	await get_tree().process_frame
	get_window().content_scale_size = Vector2i(720, 1280)
	get_tree().root.size = Vector2i(720, 1280)
	await get_tree().process_frame
	var overlay: WeaponShopOverlay = city.weapon_shop_assembler.overlay
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(get_tree().root.size))
	assert_eq(overlay.cards.size(), 3)
	for card: WeaponShopCard in overlay.cards:
		assert_true(viewport_rect.encloses(card.get_global_rect()))
	assert_false(overlay.cards[0].get_global_rect().intersects(
		overlay.cards[1].get_global_rect()
	))
	assert_false(overlay.cards[1].get_global_rect().intersects(
		overlay.cards[2].get_global_rect()
	))
	assert_true(viewport_rect.encloses(overlay.continue_button.get_global_rect()))
	get_window().content_scale_size = Vector2i(1280, 720)
	get_tree().root.size = Vector2i(1280, 720)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	return city


func _product(product_id: StringName, district_id: StringName) -> WeaponShopProduct:
	for product: WeaponShopProduct in WeaponShopCatalog.products_for(district_id):
		if product.product_id == product_id:
			return product
	return null
