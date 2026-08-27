class_name BuildingSectionBurst2D
extends Node2D

const CONCRETE_TEXTURE: Texture2D = preload(
	"res://art/city/destructibles/debris/concrete_chunk.png"
)
const GLASS_TEXTURE: Texture2D = preload(
	"res://art/city/destructibles/debris/glass_shard.png"
)
const STEEL_TEXTURE: Texture2D = preload(
	"res://art/city/destructibles/debris/steel_fragment.png"
)
const DUST_TEXTURE: Texture2D = preload(
	"res://art/city/destructibles/debris/dust_puff.png"
)
const FLASH_TEXTURE: Texture2D = preload(
	"res://art/city/destructibles/debris/impact_flash.png"
)

const ACTIVE_LIFETIME: float = 1.25
const FLASH_LIFETIME: float = 0.24

var fragments: CPUParticles2D
var dust: CPUParticles2D
var flash: Sprite2D
var material_id: StringName = &"concrete"
var activation_sequence: int = 0
var _age: float = ACTIVE_LIFETIME
var _active: bool = false


func setup() -> void:
	if fragments != null:
		return
	top_level = true
	z_as_relative = false
	z_index = 41
	fragments = _make_particles("Fragments", 12, 1.05)
	fragments.angular_velocity_min = -540.0
	fragments.angular_velocity_max = 540.0
	fragments.damping_min = 22.0
	fragments.damping_max = 62.0
	add_child(fragments)
	dust = _make_particles("Dust", 7, 0.82)
	dust.angular_velocity_min = -95.0
	dust.angular_velocity_max = 95.0
	dust.damping_min = 58.0
	dust.damping_max = 120.0
	dust.texture = DUST_TEXTURE
	add_child(dust)
	flash = Sprite2D.new()
	flash.name = "ImpactFlash"
	flash.texture = FLASH_TEXTURE
	flash.visible = false
	flash.z_index = 2
	add_child(flash)
	deactivate()


func activate(
	origin: Vector2,
	impact_direction: Vector2,
	impact_speed: float,
	profile: StructuralMaterialProfile,
	sequence: int
) -> void:
	if fragments == null:
		setup()
	material_id = profile.material_id if profile != null else &"concrete"
	activation_sequence = sequence
	global_position = origin
	var direction: Vector2 = impact_direction
	if direction.is_zero_approx():
		direction = Vector2.UP
	direction = Vector2(direction.x, minf(direction.y - 0.28, -0.18)).normalized()
	var speed: float = clampf(impact_speed, 220.0, 920.0)
	_configure_fragments(direction, speed, profile)
	_configure_dust(direction, speed, profile)
	_configure_flash(speed)
	_age = 0.0
	_active = true
	visible = true
	set_process(true)
	fragments.restart()
	dust.restart()


func deactivate() -> void:
	_active = false
	_age = ACTIVE_LIFETIME
	set_process(false)
	if fragments != null:
		fragments.emitting = false
	if dust != null:
		dust.emitting = false
	if flash != null:
		flash.visible = false
	visible = false


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	if flash != null and _age < FLASH_LIFETIME:
		var progress: float = clampf(_age / FLASH_LIFETIME, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 3.0)
		flash.scale = Vector2.ONE * lerpf(0.18, 0.72, eased)
		flash.modulate.a = 1.0 - progress
	else:
		flash.visible = false
	if _age >= ACTIVE_LIFETIME:
		deactivate()


func _configure_fragments(
	direction: Vector2,
	impact_speed: float,
	profile: StructuralMaterialProfile
) -> void:
	fragments.texture = texture_for_material(material_id)
	fragments.direction = direction
	fragments.spread = profile.particle_spread if profile != null else 72.0
	fragments.gravity = Vector2(
		0.0,
		profile.particle_gravity if profile != null else 560.0
	)
	var speed_min: float = profile.particle_speed_min if profile != null else 0.35
	var speed_max: float = profile.particle_speed_max if profile != null else 0.95
	fragments.initial_velocity_min = impact_speed * speed_min
	fragments.initial_velocity_max = impact_speed * speed_max
	fragments.color = Color.WHITE
	match material_id:
		&"glass":
			fragments.amount = 18
			fragments.scale_amount_min = 0.055
			fragments.scale_amount_max = 0.16
		&"steel":
			fragments.amount = 8
			fragments.scale_amount_min = 0.075
			fragments.scale_amount_max = 0.19
		_:
			fragments.amount = 12
			fragments.scale_amount_min = 0.065
			fragments.scale_amount_max = 0.20


func _configure_dust(
	direction: Vector2,
	impact_speed: float,
	_profile: StructuralMaterialProfile
) -> void:
	dust.direction = Vector2(direction.x * 0.42, -0.82).normalized()
	dust.initial_velocity_min = impact_speed * 0.16
	dust.initial_velocity_max = impact_speed * 0.34
	dust.scale_amount_min = 0.16
	dust.scale_amount_max = 0.42
	match material_id:
		&"glass":
			dust.amount = 4
			dust.spread = 78.0
			dust.gravity = Vector2(0.0, 230.0)
			dust.color = Color(0.42, 0.86, 0.94, 0.38)
		&"steel":
			dust.amount = 5
			dust.spread = 42.0
			dust.gravity = Vector2(0.0, 680.0)
			dust.color = Color(1.0, 0.58, 0.24, 0.62)
		_:
			dust.amount = 9
			dust.spread = 92.0
			dust.gravity = Vector2(0.0, 210.0)
			dust.color = Color(0.72, 0.64, 0.54, 0.72)


func _configure_flash(impact_speed: float) -> void:
	flash.rotation = float(activation_sequence % 12) * TAU / 12.0
	flash.scale = Vector2.ONE * 0.18
	flash.modulate = _flash_color(material_id)
	flash.modulate.a = clampf(impact_speed / 520.0, 0.66, 1.0)
	flash.visible = true


func _make_particles(
	particle_name: String,
	amount: int,
	lifetime: float
) -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = particle_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.32
	particles.local_coords = false
	particles.emitting = false
	return particles


static func texture_for_material(kind: StringName) -> Texture2D:
	match kind:
		&"glass":
			return GLASS_TEXTURE
		&"steel":
			return STEEL_TEXTURE
		_:
			return CONCRETE_TEXTURE


static func _flash_color(kind: StringName) -> Color:
	match kind:
		&"glass":
			return Color(0.66, 0.97, 1.0, 1.0)
		&"steel":
			return Color(1.0, 0.62, 0.28, 1.0)
		_:
			return Color(0.88, 0.94, 0.96, 1.0)
