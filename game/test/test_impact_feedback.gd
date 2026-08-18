extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")


func after_each() -> void:
	Engine.time_scale = 1.0


func test_hit_stop_clamps_deduplicates_and_restores_prior_scale() -> void:
	var prior_scale: float = 0.75
	Engine.time_scale = prior_scale
	var lease: HitStopLease = HitStopLease.new()
	add_child_autofree(lease)
	await get_tree().process_frame
	assert_true(lease.request(5, 71))
	assert_eq(lease.last_duration_ms, 25)
	assert_almost_eq(Engine.time_scale, HitStopLease.HIT_STOP_SCALE, 0.001)
	assert_false(lease.request(100, 71))
	assert_eq(lease.ignored_request_count, 1)
	lease.cancel_and_restore()
	assert_almost_eq(Engine.time_scale, prior_scale, 0.001)


func test_camera_impact_spring_is_bounded_and_settles_exactly() -> void:
	var rig: CameraRig = CameraRig.new()
	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera2D"
	rig.add_child(camera)
	add_child_autofree(rig)
	await get_tree().process_frame
	rig.add_impact_impulse(Vector2(500.0, -300.0))
	for step: int in range(420):
		rig._physics_process(1.0 / 60.0)
		assert_lte(rig.impact_offset.length(), rig.maximum_impact_offset + 0.001)
	assert_eq(rig.impact_offset, Vector2.ZERO)
	assert_eq(rig.impact_velocity, Vector2.ZERO)
	assert_eq(camera.offset, Vector2.ZERO)


func test_pool_stays_at_eight_and_tracks_drop_and_recycle() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)
	var audio_root: Node2D = Node2D.new()
	root.add_child(audio_root)
	var pool: ImpactFeedbackPool = ImpactFeedbackPool.new()
	pool.setup(root, audio_root)
	root.add_child(pool)
	await get_tree().process_frame
	var profile: StructuralMaterialProfile = StructuralMaterialProfile.concrete()
	for request_index: int in range(8):
		assert_not_null(pool.spawn_particles(Vector2.ZERO, Vector2.RIGHT, 300.0, profile, 5))
		assert_not_null(pool.play_audio(profile, Vector2.ZERO, 300.0, true, 5))
	assert_null(pool.spawn_particles(Vector2.ZERO, Vector2.RIGHT, 300.0, profile, 1))
	assert_null(pool.play_audio(profile, Vector2.ZERO, 300.0, true, 1))
	assert_not_null(pool.spawn_particles(Vector2.ZERO, Vector2.RIGHT, 300.0, profile, 6))
	assert_not_null(pool.play_audio(profile, Vector2.ZERO, 300.0, true, 6))
	assert_eq(pool.particle_child_count(), 8)
	assert_eq(pool.audio_child_count(), 8)
	assert_eq(pool.particle_drop_count, 1)
	assert_eq(pool.audio_drop_count, 1)
	assert_eq(pool.particle_recycle_count, 1)
	assert_eq(pool.audio_recycle_count, 1)


func test_accepted_events_coalesce_to_one_strongest_feedback_transaction() -> void:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	for enemy: EnemyActor2D in [city.soldier, city.tank, city.helicopter]:
		enemy.set_physics_process(false)
	var damage_event: GameplayEvent = GameplayEvent.new(
		&"feedback_damage",
		9001,
		GameplayEvent.Kind.PROP_DESTROYED,
		GameplayEvent.PROP_BREAK,
		150,
		6.0,
		true,
		city.building.global_position,
		&"concrete"
	)
	var breach_event: GameplayEvent = GameplayEvent.new(
		&"feedback_breach",
		9001,
		GameplayEvent.Kind.CELL_DESTROYED,
		GameplayEvent.CELL_BREACH,
		300,
		12.0,
		true,
		city.building.global_position,
		&"concrete"
	)
	assert_true(city.rampage_session.publish(damage_event))
	assert_true(city.rampage_session.publish(breach_event))
	await get_tree().process_frame
	assert_eq(city.impact_feedback_director.flush_count, 1)
	assert_eq(city.impact_feedback_director.coalesced_count, 1)
	assert_eq(city.impact_feedback_director.last_priority, 4)
	assert_eq(city.hit_stop.request_count, 1)
	assert_eq(city.hit_stop.last_duration_ms, 70)
	assert_eq(city.haptics_adapter.request_count, 1)
	assert_eq(city.haptics_adapter.last_duration_ms, 52)
	assert_gt(city.camera_rig.impact_velocity.length(), 0.0)
	city.impact_feedback_director.cancel_all()
	assert_false(city.hit_stop.is_active())
	assert_eq(city.camera_rig.impact_offset, Vector2.ZERO)
