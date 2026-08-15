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
const LAND_VISUAL_BASELINE_Y: float = 655.0

const PROJECTILE_SCRIPT: Script = preload("res://scripts/combat/projectile_2d.gd")
const ROBOT_SCRIPT: Script = preload("res://scripts/player/giant_robot_controller.gd")
const CAMERA_RIG_SCRIPT: Script = preload("res://scripts/camera/camera_rig.gd")
const DIRECTOR_SCRIPT: Script = preload("res://scripts/destruction/destruction_director.gd")
const DEBRIS_POOL_SCRIPT: Script = preload("res://scripts/destruction/debris_pool.gd")
const DESTRUCTIBLE_SCRIPT: Script = preload("res://scripts/destruction/destructible_2d.gd")
const PROP_SCRIPT: Script = preload("res://scripts/destruction/destructible_prop_2d.gd")
const SOLDIER_SCRIPT: Script = preload("res://scripts/actors/soldier.gd")
const TANK_SCRIPT: Script = preload("res://scripts/actors/tank.gd")
const HELICOPTER_SCRIPT: Script = preload("res://scripts/actors/helicopter.gd")

const SKY_TEXTURE: Texture2D = preload("res://art/city/parallax/sky.png")
const FAR_TEXTURE: Texture2D = preload("res://art/city/parallax/far_skyline.png")
const INFRA_TEXTURE: Texture2D = preload("res://art/city/parallax/infrastructure.png")
const NEAR_TEXTURE: Texture2D = preload("res://art/city/parallax/near_buildings.png")
const FOREGROUND_TEXTURE: Texture2D = preload("res://art/city/parallax/foreground.png")
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
const ROBOT_DRAFT_TEXTURE: Texture2D = preload(
	"res://art/robot/provisional/robot_draft_idle.png"
)

var robot: GiantRobotController
var destruction_director: DestructionDirector
var debris_pool: DebrisPool
var projectile_root: Node2D
var building: Destructible2D
var streetlamp: DestructibleProp2D
var car: DestructibleProp2D
var soldier: SoldierEnemy
var tank: TankEnemy
var helicopter: HelicopterEnemy
var game_over_active: bool = false
var score: int = 0
var _health_label: Label
var _status_label: Label
var _objective_label: Label
var _score_label: Label
var _game_over_overlay: Control
var _retry_button: Button
var _pulse_age: float = 0.0


func _ready() -> void:
	_build_parallax()
	_build_street()
	_build_services()
	_build_robot()
	_build_destructibles()
	_build_enemies()
	_build_camera()
	_build_hud()


func _process(delta: float) -> void:
	_pulse_age += delta
	if _status_label != null:
		_status_label.modulate.a = 0.86 + sin(_pulse_age * 2.2) * 0.14


func trigger_test_stomp() -> int:
	return robot.request_stomp()


func all_destructibles_broken() -> bool:
	return building.is_destroyed() and streetlamp.is_broken and car.is_broken


func _build_parallax() -> void:
	var backdrop: Node2D = Node2D.new()
	backdrop.name = "ParallaxCity"
	add_child(backdrop)
	_create_parallax_band(backdrop, "Sky", SKY_TEXTURE, Vector2(0.05, 1.0), -50, 0.0)
	_create_parallax_band(backdrop, "FarSkyline", FAR_TEXTURE, Vector2(0.18, 1.0), -40, 85.0)
	_create_parallax_band(backdrop, "Infrastructure", INFRA_TEXTURE, Vector2(0.35, 1.0), -30, 95.0)
	_create_parallax_band(backdrop, "NearBuildings", NEAR_TEXTURE, Vector2(0.60, 1.0), -20, 116.0)
	_create_parallax_band(backdrop, "Foreground", FOREGROUND_TEXTURE, Vector2(1.10, 1.0), 80, 350.0)


func _create_parallax_band(
	parent: Node2D,
	band_name: String,
	texture: Texture2D,
	scroll_scale: Vector2,
	z_value: int,
	y_offset: float
) -> void:
	var band: Parallax2D = Parallax2D.new()
	band.name = band_name
	band.scroll_scale = scroll_scale
	band.repeat_size = Vector2(1344.0, 0.0)
	band.repeat_times = 3
	band.z_index = z_value
	parent.add_child(band)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(0.0, y_offset)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	band.add_child(sprite)


