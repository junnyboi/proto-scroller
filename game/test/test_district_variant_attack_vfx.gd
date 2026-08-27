# gdlint: disable=max-public-methods
extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func test_catalog_exactly_covers_twenty_variants_and_sixty_regions() -> void:
	assert_eq(EnemyAttackVfxCatalog.validation_errors(), PackedStringArray())
	assert_eq(EnemyAttackVfxCatalog.SPECS.size(), 20)
	assert_eq(EnemyAttackVfxCatalog.RANGED_IDS.size(), 9)
	var projectile_deliveries: int = 0
	var actor_deliveries: int = 0
	for archetype_id: StringName in EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS:
		assert_true(EnemyAttackVfxCatalog.has(archetype_id), archetype_id)
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		assert_eq(profile.get("attack_vfx_id"), archetype_id, archetype_id)
		for phase: StringName in [&"projectile", &"impact", &"attack"]:
			var phase_spec: Dictionary = EnemyAttackVfxCatalog.phase_spec(
				archetype_id,
				phase
			)
			assert_not_null(phase_spec.get("texture"), "%s %s" % [archetype_id, phase])
			assert_eq(
				Vector2i((phase_spec.texture as Texture2D).get_size()),
				EnemyAttackVfxCatalog.ATLAS_SIZE,
				"%s %s" % [archetype_id, phase]
			)
			assert_eq(
				(phase_spec.region as Rect2i).size,
				EnemyAttackVfxCatalog.CELL_SIZE,
				"%s %s" % [archetype_id, phase]
			)
			assert_gt((phase_spec.display_size as Vector2).x, 0.0, archetype_id)
		if EnemyAttackVfxCatalog.is_projectile_delivery(archetype_id):
			projectile_deliveries += 1
		else:
			actor_deliveries += 1
	assert_eq(projectile_deliveries, 9)
	assert_eq(actor_deliveries, 11)


func test_ranged_projectile_specs_preserve_kind_radius_and_unique_impacts() -> void:
	assert_true(ProjectileVisualCatalog.debug_validate())
	var projectile_keys: Dictionary[StringName, bool] = {}
	var impact_keys: Dictionary[StringName, bool] = {}
	for archetype_id: StringName in EnemyAttackVfxCatalog.RANGED_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var projectile_key: StringName = EnemyAttackVfxCatalog.projectile_key(archetype_id)
		var impact_key: StringName = EnemyAttackVfxCatalog.impact_key(archetype_id)
		assert_false(projectile_key.is_empty(), archetype_id)
		assert_false(impact_key.is_empty(), archetype_id)
		assert_false(projectile_keys.has(projectile_key), archetype_id)
		assert_false(impact_keys.has(impact_key), archetype_id)
		projectile_keys[projectile_key] = true
		impact_keys[impact_key] = true
		var projectile_spec: Dictionary = ProjectileVisualCatalog.spec(projectile_key)
		assert_eq(
			projectile_spec.get("damage_kind"),
			profile.get("projectile_kind"),
			archetype_id
		)
		assert_eq(
			float(projectile_spec.get("collision_radius_contract")),
			_expected_radius(StringName(profile.projectile_kind)),
			archetype_id
		)
		assert_eq(projectile_spec.get("impact_key"), impact_key, archetype_id)
		assert_false(
			EnemyAttackVfxCatalog.impact_spec_for_key(impact_key).is_empty(),
			archetype_id
		)


