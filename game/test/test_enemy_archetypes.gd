extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const DISTRICT: DistrictDefinition = preload("res://resources/siege/district_contact.tres")
const BLITZ: EnemyTraitProfile = preload("res://resources/traits/blitz.tres")
const BRUTAL: EnemyTraitProfile = preload("res://resources/traits/brutal.tres")
const PHASED: EnemyTraitProfile = preload("res://resources/traits/phased.tres")
const SHIELDED: EnemyTraitProfile = preload("res://resources/traits/shielded.tres")
const EXPECTED_FIRST_ACT: Dictionary = {
	&"needle": 0, &"bulwark": 0, &"jackal": 0,
	&"lobber": 1, &"sapper": 1, &"hound": 1,
	&"mule": 2, &"basilisk": 2, &"lancer": 2, &"static": 2,
	&"kestrel": 3, &"rainmaker": 3, &"shrike": 3, &"cinder": 3,
	&"aegis": 4, &"longbow": 4, &"hive": 4, &"goliath": 4,
	&"nemesis": 5, &"leviathan": 5,
}
const EXPECTED_BASELINE_PUNCHES: Dictionary = {
	&"needle": 1, &"bulwark": 3, &"jackal": 1, &"lobber": 1, &"sapper": 1,
	&"hound": 2, &"mule": 2, &"basilisk": 2, &"lancer": 2, &"static": 2,
	&"kestrel": 2, &"rainmaker": 2, &"shrike": 2, &"cinder": 3, &"aegis": 2,
	&"longbow": 3, &"hive": 3, &"goliath": 5, &"nemesis": 6, &"leviathan": 13,
	&"reclaimed_breacher": 8, &"graft_runner": 2, &"choir_siren": 3,
	&"ossuary_crawler": 3, &"seraph_carrier": 5, &"pale_engine": 9,
}
const EXPECTED_ACT_PEAK_THREAT: Array[int] = [5, 9, 12, 16, 17, 20]
const EXPECTED_FACES_RIGHT: Dictionary[StringName, bool] = {
	&"needle": false,
	&"bulwark": true,
	&"jackal": false,
	&"lobber": true,
	&"sapper": true,
	&"hound": true,
	&"mule": false,
	&"basilisk": true,
	&"lancer": true,
	&"static": false,
	&"kestrel": true,
	&"rainmaker": false,
	&"shrike": false,
	&"cinder": false,
	&"aegis": false,
	&"longbow": false,
	&"hive": false,
	&"goliath": true,
	&"nemesis": true,
	&"leviathan": false,
	&"reclaimed_breacher": false,
	&"graft_runner": false,
	&"choir_siren": false,
	&"ossuary_crawler": false,
	&"seraph_carrier": false,
	&"pale_engine": false,
}
const GROUND_VEHICLE_IDS: Array[StringName] = [
	&"jackal", &"mule", &"basilisk", &"static", &"rainmaker", &"cinder", &"aegis",
	&"longbow", &"goliath", &"nemesis", &"leviathan", &"graft_runner",
	&"ossuary_crawler", &"pale_engine",
]
const MAX_ARMOR_LOADOUT_HEALTH: float = 1200.0
const LATE_WAVE_MINIMUM_DPS: float = 20.0

var city: CitySlice
var runtime: EncounterRuntime


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	runtime = city.encounter_runtime
	runtime.release_all()


func test_catalog_contains_twenty_six_valid_visual_and_gameplay_profiles() -> void:
	assert_eq(EnemyArchetypeCatalog.PROCEDURAL_IDS.size(), 26)
	var signatures: Dictionary[String, bool] = {}
	for archetype_id: StringName in EnemyArchetypeCatalog.PROCEDURAL_IDS:
		assert_true(EnemyArchetypeCatalog.has(archetype_id), archetype_id)
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		assert_not_null(load(String(profile.texture)), archetype_id)
		assert_gt(float(profile.health), 0.0, archetype_id)
		assert_gt(float(profile.speed), 0.0, archetype_id)
		assert_gt(int(profile.xp), 0, archetype_id)
		assert_between(int(profile.threat), 1, 12, archetype_id)
		var signature: String = "%s/%s" % [profile.movement_style, profile.attack_style]
		assert_false(signatures.has(signature), signature)
		signatures[signature] = true
	assert_eq(signatures.size(), 26)


