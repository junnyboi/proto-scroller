class_name CitySlice
extends Node2D

signal retry_requested

const DAMAGE_MASK: int = (1 << 1) | (1 << 6) | (1 << 7)
const WORLD_LAYER: int = 1 << 0
const ROBOT_LAYER: int = 1 << 1
const ENEMY_LAYER: int = 1 << 2
const BUILDING_LAYER: int = 1 << 3
const HURTBOX_LAYER: int = 1 << 6
const PROP_LAYER: int = 1 << 7
const DEBRIS_LAYER: int = 1 << 8
const REMAINS_LAYER: int = 1 << 9
const REMAINS_GROUND_LAYER: int = 1 << 10
const LAND_VISUAL_BASELINE_Y: float = 655.0
const MOBILE_CONTROLS_SCRIPT: Script = preload("res://scripts/input/mobile_controls.gd")
const GAMEPLAY_HUD_SCRIPT: Script = preload("res://scripts/ui/gameplay_hud.gd")
const WORLD_BUILDER_SCRIPT: Script = preload("res://scripts/gameplay/city_world_builder.gd")
const PROJECTILE_POOL_SCRIPT: Script = preload("res://scripts/combat/projectile_pool.gd")
const IMPACT_FEEDBACK_SCRIPT: Script = preload(
	"res://scripts/gameplay/impact_feedback_pool.gd"
)
const HIT_STOP_SCRIPT: Script = preload("res://scripts/feedback/hit_stop_lease.gd")
const HAPTICS_SCRIPT: Script = preload("res://scripts/input/haptics_adapter.gd")
const FEEDBACK_DIRECTOR_SCRIPT: Script = preload(
	"res://scripts/feedback/impact_feedback_director.gd"
)
const ENEMY_REMAINS_FACTORY_SCRIPT: Script = preload(
	"res://scripts/actors/enemy_remains_factory.gd"
)
const RAMPAGE_SESSION_SCRIPT: Script = preload("res://scripts/rampage/rampage_session.gd")
const OVERDRIVE_SCRIPT: Script = preload("res://scripts/rampage/overdrive_session.gd")
const RUN_LIFECYCLE_SCRIPT: Script = preload(
	"res://scripts/gameplay/city_run_lifecycle.gd"
)
const RAMPAGE_EVENT_ADAPTER_SCRIPT: Script = preload(
	"res://scripts/rampage/rampage_event_adapter.gd"
)
const DIRECTOR_SCRIPT: Script = preload("res://scripts/destruction/destruction_director.gd")
const DEBRIS_POOL_SCRIPT: Script = preload("res://scripts/destruction/debris_pool.gd")
const STRUCTURAL_BUILDING_SCRIPT: Script = preload(
	"res://scripts/destruction/structural_building_2d.gd"
)
const PROP_SCRIPT: Script = preload("res://scripts/destruction/destructible_prop_2d.gd")
const ENCOUNTER_RUNTIME_SCRIPT: Script = preload(
	"res://scripts/encounter/encounter_runtime.gd"
)
const URBAN_SIEGE_SCRIPT: Script = preload("res://scripts/siege/urban_siege_runtime.gd")
const TELEGRAPH_SCRIPT: Script = preload(
	"res://scripts/encounter/telegraph_presenter_2d.gd"
)
const CONTACT_DISTRICT: DistrictDefinition = preload(
	"res://resources/siege/district_contact.tres"
)
const TRANSFORMER_PROFILE: CatalystProfile = preload(
	"res://resources/catalysts/transformer.tres"
)
const SOLDIER_DEFEAT_POOL_SCRIPT: Script = preload(
	"res://scripts/actors/soldier_defeat_pool.gd"
)
const BUILDING_INTACT: Texture2D = preload("res://art/city/destructibles/building_intact.png")
const BUILDING_DAMAGED: Texture2D = preload("res://art/city/destructibles/building_damaged.png")
const BUILDING_RUBBLE: Texture2D = preload("res://art/city/destructibles/building_rubble.png")
const LAMP_INTACT: Texture2D = preload("res://art/city/destructibles/streetlamp_intact.png")
const LAMP_BROKEN: Texture2D = preload("res://art/city/destructibles/streetlamp_broken.png")
const CAR_INTACT: Texture2D = preload("res://art/city/destructibles/car_intact.png")
const CAR_WRECK: Texture2D = preload("res://art/city/destructibles/car_wreck.png")
const SOLDIER_TEXTURE: Texture2D = preload("res://art/city/enemies/soldier.png")
const TANK_TEXTURE: Texture2D = preload("res://art/city/enemies/tank.png")
const HELICOPTER_TEXTURE: Texture2D = preload("res://art/city/enemies/helicopter.png")
const GLASS_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/structural/glass_shatter.wav"
)
const CONCRETE_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/structural/concrete_crunch.wav"
)
const STEEL_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/structural/steel_groan.wav"
)