func test_projectile_pool_carries_custom_visual_and_dispatches_bounded_impact() -> void:
	var pool: ProjectilePool = ProjectilePool.new()
	add_child_autofree(pool)
	await get_tree().process_frame
	assert_eq(pool.total_count(), 32)
	assert_eq(pool.hostile_impacts.size(), ProjectilePool.HOSTILE_IMPACT_CAPACITY)
	var child_count: int = pool.get_child_count()
	for archetype_id: StringName in EnemyAttackVfxCatalog.RANGED_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var projectile_key: StringName = EnemyAttackVfxCatalog.projectile_key(archetype_id)
		var impact_key: StringName = EnemyAttackVfxCatalog.impact_key(archetype_id)
		var projectile: Projectile2D = pool.acquire(
			Vector2(50.0, 60.0),
			Vector2.RIGHT,
			float(profile.projectile_speed),
			float(profile.damage),
			null,
			1,
			StringName(profile.projectile_kind),
			projectile_key
		)
		assert_not_null(projectile, archetype_id)
		assert_eq(projectile.visual_key, projectile_key, archetype_id)
		assert_eq(projectile.impact_key, impact_key, archetype_id)
		assert_almost_eq(
			projectile.velocity.length(),
			float(profile.projectile_speed),
			0.001,
			archetype_id
		)
		assert_eq(projectile.damage, float(profile.damage), archetype_id)
		assert_eq(
			projectile.projectile_radius,
			_expected_radius(StringName(profile.projectile_kind)),
			archetype_id
		)
		pool._on_impact_requested(
			projectile,
			Vector2(400.0, 300.0),
			Vector2.RIGHT,
			StringName(profile.projectile_kind),
			impact_key
		)
		assert_gt(pool.active_hostile_impact_count(), 0, archetype_id)
		pool.release(projectile)
		assert_eq(projectile.visual_key, &"", archetype_id)
		assert_eq(projectile.impact_key, &"", archetype_id)
		pool.release_all()
		assert_eq(pool.active_hostile_impact_count(), 0, archetype_id)
		assert_eq(pool.get_child_count(), child_count, archetype_id)
	assert_eq(pool.total_count(), 32)


func test_procedural_ranged_variants_fire_their_custom_projectile_keys() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	city.encounter_runtime.release_all()
	city.projectile_root.release_all()
	for archetype_id: StringName in EnemyAttackVfxCatalog.RANGED_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var enemy: ProceduralEnemy = city.encounter_runtime.acquire(
			archetype_id,
			Vector2(1120.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(enemy, archetype_id)
		enemy.set_physics_process(false)
		enemy._begin_attack()
		assert_true(enemy.is_telegraphing(), archetype_id)
		assert_eq(
			city.projectile_root.reservation_count(
				StringName(profile.projectile_kind)
			),
			1,
			archetype_id
		)
		enemy._complete_attack()
		var projectile: Projectile2D = city.projectile_root.last_acquired
		assert_not_null(projectile, archetype_id)
		assert_eq(
			projectile.visual_key,
			EnemyAttackVfxCatalog.projectile_key(archetype_id),
			archetype_id
		)
		assert_eq(projectile.damage_type, profile.projectile_kind, archetype_id)
		assert_eq(projectile.damage, float(profile.damage), archetype_id)
		assert_eq(city.projectile_root.reservation_count(), 0, archetype_id)
		city.projectile_root.release_all()
		city.encounter_runtime.release(enemy)


func test_hostile_impact_cursor_wraps_without_node_growth_or_gameplay_denial() -> void:
	var pool: ProjectilePool = ProjectilePool.new()
	add_child_autofree(pool)
	await get_tree().process_frame
	var child_count: int = pool.get_child_count()
	var impact_key: StringName = EnemyAttackVfxCatalog.impact_key(&"regency_conservator")
	for impact_index: int in range(ProjectilePool.HOSTILE_IMPACT_CAPACITY * 3):
		pool._on_impact_requested(
			null,
			Vector2(float(impact_index) * 10.0, 200.0),
			Vector2.RIGHT,
			&"shell",
			impact_key
		)
	assert_eq(pool.active_hostile_impact_count(), ProjectilePool.HOSTILE_IMPACT_CAPACITY)
	assert_eq(pool.get_child_count(), child_count)
	assert_eq(pool.total_count(), 32)
	assert_eq(pool.denial_count, 0)
	pool.release_all()
	assert_eq(pool.active_hostile_impact_count(), 0)
	assert_eq(pool.get_child_count(), child_count)


func _expected_radius(kind: StringName) -> float:
	match kind:
		&"shell":
			return 9.0
		&"rocket":
			return 7.0
		_:
			return 5.0
