class_name RuntimeBudget
extends RefCounted

const SOLDIERS: int = 6
const TANKS: int = 2
const HELICOPTERS: int = 1
const BULLETS: int = 16
const SHELLS: int = 4
const ROCKETS: int = 4
const PLAYER_BULLETS: int = 8
const STRUCTURAL_DEBRIS: int = 24
const ENEMY_SCRAP: int = 32
const SOLDIER_DEFEATS: int = 8
const WRECKS: int = 4
const PARTICLE_SLOTS: int = 8
const AUDIO_VOICES: int = 8
const ROBOT_AUDIO_VOICES: int = 4
const RARE_TAG_ROWS: int = 3
const TELEGRAPH_RECORDS: int = 12
const CATALYST_SLOTS: int = 2
const ACTIVE_CATALYSTS: int = 2
const ACTOR_RESERVATIONS: int = 9
const PENDING_BEAT_RECORDS: int = 12
const CATALYST_QUERY_RESULTS: int = 12
const DIRECTIVE_SESSIONS: int = 1
const DIRECTIVE_CARDS: int = 1
const DIRECTIVE_OVERLAYS: int = 1
const PAUSE_COORDINATORS: int = 1
const ROLE_BADGES: int = SOLDIERS + TANKS + HELICOPTERS
const TRAIT_RUNTIMES: int = 1
const BOSS_SESSIONS: int = 1
const CAUSAL_RECORDS: int = CausalChainTracker.MAX_RECORDS
const DISTRICT_RECIPES: int = 3
const RUN_CONTRACTS: int = 3
const TERMINAL_CHOICE_OVERLAYS: int = 1
const UPGRADE_SESSIONS: int = 1
const UPGRADE_OVERLAYS: int = 1
const UPGRADE_CARDS: int = 2
const WEAPON_STATUS_STRIPS: int = 1
const COSMETIC_DEBRIS_INSTANCES: int = 64
const SHOCKWAVE_RING_SLOTS: int = 10
const PLAYER_ARSENALS: int = 1
const LASER_BEAM_SLOTS: int = 2
const FLAME_VISUAL_SLOTS: int = 6
const SCORCH_VISUAL_SLOTS: int = 8
const FLAMETHROWER_LOOP_VOICES: int = 1
const PLAYER_MISSILES: int = 4
const MISSILE_EXPLOSION_QUEUE: int = 8
const MAX_WEB_PCK_BYTES: int = 8 * 1024 * 1024