@export_range(-1, 1, 1) var mobile_detection_override: int = -1

var robot: GiantRobotController
var destruction_director: DestructionDirector
var debris_pool: DebrisPool
var enemy_scrap_pool: DebrisPool
var soldier_defeat_pool: SoldierDefeatPool
var mobile_controls: MobileControls
var gameplay_hud: GameplayHud
var projectile_root: ProjectilePool
var impact_audio_root: Node2D
var impact_feedback_pool: ImpactFeedbackPool
var hit_stop: HitStopLease
var haptics_adapter: HapticsAdapter
var impact_feedback_director: ImpactFeedbackDirector
var camera_rig: CameraRig
var enemy_remains_root: Node2D
var enemy_remains_factory: EnemyRemainsFactory
var rampage_session: RampageSession
var rampage_events: RampageEventAdapter
var overdrive_session: OverdriveSession
var run_lifecycle: CityRunLifecycle
var contextual_attacks: ContextualAttackController
var telegraph_presenter: TelegraphPresenter2D
var encounter_runtime: EncounterRuntime
var encounter_director: EncounterDirector
var urban_siege: UrbanSiegeRuntime
var building: StructuralBuilding2D
var streetlamp: DestructibleProp2D
var car: DestructibleProp2D
var soldier: SoldierEnemy
var tank: TankEnemy
var helicopter: HelicopterEnemy
var soldier_defeat_body: SoldierDefeatBody2D
var tank_wreck: EnemyWreck2D
var helicopter_wreck: EnemyWreck2D
var game_over_active: bool = false
var score: int:
	get:
		return rampage_session.current_score() if rampage_session != null else 0
var last_material_audio: StringName:
	get:
		return (
			impact_feedback_pool.last_material_audio
			if impact_feedback_pool != null
			else &""
		)
var material_audio_play_count: int:
	get:
		return (
			impact_feedback_pool.material_audio_play_count
			if impact_feedback_pool != null
			else 0
		)


func _ready() -> void:
	CityWorldBuilder.build_environment(self)
	_build_services()
	robot = CityWorldBuilder.build_robot(
		self,
		_on_robot_heavy_impact,
		_on_robot_health_changed,
		_on_robot_damage_received,
		_on_robot_defeated
	)
	contextual_attacks = ContextualAttackController.new()
	contextual_attacks.name = "ContextualAttackController"
	contextual_attacks.setup(robot)
	add_child(contextual_attacks)
	overdrive_session = OVERDRIVE_SCRIPT.new() as OverdriveSession
	overdrive_session.name = "OverdriveSession"
	overdrive_session.setup(rampage_session.momentum_meter, robot)
	add_child(overdrive_session)
	contextual_attacks.set_overdrive_session(overdrive_session)
	_build_destructibles()
	_build_enemies()
	CityWorldBuilder.build_camera(self, robot)
	camera_rig = get_node(^"CameraRig") as CameraRig
	_build_hud()
	_build_urban_siege()
	run_lifecycle = RUN_LIFECYCLE_SCRIPT.new() as CityRunLifecycle
	run_lifecycle.name = "CityRunLifecycle"
	run_lifecycle.setup(self)
	add_child(run_lifecycle)


func _process(delta: float) -> void:
	if game_over_active or rampage_session == null or robot == null:
		return
	var speed_ratio: float = absf(robot.velocity.x) / maxf(robot.max_speed, 1.0)
	rampage_session.advance(speed_ratio, delta)


func trigger_test_stomp() -> int:
	return robot.request_stomp()


func all_destructibles_broken() -> bool:
	return building.is_destroyed() and streetlamp.is_broken and car.is_broken