func test_catalog_adds_exactly_twenty_district_variants_without_replacing_bases() -> void:
	assert_eq(EnemyArchetypeCatalog.PROCEDURAL_IDS.size(), 26)
	assert_eq(EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS.size(), 20)
	assert_eq(EnemyArchetypeCatalog.ALL_SPAWNABLE_IDS.size(), 46)
	assert_eq(EnemyArchetypeCatalog.validation_errors(), PackedStringArray())
	var seen: Dictionary[StringName, bool] = {}
	for archetype_id: StringName in EnemyArchetypeCatalog.ALL_SPAWNABLE_IDS:
		assert_false(seen.has(archetype_id), archetype_id)
		seen[archetype_id] = true
		assert_true(EnemyArchetypeCatalog.has(archetype_id), archetype_id)
		assert_true(EnemyArchetypeCatalog.is_valid_kind(archetype_id), archetype_id)
	assert_eq(seen.size(), 46)
	for district_id: StringName in [
		&"BUSINESS", &"RESIDENTIAL", &"ENTERTAINMENT", &"MILITARY", &"ROYAL",
	]:
		var variants: Array[StringName] = EnemyArchetypeCatalog.variants_for_district(
			district_id
		)
		assert_eq(variants.size(), 4, district_id)
		for archetype_id: StringName in variants:
			assert_eq(EnemyArchetypeCatalog.district_for_variant(archetype_id), district_id)


func test_district_variant_profiles_flatten_valid_base_contracts_and_compact_art() -> void:
	for archetype_id: StringName in EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS:
		var canonical_id: StringName = EnemyArchetypeCatalog.canonical_id(archetype_id)
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var canonical_profile: Dictionary = EnemyArchetypeCatalog.profile(canonical_id)
		assert_true(EnemyArchetypeCatalog.PROCEDURAL_IDS.has(canonical_id), archetype_id)
		assert_eq(StringName(profile.base_archetype_id), canonical_id, archetype_id)
		assert_eq(StringName(profile.concrete_archetype_id), archetype_id, archetype_id)
		assert_eq(StringName(profile.family), StringName(canonical_profile.family), archetype_id)
		assert_eq(
			EnemyArchetypeCatalog.reservation_key(archetype_id),
			EnemyArchetypeCatalog.reservation_key(canonical_id),
			archetype_id
		)
		assert_eq(
			EnemyArchetypeCatalog.spawn_multiplier(archetype_id),
			EnemyArchetypeCatalog.spawn_multiplier(canonical_id),
			archetype_id
		)
		assert_eq(
			EnemyArchetypeCatalog.is_ground_vehicle(archetype_id),
			EnemyArchetypeCatalog.is_ground_vehicle(canonical_id),
			archetype_id
		)
		assert_eq(
			EnemyArchetypeCatalog.is_airborne(archetype_id),
			EnemyArchetypeCatalog.is_airborne(canonical_id),
			archetype_id
		)
		assert_gt(float(profile.health), 0.0, archetype_id)
		assert_between(int(profile.threat), 1, 5, archetype_id)
		assert_gt(int(profile.district_weight), 0, archetype_id)
		var texture: Texture2D = load(String(profile.texture)) as Texture2D
		assert_not_null(texture, archetype_id)
		assert_lte(texture.get_width(), 448, archetype_id)
		assert_lte(texture.get_height(), 448, archetype_id)