func _build_street() -> void:
	var street_visual: Polygon2D = Polygon2D.new()
	street_visual.name = "Street"
	street_visual.z_index = -10
	street_visual.polygon = PackedVector2Array([
		Vector2(-800.0, 590.0),
		Vector2(3600.0, 590.0),
		Vector2(3600.0, 760.0),
		Vector2(-800.0, 760.0),
	])
	street_visual.color = Color("171b21")
	add_child(street_visual)
	var curb: Line2D = Line2D.new()
	curb.width = 8.0
	curb.default_color = Color("8f8175")
	curb.points = PackedVector2Array([Vector2(-800.0, 590.0), Vector2(3600.0, 590.0)])
	curb.z_index = -9
	add_child(curb)
	var ground: StaticBody2D = StaticBody2D.new()
	ground.name = "Ground"
	ground.collision_layer = WORLD_LAYER
	ground.collision_mask = ROBOT_LAYER | ENEMY_LAYER | PROP_LAYER | (1 << 8)
	ground.position = Vector2(1400.0, 625.0)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(4400.0, 70.0)
	collision.shape = rectangle
	ground.add_child(collision)
	add_child(ground)


func _build_services() -> void:
	projectile_root = Node2D.new()
	projectile_root.name = "ProjectileRoot"
	projectile_root.z_index = 45
	add_child(projectile_root)
	destruction_director = DIRECTOR_SCRIPT.new() as DestructionDirector
	destruction_director.name = "DestructionDirector"
	destruction_director.blast_mask = HURTBOX_LAYER | PROP_LAYER | ENEMY_LAYER
	add_child(destruction_director)
	debris_pool = DEBRIS_POOL_SCRIPT.new() as DebrisPool
	debris_pool.name = "BuildingDebrisPool"
	debris_pool.capacity = 24
	debris_pool.z_index = 30
	add_child(debris_pool)


func _build_robot() -> void:
	robot = ROBOT_SCRIPT.new() as GiantRobotController
	robot.name = "Robot"
	robot.position = Vector2(760.0, 460.0)
	robot.max_health = 800.0
	robot.stomp_radius = 320.0
	robot.stomp_damage = 180.0
	robot.collision_layer = ROBOT_LAYER
	robot.collision_mask = WORLD_LAYER | BUILDING_LAYER
	robot.z_index = 20
	var body_shape: CollisionShape2D = CollisionShape2D.new()
	body_shape.name = "BodyCollision"
	var capsule: CapsuleShape2D = CapsuleShape2D.new()
	capsule.radius = 46.0
	capsule.height = 205.0
	body_shape.shape = capsule
	body_shape.position = Vector2(0.0, 21.0)
	robot.add_child(body_shape)
	var visual_root: Node2D = Node2D.new()
	visual_root.name = "VisualRoot"
	var robot_sprite: Sprite2D = _make_fitted_sprite(
		ROBOT_DRAFT_TEXTURE,
		Vector2(265.0, 245.0)
	)
	robot_sprite.name = "ProvisionalRobotSprite"
	robot_sprite.position.y = 72.0
	visual_root.add_child(robot_sprite)
	robot.add_child(visual_root)
	var impact_origin: Marker2D = Marker2D.new()
	impact_origin.name = "GroundImpactOrigin"
	impact_origin.position = Vector2(0.0, 126.0)
	robot.add_child(impact_origin)
	var hurtbox: Area2D = Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = HURTBOX_LAYER
	hurtbox.collision_mask = 0
	var hurt_shape: CollisionShape2D = CollisionShape2D.new()
	var hurt_rectangle: RectangleShape2D = RectangleShape2D.new()
	hurt_rectangle.size = Vector2(205.0, 220.0)
	hurt_shape.shape = hurt_rectangle
	hurtbox.add_child(hurt_shape)
	robot.add_child(hurtbox)
	robot.heavy_impact_requested.connect(_on_robot_heavy_impact)
	robot.structure_impact_requested.connect(_on_robot_structure_impact)
	robot.health_changed.connect(_on_robot_health_changed)
	robot.defeated.connect(_on_robot_defeated)
	add_child(robot)


func _build_destructibles() -> void:
	building = _create_building(Vector2(1450.0, LAND_VISUAL_BASELINE_Y))
	building.damage_applied.connect(_on_building_damage_applied)
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


