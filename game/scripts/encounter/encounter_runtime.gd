class_name EncounterRuntime
extends Node2D

signal projectile_requested(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	kind: StringName,
	source: Node
)
signal enemy_died(enemy: EnemyActor2D, event: DamageEvent, points: int)
signal enemy_acquired(enemy: EnemyActor2D)

const WORLD_LAYER: int = 1 << 0
const ENEMY_LAYER: int = 1 << 2
const ROBOT_LAYER: int = 1 << 1
const BUILDING_LAYER: int = 1 << 3
const HURTBOX_LAYER: int = 1 << 6
const LAND_BASELINE_Y: float = 655.0
const SOLDIER_SCRIPT: Script = preload("res://scripts/actors/soldier.gd")
const TANK_SCRIPT: Script = preload("res://scripts/actors/tank.gd")
const HELICOPTER_SCRIPT: Script = preload("res://scripts/actors/helicopter.gd")
const SOLDIER_TEXTURE: Texture2D = preload("res://art/city/enemies/soldier.png")
const TANK_TEXTURE: Texture2D = preload("res://art/city/enemies/tank.png")
const HELICOPTER_TEXTURE: Texture2D = preload("res://art/city/enemies/helicopter.png")

var robot: GiantRobotController
var telegraphs: TelegraphPresenter2D
var projectile_pool: ProjectilePool
var soldiers: Array[SoldierEnemy] = []
var tanks: Array[TankEnemy] = []
var helicopters: Array[HelicopterEnemy] = []
var post_warm_creation_count: int = 0
var attack_gate_enabled: bool = true
var structural_target: StructuralBuilding2D
var role_profiles: Dictionary[StringName, EnemyRoleProfile] = {}
var trait_profiles: Dictionary[StringName, EnemyTraitProfile] = {}


func setup(
	p_robot: GiantRobotController,
	p_telegraphs: TelegraphPresenter2D,
	p_projectile_pool: ProjectilePool,
	p_structural_target: StructuralBuilding2D = null
) -> void:
	robot = p_robot
	telegraphs = p_telegraphs
	projectile_pool = p_projectile_pool
	structural_target = p_structural_target


func configure_profiles(
	roles: Array[EnemyRoleProfile],
	traits: Array[EnemyTraitProfile]
) -> void:
	role_profiles.clear()
	trait_profiles.clear()
	for profile: EnemyRoleProfile in roles:
		role_profiles[profile.role_id] = profile
	for profile: EnemyTraitProfile in traits:
		trait_profiles[profile.trait_id] = profile


func _ready() -> void:
	for index: int in range(RuntimeBudget.SOLDIERS):
		soldiers.append(_create_enemy(&"soldier", index) as SoldierEnemy)
	for index: int in range(RuntimeBudget.TANKS):
		tanks.append(_create_enemy(&"tank", index) as TankEnemy)
	for index: int in range(RuntimeBudget.HELICOPTERS):
		helicopters.append(_create_enemy(&"helicopter", index) as HelicopterEnemy)


func acquire(
	kind: StringName,
	spawn_position: Vector2,
	role_id: StringName = &"",
	trait_id: StringName = &""
) -> EnemyActor2D:
	for enemy: EnemyActor2D in _actors_for_kind(kind):
		if not enemy.active:
			enemy.activate(spawn_position, robot)
			var accepted_trait: StringName = trait_id
			if trait_id == &"COMMAND" and _has_active_command():
				accepted_trait = &""
			enemy.apply_profiles(
				role_profiles.get(role_id) as EnemyRoleProfile,
				trait_profiles.get(accepted_trait) as EnemyTraitProfile
			)
			enemy.structural_target = structural_target
			enemy.set_attack_gate(attack_gate_enabled)
			enemy_acquired.emit(enemy)
			return enemy
	return null


func release(enemy: EnemyActor2D) -> void:
	if enemy != null and enemy.active:
		enemy.deactivate()


func release_deferred(enemy: EnemyActor2D) -> void:
	call_deferred("release", enemy)


func release_all() -> void:
	for enemy: EnemyActor2D in all_actors():
		release(enemy)


func set_attack_gate(enabled: bool) -> void:
	attack_gate_enabled = enabled
	for enemy: EnemyActor2D in all_actors():
		enemy.set_attack_gate(enabled)


