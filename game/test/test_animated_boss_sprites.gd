extends GutTest

const PRESETS: Array[StringName] = [
	&"SETTLEMENT_ENGINE",
	&"SAMARITAN",
	&"MIMESIS",
	&"CANTOR_PALE_ENGINE",
	&"CHOIR_PRIME",
]


func test_animation_catalog_covers_all_five_bosses() -> void:
	assert_eq(BossAnimationCatalog.validation_errors(), [])
	for preset: StringName in PRESETS:
		var texture: Texture2D = BossAnimationCatalog.texture_for_preset(preset)
		assert_not_null(texture, "%s has an animation atlas" % preset)
		assert_eq(int(texture.get_size().x) % BossAnimationCatalog.COLUMN_COUNT, 0)
		assert_eq(int(texture.get_size().y) % BossAnimationCatalog.ROW_COUNT, 0)


func test_all_direction_and_state_sequences_have_stable_rows() -> void:
	assert_eq(BossAnimationCatalog.sequence_row(&"E", BossRig2D.STATE_MOVING), 0)
	assert_eq(BossAnimationCatalog.sequence_row(&"W", BossRig2D.STATE_MOVING), 1)
	assert_eq(BossAnimationCatalog.sequence_row(&"E", BossRig2D.STATE_ATTACKING), 2)
	assert_eq(BossAnimationCatalog.sequence_row(&"W", BossRig2D.STATE_ATTACKING), 3)
	assert_eq(BossAnimationCatalog.FRAME_COUNT, 8)


func test_attack_frames_partition_without_gaps_or_overlap() -> void:
	assert_eq(BossAnimationCatalog.TELEGRAPH_FRAME_RANGE, Vector2i(0, 3))
	assert_eq(BossAnimationCatalog.ACTIVE_FRAME_RANGE, Vector2i(3, 5))
	assert_eq(BossAnimationCatalog.RECOVERY_FRAME_RANGE, Vector2i(5, 8))
	assert_eq(BossAnimationCatalog.TELEGRAPH_SECONDS, BossVerticalSliceController.TELEGRAPH_SECONDS)
	assert_eq(BossAnimationCatalog.TELEGRAPH_SECONDS, BossEscalationController.TELEGRAPH_SECONDS)
	assert_eq(BossAnimationCatalog.TELEGRAPH_SECONDS, BossRoyalFinaleController.TELEGRAPH_SECONDS)
	assert_eq(BossAnimationCatalog.ACTIVE_SECONDS, BossVerticalSliceController.ACTIVE_SECONDS)
	assert_eq(BossAnimationCatalog.RECOVERY_SECONDS, BossRoyalFinaleController.RECOVERY_SECONDS)
	assert_eq(BossAnimationCatalog.frame_range_for_stage(&"TELEGRAPH").x, 0)
	assert_eq(BossAnimationCatalog.frame_range_for_stage(&"RECOVERY").y, 8)


func test_rig_animation_never_moves_mechanical_regions_or_sockets() -> void:
	var rig := BossRig2D.new()
	add_child_autofree(rig)
	var definition := BossEncounterDefinition.new()
	definition.rig_preset = &"SETTLEMENT_ENGINE"
	var host := TankEnemy.new()
	add_child_autofree(host)
	assert_true(rig.configure(definition, host))
	var before_mechanics: Dictionary = rig.mechanical_signature()
	var before_sockets: Dictionary = rig.presentation_signature().sockets
	rig.play_attacking(&"TELEGRAPH", &"E")
	rig.advance_animation(0.42)
	rig.play_attacking(&"ACTIVE", &"W")
	rig.advance_animation(0.31)
	assert_eq(rig.mechanical_signature(), before_mechanics)
	assert_eq(rig.presentation_signature().sockets, before_sockets)
	assert_eq(rig.animation_signature().direction, &"W")
	assert_eq(rig.animation_signature().sequence_row, 3)


func test_moving_loop_and_attack_stage_reset_are_deterministic() -> void:
	var rig := BossRig2D.new()
	add_child_autofree(rig)
	var definition := BossEncounterDefinition.new()
	definition.rig_preset = &"SAMARITAN"
	var host := TankEnemy.new()
	add_child_autofree(host)
	assert_true(rig.configure(definition, host))
	rig.advance_animation(0.5)
	assert_eq(rig.animation_signature().frame, 3)
	rig.play_attacking(&"ACTIVE", &"E")
	assert_eq(rig.animation_signature().frame, 3)
	rig.advance_animation(BossAnimationCatalog.stage_duration(&"ACTIVE"))
	assert_eq(rig.animation_signature().frame, 4)
	rig.play_attacking(&"RECOVERY", &"E")
	assert_eq(rig.animation_signature().frame, 5)