func test_all_ground_vehicles_render_and_collide_at_exactly_double_size() -> void:
	assert_true(EnemyArchetypeCatalog.is_ground_vehicle(&"tank"))
	assert_false(EnemyArchetypeCatalog.is_ground_vehicle(&"soldier"))
	assert_false(EnemyArchetypeCatalog.is_ground_vehicle(&"helicopter"))
	for archetype_id: StringName in EnemyArchetypeCatalog.PROCEDURAL_IDS:
		var is_ground_vehicle: bool = archetype_id in GROUND_VEHICLE_IDS
		assert_eq(
			EnemyArchetypeCatalog.is_ground_vehicle(archetype_id),
			is_ground_vehicle,
			archetype_id
		)
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var actor: ProceduralEnemy = runtime.acquire(
			archetype_id,
			Vector2(1080.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(actor, archetype_id)
		var expected_scale: float = (
			EnemyArchetypeCatalog.GROUND_VEHICLE_SCALE if is_ground_vehicle else 1.0
		)
		var rendered_size: Vector2 = actor.visual.texture.get_size() * actor.visual.scale.abs()
		var display_bounds: Vector2 = profile.display as Vector2
		if EnemyArchetypeCatalog.is_human_enemy(archetype_id):
			display_bounds = Vector2(
				actor.visual.texture.get_size().x
				* EnemyArchetypeCatalog.HUMAN_RENDER_HEIGHT_PIXELS
				/ actor.visual.texture.get_size().y,
				EnemyArchetypeCatalog.HUMAN_RENDER_HEIGHT_PIXELS
			)
		display_bounds *= expected_scale
		var texture_size: Vector2 = actor.visual.texture.get_size()
		var expected_fit: float = minf(
			display_bounds.x / texture_size.x,
			display_bounds.y / texture_size.y
		)
		var expected_rendered_size: Vector2 = texture_size * expected_fit
		assert_almost_eq(rendered_size.x, expected_rendered_size.x, 0.01, archetype_id)
		assert_almost_eq(rendered_size.y, expected_rendered_size.y, 0.01, archetype_id)
		var body: RectangleShape2D = (
			actor.get_node(^"CollisionShape2D").shape as RectangleShape2D
		)
		assert_eq(body.size, (profile.collision as Vector2) * expected_scale, archetype_id)
		if is_ground_vehicle:
			var wreck: EnemyWreck2D = city.enemy_remains_factory.spawn_wreck(
				actor,
				DamageEvent.new(71_000, city.robot, 10.0)
			)
			assert_eq(wreck.display_size, display_bounds, archetype_id)
			assert_eq(wreck.collision_size, (profile.collision as Vector2) * expected_scale)
			city.enemy_remains_factory.release_wreck(wreck)
		runtime.release(actor)


func test_project_choir_hybrids_reuse_existing_families_and_production_art() -> void:
	var expected_families: Dictionary[StringName, StringName] = {
		&"reclaimed_breacher": &"infantry",
		&"graft_runner": &"light",
		&"choir_siren": &"air",
		&"ossuary_crawler": &"light",
		&"seraph_carrier": &"air",
		&"pale_engine": &"siege",
	}
	for archetype_id: StringName in expected_families:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		assert_eq(StringName(profile.family), expected_families[archetype_id])
		var texture: Texture2D = load(String(profile.texture)) as Texture2D
		assert_not_null(texture, archetype_id)
		assert_lte(texture.get_width(), 768, archetype_id)
		assert_lte(texture.get_height(), 768, archetype_id)


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
	assert_almost_eq(hive.max_health, 400.0, 0.01)
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


func test_elite_affixes_modify_distinct_pressure_axes_and_keep_honest_warnings() -> void:
	var blitz: ProceduralEnemy = runtime.acquire(
		&"hound", Vector2(1180.0, 230.0), &"", BLITZ.trait_id
	) as ProceduralEnemy
	assert_almost_eq(blitz.max_health, 153.0, 0.01)
	assert_almost_eq(blitz.movement_multiplier, 1.35, 0.001)
	assert_almost_eq(blitz.attack_interval_multiplier, 0.72, 0.001)
	blitz._begin_attack()
	assert_gte(blitz._telegraph_remaining, EnemyActor2D.MINIMUM_TELEGRAPH_SECONDS)
	runtime.release(blitz)
	var brutal: ProceduralEnemy = runtime.acquire(
		&"cinder", Vector2(1180.0, 547.0), &"", BRUTAL.trait_id
	) as ProceduralEnemy
	assert_almost_eq(brutal.max_health, 374.0, 0.01)
	assert_almost_eq(brutal.projectile_damage_multiplier, 1.4, 0.001)
	runtime.release(brutal)
	var phased: ProceduralEnemy = runtime.acquire(
		&"jackal", Vector2(1180.0, 554.0), &"", PHASED.trait_id
	) as ProceduralEnemy
	assert_true(phased.receive_damage(DamageEvent.new(41_001, city.robot, 60.0)))
	assert_almost_eq(phased.current_health, 57.0, 0.01)
	assert_true(phased.receive_damage(DamageEvent.new(41_002, city.robot, 60.0)))
	assert_true(phased.dead)


func test_specialist_humans_match_108_pixel_height_through_attack_animation() -> void:
	for archetype_id: StringName in [&"bulwark", &"lobber", &"sapper", &"lancer"]:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var actor: ProceduralEnemy = runtime.acquire(
			archetype_id,
			Vector2(1100.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(actor)
		actor.set_physics_process(false)
		actor._attack_kick = 1.0
		actor._animate_visual(0.12)
		var rendered_height: float = (
			actor.visual.texture.get_size().y * absf(actor.visual.scale.y)
		)
		assert_almost_eq(
			rendered_height,
			EnemyArchetypeCatalog.HUMAN_RENDER_HEIGHT_PIXELS,
			0.01,
			archetype_id
		)
		runtime.release(actor)


func test_shielded_bulwark_faces_player_from_both_sides() -> void:
	city.robot.global_position.x = 1300.0
	var bulwark: ProceduralEnemy = runtime.acquire(
		&"bulwark",
		Vector2(1000.0, 540.0),
		&"",
		SHIELDED.trait_id
	) as ProceduralEnemy
	assert_not_null(bulwark)
	assert_true(bulwark.visual_faces_right_by_default)
	assert_eq(bulwark.facing, 1)
	assert_false(bulwark.visual.flip_h)
	city.robot.global_position.x = 700.0
	bulwark._update_facing()
	assert_eq(bulwark.facing, -1)
	assert_true(bulwark.visual.flip_h)


func test_every_procedural_sprite_faces_player_from_both_sides() -> void:
	for archetype_id: StringName in EnemyArchetypeCatalog.PROCEDURAL_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var authored_right: bool = EXPECTED_FACES_RIGHT[archetype_id]
		city.robot.global_position.x = 1300.0
		var actor: ProceduralEnemy = runtime.acquire(
			archetype_id,
			Vector2(1000.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(actor, archetype_id)
		actor.set_physics_process(false)
		assert_eq(
			actor.visual_faces_right_by_default,
			authored_right,
			"%s authored direction" % archetype_id
		)
		assert_eq(actor.facing, 1, "%s target east" % archetype_id)
		assert_eq(
			actor.visual.flip_h,
			not authored_right,
			"%s visual east" % archetype_id
		)
		city.robot.global_position.x = 700.0
		actor._update_facing()
		assert_eq(actor.facing, -1, "%s target west" % archetype_id)
		assert_eq(
			actor.visual.flip_h,
			authored_right,
			"%s visual west" % archetype_id
		)
		runtime.release(actor)


func test_base_enemy_sprites_face_player_from_both_sides() -> void:
	for kind: StringName in EnemyArchetypeCatalog.BASE_KINDS:
		city.robot.global_position.x = 1300.0
		var actor: EnemyActor2D = runtime.acquire(kind, Vector2(1000.0, 542.5))
		assert_not_null(actor, kind)
		actor.set_physics_process(false)
		assert_false(actor.visual_faces_right_by_default, "%s authored west" % kind)
		assert_eq(actor.facing, 1, "%s target east" % kind)
		assert_true(actor.visual.flip_h, "%s visual east" % kind)
		city.robot.global_position.x = 700.0
		actor._update_facing()
		assert_eq(actor.facing, -1, "%s target west" % kind)
		assert_false(actor.visual.flip_h, "%s visual west" % kind)
		runtime.release(actor)


func test_random_affix_spawns_play_bounded_colored_impact_effects() -> void:
	var effects: EliteSpawnEffectPool = runtime.elite_spawn_effect_pool
	assert_eq(effects.slot_count(), RuntimeBudget.ELITE_SPAWN_EFFECT_SLOTS)
	for trait_id: StringName in EnemyArchetypeCatalog.RANDOM_AFFIXES:
		var actor: ProceduralEnemy = runtime.acquire(
			&"hound",
			Vector2(980.0 + float(effects.play_count) * 80.0, 230.0),
			&"",
			trait_id
		) as ProceduralEnemy
		assert_not_null(actor)
	assert_eq(effects.play_count, 3)
	assert_eq(effects.active_count(), 3)
	assert_eq(effects.last_trait_id, &"PHASED")
	var latest: Node2D = effects.get_child(2) as Node2D
	assert_true((latest.get_node(^"Particles") as CPUParticles2D).emitting)
	assert_eq(latest.get_meta(&"trait_id"), &"PHASED")
	await get_tree().create_timer(0.75).timeout
	assert_eq(effects.active_count(), 0)


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


func test_baseline_melee_ttk_matches_role_bands_without_apex_damage_sponges() -> void:
	var resolver: AttackResolver = AttackResolver.new()
	add_child_autofree(resolver)
	var punch_damage: float = resolver.jab_cross_actor_damage
	for archetype_id: StringName in EnemyArchetypeCatalog.PROCEDURAL_IDS:
		var profile: Dictionary = EnemyArchetypeCatalog.profile(archetype_id)
		var actor: ProceduralEnemy = runtime.acquire(
			archetype_id,
			Vector2(1080.0, float(profile.spawn_y))
		) as ProceduralEnemy
		assert_not_null(actor, archetype_id)
		actor.facing = -1
		var expected_hits: int = EXPECTED_BASELINE_PUNCHES[archetype_id]
		for hit_index: int in range(expected_hits):
			var accepted: bool = actor.receive_damage(DamageEvent.new(
				20_000 + hit_index,
				city.robot,
				punch_damage,
				&"jab_cross",
				actor.global_position,
				Vector2.RIGHT,
				0.0
			))
			assert_true(accepted, "%s hit %d" % [archetype_id, hit_index + 1])
			assert_eq(actor.dead, hit_index == expected_hits - 1, archetype_id)
		runtime.release(actor)
	var leviathan_seconds: float = (
		AttackResolver.FULL_ANTICIPATION_SECONDS
		+ float(EXPECTED_BASELINE_PUNCHES[&"leviathan"] - 1)
		* AttackResolver.FULL_ATTACK_SECONDS
	)
	assert_lt(leviathan_seconds, 27.0)


func test_late_acts_use_cross_family_waves_and_smooth_threat_peaks() -> void:
	var previous_peak: int = 0
	for act_index: int in range(DISTRICT.acts.size()):
		var act: DistrictAct = DISTRICT.acts[act_index]
		var peak_threat: int = 0
		for beat: DistrictBeat in act.beats:
			var beat_threat: int = 0
			var families: Dictionary[StringName, bool] = {}
			for entry: EnemySpawnEntry in beat.spawns:
				var kind: StringName = StringName(entry.kind)
				beat_threat += (
					EnemyArchetypeCatalog.threat_cost(kind)
					* EnemyArchetypeCatalog.spawn_multiplier(kind)
				)
				families[EnemyArchetypeCatalog.family_for(kind)] = true
			peak_threat = maxi(peak_threat, beat_threat)
			if act_index >= 3 and beat.spawns.size() >= 2:
				assert_gte(families.size(), 2, beat.beat_id)
			if act_index >= 3:
				assert_gte(beat.spawns.size(), 3, beat.beat_id)
				assert_lte(beat.recovery_seconds, 2.0, beat.beat_id)
				assert_gte(_direct_outgoing_dps(beat), LATE_WAVE_MINIMUM_DPS, beat.beat_id)
		assert_eq(peak_threat, EXPECTED_ACT_PEAK_THREAT[act_index], act.act_id)
		if act_index > 0:
			assert_gte(peak_threat, previous_peak, act.act_id)
			assert_lte(peak_threat - previous_peak, 4, act.act_id)
		previous_peak = peak_threat
	var maximum_armor_survival: float = (
		MAX_ARMOR_LOADOUT_HEALTH / LATE_WAVE_MINIMUM_DPS
	)
	assert_lt(maximum_armor_survival, 61.0)
	assert_gt(
		LATE_WAVE_MINIMUM_DPS * 13.0 / MAX_ARMOR_LOADOUT_HEALTH,
		0.20
	)


func test_all_twenty_archetypes_enter_in_monotonic_act_order_within_caps() -> void:
	var first_act: Dictionary[StringName, int] = {}
	for act_index: int in range(DISTRICT.acts.size()):
		for beat: DistrictBeat in DISTRICT.acts[act_index].beats:
			var threat: int = 0
			for entry: EnemySpawnEntry in beat.spawns:
				var kind: StringName = StringName(entry.kind)
				threat += (
					EnemyArchetypeCatalog.threat_cost(kind)
					* EnemyArchetypeCatalog.spawn_multiplier(kind)
				)
				if EnemyArchetypeCatalog.has(kind) and not first_act.has(kind):
					first_act[kind] = act_index
			assert_lte(threat, beat.maximum_threat, beat.beat_id)
	assert_eq(first_act.size(), 20)
	for archetype_id: StringName in EXPECTED_FIRST_ACT:
		assert_eq(first_act.get(archetype_id, -1), EXPECTED_FIRST_ACT[archetype_id])
	assert_eq(DistrictRecipeValidator.validate(DISTRICT), PackedStringArray())


func _direct_outgoing_dps(beat: DistrictBeat) -> float:
	var total: float = 0.0
	for entry: EnemySpawnEntry in beat.spawns:
		var kind: StringName = StringName(entry.kind)
		var spawn_multiplier: float = float(EnemyArchetypeCatalog.spawn_multiplier(kind))
		if kind == &"soldier":
			total += spawn_multiplier * 8.0 / 0.95
			continue
		if kind == &"tank":
			total += 24.0 / 2.30
			continue
		if kind == &"helicopter":
			total += 16.0 / 1.75
			continue
		var profile: Dictionary = EnemyArchetypeCatalog.profile(kind)
		if profile.attack_style in [
			&"scan", &"repair", &"jammer_pulse", &"shield_pulse", &"deploy", &"drone_launch",
		]:
			continue
		var salvo_multiplier: float = 1.0
		if profile.attack_style == &"pod_salvo":
			salvo_multiplier = 2.44
		elif profile.attack_style == &"fortress_barrage":
			salvo_multiplier = 3.16
		total += (
			spawn_multiplier
			* float(profile.damage)
			* salvo_multiplier
			/ float(profile.attack_interval)
		)
	return total