func _create_building(position_value: Vector2) -> Destructible2D:
	var node: Destructible2D = DESTRUCTIBLE_SCRIPT.new() as Destructible2D
	node.name = "DestructibleBuilding"
	node.position = position_value
	node.z_index = 5
	node.max_health = 85.0
	node.damaged_stage_ratio = 0.65
	node.gameplay_chunk_count = 6
	node.debris_pool_path = NodePath("../BuildingDebrisPool")
	node.intact_visual_path = ^"IntactVisual"
	node.damaged_visual_path = ^"DamagedVisual"
	node.rubble_visual_path = ^"RubbleVisual"
	node.intact_collision_path = ^"IntactBody/CollisionShape2D"
	node.rubble_collision_path = ^"RubbleBody/CollisionShape2D"
	var intact: Sprite2D = _make_fitted_sprite(BUILDING_INTACT, Vector2(500.0, 445.0))
	intact.name = "IntactVisual"
	intact.position = Vector2(0.0, -222.0)
	node.add_child(intact)
	var damaged: Sprite2D = _make_fitted_sprite(BUILDING_DAMAGED, Vector2(500.0, 445.0))
	damaged.name = "DamagedVisual"
	damaged.position = Vector2(0.0, -222.0)
	node.add_child(damaged)
	var rubble: Sprite2D = _make_fitted_sprite(BUILDING_RUBBLE, Vector2(500.0, 170.0))
	rubble.name = "RubbleVisual"
	rubble.position = Vector2(0.0, -78.0)
	node.add_child(rubble)
	var intact_body: StaticBody2D = StaticBody2D.new()
	intact_body.name = "IntactBody"
	intact_body.collision_layer = BUILDING_LAYER
	intact_body.collision_mask = ROBOT_LAYER
	var intact_collision: CollisionShape2D = CollisionShape2D.new()
	intact_collision.name = "CollisionShape2D"
	var intact_rectangle: RectangleShape2D = RectangleShape2D.new()
	intact_rectangle.size = Vector2(475.0, 420.0)
	intact_collision.shape = intact_rectangle
	intact_collision.position = Vector2(0.0, -210.0)
	intact_body.add_child(intact_collision)
	node.add_child(intact_body)
	var rubble_body: StaticBody2D = StaticBody2D.new()
	rubble_body.name = "RubbleBody"
	rubble_body.collision_layer = 0
	rubble_body.collision_mask = 0
	var rubble_collision: CollisionShape2D = CollisionShape2D.new()
	rubble_collision.name = "CollisionShape2D"
	var rubble_rectangle: RectangleShape2D = RectangleShape2D.new()
	rubble_rectangle.size = Vector2(450.0, 92.0)
	rubble_collision.shape = rubble_rectangle
	rubble_collision.position = Vector2(0.0, -45.0)
	rubble_body.add_child(rubble_collision)
	node.add_child(rubble_body)
	var hurtbox: Area2D = Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = HURTBOX_LAYER
	hurtbox.collision_mask = 0
	var hurt_collision: CollisionShape2D = CollisionShape2D.new()
	var hurt_rectangle: RectangleShape2D = RectangleShape2D.new()
	hurt_rectangle.size = Vector2(500.0, 440.0)
	hurt_collision.shape = hurt_rectangle
	hurt_collision.position = Vector2(0.0, -220.0)
	hurtbox.add_child(hurt_collision)
	node.add_child(hurtbox)
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
	soldier = _create_enemy(
		SOLDIER_SCRIPT,
		SOLDIER_TEXTURE,
		Vector2(1320.0, 542.5),
		Vector2(68.0, 108.0),
		Vector2(42.0, 95.0)
	) as SoldierEnemy
	tank = _create_enemy(
		TANK_SCRIPT,
		TANK_TEXTURE,
		Vector2(1700.0, 551.0),
		Vector2(235.0, 100.0),
		Vector2(220.0, 78.0)
	) as TankEnemy
	helicopter = _create_enemy(
		HELICOPTER_SCRIPT,
		HELICOPTER_TEXTURE,
		Vector2(1500.0, 180.0),
		Vector2(235.0, 72.0),
		Vector2(210.0, 58.0)
	) as HelicopterEnemy
	helicopter.collision_mask = 0
	soldier.died.connect(_on_enemy_died.bind(500))
	tank.died.connect(_on_enemy_died.bind(1500))
	helicopter.died.connect(_on_enemy_died.bind(1200))


