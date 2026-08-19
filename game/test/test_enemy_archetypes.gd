extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const DISTRICT: DistrictDefinition = preload("res://resources/siege/district_contact.tres")
const EXPECTED_FIRST_ACT: Dictionary = {
	&"needle": 0, &"bulwark": 0, &"jackal": 0,
	&"lobber": 1, &"sapper": 1, &"hound": 1,
	&"mule": 2, &"basilisk": 2, &"lancer": 2, &"static": 2,
	&"kestrel": 3, &"rainmaker": 3, &"shrike": 3, &"cinder": 3,
	&"aegis": 4, &"longbow": 4, &"hive": 4, &"goliath": 4,
	&"nemesis": 5, &"leviathan": 5,
}

var city: CitySlice
var runtime: EncounterRuntime


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	runtime = city.encounter_runtime
	runtime.release_all()


func test_catalog_contains_twenty_valid_visual_and_gameplay_profiles() -> void:
	assert_eq(EnemyArchetypeCatalog.PROCEDURAL_IDS.size(), 20)
	var previous_threat: int = 0
	var signatures: Dictionary[String, bool] = {}
	for archetype_id: StringName in EnemyArchetypeCatalog.PROCEDURAL_IDS:
		assert_true(EnemyArchetypeCatalog.has(archetype_id), archetype_id)
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		assert_not_null(load(String(profile.texture)), archetype_id)
		assert_gt(float(profile.health), 0.0, archetype_id)
		assert_gt(float(profile.speed), 0.0, archetype_id)
		assert_gt(int(profile.xp), 0, archetype_id)
		assert_gte(int(profile.threat), previous_threat, archetype_id)
		previous_threat = int(profile.threat)
		var signature: String = "%s/%s" % [profile.movement_style, profile.attack_style]
		assert_false(signatures.has(signature), signature)
		signatures[signature] = true
	assert_eq(signatures.size(), 20)


