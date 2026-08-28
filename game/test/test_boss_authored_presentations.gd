extends GutTest

const CHOIR_TEST_TEXTURE: Texture2D = preload(
	"res://art/city/enemies/archetypes/02-bulwark-riot-trooper.png"
)


func test_area_roles_keep_geometry_and_echo_presentation_collisionless() -> void:
	var pool: BossUtilityPool = BossUtilityPool.new()
	add_child_autofree(pool)
	var lane: BossAttackArea2D = pool.lane_damage_areas[0]
	var line: BossAttackArea2D = pool.line_areas[0]
	assert_false(pool.arena_adapter.visible)
	assert_same(lane.get_parent(), pool.attack_presentation_root)
	assert_same(line.get_parent(), pool.attack_presentation_root)
	assert_false(pool.attack_presentation_root.z_as_relative)
	assert_eq(
		pool.attack_presentation_root.z_index,
		BossUtilityPool.ATTACK_PRESENTATION_Z_INDEX
	)
	assert_gt(pool.attack_presentation_root.z_index, pool.rig.z_index)
	assert_lt(pool.attack_presentation_root.z_index, 80)
	assert_eq(lane.presentation_role, BossAttackArea2D.PresentationRole.LANE_PLATE)
	assert_eq(line.presentation_role, BossAttackArea2D.PresentationRole.LINE_BEAM)
	assert_not_null(lane.authored_texture())
	assert_not_null(line.authored_texture())
	assert_false(lane.uses_procedural_rendering())
	assert_false(line.uses_procedural_rendering())
	assert_false(pool.radial_shockwave.uses_procedural_rendering())
	var lane_size: Vector2 = Vector2(272.0, 112.0)
	lane.configure_footprint(
		Vector2(128.0, 64.0), lane_size, BossAttackArea2D.VisualState.ARMED, &"LANE"
	)
	var collision: CollisionShape2D = lane.get_node(^"Collision") as CollisionShape2D
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	assert_eq(rectangle.size, lane_size)
	assert_false(collision.disabled)
	assert_true(lane.monitoring)
	assert_eq(lane.collision_mask, BossAttackArea2D.ROBOT_LAYER)
	assert_true(lane.is_visible_in_tree())
	var echo: BossAttackArea2D = pool.line_areas[1]
	echo.configure_footprint(
		Vector2.ZERO,
		Vector2(920.0, 300.0),
		BossAttackArea2D.VisualState.ARMED,
		&"ECHO_TESTIMONY"
	)
	collision = echo.get_node(^"Collision") as CollisionShape2D
	rectangle = collision.shape as RectangleShape2D
	assert_eq(echo.presentation_role, BossAttackArea2D.PresentationRole.ECHO_PRESENTATION)
	assert_null(echo.authored_texture())
	assert_false(echo.uses_procedural_rendering())
	assert_eq(rectangle.size, Vector2(920.0, 300.0))
	assert_true(collision.disabled)
	assert_false(echo.monitoring)
	assert_eq(echo.collision_mask, 0)
	assert_false(echo.contains_world_point(Vector2.ZERO))
	var generic: BossAttackArea2D = BossAttackArea2D.new()
	add_child_autofree(generic)
	assert_false(generic.uses_procedural_rendering())
	for pod: BossPodVisual2D in pool.pod_visuals:
		assert_false(pod.uses_procedural_rendering())