func _create_enemy(
	script: Script,
	texture: Texture2D,
	position_value: Vector2,
	display_size: Vector2,
	collision_size: Vector2
) -> EnemyActor2D:
	var enemy: EnemyActor2D = script.new() as EnemyActor2D
	enemy.position = position_value
	enemy.collision_layer = ENEMY_LAYER
	enemy.collision_mask = WORLD_LAYER
	enemy.z_index = 30
	var visual: Sprite2D = _make_fitted_sprite(texture, display_size)
	visual.name = "Visual"
	if enemy is SoldierEnemy or enemy is TankEnemy:
		var rendered_height: float = texture.get_size().y * absf(visual.scale.y)
		visual.position.y = (
			LAND_VISUAL_BASELINE_Y - position_value.y - rendered_height * 0.5
		)
		enemy.movement_bounce_enabled = true
		if enemy is SoldierEnemy:
			enemy.bounce_height = 5.5
			enemy.bounce_frequency = 3.8
			enemy.bounce_squash = 0.055
			enemy.bounce_speed_reference = 92.0
		else:
			enemy.bounce_height = 2.5
			enemy.bounce_frequency = 2.2
			enemy.bounce_squash = 0.025
			enemy.bounce_speed_reference = 62.0
	enemy.add_child(visual)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = collision_size
	collision.shape = rectangle
	enemy.add_child(collision)
	var hurtbox: Area2D = Area2D.new()
	hurtbox.collision_layer = HURTBOX_LAYER
	hurtbox.collision_mask = 0
	var hurt_shape: CollisionShape2D = CollisionShape2D.new()
	var hurt_rectangle: RectangleShape2D = RectangleShape2D.new()
	hurt_rectangle.size = collision_size * 1.12
	hurt_shape.shape = hurt_rectangle
	hurtbox.add_child(hurt_shape)
	enemy.add_child(hurtbox)
	enemy.set_target(robot)
	enemy.projectile_requested.connect(_on_projectile_requested)
	add_child(enemy)
	return enemy


func _build_camera() -> void:
	var camera_rig: CameraRig = CAMERA_RIG_SCRIPT.new() as CameraRig
	camera_rig.name = "CameraRig"
	camera_rig.target = robot
	camera_rig.position = Vector2(640.0, 360.0)
	var camera: Camera2D = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.position = Vector2.ZERO
	camera_rig.add_child(camera)
	add_child(camera_rig)
	camera.make_current()
	camera.reset_smoothing()


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "HUD"
	layer.layer = 20
	add_child(layer)
	var panel: ColorRect = ColorRect.new()
	panel.position = Vector2(24.0, 22.0)
	panel.size = Vector2(420.0, 112.0)
	panel.color = Color(0.03, 0.05, 0.08, 0.86)
	layer.add_child(panel)
	_status_label = Label.new()
	_status_label.position = Vector2(48.0, 34.0)
	_status_label.text = "CITY RESPONSE / ACTIVE"
	_status_label.add_theme_font_size_override(&"font_size", 24)
	_status_label.modulate = Color("f1b36f")
	layer.add_child(_status_label)
	_health_label = Label.new()
	_health_label.position = Vector2(48.0, 68.0)
	_health_label.text = "CHASSIS %03d / %03d" % [
		roundi(robot.current_health),
		roundi(robot.max_health),
	]
	_health_label.add_theme_font_size_override(&"font_size", 25)
	layer.add_child(_health_label)
	_objective_label = Label.new()
	_objective_label.position = Vector2(48.0, 100.0)
	_objective_label.text = "A/D MOVE   SPACE STOMP   BREAK THE STREET"
	_objective_label.add_theme_font_size_override(&"font_size", 20)
	_objective_label.modulate = Color("b7c4cb")
	layer.add_child(_objective_label)
	var score_panel: ColorRect = ColorRect.new()
	score_panel.position = Vector2(1000.0, 22.0)
	score_panel.size = Vector2(256.0, 88.0)
	score_panel.color = Color(0.03, 0.05, 0.08, 0.86)
	layer.add_child(score_panel)
	var score_caption: Label = Label.new()
	score_caption.position = Vector2(1024.0, 30.0)
	score_caption.size = Vector2(208.0, 28.0)
	score_caption.text = "DESTRUCTION SCORE"
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_caption.add_theme_font_size_override(&"font_size", 18)
	score_caption.modulate = Color("f1b36f")
	layer.add_child(score_caption)
	_score_label = Label.new()
	_score_label.name = "ScoreLabel"
	_score_label.position = Vector2(1024.0, 56.0)
	_score_label.size = Vector2(208.0, 42.0)
	_score_label.text = "%08d" % score
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.add_theme_font_size_override(&"font_size", 30)
	layer.add_child(_score_label)
	_build_game_over_overlay(layer)


