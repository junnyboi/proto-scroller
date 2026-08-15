class_name CitySlice
extends Node2D

const DAMAGE_MASK: int = (1 << 1) | (1 << 6) | (1 << 7)
const WORLD_LAYER: int = 1 << 0
const ROBOT_LAYER: int = 1 << 1
const ENEMY_LAYER: int = 1 << 2
const HURTBOX_LAYER: int = 1 << 6
const PROP_LAYER: int = 1 << 7

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
var _health_label: Label
var _status_label: Label
var _objective_label: Label
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
	robot.collision_mask = WORLD_LAYER
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
	robot_sprite.position.y = 48.0
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
	robot.health_changed.connect(_on_robot_health_changed)
	add_child(robot)


func _build_destructibles() -> void:
	building = _create_building(Vector2(1450.0, 590.0))
	streetlamp = _create_prop(
		"Streetlamp",
		Vector2(1220.0, 472.0),
		LAMP_INTACT,
		LAMP_BROKEN,
		Vector2(70.0, 235.0),
		Vector2(185.0, 90.0),
		Vector2(42.0, 220.0),
		Vector2(170.0, 55.0),
		38.0,
		4.0
	)
	car = _create_prop(
		"Car",
		Vector2(930.0, 548.0),
		CAR_INTACT,
		CAR_WRECK,
		Vector2(165.0, 78.0),
		Vector2(175.0, 76.0),
		Vector2(150.0, 62.0),
		Vector2(160.0, 58.0),
		35.0,
		12.0
	)


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
	intact_body.collision_layer = WORLD_LAYER
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
	rubble_body.collision_layer = WORLD_LAYER
	rubble_body.collision_mask = ROBOT_LAYER
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
		Vector2(1320.0, 530.0),
		Vector2(68.0, 108.0),
		Vector2(42.0, 95.0)
	) as SoldierEnemy
	tank = _create_enemy(
		TANK_SCRIPT,
		TANK_TEXTURE,
		Vector2(1700.0, 535.0),
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