func _build_services() -> void:
	rampage_session = RAMPAGE_SESSION_SCRIPT.new() as RampageSession
	rampage_session.name = "RampageSession"
	rampage_session.run_score.score_changed.connect(_on_score_changed)
	rampage_session.combo_tracker.combo_changed.connect(_on_combo_changed)
	add_child(rampage_session)
	rampage_events = RAMPAGE_EVENT_ADAPTER_SCRIPT.new(rampage_session) as RampageEventAdapter
	projectile_root = PROJECTILE_POOL_SCRIPT.new() as ProjectilePool
	projectile_root.name = "ProjectileRoot"
	projectile_root.capacity = (
		RuntimeBudget.BULLETS + RuntimeBudget.SHELLS + RuntimeBudget.ROCKETS
	)
	projectile_root.z_index = 45
	add_child(projectile_root)
	impact_audio_root = Node2D.new()
	impact_audio_root.name = "ImpactAudioRoot"
	add_child(impact_audio_root)
	enemy_remains_root = Node2D.new()
	enemy_remains_root.name = "EnemyRemainsRoot"
	enemy_remains_root.z_index = 28
	add_child(enemy_remains_root)
	impact_feedback_pool = IMPACT_FEEDBACK_SCRIPT.new() as ImpactFeedbackPool
	impact_feedback_pool.name = "ImpactFeedbackPool"
	impact_feedback_pool.setup(self, impact_audio_root)
	add_child(impact_feedback_pool)
	hit_stop = HIT_STOP_SCRIPT.new() as HitStopLease
	hit_stop.name = "HitStopLease"
	hit_stop.enabled = DisplayServer.get_name() != "headless"
	add_child(hit_stop)
	destruction_director = DIRECTOR_SCRIPT.new() as DestructionDirector
	destruction_director.name = "DestructionDirector"
	destruction_director.max_results = 64
	destruction_director.blast_mask = (
		HURTBOX_LAYER
		| PROP_LAYER
		| ENEMY_LAYER
		| DEBRIS_LAYER
		| REMAINS_LAYER
	)
	add_child(destruction_director)
	debris_pool = DEBRIS_POOL_SCRIPT.new() as DebrisPool
	debris_pool.name = "BuildingDebrisPool"
	debris_pool.capacity = RuntimeBudget.STRUCTURAL_DEBRIS
	debris_pool.z_index = 30
	debris_pool.aerial_impact_accepted.connect(_on_aerial_impact_accepted)
	add_child(debris_pool)
	enemy_scrap_pool = DEBRIS_POOL_SCRIPT.new() as DebrisPool
	enemy_scrap_pool.name = "EnemyScrapPool"
	enemy_scrap_pool.capacity = RuntimeBudget.ENEMY_SCRAP
	enemy_scrap_pool.z_index = 31
	add_child(enemy_scrap_pool)
	soldier_defeat_pool = SOLDIER_DEFEAT_POOL_SCRIPT.new() as SoldierDefeatPool
	soldier_defeat_pool.name = "SoldierDefeatPool"
	soldier_defeat_pool.capacity = RuntimeBudget.SOLDIER_DEFEATS
	soldier_defeat_pool.z_index = 28
	enemy_remains_root.add_child(soldier_defeat_pool)
	enemy_remains_factory = ENEMY_REMAINS_FACTORY_SCRIPT.new() as EnemyRemainsFactory
	enemy_remains_factory.name = "EnemyRemainsFactory"
	enemy_remains_factory.setup(
		enemy_remains_root,
		enemy_scrap_pool,
		TANK_TEXTURE,
		HELICOPTER_TEXTURE
	)
	enemy_remains_factory.wreck_scrapped.connect(_on_enemy_wreck_scrapped)
	add_child(enemy_remains_factory)
