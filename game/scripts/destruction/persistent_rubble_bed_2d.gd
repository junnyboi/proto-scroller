class_name PersistentRubbleBed2D
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
const DEFAULT_PIECE_COUNT: int = 4
const MAX_PIECE_COUNT: int = 6

var _pieces: Array[Sprite2D] = []
var _active: bool = false
var _baseline_y: float = 0.0
var _material_id: StringName = &"concrete"


func configure(
	footprint: Vector2,
	material_id: StringName,
	visual_tint: Color,
	pattern_seed: int,
	baseline_y: float,
	bed_height: float,
	piece_count: int = DEFAULT_PIECE_COUNT
) -> void:
	_material_id = material_id
	_baseline_y = baseline_y
	var bounded_count: int = clampi(piece_count, 1, MAX_PIECE_COUNT)
	_ensure_piece_count(bounded_count)
	var texture: Texture2D = _texture_for_material(material_id)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = maxi(pattern_seed, 1) * 982451653 + 961748927
	var half_width: float = maxf(footprint.x, 1.0) * 0.5
	var bounded_height: float = maxf(bed_height, 8.0)
	var width_range: Vector2 = Vector2(0.30, 0.42)
	if material_id == &"glass":
		width_range = Vector2(0.18, 0.26)
	elif material_id == &"steel":
		width_range = Vector2(0.25, 0.35)
	for index: int in range(_pieces.size()):
		var sprite: Sprite2D = _pieces[index]
		var weight: float = (float(index) + 0.5) / float(_pieces.size())
		var desired_width: float = footprint.x * rng.randf_range(
			width_range.x,
			width_range.y
		)
		var texture_width: float = maxf(texture.get_width(), 1.0)
		var texture_height: float = maxf(texture.get_height(), 1.0)
		var horizontal_scale: float = desired_width / texture_width
		var natural_height: float = texture_height * horizontal_scale
		var displayed_height: float = minf(natural_height, bounded_height)
		var vertical_scale: float = displayed_height / texture_height
		sprite.texture = texture
		sprite.position = Vector2(
			lerpf(-half_width * 0.76, half_width * 0.76, weight)
				+ rng.randf_range(-footprint.x * 0.045, footprint.x * 0.045),
			baseline_y - displayed_height * 0.5
				+ rng.randf_range(-bounded_height * 0.06, bounded_height * 0.06)
		)
		sprite.rotation = rng.randf_range(-0.24, 0.24)
		sprite.scale = Vector2(horizontal_scale, vertical_scale)
		sprite.flip_h = rng.randi_range(0, 1) == 1
		var readable_tint: Color = visual_tint.lerp(Color.WHITE, 0.76)
		sprite.modulate = readable_tint * Color(1.0, 0.97, 0.90, 1.0)
	set_active(_active)


func set_active(value: bool) -> void:
	_active = value
	visible = value


func is_active() -> bool:
	return _active and visible


func active_piece_count() -> int:
	return _pieces.size() if is_active() else 0


func total_piece_count() -> int:
	return _pieces.size()


func baseline_y() -> float:
	return _baseline_y


func material_id() -> StringName:
	return _material_id


func uses_only_rubble_fragments() -> bool:
	for sprite: Sprite2D in _pieces:
		if sprite.texture not in [CONCRETE_TEXTURE, GLASS_TEXTURE, STEEL_TEXTURE]:
			return false
	return true


func _ensure_piece_count(piece_count: int) -> void:
	while _pieces.size() < piece_count:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "RubblePiece%02d" % _pieces.size()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
		_pieces.append(sprite)
	while _pieces.size() > piece_count:
		var sprite: Sprite2D = _pieces.pop_back()
		sprite.queue_free()


func _texture_for_material(material_id: StringName) -> Texture2D:
	if material_id == &"glass":
		return GLASS_TEXTURE
	if material_id == &"steel":
		return STEEL_TEXTURE
	return CONCRETE_TEXTURE
