class_name ImpactFeedbackPool
extends Node

const GLASS_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/structural/glass_shatter.wav"
)
const CONCRETE_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/structural/concrete_crunch.wav"
)
const STEEL_IMPACT_SFX: AudioStream = preload(
	"res://audio/sfx/structural/steel_groan.wav"
)

@export_range(1, 16, 1) var particle_capacity: int = 8
@export_range(1, 16, 1) var audio_capacity: int = 8

var last_material_audio: StringName = &""
var material_audio_play_count: int = 0
var _particle_root: Node2D
var _audio_root: Node2D
var _particles: Array[CPUParticles2D] = []
var _audio_players: Array[AudioStreamPlayer2D] = []
var _particle_cursor: int = 0
var _audio_cursor: int = 0
var _material_audio_cooldowns: Dictionary[StringName, int] = {}


func setup(particle_root: Node2D, audio_root: Node2D) -> void:
	_particle_root = particle_root
	_audio_root = audio_root


func _ready() -> void:
	_prewarm_particles()
	_prewarm_audio()


func spawn_particles(
	origin: Vector2,
	direction: Vector2,
	impact_speed: float,
	profile: StructuralMaterialProfile
) -> CPUParticles2D:
	if profile == null or _particles.is_empty():
		return null
	var particles: CPUParticles2D = _particles[_particle_cursor]
	_particle_cursor = (_particle_cursor + 1) % _particles.size()
	particles.global_position = origin
	particles.amount = clampi(roundi(impact_speed * profile.particle_amount_scale), 8, 56)
	particles.direction = direction.normalized()
	particles.spread = profile.particle_spread
	particles.gravity = Vector2(0.0, profile.particle_gravity)
	particles.initial_velocity_min = impact_speed * profile.particle_speed_min
	particles.initial_velocity_max = impact_speed * profile.particle_speed_max
	particles.scale_amount_min = profile.particle_scale_min
	particles.scale_amount_max = profile.particle_scale_max
	particles.color = profile.particle_color
	particles.set_meta(&"structural_material", profile.material_id)
	particles.restart()
	return particles


func play_audio(
	profile: StructuralMaterialProfile,
	origin: Vector2,
	impact_speed: float,
	force_play: bool = false
) -> AudioStreamPlayer2D:
	if profile == null or _audio_players.is_empty():
		return null
	var now_msec: int = Time.get_ticks_msec()
	var next_allowed: int = _material_audio_cooldowns.get(profile.material_id, 0)
	if not force_play and now_msec < next_allowed:
		return null
	_material_audio_cooldowns[profile.material_id] = now_msec + 140
	var player: AudioStreamPlayer2D = _audio_players[_audio_cursor]
	_audio_cursor = (_audio_cursor + 1) % _audio_players.size()
	player.stop()
	player.name = "%sImpact" % profile.display_name
	player.stream = audio_stream_for_material(profile.material_id)
	player.global_position = origin
	player.volume_db = clampf(-8.0 + impact_speed / 90.0, -8.0, -2.0)
	player.pitch_scale = pitch_for_material(profile.material_id, impact_speed)
	player.set_meta(&"structural_material", profile.material_id)
	last_material_audio = profile.material_id
	material_audio_play_count += 1
	player.play()
	return player


func audio_stream_for_material(material_id: StringName) -> AudioStream:
	match material_id:
		&"glass":
			return GLASS_IMPACT_SFX
		&"steel":
			return STEEL_IMPACT_SFX
		_:
			return CONCRETE_IMPACT_SFX


func pitch_for_material(material_id: StringName, impact_speed: float) -> float:
	var speed_pitch: float = clampf(impact_speed / 900.0, 0.0, 0.16)
	match material_id:
		&"glass":
			return 1.04 + speed_pitch
		&"steel":
			return 0.78 + speed_pitch * 0.45
		_:
			return 0.90 + speed_pitch * 0.65


func _prewarm_particles() -> void:
	if _particle_root == null:
		return
	for index: int in range(particle_capacity):
		var particles: CPUParticles2D = CPUParticles2D.new()
		particles.name = "ImpactFragments" if index == 0 else "ImpactFragments%d" % index
		particles.z_index = 42
		particles.amount = 8
		particles.lifetime = 0.9
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.local_coords = false
		particles.emitting = false
		particles.angular_velocity_min = -420.0
		particles.angular_velocity_max = 420.0
		particles.damping_min = 25.0
		particles.damping_max = 70.0
		_particle_root.add_child(particles)
		_particles.append(particles)


func _prewarm_audio() -> void:
	if _audio_root == null:
		return
	for index: int in range(audio_capacity):
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		player.name = "ImpactAudio%02d" % index
		player.max_distance = 1500.0
		player.attenuation = 0.55
		_audio_root.add_child(player)
		_audio_players.append(player)