static func snapshot(city: CitySlice) -> Dictionary:
	return {
		"node_count": _count_nodes(city),
		"enemy_total": city.encounter_runtime.total_count(),
		"enemy_active": city.encounter_runtime.active_count(),
		"enemy_post_warm_creations": city.encounter_runtime.post_warm_creation_count,
		"projectile_total": city.projectile_root.total_count(),
		"projectile_active": city.projectile_root.active_count(),
		"hostile_projectile_total": (
			city.projectile_root.bullet_capacity
			+ city.projectile_root.shell_capacity
			+ city.projectile_root.rocket_capacity
		),
		"player_bullet_total": city.projectile_root.player_bullet_capacity,
		"player_bullet_active": city.projectile_root.active_count(&"player_bullet"),
		"structural_debris_total": (
			city.debris_pool.active_count() + city.debris_pool.available_count()
		),
		"structural_debris_peak": city.debris_pool.peak_active_count,
		"enemy_scrap_total": (
			city.enemy_scrap_pool.active_count() + city.enemy_scrap_pool.available_count()
		),
		"enemy_scrap_peak": city.enemy_scrap_pool.peak_active_count,
		"soldier_defeat_total": city.soldier_defeat_pool.total_count(),
		"soldier_defeat_peak": city.soldier_defeat_pool.peak_active_count,
		"wreck_total": city.enemy_remains_factory.total_count(),
		"wreck_peak": city.enemy_remains_factory.peak_active_count,
		"particle_slots": city.impact_feedback_pool.particle_child_count(),
		"audio_voices": city.impact_feedback_pool.audio_child_count(),
		"robot_audio_voices": _robot_audio_voice_count(city),
		"telegraph_active": city.telegraph_presenter.active_count(),
		"telegraph_peak": city.telegraph_presenter.peak_active_count,
		"rare_rows": city.gameplay_hud.rare_labels.size(),
		"catalyst_total": (
			city.urban_siege.catalysts.total_count() if city.urban_siege != null else 0
		),
		"catalyst_active": (
			city.urban_siege.catalysts.active_count() if city.urban_siege != null else 0
		),
		"actor_reservation_peak": (
			city.urban_siege.director.ledger.peak_pending if city.urban_siege != null else 0
		),
		"pending_beat_peak": (
			city.urban_siege.director.peak_pending_records if city.urban_siege != null else 0
		),
		"directive_sessions": 1 if city.urban_siege.directives != null else 0,
		"directive_cards": 1 if city.gameplay_hud.directive_card != null else 0,
		"directive_overlays": (
			1 if city.gameplay_hud.directive_choice_overlay != null else 0
		),
		"pause_coordinators": (
			1 if city.urban_siege.pause_coordinator != null else 0
		),
		"role_badges": city.encounter_runtime.total_count(),
		"trait_runtimes": 1 if city.urban_siege.trait_runtime != null else 0,
		"boss_sessions": 1 if city.urban_siege.boss_session != null else 0,
		"causal_records": city.rampage_session.causal_chain_tracker.active_count(),
		"district_recipes": city.urban_siege.DISTRICT_DECK.recipes.size(),
		"run_contracts": city.urban_siege.RUN_CONTRACTS.size(),
		"terminal_choice_overlays": 1 if city.gameplay_hud.extract_button != null else 0,
		"upgrade_sessions": (
			1 if city.upgrade_assembler.session != null else 0
		),
		"upgrade_overlays": 1 if city.gameplay_hud.upgrade_choice_overlay != null else 0,
		"upgrade_cards": city.gameplay_hud.upgrade_choice_overlay.cards.size(),
		"weapon_status_strips": 1 if city.gameplay_hud.weapon_status_strip != null else 0,
		"cosmetic_debris_instances": CosmeticDebrisField2D.CAPACITY,
		"shockwave_ring_slots": ShockwaveUpgradeRuntime.CAPACITY,
		"player_arsenals": (
			1
			if city.upgrade_assembler.get_node_or_null(^"PlayerArsenalRuntime") != null
			else 0
		),
		"laser_beam_slots": PlayerLaserWeapon.BEAM_CAPACITY,
		"flame_visual_slots": FlamethrowerRuntime.FLAME_CAPACITY,
		"scorch_visual_slots": FlamethrowerRuntime.SCORCH_CAPACITY,
		"flamethrower_loop_voices": FlamethrowerRuntime.LOOP_AUDIO_VOICES,
		"player_missiles": MissileProjectilePool.CAPACITY,
		"missile_explosion_queue": MissileWeapon.EXPLOSION_QUEUE_CAPACITY,
	}


