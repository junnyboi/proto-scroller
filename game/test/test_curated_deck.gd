extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const BASE_DISTRICT: DistrictDefinition = preload(
	"res://resources/siege/district_contact.tres"
)
const DECK: DistrictDeck = preload("res://resources/siege/district_deck.tres")
const CONTRACTS: Array[RunContract] = [
	preload("res://resources/contracts/no_heavy_hits.tres"),
	preload("res://resources/contracts/controlled_damage.tres"),
	preload("res://resources/contracts/deep_chain.tres"),
]


func test_same_seed_produces_identical_recipe_contract_and_beat_order() -> void:
	var first: Dictionary = DistrictDeckSelector.select(BASE_DISTRICT, DECK, CONTRACTS, 42, 1)
	var second: Dictionary = DistrictDeckSelector.select(BASE_DISTRICT, DECK, CONTRACTS, 42, 1)
	assert_eq(first.recipe.recipe_id, second.recipe.recipe_id)
	assert_eq(first.contract.contract_id, second.contract.contract_id)
	assert_eq(_beat_ids(first.district), _beat_ids(second.district))


func test_different_seed_changes_multiple_run_decisions() -> void:
	var first: Dictionary = DistrictDeckSelector.select(BASE_DISTRICT, DECK, CONTRACTS, 0, 1)
	var second: Dictionary = DistrictDeckSelector.select(BASE_DISTRICT, DECK, CONTRACTS, 1, 1)
	assert_ne(first.recipe.recipe_id, second.recipe.recipe_id)
	assert_ne(first.contract.contract_id, second.contract.contract_id)


func test_every_curated_recipe_passes_static_budget_validation() -> void:
	for recipe_index: int in range(DECK.recipes.size()):
		var selection: Dictionary = DistrictDeckSelector.select(
			BASE_DISTRICT, DECK, CONTRACTS, recipe_index, 1
		)
		assert_eq(DistrictRecipeValidator.validate(selection.district).size(), 0)


func test_continue_preserves_city_health_score_and_directive_without_node_growth() -> void:
	var city: CitySlice = await _spawn_city()
	city.urban_siege.run_seed = 17
	city.urban_siege.directives.select(
		preload("res://resources/directives/demolition_breach.tres")
	)
	city.rampage_session.publish(GameplayEvent.new(
		&"continuation_score", 9001, GameplayEvent.Kind.PROP_DESTROYED,
		GameplayEvent.PROP_BREAK, 400, 5.0, true
	))
	city.robot.current_health = 640.0
	city.building.get_cell(0, 1).current_health = 12.0
	var node_count: int = RuntimeBudget.snapshot(city).node_count
	var score: int = city.score
	var directive: DirectiveProfile = city.urban_siege.directives.selected_profile
	city.run_lifecycle._on_district_completed()
	assert_true(city.weapon_shop_assembler.session.active)
	city.weapon_shop_assembler.session.close_shop()
	assert_true(city.gameplay_hud.continue_button.visible)
	city.run_lifecycle._on_continue_pressed()
	assert_eq(city.urban_siege.cycle_count, 2)
	assert_eq(city.score, score)
	assert_almost_eq(city.robot.current_health, 640.0, 0.001)
	assert_almost_eq(city.building.get_cell(0, 1).current_health, 12.0, 0.001)
	assert_eq(city.urban_siege.directives.selected_profile, directive)
	assert_eq(RuntimeBudget.snapshot(city).node_count, node_count)
	assert_false(city.gameplay_hud.game_over_overlay.visible)


func test_second_cycle_offers_extract_only_and_freezes_cycle_count() -> void:
	var city: CitySlice = await _spawn_city()
	city.urban_siege.cycle_count = 2
	city.run_lifecycle._on_district_completed()
	assert_true(city.weapon_shop_assembler.session.active)
	city.weapon_shop_assembler.session.close_shop()
	assert_true(city.gameplay_hud.extract_button.visible)
	assert_false(city.gameplay_hud.continue_button.visible)
	city.run_lifecycle._on_extract_pressed()
	assert_true(city.game_over_active)
	assert_eq(city.rampage_session.frozen_summary.cycle_count, 2)


func _spawn_city() -> CitySlice:
	var city: CitySlice = CITY_SCENE.instantiate() as CitySlice
	add_child_autofree(city)
	await get_tree().process_frame
	return city


func _beat_ids(district: DistrictDefinition) -> PackedStringArray:
	var ids: PackedStringArray = []
	for act: DistrictAct in district.acts:
		for beat: DistrictBeat in act.beats:
			ids.append(beat.beat_id)
	return ids
