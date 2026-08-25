class_name CityWorldBuilder
extends RefCounted
# gdlint: disable=function-arguments-number

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
const ROBOT_ROAD_CLEARANCE_PIXELS: float = 15.0
const ROBOT_ROAD_CENTER_VISUAL_OFFSET_Y: float = 50.0
const ROBOT_SCRIPT: Script = preload("res://scripts/player/giant_robot_controller.gd")
const CAMERA_RIG_SCRIPT: Script = preload("res://scripts/camera/camera_rig.gd")
const SKY_TEXTURE: Texture2D = preload("res://art/city/parallax/sky.png")
const FAR_TEXTURE: Texture2D = preload("res://art/city/parallax/far_skyline.png")
const INFRA_TEXTURE: Texture2D = preload("res://art/city/parallax/infrastructure.png")
const NEAR_TEXTURE: Texture2D = preload("res://art/city/parallax/near_buildings.png")
const ROBOT_ATLAS: Texture2D = preload(
	"res://art/robot/grunt/grunt_horizontal_atlas.png"
)
const ROBOT_ANIMATION_PRESENTER: Script = preload(
	"res://scripts/player/robot_animation_presenter.gd"
)


static func build_environment(parent: Node2D) -> void:
	_build_parallax(parent)


static func compensate_parallax(parent: Node2D, offset: Vector2) -> void:
	var backdrop: Node2D = parent.get_node_or_null(^"ParallaxCity") as Node2D
	if backdrop == null:
		return
	for child: Node in backdrop.get_children():
		var band: Parallax2D = child as Parallax2D
		if band != null:
			band.scroll_offset += offset * band.scroll_scale


static func build_robot(
	parent: Node2D,
	on_heavy_impact: Callable,
	on_health_changed: Callable,
	on_damage_received: Callable,
	on_defeated: Callable
) -> GiantRobotController:
	var robot: GiantRobotController = ROBOT_SCRIPT.new() as GiantRobotController
	robot.name = "Robot"
	robot.position = Vector2(760.0, 460.0)
	robot.max_health = 800.0
	robot.stomp_radius = 320.0
	robot.stomp_damage = 180.0
	robot.collision_layer = ROBOT_LAYER
	robot.collision_mask = WORLD_LAYER | BUILDING_LAYER
	robot.z_index = 100
	robot.set_meta(&"combat_team", &"player")
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
	visual_root.position.y = ROBOT_ROAD_CENTER_VISUAL_OFFSET_Y
	visual_root.set_meta(&"baked_directional_art", true)
	var robot_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	robot_sprite.name = "RobotAnimatedSprite"
	robot_sprite.sprite_frames = RobotSpriteFramesBuilder.build(ROBOT_ATLAS)
	robot_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	robot_sprite.scale = Vector2.ONE * 1.246
	robot_sprite.position.y = 72.0
	visual_root.add_child(robot_sprite)
	var visual_ground_origin: Marker2D = Marker2D.new()
	visual_ground_origin.name = "VisualGroundOrigin"
	visual_ground_origin.position = Vector2(0.0, 126.0)
	visual_root.add_child(visual_ground_origin)
	robot.add_child(visual_root)
	var impact_origin: Marker2D = Marker2D.new()
	impact_origin.name = "GroundImpactOrigin"
	impact_origin.position = Vector2(0.0, 126.0)
	robot.add_child(impact_origin)
	var laser_emitter: Marker2D = Marker2D.new()
	laser_emitter.name = "LaserEmitter"
	laser_emitter.position = Vector2(54.0, -32.0)
	visual_root.add_child(laser_emitter)
	var animation_presenter: RobotAnimationPresenter = ROBOT_ANIMATION_PRESENTER.new()
	animation_presenter.name = "RobotAnimationPresenter"
	animation_presenter.setup(robot, robot_sprite)
	robot.add_child(animation_presenter)
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
	robot.heavy_impact_requested.connect(on_heavy_impact)
	robot.health_changed.connect(on_health_changed)
	robot.damage_received.connect(on_damage_received)
	robot.defeated.connect(on_defeated)
	parent.add_child(robot)
	return robot


static func build_camera(parent: Node2D, robot: GiantRobotController) -> void:
	var camera_rig: CameraRig = CAMERA_RIG_SCRIPT.new() as CameraRig
	camera_rig.name = "CameraRig"
	camera_rig.target = robot
	camera_rig.position = Vector2(640.0, 360.0)
	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera2D"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.position = Vector2.ZERO
	camera_rig.add_child(camera)
	parent.add_child(camera_rig)
	camera.make_current()
	camera.reset_smoothing()


static func fit_sprite(texture: Texture2D, display_size: Vector2) -> Sprite2D:
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


static func _build_parallax(parent: Node2D) -> void:
	var backdrop: Node2D = Node2D.new()
	backdrop.name = "ParallaxCity"
	parent.add_child(backdrop)
	_create_parallax_band(backdrop, "Sky", SKY_TEXTURE, Vector2(0.05, 1.0), -50, 0.0)
	_create_parallax_band(backdrop, "FarSkyline", FAR_TEXTURE, Vector2(0.18, 1.0), -40, 85.0)
	_create_parallax_band(backdrop, "Infrastructure", INFRA_TEXTURE, Vector2(0.35, 1.0), -30, 95.0)
	_create_parallax_band(backdrop, "NearBuildings", NEAR_TEXTURE, Vector2(0.60, 1.0), -20, 116.0)


static func _create_parallax_band(
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
