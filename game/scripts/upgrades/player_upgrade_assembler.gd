class_name PlayerUpgradeAssembler
extends Node

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/upgrade_catalog.tres"
)

var session: UpgradeSession
var runtimes: Dictionary[StringName, UpgradeRuntime] = {}
var _last_upgrade_audio_msec: int = -1000


func setup(city: Node) -> PackedStringArray:
	name = "PlayerUpgradeAssembler"
	var robot: GiantRobotController = city.get("robot") as GiantRobotController
	for profile: UpgradeProfile in CATALOG.profiles:
		var runtime: UpgradeRuntime = _create_runtime(profile, robot)
		runtime.name = "%sRuntime" % String(profile.runtime_key).to_pascal_case()
		add_child(runtime)
		runtimes[profile.runtime_key] = runtime
	var kinetic: KineticFieldRuntime = (
		runtimes[&"KINETIC_FIELD"] as KineticFieldRuntime
	)
	var attacks: ContextualAttackController = (
		city.get("contextual_attacks") as ContextualAttackController
	)
	var feedback: ImpactFeedbackDirector = (
		city.get("impact_feedback_director") as ImpactFeedbackDirector
	)
	feedback.bind_player_attacks(attacks)
	var reactions: PlayerAttackReactionRuntime = PlayerAttackReactionRuntime.new()
	reactions.name = "PlayerAttackReactionRuntime"
	add_child(reactions)
	reactions.setup(
		attacks,
		robot,
		city.get("encounter_runtime") as EncounterRuntime
	)
	var debris_pool: DebrisPool = city.get("debris_pool") as DebrisPool
	attacks.set_kinetic_field_runtime(kinetic)
	debris_pool.set_kinetic_field_runtime(kinetic)
	var arsenal: PlayerArsenalRuntime = PlayerArsenalRuntime.new()
	arsenal.name = "PlayerArsenalRuntime"
	add_child(arsenal)
	arsenal.setup(
		robot,
		city.get("projectile_root") as ProjectilePool,
		city.get("encounter_runtime") as EncounterRuntime
	)
	var machine_gun: MachineGunRuntime = (
		runtimes[&"MACHINE_GUN"] as MachineGunRuntime
	)
	machine_gun.setup_arsenal(arsenal)
	var laser: PlayerLaserWeapon = runtimes[&"LASER"] as PlayerLaserWeapon
	laser.setup_arsenal(
		arsenal,
		robot.get_node(^"VisualRoot/LaserEmitter") as Node2D
	)
	var flamethrower: FlamethrowerRuntime = (
		runtimes[&"FLAMETHROWER"] as FlamethrowerRuntime
	)
	flamethrower.setup_arsenal(
		arsenal,
		robot.get_node(^"VisualRoot/LaserEmitter") as Node2D
	)
	var missiles: MissileWeapon = runtimes[&"MISSILE"] as MissileWeapon
	missiles.setup_arsenal(
		arsenal,
		robot.get_node(^"VisualRoot/LaserEmitter") as Node2D
	)
	session = UpgradeSession.new()
	session.name = "UpgradeSession"
	add_child(session)
	var siege: UrbanSiegeRuntime = city.get("urban_siege") as UrbanSiegeRuntime
	var rampage: RampageSession = city.get("rampage_session") as RampageSession
	var hud: GameplayHud = city.get("gameplay_hud") as GameplayHud
	var destruction: DestructionUpgradeRuntime = (
		runtimes[&"DESTRUCTION"] as DestructionUpgradeRuntime
	)
	destruction.setup_events(rampage.event_hub, city.get_instance_id())
	var shockwave: ShockwaveUpgradeRuntime = (
		runtimes[&"SHOCKWAVE"] as ShockwaveUpgradeRuntime
	)
	shockwave.setup_combat(
		attacks,
		rampage,
		robot,
		city.get("camera_rig") as CameraRig
	)
	siege.pause_coordinator.pause_changed.connect(_on_pause_changed)
	var errors: PackedStringArray = session.setup(
		siege.run_seed,
		CATALOG,
		siege.pause_coordinator,
		runtimes,
		city.get_instance_id()
	)
	session.offer_opened.connect(_on_offer_opened.bind(hud))
	session.offer_resolved.connect(_on_offer_resolved.bind(hud))
	session.queue_drained.connect(hud.upgrade_choice_overlay.hide_offer)
	session.rank_changed.connect(hud.weapon_status_strip.set_rank)
	session.upgrade_acquired.connect(
		_on_upgrade_acquired.bind(city.get("impact_feedback_pool"), robot)
	)
	hud.upgrade_choice_overlay.choice_selected.connect(session.select_choice)
	session.set_presentation_blocked(false)
	rampage.run_experience.level_gained.connect(session.queue_level)
	return errors


func decorate_damage_options(options: DamageQueryOptions, spec: AttackSpec) -> void:
	var runtime: KineticFieldRuntime = (
		runtimes.get(&"KINETIC_FIELD") as KineticFieldRuntime
	)
	if runtime != null:
		runtime.decorate_query_options(options, spec)


func _create_runtime(
	profile: UpgradeProfile,
	robot: GiantRobotController
) -> UpgradeRuntime:
	var runtime: UpgradeRuntime
	match profile.runtime_key:
		&"ARMOR_PLATING":
			var armor: ArmorPlatingRuntime = ArmorPlatingRuntime.new()
			armor.setup_robot(robot)
			runtime = armor
		&"ENGINE":
			var engine: EngineUpgradeRuntime = EngineUpgradeRuntime.new()
			engine.setup_robot(robot)
			runtime = engine
		&"KINETIC_FIELD":
			runtime = KineticFieldRuntime.new()
		&"DESTRUCTION":
			runtime = DestructionUpgradeRuntime.new()
		&"SHOCKWAVE":
			runtime = ShockwaveUpgradeRuntime.new()
		&"MACHINE_GUN":
			runtime = MachineGunRuntime.new()
		&"LASER":
			runtime = PlayerLaserWeapon.new()
		&"FLAMETHROWER":
			runtime = FlamethrowerRuntime.new()
		&"MISSILE":
			runtime = MissileWeapon.new()
		_:
			runtime = UpgradeRuntime.new()
			runtime.setup(profile.runtime_key, profile.max_rank)
	return runtime


func _on_pause_changed(is_paused: bool) -> void:
	for runtime: UpgradeRuntime in runtimes.values():
		runtime.set_paused(is_paused)


func _on_offer_opened(offer: UpgradeOffer, hud: GameplayHud) -> void:
	hud.upgrade_choice_overlay.show_offer(
		offer,
		CATALOG,
		session.ranks,
		offer.sequence + session.pending.size()
	)


func _on_offer_resolved(
	_offer: UpgradeOffer,
	_selected_id: StringName,
	_new_rank: int,
	hud: GameplayHud
) -> void:
	hud.upgrade_choice_overlay.hide_offer()


func _on_upgrade_acquired(
	_profile: UpgradeProfile,
	_rank: int,
	_max_rank: int,
	_grant_id: StringName,
	feedback: ImpactFeedbackPool,
	robot: GiantRobotController
) -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_upgrade_audio_msec < 180:
		return
	_last_upgrade_audio_msec = now_msec
	feedback.play_semantic(&"upgrade", robot.global_position, 6)
