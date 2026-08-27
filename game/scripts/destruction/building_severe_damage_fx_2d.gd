class_name BuildingSevereDamageFx2D
extends Node2D

const SEVERE_THRESHOLD: float = 0.62
const FIRE_TONGUES: int = 5
const EMBER_COUNT: int = 4
const ARC_SEGMENTS: int = 5
const ARC_FLASH_RATE: float = 5.4

var severity: float = 0.0
var destroyed_stage: bool = false
var fire_intensity: float = 0.0
var arc_intensity: float = 0.0
var activation_count: int = 0
var _cell_size: Vector2 = Vector2.ONE
var _pattern_seed: int = 1
var _time: float = 0.0
var _active: bool = false


func configure(cell_size: Vector2, pattern_seed: int) -> void:
	_cell_size = cell_size
	_pattern_seed = maxi(pattern_seed, 1)
	z_index = 0
	if material == null:
		var additive_material: CanvasItemMaterial = CanvasItemMaterial.new()
		additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive_material
	reset_effect()


func set_damage_state(value: float, destroyed: bool) -> void:
	severity = clampf(value, 0.0, 1.0)
	destroyed_stage = destroyed
	var next_active: bool = severity >= SEVERE_THRESHOLD
	if next_active and not _active:
		activation_count += 1
	_active = next_active
	visible = _active
	set_process(_active)
	if not _active:
		fire_intensity = 0.0
		arc_intensity = 0.0
		return
	var severe_progress: float = inverse_lerp(SEVERE_THRESHOLD, 1.0, severity)
	fire_intensity = lerpf(0.38, 1.0, severe_progress)
	if destroyed_stage:
		fire_intensity = 1.0
	arc_intensity = lerpf(0.34, 0.92, severe_progress)
	if destroyed_stage:
		arc_intensity *= 0.72
	queue_redraw()


func reset_effect() -> void:
	severity = 0.0
	destroyed_stage = false
	fire_intensity = 0.0
	arc_intensity = 0.0
	activation_count = 0
	_time = 0.0
	_active = false
	visible = false
	set_process(false)
	queue_redraw()


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var center: Vector2 = Vector2(0.0, _cell_size.y * 0.09)
	var pulse: float = 0.82 + sin(_time * 8.4 + float(_pattern_seed)) * 0.18
	var glow_radius: float = minf(_cell_size.x, _cell_size.y) * 0.17
	draw_circle(
		center,
		glow_radius * pulse,
		Color(1.0, 0.16, 0.015, 0.12 * fire_intensity)
	)
	draw_circle(
		center + Vector2(0.0, glow_radius * 0.12),
		glow_radius * 0.62 * pulse,
		Color(1.0, 0.48, 0.035, 0.20 * fire_intensity)
	)
	_draw_flames(center, glow_radius)
	_draw_embers(center, glow_radius)
	if _arc_flash_visible():
		_draw_arcs(center, glow_radius)


func _draw_flames(center: Vector2, radius: float) -> void:
	for flame_index: int in range(FIRE_TONGUES):
		var phase: float = _time * (6.1 + float(flame_index) * 0.37)
		phase += float(_pattern_seed * 3 + flame_index * 11)
		var x_ratio: float = lerpf(-0.72, 0.72, float(flame_index) / 4.0)
		var base: Vector2 = center + Vector2(x_ratio * radius, radius * 0.46)
		var height: float = radius * lerpf(0.64, 1.16, _wave(phase)) * fire_intensity
		var half_width: float = radius * lerpf(0.13, 0.22, _wave(phase * 1.43))
		var tip: Vector2 = base + Vector2(
			sin(phase * 0.73) * half_width * 0.82,
			-height
		)
		var flame: PackedVector2Array = PackedVector2Array([
			base - Vector2(half_width, 0.0),
			tip,
			base + Vector2(half_width, 0.0),
		])
		draw_colored_polygon(flame, Color(1.0, 0.25, 0.025, 0.68 * fire_intensity))
		var inner_base: Vector2 = base - Vector2(0.0, radius * 0.04)
		var inner: PackedVector2Array = PackedVector2Array([
			inner_base - Vector2(half_width * 0.42, 0.0),
			inner_base.lerp(tip, 0.72),
			inner_base + Vector2(half_width * 0.42, 0.0),
		])
		draw_colored_polygon(inner, Color(1.0, 0.86, 0.20, 0.82 * fire_intensity))


func _draw_embers(center: Vector2, radius: float) -> void:
	for ember_index: int in range(EMBER_COUNT):
		var phase: float = _time * (1.8 + float(ember_index) * 0.19)
		phase += float(_pattern_seed + ember_index * 7)
		var rise: float = fmod(phase, 1.0)
		var x_offset: float = sin(phase * 8.7) * radius * (0.24 + 0.09 * ember_index)
		var ember: Vector2 = center + Vector2(x_offset, radius * 0.32 - rise * radius * 1.55)
		draw_circle(
			ember,
			lerpf(1.4, 3.2, _wave(phase * 4.3)),
			Color(1.0, 0.58, 0.08, (1.0 - rise) * 0.82 * fire_intensity)
		)


func _arc_flash_visible() -> bool:
	var flash_phase: float = fmod(
		_time * ARC_FLASH_RATE + float(posmod(_pattern_seed, 17)) * 0.13,
		1.0
	)
	return flash_phase >= lerpf(0.72, 0.48, arc_intensity)


func _draw_arcs(center: Vector2, radius: float) -> void:
	for arc_index: int in range(2):
		var points: PackedVector2Array = PackedVector2Array()
		var arc_y: float = center.y - radius * (0.46 - float(arc_index) * 0.51)
		for segment_index: int in range(ARC_SEGMENTS):
			var ratio: float = float(segment_index) / float(ARC_SEGMENTS - 1)
			var x: float = lerpf(-radius * 0.88, radius * 0.88, ratio)
			var jitter: float = sin(
				float(_pattern_seed * 5 + arc_index * 31 + segment_index * 17)
				+ floor(_time * ARC_FLASH_RATE) * 2.7
			) * radius * 0.16
			points.append(Vector2(center.x + x, arc_y + jitter))
		draw_polyline(points, Color(0.08, 0.54, 1.0, 0.34 * arc_intensity), 6.0, true)
		draw_polyline(points, Color(0.78, 0.96, 1.0, 0.95 * arc_intensity), 1.8, true)


func _wave(value: float) -> float:
	return sin(value) * 0.5 + 0.5