func _build_game_over_overlay(layer: CanvasLayer) -> void:
	_game_over_overlay = Control.new()
	_game_over_overlay.name = "GameOverOverlay"
	_game_over_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over_overlay.visible = false
	_game_over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_game_over_overlay)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.02, 0.03, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_game_over_overlay.add_child(shade)
	var panel: ColorRect = ColorRect.new()
	panel.position = Vector2(365.0, 188.0)
	panel.size = Vector2(550.0, 340.0)
	panel.color = Color(0.025, 0.05, 0.065, 0.97)
	_game_over_overlay.add_child(panel)
	var title: Label = Label.new()
	title.position = Vector2(405.0, 232.0)
	title.size = Vector2(470.0, 86.0)
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 58)
	title.modulate = Color("f1b36f")
	_game_over_overlay.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.position = Vector2(405.0, 320.0)
	subtitle.size = Vector2(470.0, 46.0)
	subtitle.text = "CHASSIS SIGNAL LOST"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override(&"font_size", 24)
	subtitle.modulate = Color("b7c4cb")
	_game_over_overlay.add_child(subtitle)
	_retry_button = Button.new()
	_retry_button.name = "RetryButton"
	_retry_button.position = Vector2(490.0, 398.0)
	_retry_button.size = Vector2(300.0, 78.0)
	_retry_button.text = "RETRY"
	_retry_button.focus_mode = Control.FOCUS_ALL
	_retry_button.add_theme_font_size_override(&"font_size", 30)
	_retry_button.pressed.connect(_on_retry_pressed)
	_game_over_overlay.add_child(_retry_button)


func _make_fitted_sprite(texture: Texture2D, display_size: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texture_size: Vector2 = texture.get_size()
	var fit_scale: float = minf(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	sprite.scale = Vector2.ONE * fit_scale
	return sprite


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
	if _objective_label != null:
		_objective_label.text = "IMPACT REGISTERED / PHYSICS FIELD ACTIVE"


func _on_robot_structure_impact(
	target: Node,
	hit_position: Vector2,
	direction: Vector2,
	impact_speed: float,
	impact_mass: float,
	attack_id: int
) -> void:
	if target == null or not target.has_method("receive_damage"):
		return
	var structural_damage: float = clampf(
		impact_mass * impact_speed * impact_speed / 25000.0,
		12.0,
		240.0
	)
	var event: DamageEvent = DamageEvent.new(
		attack_id,
		robot,
		structural_damage,
		&"structural",
		hit_position,
		direction,
		impact_speed * 1.15
	)
	if bool(target.call("receive_damage", event)):
		_spawn_impact_particles(hit_position, direction, impact_speed)
		_objective_label.text = "STRUCTURAL BREACH / MOMENTUM TRANSFERRED"


func _spawn_impact_particles(
	origin: Vector2,
	direction: Vector2,
	impact_speed: float
) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = "ImpactFragments"
	particles.global_position = origin
	particles.z_index = 42
	particles.amount = clampi(roundi(impact_speed * 0.14), 12, 42)
	particles.lifetime = 0.9
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.direction = direction.normalized()
	particles.spread = 72.0
	particles.gravity = Vector2(0.0, 560.0)
	particles.initial_velocity_min = impact_speed * 0.35
	particles.initial_velocity_max = impact_speed * 0.95
	particles.angular_velocity_min = -420.0
	particles.angular_velocity_max = 420.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 8.0
	particles.damping_min = 25.0
	particles.damping_max = 70.0
	particles.color = Color("bca58f")
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	particles.emitting = true


func _on_building_damage_applied(amount: float, _event: DamageEvent) -> void:
	_add_score(roundi(amount * 10.0))


func _on_building_destroyed(_event: DamageEvent) -> void:
	_add_score(1000)


func _on_prop_destroyed(_prop: DestructibleProp2D, points: int) -> void:
	_add_score(points)


func _on_enemy_died(_enemy: EnemyActor2D, points: int) -> void:
	_add_score(points)


func _add_score(points: int) -> void:
	if points <= 0:
		return
	score += points
	if _score_label != null:
		_score_label.text = "%08d" % score


func _on_projectile_requested(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	kind: StringName,
	source: Node
) -> void:
	var projectile: Projectile2D = PROJECTILE_SCRIPT.new() as Projectile2D
	projectile_root.add_child(projectile)
	projectile.setup(origin, direction, speed, damage, source, ROBOT_LAYER, kind)


func _on_robot_health_changed(current: float, maximum: float) -> void:
	if _health_label != null:
		_health_label.text = "CHASSIS %03d / %03d" % [roundi(current), roundi(maximum)]


func _on_robot_defeated() -> void:
	if game_over_active:
		return
	game_over_active = true
	_status_label.text = "CITY RESPONSE / LOST"
	_objective_label.text = "CHASSIS SIGNAL TERMINATED"
	for enemy: EnemyActor2D in [soldier, tank, helicopter]:
		if enemy != null:
			enemy.set_physics_process(false)
	projectile_root.process_mode = Node.PROCESS_MODE_DISABLED
	_game_over_overlay.visible = true
	_retry_button.grab_focus()


func _on_retry_pressed() -> void:
	if not game_over_active:
		return
	retry_requested.emit()
