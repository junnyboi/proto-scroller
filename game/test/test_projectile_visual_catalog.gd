extends GutTest

const EXPECTED_SPECS: Dictionary = {
	&"enemy_bullet": {
		"source_size": Vector2i(96, 32),
		"display_size": Vector2(36.0, 12.0),
		"radius": 5.0,
	},
	&"enemy_shell": {
		"source_size": Vector2i(256, 128),
		"display_size": Vector2(36.0, 18.0),
		"radius": 9.0,
	},
	&"enemy_rocket_direct": {
		"source_size": Vector2i(256, 96),
		"display_size": Vector2(42.0, 16.0),
		"radius": 7.0,
	},
	&"enemy_rocket_salvo": {
		"source_size": Vector2i(192, 72),
		"display_size": Vector2(36.0, 14.0),
		"radius": 7.0,
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
	assert_eq(projectile.projectile_radius, 7.0)
	projectile.modulate = Color.RED
	projectile.deactivate()
	assert_false(projectile.active)
	assert_eq(projectile.visual_key, &"")
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


func _spawn_projectile() -> Projectile2D:
	var projectile: Projectile2D = Projectile2D.new()
	add_child_autofree(projectile)
	await get_tree().process_frame
	projectile.set_physics_process(false)
	return projectile