func test_mimesis_markers_reset_before_choir_reuse() -> void:
	var pool: BossUtilityPool = BossUtilityPool.new()
	add_child_autofree(pool)
	var recorder: MotionEchoRecorder = pool.motion_echo_recorder
	recorder.activate()
	recorder.record_motion(Vector2(64.0, 128.0), 0.0)
	var marker_sprite: Sprite2D = pool.marker_presentations[0]
	assert_eq(marker_sprite.texture, BossUtilityPool.MIMESIS_AFTERIMAGE_TEXTURE)
	assert_true(marker_sprite.visible)
	assert_true(recorder.arm_marker(0, &"ARMED_AFTERIMAGE"))
	assert_eq(
		marker_sprite.scale,
		MotionEchoRecorder.SELECTED_DISPLAY_SIZE
		/ BossUtilityPool.MIMESIS_AFTERIMAGE_TEXTURE.get_size()
	)
	assert_true(pool.configure_royal_echo_presentation(
		0, CHOIR_TEST_TEXTURE, Vector2.ZERO, Vector2(78.0, 112.0)
	))
	assert_eq(marker_sprite.texture, CHOIR_TEST_TEXTURE)
	pool.hide_royal_echo_presentations()
	assert_eq(marker_sprite.texture, BossUtilityPool.MIMESIS_AFTERIMAGE_TEXTURE)
	assert_false(marker_sprite.visible)
	assert_false(pool.markers[0].visible)


func test_utility_records_are_prewarmed_collisionless_and_fully_reset() -> void:
	var pool: BossUtilityPool = BossUtilityPool.new()
	add_child_autofree(pool)
	assert_eq(pool.reclamation_anchor_records.size(), 3)
	assert_eq(pool.projection_slots.size(), 4)
	var roles: Array[BossUtilityPool.UtilityPresentationRole] = [
		BossUtilityPool.UtilityPresentationRole.ARCHIVE_TREASURY,
		BossUtilityPool.UtilityPresentationRole.EVACUATION_CRADLE,
		BossUtilityPool.UtilityPresentationRole.EXTRACTION_CLAMP,
		BossUtilityPool.UtilityPresentationRole.SHOW_CONTROL_CABINET,
		BossUtilityPool.UtilityPresentationRole.RUBBLE_BED,
		BossUtilityPool.UtilityPresentationRole.FREIGHT_RECLAMATION_ANCHOR,
		BossUtilityPool.UtilityPresentationRole.SERAPH_PROJECTION,
	]
	for role: BossUtilityPool.UtilityPresentationRole in roles:
		var record: Node2D = (
			pool.projection_slots[0]
			if role == BossUtilityPool.UtilityPresentationRole.SERAPH_PROJECTION
			else pool.reclamation_anchor_records[0]
		)
		assert_eq(record.get_child_count(), 1)
		assert_true(pool.configure_utility_presentation(record, role))
		var sprite: Sprite2D = record.get_child(0) as Sprite2D
		assert_not_null(sprite.texture)
		assert_true(sprite.visible)
		assert_eq(record.find_children("*", "CollisionObject2D", true, false).size(), 0)
	assert_eq(pool.post_warm_creation_count, 0)
	var token: int = pool.begin_generation()
	assert_true(pool.cleanup_generation(token))
	for record: Node2D in pool.reclamation_anchor_records + pool.projection_slots:
		var sprite: Sprite2D = record.get_child(0) as Sprite2D
		assert_null(sprite.texture)
		assert_eq(sprite.scale, Vector2.ONE)
		assert_eq(sprite.modulate, Color.WHITE)
		assert_false(sprite.visible)
		assert_eq(
			int(record.get_meta(&"presentation_role")),
			BossUtilityPool.UtilityPresentationRole.NONE
		)


func test_choir_pylon_preserves_existing_scale_and_tint_contract() -> void:
	var pool: BossUtilityPool = BossUtilityPool.new()
	add_child_autofree(pool)
	var sprite: Sprite2D = pool.pylon_presentations[0].get_child(0) as Sprite2D
	assert_eq(sprite.texture, BossUtilityPool.CHOIR_PYLON_TEXTURE)
	assert_eq(sprite.scale, Vector2(0.68, 0.68))
	assert_eq(sprite.modulate, Color(0.72, 1.0, 0.95, 0.96))
	assert_true(pool.set_royal_pylon_active(0, true))
	assert_eq(sprite.scale, Vector2(0.80, 0.80))
	assert_eq(sprite.modulate, Color(1.0, 0.78, 0.28, 1.0))