func _build_destructibles() -> void:
	building = _create_building(Vector2(1450.0, LAND_VISUAL_BASELINE_Y))
	building.damage_applied.connect(_on_building_damage_applied)
	building.cell_destroyed.connect(_on_building_cell_destroyed)
	building.chain_reaction_started.connect(_on_building_chain_reaction_started)
	building.chain_reaction_step.connect(_on_building_chain_reaction_step)
	building.chain_reaction_completed.connect(_on_building_chain_reaction_completed)
	building.destroyed.connect(_on_building_destroyed)
	streetlamp = _create_prop(
		"Streetlamp",
		Vector2(1220.0, 480.0),
		LAMP_INTACT,
		LAMP_BROKEN,
		Vector2(70.0, 235.0),
		Vector2(185.0, 90.0),
		Vector2(42.0, 220.0),
		Vector2(170.0, 55.0),
		38.0,
		4.0
	)
	streetlamp.destroyed.connect(_on_prop_destroyed.bind(150))
	car = _create_prop(
		"Car",
		Vector2(930.0, 559.0),
		CAR_INTACT,
		CAR_WRECK,
		Vector2(165.0, 78.0),
		Vector2(175.0, 76.0),
		Vector2(150.0, 62.0),
		Vector2(160.0, 58.0),
		35.0,
		12.0
	)
	car.destroyed.connect(_on_prop_destroyed.bind(300))


func _create_building(position_value: Vector2) -> StructuralBuilding2D:
	var node: StructuralBuilding2D = (
		STRUCTURAL_BUILDING_SCRIPT.new() as StructuralBuilding2D
	)
	node.name = "DestructibleBuilding"
	node.position = position_value
	node.z_index = 5
	node.intact_texture = BUILDING_INTACT
	node.damaged_texture = BUILDING_DAMAGED
	node.rubble_texture = BUILDING_RUBBLE
	node.display_size = Vector2(500.0, 445.0)
	node.collision_layer_value = BUILDING_LAYER
	node.collision_mask_value = ROBOT_LAYER
	node.hurtbox_layer_value = HURTBOX_LAYER
	node.debris_pool_path = NodePath("../BuildingDebrisPool")
	add_child(node)
	return node


func _create_prop(
	prop_name: String,
	position_value: Vector2,
	intact_texture: Texture2D,
	broken_texture: Texture2D,
	intact_size: Vector2,
	broken_size: Vector2,
	collision_size: Vector2,
	broken_collision_size: Vector2,
	health: float,
	body_mass: float
) -> DestructibleProp2D:
	var prop: DestructibleProp2D = PROP_SCRIPT.new() as DestructibleProp2D
	prop.name = prop_name
	prop.position = position_value
	prop.z_index = 25
	prop.max_health = health
	prop.mass = body_mass
	prop.collision_layer = PROP_LAYER
	prop.collision_mask = WORLD_LAYER | ROBOT_LAYER
	prop.intact_texture = intact_texture
	prop.destroyed_texture = broken_texture
	prop.intact_display_size = intact_size
	prop.destroyed_display_size = broken_size
	prop.destroyed_collision_size = broken_collision_size
	prop.visual_ground_offset = LAND_VISUAL_BASELINE_Y - position_value.y
	var visual: Sprite2D = Sprite2D.new()
	visual.name = "Visual"
	prop.add_child(visual)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = collision_size
	collision.shape = rectangle
	prop.add_child(collision)
	add_child(prop)
	return prop


func _build_enemies() -> void:
	telegraph_presenter = TELEGRAPH_SCRIPT.new() as TelegraphPresenter2D
	telegraph_presenter.name = "TelegraphPresenter"
	add_child(telegraph_presenter)
	encounter_runtime = ENCOUNTER_RUNTIME_SCRIPT.new() as EncounterRuntime
	encounter_runtime.name = "EncounterRuntime"
	encounter_runtime.setup(robot, telegraph_presenter, projectile_root)
	encounter_runtime.projectile_requested.connect(_on_projectile_requested)
	encounter_runtime.enemy_died.connect(_on_enemy_died)
	add_child(encounter_runtime)
	soldier = encounter_runtime.soldiers[0]
	tank = encounter_runtime.tanks[0]
	helicopter = encounter_runtime.helicopters[0]
	if DisplayServer.get_name() == "headless":
		encounter_runtime.acquire(&"soldier", Vector2(1320.0, 542.5))
		encounter_runtime.acquire(&"tank", Vector2(1700.0, 551.0))
		encounter_runtime.acquire(&"helicopter", Vector2(1500.0, 180.0))


