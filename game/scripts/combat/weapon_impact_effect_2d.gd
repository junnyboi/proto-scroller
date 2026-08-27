class_name WeaponImpactEffect2D
extends Node2D

var active: bool = false
var paused: bool = false
var age: float = 0.0
var lifetime: float = 0.24
var activation_count: int = 0
var sprite: Sprite2D
var particles: GPUParticles2D
var _base_scale: Vector2 = Vector2.ONE
var _uses_atlas_region: bool = false


func setup(
	texture: Texture2D,
	display_size: Vector2,
	p_lifetime: float,
	p_z_index: int,
	particle_amount: int = 6
) -> void:
	_ensure_nodes(p_lifetime, particle_amount)
	z_as_relative = false
	z_index = p_z_index
	_configure_visual(texture, Rect2i(), display_size, p_lifetime, Color.WHITE)
	deactivate()


func configure_from_spec(spec: Dictionary) -> bool:
	var texture: Texture2D = spec.get("texture") as Texture2D
	var region: Rect2i = spec.get("region", Rect2i())
	var display_size: Vector2 = spec.get("display_size", Vector2.ZERO)
	var next_lifetime: float = float(spec.get("lifetime", 0.24))
	var tint: Color = spec.get("tint", Color.WHITE)
	if texture == null or display_size.x <= 0.0 or display_size.y <= 0.0:
		return false
	_ensure_nodes(next_lifetime, 1)
	_configure_visual(texture, region, display_size, next_lifetime, tint)
	return true


func activate(world_position: Vector2, direction: Vector2 = Vector2.RIGHT) -> void:
	global_position = world_position
	rotation = direction.angle()
	age = 0.0
	paused = false
	active = true
	visible = true
	sprite.visible = true
	sprite.scale = _base_scale * 0.76
	sprite.modulate.a = 1.0
	if not _uses_atlas_region and particles.amount > 0:
		particles.restart()
		particles.emitting = true
	activation_count += 1
	set_process(true)


func deactivate() -> void:
	active = false
	paused = false
	age = 0.0
	visible = false
	rotation = 0.0
	set_process(false)
	if sprite != null:
		sprite.visible = false
		sprite.scale = _base_scale
		sprite.rotation = 0.0
		sprite.modulate.a = 1.0
	if particles != null:
		particles.emitting = false


func _process(delta: float) -> void:
	if not active or paused:
		return
	age += delta
	var progress: float = clampf(age / lifetime, 0.0, 1.0)
	sprite.scale = _base_scale * lerpf(0.76, 1.18, progress)
	sprite.modulate.a = 1.0 - progress
	if age >= lifetime:
		deactivate()


func _ensure_nodes(p_lifetime: float, particle_amount: int) -> void:
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "ImpactSprite"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
	if particles != null:
		return
	particles = GPUParticles2D.new()
	particles.name = "ImpactParticles"
	particles.amount = particle_amount
	particles.lifetime = p_lifetime * 1.15
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.35
	particles.visibility_rect = Rect2(-128.0, -128.0, 256.0, 256.0)
	var particle_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	particle_material.direction = Vector3(1.0, 0.0, 0.0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 95.0
	particle_material.initial_velocity_max = 210.0
	particle_material.gravity = Vector3(0.0, 180.0, 0.0)
	particle_material.scale_min = 0.035
	particle_material.scale_max = 0.075
	particles.process_material = particle_material
	add_child(particles)


func _configure_visual(
	texture: Texture2D,
	region: Rect2i,
	display_size: Vector2,
	p_lifetime: float,
	tint: Color
) -> void:
	lifetime = p_lifetime
	_uses_atlas_region = region.size != Vector2i.ZERO
	sprite.texture = texture
	sprite.region_enabled = _uses_atlas_region
	sprite.region_rect = Rect2(region) if _uses_atlas_region else Rect2()
	var source_size: Vector2 = Vector2(region.size) if _uses_atlas_region else texture.get_size()
	var fit_scale: float = minf(
		display_size.x / maxf(source_size.x, 1.0),
		display_size.y / maxf(source_size.y, 1.0)
	)
	_base_scale = Vector2.ONE * fit_scale
	sprite.scale = _base_scale
	sprite.modulate = tint
	particles.texture = texture if not _uses_atlas_region else null
	particles.visible = not _uses_atlas_region
	particles.amount = maxi(particles.amount, 1)
	particles.lifetime = p_lifetime * 1.15
	particles.emitting = false