static func validation_errors(city: CitySlice) -> PackedStringArray:
	var data: Dictionary = snapshot(city)
	var errors: PackedStringArray = []
	_check_equal(errors, data, "enemy_total", SOLDIERS + TANKS + HELICOPTERS)
	_check_equal(
		errors,
		data,
		"projectile_total",
		BULLETS + SHELLS + ROCKETS + PLAYER_BULLETS
	)
	_check_equal(errors, data, "hostile_projectile_total", BULLETS + SHELLS + ROCKETS)
	_check_equal(errors, data, "player_bullet_total", PLAYER_BULLETS)
	_check_equal(errors, data, "structural_debris_total", STRUCTURAL_DEBRIS)
	_check_equal(errors, data, "enemy_scrap_total", ENEMY_SCRAP)
	_check_equal(errors, data, "soldier_defeat_total", SOLDIER_DEFEATS)
	_check_equal(errors, data, "wreck_total", WRECKS)
	_check_equal(errors, data, "particle_slots", PARTICLE_SLOTS)
	_check_equal(errors, data, "audio_voices", AUDIO_VOICES)
	_check_equal(errors, data, "robot_audio_voices", ROBOT_AUDIO_VOICES)
	_check_equal(errors, data, "rare_rows", RARE_TAG_ROWS)
	_check_equal(errors, data, "enemy_post_warm_creations", 0)
	_check_equal(errors, data, "catalyst_total", CATALYST_SLOTS)
	_check_equal(errors, data, "directive_sessions", DIRECTIVE_SESSIONS)
	_check_equal(errors, data, "directive_cards", DIRECTIVE_CARDS)
	_check_equal(errors, data, "directive_overlays", DIRECTIVE_OVERLAYS)
	_check_equal(errors, data, "pause_coordinators", PAUSE_COORDINATORS)
	_check_equal(errors, data, "role_badges", ROLE_BADGES)
	_check_equal(errors, data, "trait_runtimes", TRAIT_RUNTIMES)
	_check_equal(errors, data, "boss_sessions", BOSS_SESSIONS)
	_check_equal(errors, data, "district_recipes", DISTRICT_RECIPES)
	_check_equal(errors, data, "run_contracts", RUN_CONTRACTS)
	_check_equal(
		errors,
		data,
		"terminal_choice_overlays",
		TERMINAL_CHOICE_OVERLAYS
	)
	_check_equal(errors, data, "upgrade_sessions", UPGRADE_SESSIONS)
	_check_equal(errors, data, "upgrade_overlays", UPGRADE_OVERLAYS)
	_check_equal(errors, data, "upgrade_cards", UPGRADE_CARDS)
	_check_equal(errors, data, "weapon_status_strips", WEAPON_STATUS_STRIPS)
	_check_equal(errors, data, "cosmetic_debris_instances", COSMETIC_DEBRIS_INSTANCES)
	_check_equal(errors, data, "shockwave_ring_slots", SHOCKWAVE_RING_SLOTS)
	_check_equal(errors, data, "player_arsenals", PLAYER_ARSENALS)
	_check_equal(errors, data, "laser_beam_slots", LASER_BEAM_SLOTS)
	_check_equal(errors, data, "flame_visual_slots", FLAME_VISUAL_SLOTS)
	_check_equal(errors, data, "scorch_visual_slots", SCORCH_VISUAL_SLOTS)
	_check_equal(errors, data, "flamethrower_loop_voices", FLAMETHROWER_LOOP_VOICES)
	_check_equal(errors, data, "player_missiles", PLAYER_MISSILES)
	_check_equal(errors, data, "missile_explosion_queue", MISSILE_EXPLOSION_QUEUE)
	if int(data.causal_records) > CAUSAL_RECORDS:
		errors.append(
			"causal_records=%d cap=%d" % [data.causal_records, CAUSAL_RECORDS]
		)
	if int(data.catalyst_active) > ACTIVE_CATALYSTS:
		errors.append("catalyst_active=%d cap=%d" % [data.catalyst_active, ACTIVE_CATALYSTS])
	if int(data.actor_reservation_peak) > ACTOR_RESERVATIONS:
		errors.append(
			"actor_reservation_peak=%d cap=%d"
			% [data.actor_reservation_peak, ACTOR_RESERVATIONS]
		)
	if int(data.pending_beat_peak) > PENDING_BEAT_RECORDS:
		errors.append(
			"pending_beat_peak=%d cap=%d"
			% [data.pending_beat_peak, PENDING_BEAT_RECORDS]
		)
	if int(data.telegraph_peak) > TELEGRAPH_RECORDS:
		errors.append("telegraph_peak=%d cap=%d" % [data.telegraph_peak, TELEGRAPH_RECORDS])
	return errors


static func _check_equal(
	errors: PackedStringArray,
	data: Dictionary,
	key: String,
	expected: int
) -> void:
	var actual: int = int(data[key])
	if actual != expected:
		errors.append("%s=%d expected=%d" % [key, actual, expected])


static func _count_nodes(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children():
		count += _count_nodes(child)
	return count


static func _robot_audio_voice_count(city: CitySlice) -> int:
	var presenter: RobotAnimationPresenter = (
		city.robot.get_node_or_null(^"RobotAnimationPresenter") as RobotAnimationPresenter
	)
	return presenter.audio_voice_count() if presenter != null else 0