func _build_urban_siege() -> void:
	var dependencies: UrbanSiegeDependencies = UrbanSiegeDependencies.new()
	dependencies.city = self
	dependencies.robot = robot
	dependencies.encounter_runtime = encounter_runtime
	dependencies.projectile_pool = projectile_root
	dependencies.telegraphs = telegraph_presenter
	dependencies.destruction_director = destruction_director
	dependencies.rampage_session = rampage_session
	dependencies.gameplay_hud = gameplay_hud
	dependencies.mobile_controls = mobile_controls
	dependencies.debris_pool = debris_pool
	dependencies.remains_factory = enemy_remains_factory
	urban_siege = URBAN_SIEGE_SCRIPT.new() as UrbanSiegeRuntime
	urban_siege.name = "UrbanSiegeRuntime"
	urban_siege.setup(dependencies, CONTACT_DISTRICT)
	add_child(urban_siege)
	encounter_director = urban_siege.director
	urban_siege.catalysts.activate(0, TRANSFORMER_PROFILE, Vector2(1880.0, 590.0))
	if DisplayServer.get_name() != "headless":
		urban_siege.start_run()
func _build_hud() -> void:
	gameplay_hud = GAMEPLAY_HUD_SCRIPT.new() as GameplayHud
	gameplay_hud.setup(robot)
	gameplay_hud.retry_pressed.connect(_on_retry_pressed)
	add_child(gameplay_hud)
	haptics_adapter = HAPTICS_SCRIPT.new() as HapticsAdapter
	haptics_adapter.name = "HapticsAdapter"
	haptics_adapter.setup(mobile_detection_override)
	add_child(haptics_adapter)
	mobile_controls = MOBILE_CONTROLS_SCRIPT.new() as MobileControls
	mobile_controls.setup(robot, mobile_detection_override)
	gameplay_hud.add_child(mobile_controls)
	impact_feedback_director = FEEDBACK_DIRECTOR_SCRIPT.new() as ImpactFeedbackDirector
	impact_feedback_director.name = "ImpactFeedbackDirector"
	impact_feedback_director.setup(
		rampage_session.event_hub,
		hit_stop,
		camera_rig,
		haptics_adapter,
		robot
	)
	add_child(impact_feedback_director)
func _on_robot_heavy_impact(
	origin: Vector2,
	radius: float,
	damage: float,
	impulse_per_mass: float,
	attack_id: int
) -> void:
	destruction_director.queue_explosion(
		origin,
		radius,
		damage,
		impulse_per_mass,
		attack_id,
		robot
	)
	AerialDebrisLauncher.launch(get_tree(), debris_pool, robot, origin, impulse_per_mass, attack_id)
	gameplay_hud.set_objective("IMPACT REGISTERED / PHYSICS FIELD ACTIVE")


func _material_for_target(
	target: Node,
	hit_position: Vector2
) -> StructuralMaterialProfile:
	if target is Destructible2D:
		var cell_profile: StructuralMaterialProfile = (
			(target as Destructible2D).get_material_profile()
		)
		if cell_profile != null:
			return cell_profile
	if target is StructuralBuilding2D:
		var cell: Destructible2D = (
			(target as StructuralBuilding2D).cell_at_world_point(hit_position)
		)
		if cell != null and cell.get_material_profile() != null:
			return cell.get_material_profile()
	if target is EnemyWreck2D:
		return (target as EnemyWreck2D).get_material_profile()
	return StructuralMaterialProfile.concrete()


func _on_building_damage_applied(amount: float, event: DamageEvent) -> void:
	rampage_events.building_damage(amount, event, building, robot)
	if event.damage_type in [&"floor_chain", &"steel_support_chain"]:
		return
	var material_profile: StructuralMaterialProfile = _material_for_target(
		building,
		event.hit_position
	)
	impact_feedback_pool.play_audio(
		material_profile,
		event.hit_position,
		event.impulse_per_mass
	)
	impact_feedback_pool.spawn_particles(
		event.hit_position,
		event.direction,
		event.impulse_per_mass,
		material_profile
	)


func _on_building_cell_destroyed(
	column: int,
	row: int,
	event: DamageEvent
) -> void:
	rampage_events.cell_destroyed(column, row, event, building, robot)


