class_name HazardRuntime
extends Node2D

signal hazard_activated(hazard_id: StringName, world_position: Vector2)
signal hazard_triggered(hazard_id: StringName, world_position: Vector2)
signal hazard_released(hazard_id: StringName)

const HAZARD_SCRIPT: Script = preload(
	"res://scripts/hazards/environmental_hazard_2d.gd"
)
const VFX_SCRIPT: Script = preload("res://scripts/hazards/hazard_vfx_pool.gd")
const BASE_ATTACK_ID: int = 2_400_000

var dependencies: UrbanSiegeDependencies
var actors: Array[EnvironmentalHazard2D] = []
var vfx_pool: HazardVfxPool
var post_warm_creation_count: int = 0
var activation_count: int = 0
var impact_count: int = 0
var recycle_count: int = 0
var last_hazard_id: StringName = &""
var _next_attack_id: int = BASE_ATTACK_ID


func setup(p_dependencies: UrbanSiegeDependencies) -> void:
	dependencies = p_dependencies


func _ready() -> void:
	vfx_pool = VFX_SCRIPT.new() as HazardVfxPool
	vfx_pool.name = "HazardVfxPool"
	add_child(vfx_pool)
	for hazard_id: StringName in EnvironmentalHazardCatalog.MVP_IDS:
		var actor: EnvironmentalHazard2D = _build_actor(hazard_id)
		add_child(actor)
		actor.reset_hazard()
		actors.append(actor)


func activate(
	hazard_id: StringName,
	world_position: Vector2,
	facing: int = 1
) -> EnvironmentalHazard2D:
	if not EnvironmentalHazardCatalog.MVP_IDS.has(hazard_id):
		return null
	var actor: EnvironmentalHazard2D = actor_for(hazard_id)
	if actor == null:
		post_warm_creation_count += 1
		return null
	if actor.active:
		recycle_count += 1
		actor.reset_hazard()
	var position_value: Vector2 = world_position
	position_value.x = clampf(position_value.x, 120.0, 2440.0)
	position_value.y = CitySlice.LAND_VISUAL_BASELINE_Y
	actor.activate(
		hazard_id,
		EnvironmentalHazardCatalog.profile(hazard_id),
		position_value,
		facing
	)
	activation_count += 1
	last_hazard_id = hazard_id
	hazard_activated.emit(hazard_id, position_value)
	return actor


func resolve_impact(
	hazard: EnvironmentalHazard2D,
	trigger_event: DamageEvent,
	primary: bool
) -> void:
	if hazard == null or not hazard.active or dependencies == null:
		return
	var profile: Dictionary = hazard.profile
	var attack_id: int = _next_attack_id
	_next_attack_id += 1
	var root_attack_id: int = attack_id
	var causal_depth: int = 0
	if trigger_event != null:
		root_attack_id = trigger_event.root_attack_id
		causal_depth = mini(trigger_event.causal_depth + 1, DamageEvent.MAX_CAUSAL_DEPTH)
	var options: DamageQueryOptions = DamageQueryOptions.new()
	options.root_attack_id = root_attack_id
	options.causal_depth = causal_depth
	options.effect_flags = DamageEvent.FLAG_HAZARD
	options.result_limit = 32
	options.structural_limit = 1
	options.debris_limit = 4
	options.damage_type = StringName(profile.damage_type)
	options.player_damage_scale = float(profile.player_scale)
	var direction: Vector2 = _impact_direction(hazard)
	dependencies.destruction_director.queue_explosion(
		hazard.impact_origin(),
		float(profile.radius),
		float(profile.enemy_damage),
		float(profile.impulse),
		attack_id,
		hazard,
		options
	)
	vfx_pool.play(hazard.hazard_id, hazard.impact_origin(), direction)
	_apply_screen_shake(hazard, primary)
	impact_count += 1
	if primary:
		hazard_triggered.emit(hazard.hazard_id, hazard.impact_origin())


func release(hazard: EnvironmentalHazard2D) -> void:
	if hazard == null or not hazard.active:
		return
	var released_id: StringName = hazard.hazard_id
	hazard.reset_hazard()
	hazard_released.emit(released_id)


func release_all() -> void:
	for actor: EnvironmentalHazard2D in actors:
		actor.reset_hazard()
	if vfx_pool != null:
		vfx_pool.reset_all()
	if dependencies != null and dependencies.destruction_director != null:
		dependencies.destruction_director.cancel_effect_flags(DamageEvent.FLAG_HAZARD)


func actor_for(hazard_id: StringName) -> EnvironmentalHazard2D:
	for actor: EnvironmentalHazard2D in actors:
		if StringName(actor.get_meta(&"pool_hazard_id", &"")) == hazard_id:
			return actor
	return null


func active_count() -> int:
	var count: int = 0
	for actor: EnvironmentalHazard2D in actors:
		count += 1 if actor.active else 0
	return count


func total_count() -> int:
	return actors.size()


func _build_actor(hazard_id: StringName) -> EnvironmentalHazard2D:
	var actor: EnvironmentalHazard2D = HAZARD_SCRIPT.new() as EnvironmentalHazard2D
	actor.name = String(hazard_id).to_pascal_case()
	actor.runtime = self
	actor.z_index = 26
	actor.set_meta(&"pool_hazard_id", hazard_id)
	var visual: Sprite2D = Sprite2D.new()
	visual.name = "Visual"
	actor.add_child(visual)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = RectangleShape2D.new()
	actor.add_child(collision)
	actor.finished.connect(release)
	return actor


func _impact_direction(hazard: EnvironmentalHazard2D) -> Vector2:
	match StringName(hazard.profile.behavior):
		&"steam":
			return Vector2(float(hazard.facing), -0.55).normalized()
		&"electric":
			return Vector2(float(hazard.facing), -0.10).normalized()
		&"ramp":
			return Vector2(float(hazard.facing), -0.82).normalized()
		_:
			return Vector2(float(hazard.facing), -0.28).normalized()


func _apply_screen_shake(hazard: EnvironmentalHazard2D, primary: bool) -> void:
	if dependencies.city == null or dependencies.city.camera_rig == null:
		return
	var profile: Dictionary = hazard.profile
	var normalized: Vector2 = profile.shake as Vector2
	var shake_pulses: int = clampi(int(profile.shake_pulses), 1, 8)
	var impulse_scale: float = (
		16.0 + float(shake_pulses)
		if primary
		else 4.0 + float(shake_pulses) * 0.5
	)
	var impulse: Vector2 = Vector2(
		normalized.x * float(hazard.facing),
		normalized.y
	) * impulse_scale
	dependencies.city.camera_rig.add_impact_impulse(impulse)
