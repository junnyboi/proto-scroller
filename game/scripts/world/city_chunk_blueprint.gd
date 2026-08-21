class_name CityChunkBlueprint
extends RefCounted

var logical_index: int = 0
var generation_seed: int = 0
var lane_phase: float = 72.0
var asphalt_color: Color = Color("353b44")
var building_x: float = 1450.0
var car_x: float = 930.0
var car_y: float = 559.0
var lamp_x: float = 1220.0
var lamp_y: float = 480.0


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
	if chunk_index != 0:
		blueprint.building_x = rng.randf_range(620.0, 724.0)
		blueprint.car_x = rng.randf_range(1010.0, 1110.0)
		blueprint.lamp_x = rng.randf_range(210.0, 300.0)
	if chunk_index == 1:
		blueprint.lamp_x = 1200.0
	return blueprint