func _on_building_chain_reaction_started(kind: StringName, event: DamageEvent) -> void:
	rampage_events.chain_started(kind, event, building, robot)
	if kind == &"steel_support_chain":
		gameplay_hud.set_objective("STEEL SUPPORT FAILURE / CASCADE ACTIVE")
	else:
		gameplay_hud.set_objective("FLOOR LOST / CHAIN COLLAPSE ACTIVE")


func _on_building_chain_reaction_step(
	_kind: StringName,
	column: int,
	row: int,
	event: DamageEvent
) -> void:
	var profile: StructuralMaterialProfile = building.get_material_profile(column, row)
	impact_feedback_pool.play_audio(profile, event.hit_position, event.impulse_per_mass, true)
	impact_feedback_pool.spawn_particles(
		event.hit_position,
		event.direction,
		event.impulse_per_mass * 0.62,
		profile
	)


func _on_building_chain_reaction_completed(kind: StringName) -> void:
	if building.is_destroyed():
		return
	gameplay_hud.set_objective(
		"STEEL CASCADE COMPLETE / STRUCTURE UNSTABLE"
		if kind == &"steel_support_chain"
		else "FLOOR COLLAPSE COMPLETE / STRUCTURE UNSTABLE"
	)


func _on_building_destroyed(event: DamageEvent) -> void:
	rampage_events.building_destroyed(event, building, robot)


func _on_prop_destroyed(prop: DestructibleProp2D, event: DamageEvent, points: int) -> void:
	rampage_events.prop_destroyed(prop, event, points, robot, prop == car)


func _on_enemy_died(
	enemy: EnemyActor2D,
	event: DamageEvent,
	points: int
) -> void:
	rampage_events.enemy_defeated(enemy, event, points, robot)
	if enemy is SoldierEnemy:
		_spawn_soldier_defeat_body(enemy, event)
		encounter_runtime.release_deferred(enemy)
		return
	var wreck: EnemyWreck2D = enemy_remains_factory.spawn_wreck(enemy, event)
	if enemy is TankEnemy:
		tank_wreck = wreck
	else:
		helicopter_wreck = wreck
	encounter_runtime.release_deferred(enemy)


func _spawn_soldier_defeat_body(
	enemy: EnemyActor2D,
	event: DamageEvent
) -> void:
	soldier_defeat_body = soldier_defeat_pool.acquire(
		enemy.global_position,
		enemy.facing,
		event
	)


func _on_enemy_wreck_scrapped(
	wreck: EnemyWreck2D,
	event: DamageEvent,
	points: int
) -> void:
	var profile: StructuralMaterialProfile = StructuralMaterialProfile.steel()
	rampage_events.wreck_scrapped(wreck, event, points, robot)
	impact_feedback_pool.play_audio(
		profile,
		wreck.global_position,
		maxf(event.impulse_per_mass, 220.0),
		true
	)
	impact_feedback_pool.spawn_particles(
		wreck.global_position,
		event.direction,
		maxf(event.impulse_per_mass, 220.0),
		profile
	)


func _add_score(points: int) -> void:
	rampage_events.legacy_score(points)


func _on_aerial_impact_accepted(
	body: DebrisBody2D,
	event: DamageEvent,
	target: EnemyActor2D
) -> void:
	rampage_events.aerial_hit(body, event, target, robot)


func _on_robot_damage_received(event: DamageEvent, accepted_damage: float) -> void:
	rampage_events.player_heavy_hit(event, accepted_damage, robot)


func _on_score_changed(next_score: int, _awarded: int) -> void:
	if gameplay_hud != null:
		gameplay_hud.set_score(next_score)


func _on_combo_changed(multiplier: int, grace_remaining: float) -> void:
	if gameplay_hud != null:
		gameplay_hud.set_combo(multiplier, grace_remaining)


func _on_projectile_requested(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	kind: StringName,
	source: Node
) -> void:
	projectile_root.acquire(
		origin,
		direction,
		speed,
		damage,
		source,
		ROBOT_LAYER | BUILDING_LAYER,
		kind
	)


func _on_robot_health_changed(current: float, maximum: float) -> void:
	if gameplay_hud != null:
		gameplay_hud.set_health(current, maximum)


func _on_robot_defeated() -> void:
	if run_lifecycle != null:
		run_lifecycle.robot_defeated()


func _on_retry_pressed() -> void:
	if not game_over_active:
		return
	retry_requested.emit()
