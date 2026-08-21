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


func setup(
	texture: Texture2D,
	display_size: Vector2,
	p_lifetime: float,
	p_z_index: int,
	particle_amount: int = 6
) -> void:
	lifetime = p_lifetime
	z_as_relative = false
	z_index = p_z_index
	sprite = Sprite2D.new()
	sprite.name = "ImpactSprite"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texture_size: Vector2 = texture.get_size()
	var fit_scale: float = minf(
		display_size.x / maxf(texture_size.x, 1.0),
		display_size.y / maxf(texture_size.y, 1.0)
	)
	_base_scale = Vector2.ONE * fit_scale
	sprite.scale = _base_scale
	add_child(sprite)
	particles = GPUParticles2D.new()
	particles.name = "ImpactParticles"
	particles.amount = particle_amount
	particles.lifetime = p_lifetime * 1.15
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.35
	particles.texture = texture
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
	deactivate()


func activate(world_position: Vector2, direction: Vector2 = Vector2.RIGHT) -> void:
	global_position = world_position
	rotation = direction.angle()
	age = 0.0
	active = true
	visible = true
	sprite.visible = true
	sprite.scale = _base_scale * 0.76
	sprite.modulate = Color.WHITE
	particles.restart()
	particles.emitting = true
	activation_count += 1
	set_process(true)


func deactivate() -> void:
	active = false
	visible = false
	set_process(false)
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
