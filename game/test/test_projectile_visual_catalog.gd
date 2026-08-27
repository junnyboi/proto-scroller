extends GutTest

const EXPECTED_SPECS: Dictionary = {
	&"enemy_bullet": {
		"source_size": Vector2i(96, 32),
		"display_size": Vector2(36.0, 12.0),
		"radius": 5.0,
		"impact_key": &"enemy_bullet_impact",
		"impact_atlas_size": Vector2i(240, 64),
		"impact_cell_size": Vector2i(48, 32),
	},
	&"enemy_shell": {
		"source_size": Vector2i(256, 128),
		"display_size": Vector2(36.0, 18.0),
		"radius": 9.0,
		"impact_key": &"enemy_shell_impact",
		"impact_atlas_size": Vector2i(320, 96),
		"impact_cell_size": Vector2i(64, 48),
	},
	&"enemy_rocket_direct": {
		"source_size": Vector2i(256, 96),
		"display_size": Vector2(42.0, 16.0),
		"radius": 7.0,
		"impact_key": &"enemy_rocket_direct_impact",
		"impact_atlas_size": Vector2i(480, 128),
		"impact_cell_size": Vector2i(96, 64),
	},
	&"enemy_rocket_salvo": {
		"source_size": Vector2i(192, 72),
		"display_size": Vector2(36.0, 14.0),
		"radius": 7.0,
		"impact_key": &"enemy_rocket_salvo_impact",
		"impact_atlas_size": Vector2i(360, 112),
		"impact_cell_size": Vector2i(72, 56),
	},
}


func test_catalog_specs_load_and_validate_declared_contracts() -> void:
	assert_true(ProjectileVisualCatalog.debug_validate())
	assert_eq(ProjectileVisualCatalog.SPECS.size(), 4)
	for visual_key: StringName in EXPECTED_SPECS:
		assert_true(ProjectileVisualCatalog.has(visual_key))
		var item: Dictionary = ProjectileVisualCatalog.spec(visual_key)
		var expected: Dictionary = EXPECTED_SPECS[visual_key]
		var texture: Texture2D = item.get("texture") as Texture2D
		assert_not_null(texture)
		assert_eq(Vector2i(texture.get_size()), expected.source_size)
		assert_eq(item.get("source_size"), expected.source_size)
		assert_eq(item.get("display_size"), expected.display_size)
		assert_eq(float(item.get("collision_radius_contract")), expected.radius)
		assert_eq(item.get("trail_mode"), ProjectileVisualCatalog.TrailMode.NONE)
		assert_eq(item.get("impact_key"), expected.impact_key)
		var impact_spec: Dictionary = EnemyAttackVfxCatalog.impact_spec_for_key(
			expected.impact_key
		)
		var impact_texture: Texture2D = impact_spec.get("texture") as Texture2D
		assert_not_null(impact_texture)
		assert_eq(Vector2i(impact_texture.get_size()), expected.impact_atlas_size)
		assert_eq(impact_spec.get("frame_cell_size"), expected.impact_cell_size)
		assert_eq(int(impact_spec.get("frame_count")), 10)
		assert_gt(float(impact_spec.get("playback_fps")), 0.0)
		assert_gt((impact_spec.get("display_size") as Vector2).x, 0.0)
	assert_false(ProjectileVisualCatalog.has(&"missing"))
	assert_true(ProjectileVisualCatalog.spec(&"missing").is_empty())


func test_projectile_defaults_keep_radius_and_rotate_authored_visual_to_velocity() -> void:
	var projectile: Projectile2D = await _spawn_projectile()
	var cases: Array[Dictionary] = [
		{"kind": &"bullet", "key": &"enemy_bullet", "radius": 5.0},
		{"kind": &"shell", "key": &"enemy_shell", "radius": 9.0},
		{"kind": &"rocket", "key": &"enemy_rocket_direct", "radius": 7.0},
	]
	var directions: Array[Vector2] = [
		Vector2.RIGHT,
		Vector2.LEFT,
		Vector2.UP,
		Vector2.DOWN,
		Vector2(1.0, 1.0).normalized(),
	]
	for item: Dictionary in cases:
		for direction: Vector2 in directions:
			projectile.activate(
				Vector2.ZERO,
				direction,
				400.0,
				10.0,
				null,
				1,
				item.kind
			)
			assert_eq(projectile.visual_key, item.key)
			assert_false(projectile.impact_key.is_empty())
			assert_almost_eq(projectile.visual_angle(), direction.angle(), 0.0001)
			assert_eq(projectile.projectile_radius, item.radius)
			var collision: CircleShape2D = (
				projectile.get_node(^"CollisionShape2D").shape as CircleShape2D
			)
			assert_eq(collision.radius, item.radius)


func test_explicit_salvo_key_resets_cleanly_and_machine_gun_path_is_preserved() -> void:
	var projectile: Projectile2D = await _spawn_projectile()
	projectile.activate(
		Vector2(10.0, 20.0),
		Vector2.UP,
		520.0,
		12.0,
		null,
		3,
		&"rocket",
		ProjectileVisualCatalog.ENEMY_ROCKET_SALVO
	)
	assert_eq(projectile.visual_key, ProjectileVisualCatalog.ENEMY_ROCKET_SALVO)
	assert_eq(projectile.impact_key, &"enemy_rocket_salvo_impact")
	assert_eq(projectile.projectile_radius, 7.0)
	projectile.modulate = Color.RED
	projectile.deactivate()
	assert_false(projectile.active)
	assert_eq(projectile.visual_key, &"")
	assert_eq(projectile.impact_key, &"")
	assert_eq(projectile.velocity, Vector2.ZERO)
	assert_eq(projectile.collision_mask, 0)
	assert_null(projectile.source)
	assert_eq(projectile.lifetime, 2.5)
	assert_eq(projectile.modulate, Color.WHITE)
	projectile.activate(
		Vector2.ZERO, Vector2.RIGHT, 900.0, 5.0, null, 1, &"machine_gun"
	)
	assert_eq(projectile.visual_key, &"")
	assert_eq(projectile.projectile_radius, 4.0)
	assert_same(
		Projectile2D.MACHINE_GUN_ROUND_TEXTURE,
		load("res://art/player/weapons/machine_gun_round.png")
	)