func test_every_archetype_acquires_animates_telegraphs_and_releases_cleanly() -> void:
	for archetype_id: StringName in EnemyArchetypeCatalog.PROCEDURAL_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var actor: ProceduralEnemy = runtime.acquire(
			archetype_id,
			Vector2(1080.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(actor, archetype_id)
		actor.set_physics_process(false)
		assert_eq(actor.archetype_id, archetype_id)
		assert_eq(actor.family, EnemyArchetypeCatalog.family_for(archetype_id))
		assert_almost_eq(actor.max_health, float(profile.health), 0.01)
		assert_not_null(actor.visual.texture)
		var rest_position: Vector2 = actor.visual.position
		var rest_rotation: float = actor.visual.rotation
		var rest_scale: Vector2 = actor.visual.scale
		actor.velocity = Vector2(actor.move_speed, 0.0)
		actor._begin_attack()
		assert_true(actor.is_telegraphing(), archetype_id)
		actor._animate_visual(0.17)
		var changed: bool = (
			actor.visual.position != rest_position
			or not is_equal_approx(actor.visual.rotation, rest_rotation)
			or actor.visual.scale != rest_scale
		)
		assert_true(changed, "%s procedural motion" % archetype_id)
		actor.cancel_telegraph()
		assert_eq(city.projectile_root.reservation_count(), 0)
		runtime.release(actor)
		assert_false(actor.active)


func test_family_pool_reconfigures_one_shell_without_post_warm_creation() -> void:
	var needle: ProceduralEnemy = runtime.acquire(
		&"needle", Vector2(1200.0, 155.0)
	) as ProceduralEnemy
	var shell_identity: int = needle.get_instance_id()
	var needle_texture: Texture2D = needle.visual.texture
	runtime.release(needle)
	var hive: ProceduralEnemy = runtime.acquire(
		&"hive", Vector2(1200.0, 185.0)
	) as ProceduralEnemy
	assert_eq(hive.get_instance_id(), shell_identity)
	assert_eq(hive.archetype_id, &"hive")
	assert_ne(hive.visual.texture, needle_texture)
	assert_almost_eq(hive.max_health, 360.0, 0.01)
	assert_eq(runtime.post_warm_creation_count, 0)


func test_aegis_and_static_apply_bounded_nonstacking_support_modifiers() -> void:
	var aegis: ProceduralEnemy = runtime.acquire(
		&"aegis", Vector2(1180.0, 544.0)
	) as ProceduralEnemy
	var static_truck: ProceduralEnemy = runtime.acquire(
		&"static", Vector2(1210.0, 547.0)
	) as ProceduralEnemy
	var bulwark: ProceduralEnemy = runtime.acquire(
		&"bulwark", Vector2(1260.0, 540.0)
	) as ProceduralEnemy
	runtime._process(0.1)
	assert_almost_eq(
		bulwark.incoming_damage_multiplier,
		EncounterRuntime.AEGIS_DAMAGE_MULTIPLIER,
		0.001
	)
	assert_almost_eq(
		bulwark.aura_attack_interval_multiplier,
		EncounterRuntime.STATIC_INTERVAL_MULTIPLIER,
		0.001
	)
	runtime.release(aegis)
	runtime.release(static_truck)
	runtime._process(0.1)
	assert_almost_eq(bulwark.incoming_damage_multiplier, 1.0, 0.001)
	assert_almost_eq(bulwark.aura_attack_interval_multiplier, 1.0, 0.001)


func test_carrier_at_family_capacity_completes_without_firing_a_fallback_shot() -> void:
	var hive: ProceduralEnemy = runtime.acquire(
		&"hive", Vector2(1200.0, 185.0)
	) as ProceduralEnemy
	for hound_index: int in range(RuntimeBudget.PROCEDURAL_AIR - 1):
		assert_not_null(runtime.acquire(
			&"hound",
			Vector2(1280.0 + float(hound_index) * 80.0, 230.0)
		))
	assert_eq(runtime.available_family_count(&"air"), 0)
	hive._begin_attack()
	assert_true(hive.is_telegraphing())
	hive._complete_attack()
	assert_false(hive.is_telegraphing())
	assert_eq(runtime.active_family_count(&"air"), RuntimeBudget.PROCEDURAL_AIR)
	assert_eq(city.projectile_root.active_count(), 0)
	assert_eq(city.projectile_root.reservation_count(), 0)


func test_every_salvo_projectile_is_reserved_or_the_attack_is_denied() -> void:
	var rainmaker: ProceduralEnemy = runtime.acquire(
		&"rainmaker", Vector2(1200.0, 544.0)
	) as ProceduralEnemy
	rainmaker._begin_attack()
	assert_true(rainmaker.is_telegraphing())
	assert_eq(city.projectile_root.reservation_count(&"rocket"), 3)
	rainmaker.cancel_telegraph()
	assert_eq(city.projectile_root.reservation_count(&"rocket"), 0)
	var occupied: Projectile2D = city.projectile_root.acquire(
		Vector2.ZERO,
		Vector2.RIGHT,
		300.0,
		1.0,
		city.robot,
		CitySlice.ROBOT_LAYER,
		&"rocket"
	)
	assert_not_null(occupied)
	var leviathan: ProceduralEnemy = runtime.acquire(
		&"leviathan", Vector2(1400.0, 505.0)
	) as ProceduralEnemy
	leviathan._begin_attack()
	assert_false(leviathan.is_telegraphing())
	assert_eq(city.projectile_root.reservation_count(&"rocket"), 0)


func test_all_twenty_archetypes_enter_in_monotonic_act_order_within_caps() -> void:
	var first_act: Dictionary[StringName, int] = {}
	for act_index: int in range(DISTRICT.acts.size()):
		for beat: DistrictBeat in DISTRICT.acts[act_index].beats:
			var threat: int = 0
			for entry: EnemySpawnEntry in beat.spawns:
				var kind: StringName = StringName(entry.kind)
				threat += EnemyArchetypeCatalog.threat_cost(kind)
				if EnemyArchetypeCatalog.has(kind) and not first_act.has(kind):
					first_act[kind] = act_index
			assert_lte(threat, beat.maximum_threat, beat.beat_id)
	assert_eq(first_act.size(), 20)
	for archetype_id: StringName in EnemyArchetypeCatalog.PROCEDURAL_IDS:
		assert_eq(first_act.get(archetype_id, -1), EXPECTED_FIRST_ACT[archetype_id])
	assert_eq(DistrictRecipeValidator.validate(DISTRICT), PackedStringArray())
