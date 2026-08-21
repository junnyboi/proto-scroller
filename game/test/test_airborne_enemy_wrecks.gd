extends GutTest

const AIRBORNE_ARCHETYPES: Array[StringName] = [
	&"needle",
	&"hound",
	&"kestrel",
	&"shrike",
	&"hive",
]


func test_every_airborne_archetype_spawns_as_a_physical_crash() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)
	var wreck_root: Node2D = Node2D.new()
	root.add_child(wreck_root)
	var factory: EnemyRemainsFactory = EnemyRemainsFactory.new()
	factory.setup(wreck_root, null, null, null)
	root.add_child(factory)
	await get_tree().process_frame

	for index: int in range(AIRBORNE_ARCHETYPES.size()):
		var archetype_id: StringName = AIRBORNE_ARCHETYPES[index]
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		assert_true(bool(profile.get("airborne", false)), String(archetype_id))
		var enemy: ProceduralEnemy = _airborne_enemy(archetype_id, profile)
		root.add_child(enemy)
		await get_tree().process_frame
		enemy.global_position = Vector2(300.0 + index * 260.0, 120.0)
		var event: DamageEvent = DamageEvent.new(
			9100 + index,
			null,
			999.0,
			&"impact",
			enemy.global_position,
			Vector2.LEFT,
			240.0
		)
		var wreck: EnemyWreck2D = factory.spawn_wreck(enemy, event)
		assert_not_null(wreck, String(archetype_id))
		assert_true(wreck is RigidBody2D, String(archetype_id))
		assert_true(wreck.is_crashing(), String(archetype_id))
		assert_false(wreck.freeze, String(archetype_id))
		assert_gt(wreck.gravity_scale, 1.0, String(archetype_id))
		assert_gt(wreck.linear_velocity.y, 0.0, String(archetype_id))
		assert_gt(absf(wreck.angular_velocity), 1.0, String(archetype_id))


func test_airborne_wreck_falls_and_lands_on_the_remains_ground_layer() -> void:
	var ground: StaticBody2D = StaticBody2D.new()
	ground.collision_layer = EnemyWreck2D.REMAINS_GROUND_LAYER
	ground.collision_mask = 0
	ground.position = Vector2(640.0, 540.0)
	var ground_shape: CollisionShape2D = CollisionShape2D.new()
	var ground_rectangle: RectangleShape2D = RectangleShape2D.new()
	ground_rectangle.size = Vector2(1600.0, 40.0)
	ground_shape.shape = ground_rectangle
	ground.add_child(ground_shape)
	add_child_autofree(ground)

	var wreck: EnemyWreck2D = EnemyWreck2D.new()
	add_child_autofree(wreck)
	await get_tree().process_frame
	var start_position: Vector2 = Vector2(640.0, 120.0)
	wreck.activate(
		&"helicopter",
		null,
		Vector2(235.0, 72.0),
		Vector2(210.0, 58.0),
		38.0,
		85.0,
		start_position,
		DamageEvent.new(
			9200,
			null,
			999.0,
			&"impact",
			start_position,
			Vector2.LEFT,
			240.0
		),
		true
	)

	for frame: int in range(90):
		await get_tree().physics_frame
		if not wreck.is_crashing():
			break

	assert_gt(wreck.global_position.y, start_position.y + 200.0)
	assert_false(wreck.is_crashing())
	assert_eq(wreck.crash_landing_count, 1)
	assert_true(wreck.can_sleep)


func _airborne_enemy(archetype_id: StringName, profile: Dictionary) -> ProceduralEnemy:
	var enemy: ProceduralEnemy = ProceduralEnemy.new()
	var visual: Sprite2D = Sprite2D.new()
	visual.name = "Visual"
	enemy.add_child(visual)
	enemy.configure_archetype(archetype_id, profile)
	return enemy