func test_pool_carries_optional_visual_key_without_changing_capacity_or_reservations() -> void:
	var pool: ProjectilePool = ProjectilePool.new()
	add_child_autofree(pool)
	await get_tree().process_frame
	assert_eq(pool.total_count(), 32)
	var child_count: int = pool.get_child_count()
	var direct: Projectile2D = pool.acquire(
		Vector2.ZERO, Vector2.RIGHT, 440.0, 8.0, null, 1, &"rocket"
	)
	assert_not_null(direct)
	assert_eq(direct.visual_key, ProjectileVisualCatalog.ENEMY_ROCKET_DIRECT)
	var reservation_id: int = pool.reserve(&"rocket")
	assert_gt(reservation_id, 0)
	var salvo: Projectile2D = pool.acquire_reserved(
		reservation_id,
		Vector2.ZERO,
		Vector2.LEFT,
		430.0,
		6.0,
		null,
		1,
		&"rocket",
		ProjectileVisualCatalog.ENEMY_ROCKET_SALVO
	)
	assert_not_null(salvo)
	assert_eq(salvo.visual_key, ProjectileVisualCatalog.ENEMY_ROCKET_SALVO)
	assert_eq(pool.reservation_count(&"rocket"), 0)
	assert_eq(pool.get_child_count(), child_count)
	assert_eq(pool.total_count(), 32)
	pool.release_all()
	assert_eq(pool.active_count(), 0)
	assert_eq(salvo.visual_key, &"")
	assert_eq(pool.hostile_impact_slot_count(), ProjectilePool.HOSTILE_IMPACT_CAPACITY)


func test_four_generated_impact_families_animate_in_fixed_pool() -> void:
	var pool: ProjectilePool = ProjectilePool.new()
	add_child_autofree(pool)
	await get_tree().process_frame
	var child_count: int = pool.get_child_count()
	for visual_key: StringName in EXPECTED_SPECS:
		var expected: Dictionary = EXPECTED_SPECS[visual_key]
		var projectile: Projectile2D = pool.acquire(
			Vector2.ZERO,
			Vector2(1.0, 1.0).normalized(),
			440.0,
			8.0,
			null,
			1,
			_kind_for_visual_key(visual_key),
			visual_key
		)
		assert_not_null(projectile, visual_key)
		pool._on_impact_requested(
			projectile,
			Vector2(400.0, 300.0),
			projectile.velocity.normalized(),
			projectile.damage_type,
			expected.impact_key
		)
		var impact: WeaponImpactEffect2D = _active_impact_for_key(
			pool, expected.impact_key
		)
		assert_not_null(impact, visual_key)
		assert_eq(impact.current_frame, 0, visual_key)
		assert_almost_eq(impact.rotation, PI * 0.25, 0.0001, visual_key)
		assert_false(impact.particles.visible, visual_key)
		var impact_spec: Dictionary = EnemyAttackVfxCatalog.impact_spec_for_key(
			expected.impact_key
		)
		var playback_fps: float = float(impact_spec.playback_fps)
		impact._process(3.2 / playback_fps)
		assert_eq(impact.current_frame, 3, visual_key)
		impact._process(7.0 / playback_fps)
		assert_false(impact.active, visual_key)
		assert_eq(impact.current_frame, 0, visual_key)
		pool.release(projectile)
		assert_eq(pool.get_child_count(), child_count, visual_key)
	assert_not_same(
		EnemyAttackVfxCatalog.impact_spec_for_key(
			&"enemy_rocket_direct_impact"
		).texture,
		EnemyAttackVfxCatalog.impact_spec_for_key(
			&"enemy_rocket_salvo_impact"
		).texture
	)
	assert_eq(pool.total_count(), 32)
	assert_eq(pool.denial_count, 0)
	pool.release_all()
	assert_eq(pool.active_hostile_impact_count(), 0)


func _spawn_projectile() -> Projectile2D:
	var projectile: Projectile2D = Projectile2D.new()
	add_child_autofree(projectile)
	await get_tree().process_frame
	projectile.set_physics_process(false)
	return projectile


func _active_impact_for_key(
	pool: ProjectilePool,
	impact_key: StringName
) -> WeaponImpactEffect2D:
	for impact: WeaponImpactEffect2D in pool.hostile_impacts:
		if impact.active and impact.visual_key == impact_key:
			return impact
	return null


func _kind_for_visual_key(visual_key: StringName) -> StringName:
	if visual_key == ProjectileVisualCatalog.ENEMY_SHELL:
		return &"shell"
	if visual_key in [
		ProjectileVisualCatalog.ENEMY_ROCKET_DIRECT,
		ProjectileVisualCatalog.ENEMY_ROCKET_SALVO,
	]:
		return &"rocket"
	return &"bullet"