func all_actors() -> Array[EnemyActor2D]:
	var actors: Array[EnemyActor2D] = []
	actors.append_array(soldiers)
	actors.append_array(tanks)
	actors.append_array(helicopters)
	return actors


func active_count(kind: StringName = &"") -> int:
	var count: int = 0
	var actors: Array[EnemyActor2D] = all_actors() if kind.is_empty() else _actors_for_kind(kind)
	for enemy: EnemyActor2D in actors:
		if enemy.active and not enemy.dead:
			count += 1
	return count


func available_count(kind: StringName) -> int:
	return _actors_for_kind(kind).size() - active_count(kind)


func total_count(kind: StringName = &"") -> int:
	return all_actors().size() if kind.is_empty() else _actors_for_kind(kind).size()


func set_catalyst_target(catalyst: Catalyst2D) -> void:
	for enemy: EnemyActor2D in all_actors():
		enemy.catalyst_target = catalyst


func _has_active_command() -> bool:
	for enemy: EnemyActor2D in all_actors():
		if enemy.active and not enemy.dead and enemy.trait_id == &"COMMAND":
			return true
	return false


func _create_enemy(kind: StringName, index: int) -> EnemyActor2D:
	var enemy: EnemyActor2D
	var texture: Texture2D
	var display_size: Vector2
	var collision_size: Vector2
	var authored_y: float = 542.5
	if kind == &"soldier":
		enemy = SOLDIER_SCRIPT.new() as SoldierEnemy
		texture = SOLDIER_TEXTURE
		display_size = Vector2(68.0, 108.0)
		collision_size = Vector2(42.0, 95.0)
	elif kind == &"tank":
		enemy = TANK_SCRIPT.new() as TankEnemy
		texture = TANK_TEXTURE
		display_size = Vector2(235.0, 100.0)
		collision_size = Vector2(220.0, 78.0)
		authored_y = 551.0
	else:
		enemy = HELICOPTER_SCRIPT.new() as HelicopterEnemy
		texture = HELICOPTER_TEXTURE
		display_size = Vector2(235.0, 72.0)
		collision_size = Vector2(210.0, 58.0)
	enemy.name = "%sPool%02d" % [kind.capitalize(), index]
	enemy.collision_layer = ENEMY_LAYER
	enemy.collision_mask = 0 if kind == &"helicopter" else WORLD_LAYER
	enemy.z_index = 30
	enemy.set_meta(&"combat_team", &"enemy")
	enemy.telegraph_presenter = telegraphs
	enemy.projectile_pool = projectile_pool
	enemy.projectile_target_mask = ROBOT_LAYER | BUILDING_LAYER | (1 << 7)
	var visual: Sprite2D = CityWorldBuilder.fit_sprite(texture, display_size)
	visual.name = "Visual"
	if kind != &"helicopter":
		var rendered_height: float = texture.get_size().y * absf(visual.scale.y)
		visual.position.y = LAND_BASELINE_Y - authored_y - rendered_height * 0.5
		enemy.movement_bounce_enabled = true
		if kind == &"soldier":
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
	var hurt_shape: CollisionShape2D = CollisionShape2D.new()
	var hurt_rectangle: RectangleShape2D = RectangleShape2D.new()
	hurt_rectangle.size = collision_size * 1.12
	hurt_shape.shape = hurt_rectangle
	hurtbox.add_child(hurt_shape)
	enemy.add_child(hurtbox)
	enemy.projectile_requested.connect(_on_projectile_requested)
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	enemy.deactivate()
	return enemy


func _actors_for_kind(kind: StringName) -> Array[EnemyActor2D]:
	var actors: Array[EnemyActor2D] = []
	if kind == &"soldier":
		actors.assign(soldiers)
	elif kind == &"tank":
		actors.assign(tanks)
	elif kind == &"helicopter":
		actors.assign(helicopters)
	return actors


func _on_projectile_requested(
	origin: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	kind: StringName,
	source: Node
) -> void:
	projectile_requested.emit(origin, direction, speed, damage, kind, source)


func _on_enemy_died(enemy: EnemyActor2D, event: DamageEvent) -> void:
	var points: int = 500
	if enemy is TankEnemy:
		points = 1500
	elif enemy is HelicopterEnemy:
		points = 1200
	enemy_died.emit(enemy, event, points)
