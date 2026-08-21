class_name CityChunkBlueprint
extends RefCounted

var logical_index: int = 0
var generation_seed: int = 0
var lane_phase: float = 72.0
var asphalt_color: Color = Color("353b44")


static func generate(run_seed: int, chunk_index: int) -> CityChunkBlueprint:
	var blueprint: CityChunkBlueprint = CityChunkBlueprint.new()
	blueprint.logical_index = chunk_index
	blueprint.generation_seed = hash("%d:%d" % [run_seed, chunk_index])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = blueprint.generation_seed
	blueprint.lane_phase = rng.randf_range(44.0, 116.0)
	var brightness: float = rng.randf_range(0.94, 1.04)
	blueprint.asphalt_color = Color("353b44") * brightness
	blueprint.asphalt_color.a = 1.0
	return blueprint
