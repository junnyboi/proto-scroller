extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")

var city: CitySlice
var runtime: EncounterRuntime


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	runtime = city.encounter_runtime
	runtime.release_all()
	city.projectile_root.release_all()


func test_support_variants_keep_kind_and_reserve_zero_projectiles() -> void:
	var cases: Dictionary[StringName, StringName] = {
		&"needle": &"scan",
		&"static": &"jammer_pulse",
		&"aegis": &"shield_pulse",
		&"mule": &"deploy",
		&"hive": &"drone_launch",
		&"nemesis": &"melee_lance",
	}
	for archetype_id: StringName in cases:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var enemy: ProceduralEnemy = runtime.acquire(
			archetype_id,
			Vector2(1050.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(enemy, archetype_id)
		enemy.set_physics_process(false)
		enemy._begin_attack()
		assert_true(enemy.is_telegraphing(), archetype_id)
		assert_eq(city.projectile_root.reservation_count(), 0, archetype_id)
		var snapshot: Dictionary = city.telegraph_presenter.snapshot(enemy._telegraph_id)
		assert_eq(snapshot.get("kind"), &"support", archetype_id)
		assert_eq(snapshot.get("presentation_variant"), cases[archetype_id], archetype_id)
		assert_true(snapshot.has("visual_key"), archetype_id)
		assert_true(snapshot.has("style_data"), archetype_id)
		runtime.release(enemy)


func test_legacy_telegraph_reserve_has_backward_compatible_metadata() -> void:
	var enemy: ProceduralEnemy = runtime.acquire(
		&"bulwark", Vector2(1050.0, 542.5)
	) as ProceduralEnemy
	var record_id: int = city.telegraph_presenter.reserve(
		enemy,
		&"bullet",
		enemy.global_position,
		city.robot.global_position,
		0.4
	)
	var snapshot: Dictionary = city.telegraph_presenter.snapshot(record_id)
	assert_eq(snapshot.get("presentation_variant"), &"")
	assert_eq(snapshot.get("visual_key"), &"")
	assert_eq(snapshot.get("style_data"), {})


func test_nemesis_out_of_range_completion_has_no_shell_fallback() -> void:
	city.robot.global_position = Vector2(700.0, 542.5)
	var nemesis: ProceduralEnemy = runtime.acquire(
		&"nemesis", Vector2(1100.0, 510.0)
	) as ProceduralEnemy
	nemesis.set_physics_process(false)
	nemesis._begin_attack()
	assert_true(nemesis.is_telegraphing())
	assert_eq(city.projectile_root.reservation_count(), 0)
	nemesis._complete_attack()
	assert_false(nemesis.is_telegraphing())
	assert_eq(city.projectile_root.active_count(), 0)
	assert_eq(city.projectile_root.reservation_count(), 0)


func test_completion_presentations_reuse_fixed_collisionless_sprite_children() -> void:
	var enemy: ProceduralEnemy = runtime.acquire(
		&"nemesis", Vector2(900.0, 510.0)
	) as ProceduralEnemy
	enemy.set_physics_process(false)
	var child_count: int = enemy.get_child_count()
	assert_eq(enemy._presentation_sprites.size(), ProceduralEnemy.PRESENTATION_SPRITE_COUNT)
	for sprite: Sprite2D in enemy._presentation_sprites:
		assert_same(sprite.get_parent(), enemy)
		assert_eq(sprite.get_child_count(), 0)
	enemy.facing = -1
	enemy._show_lance_completion()
	assert_true(enemy._presentation_sprites[0].visible)
	assert_eq(enemy.get_child_count(), child_count)
	enemy._show_choir_contact(&"marked_leap", true)
	assert_true(enemy._presentation_sprites[0].visible)
	assert_true(enemy._presentation_sprites[1].visible)
	assert_eq(enemy.get_child_count(), child_count)
	enemy._show_conventional_deployment(2)
	assert_eq(_visible_presentation_count(enemy), 3)
	assert_eq(enemy.get_child_count(), child_count)
	enemy._show_seraph_deployment(6)
	assert_eq(_visible_presentation_count(enemy), 4)
	assert_eq(enemy.get_child_count(), child_count)
	runtime.release(enemy)
	for sprite: Sprite2D in enemy._presentation_sprites:
		assert_false(sprite.visible)
		assert_null(sprite.texture)


func test_carrier_payload_sprite_count_uses_successful_acquisitions() -> void:
	var hive: ProceduralEnemy = runtime.acquire(
		&"hive", Vector2(1200.0, 185.0)
	) as ProceduralEnemy
	hive.set_physics_process(false)
	for hound_index: int in range(RuntimeBudget.PROCEDURAL_AIR - 2):
		assert_not_null(runtime.acquire(
			&"hound",
			Vector2(1280.0 + float(hound_index) * 80.0, 230.0)
		))
	assert_eq(runtime.available_family_count(&"air"), 1)
	hive._begin_attack()
	hive._complete_attack()
	assert_eq(hive._spawned_children, 1)
	assert_eq(_visible_presentation_count(hive), 2)
	assert_eq(city.projectile_root.active_count(), 0)
	assert_eq(city.projectile_root.reservation_count(), 0)


func test_rainmaker_and_leviathan_use_salvo_visual_key_on_every_rocket() -> void:
	for archetype_id: StringName in [&"rainmaker", &"leviathan"]:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var enemy: ProceduralEnemy = runtime.acquire(
			archetype_id,
			Vector2(1200.0, float(profile.spawn_y))
		) as ProceduralEnemy
		enemy.set_physics_process(false)
		enemy._begin_attack()
		enemy._complete_attack()
		var expected_count: int = 3 if archetype_id == &"rainmaker" else 4
		assert_eq(city.projectile_root.active_count(&"rocket"), expected_count)
		for projectile: Projectile2D in city.projectile_root._active_order:
			assert_eq(projectile.visual_key, &"enemy_rocket_salvo", archetype_id)
		city.projectile_root.release_all()
		runtime.release(enemy)


func test_every_current_enemy_identity_resolves_to_authored_emission_family() -> void:
	var authored_presentation_styles: Array[StringName] = [
		&"scan", &"repair", &"jammer_pulse", &"shield_pulse",
		&"deploy", &"drone_launch", &"shock_brace", &"marked_leap",
		&"choir_ring", &"drop_lunge", &"incubation_drop", &"lance_thrust",
	]
	assert_eq(EnemyArchetypeCatalog.PROCEDURAL_IDS.size(), 26)
	assert_eq(EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS.size(), 20)
	assert_eq(EnemyArchetypeCatalog.ALL_SPAWNABLE_IDS.size(), 46)
	for archetype_id: StringName in EnemyArchetypeCatalog.ALL_SPAWNABLE_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		assert_false(profile.is_empty(), archetype_id)
		var attack_style: StringName = StringName(profile.get("attack_style", &""))
		var projectile_kind: StringName = StringName(profile.get("projectile_kind", &""))
		if attack_style in authored_presentation_styles:
			assert_true(attack_style in authored_presentation_styles, archetype_id)
		else:
			assert_false(
				ProjectileVisualCatalog.default_key(projectile_kind).is_empty(),
				archetype_id
			)
	var base_actor_projectiles: Dictionary[StringName, StringName] = {
		&"soldier": &"bullet",
		&"tank": &"shell",
		&"helicopter": &"rocket",
	}
	for actor_id: StringName in base_actor_projectiles:
		assert_false(
			ProjectileVisualCatalog.default_key(base_actor_projectiles[actor_id]).is_empty(),
			actor_id
		)


func _visible_presentation_count(enemy: ProceduralEnemy) -> int:
	var count: int = 0
	for sprite: Sprite2D in enemy._presentation_sprites:
		if sprite.visible:
			count += 1
	return count
