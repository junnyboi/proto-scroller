class_name UrbanSiegeRuntime
extends Node

signal act_changed(index: int, act_id: StringName, display_name: String)
signal beat_changed(act_index: int, beat_index: int, beat_id: StringName)
signal recovery_started(duration: float)
signal milestone_reached(milestone: StringName)
signal district_completed

const DIRECTOR_SCRIPT: Script = preload("res://scripts/siege/district_response_director.gd")
const CATALYST_RUNTIME_SCRIPT: Script = preload(
	"res://scripts/destruction/catalysts/catalyst_runtime.gd"
)
const HAZARD_RUNTIME_SCRIPT: Script = preload("res://scripts/hazards/hazard_runtime.gd")
const BREACH_PROFILE: DirectiveProfile = preload(
	"res://resources/directives/demolition_breach.tres"
)
const AFTERSHOCK_PROFILE: DirectiveProfile = preload(
	"res://resources/directives/aftershock_breaks.tres"
)
const SKYBREAKER_PROFILE: DirectiveProfile = preload(
	"res://resources/directives/skybreaker.tres"
)
const GAS_MAIN_PROFILE: CatalystProfile = preload("res://resources/catalysts/gas_main.tres")
const ROLE_PROFILES: Array[EnemyRoleProfile] = [
	preload("res://resources/roles/advancing_soldier.tres"),
	preload("res://resources/roles/suppressor.tres"),
	preload("res://resources/roles/anchor_tank.tres"),
	preload("res://resources/roles/support_breaker.tres"),
	preload("res://resources/roles/strafe_helicopter.tres"),
	preload("res://resources/roles/catalyst_marker.tres"),
]
const TRAIT_PROFILES: Array[EnemyTraitProfile] = [
	preload("res://resources/traits/command.tres"),
	preload("res://resources/traits/volatile.tres"),
	preload("res://resources/traits/shielded.tres"),
	preload("res://resources/traits/blitz.tres"),
	preload("res://resources/traits/brutal.tres"),
	preload("res://resources/traits/phased.tres"),
]
const DISTRICT_DECK: DistrictDeck = preload("res://resources/siege/district_deck.tres")
const RUN_CONTRACTS: Array[RunContract] = [
	preload("res://resources/contracts/no_heavy_hits.tres"),
	preload("res://resources/contracts/controlled_damage.tres"),
	preload("res://resources/contracts/deep_chain.tres"),
]

var dependencies: UrbanSiegeDependencies
var base_district: DistrictDefinition
var district: DistrictDefinition
var director: DistrictResponseDirector
var catalysts: CatalystRuntime
var hazards: HazardRuntime
var hazard_pressure: HazardPressureController
var directives: DirectiveSession
var pause_coordinator: RunPauseCoordinator
var trait_runtime: EnemyTraitRuntime
var boss_session: CommandBossSession
var run_seed: int = 0
var cycle_count: int = 1
var selected_recipe: DistrictRecipe
var selected_contract: RunContract
var _directive_pause_token: int = 0
var _terminal_pause_token: int = 0


func setup(p_dependencies: UrbanSiegeDependencies, p_district: DistrictDefinition) -> void:
	dependencies = p_dependencies
	base_district = p_district
	district = p_district.duplicate(true) as DistrictDefinition
	director = DIRECTOR_SCRIPT.new() as DistrictResponseDirector
	director.name = "DistrictResponseDirector"
	director.setup_district(dependencies.encounter_runtime, district)
	director.phase_changed.connect(_on_phase_changed)
	director.beat_changed.connect(beat_changed.emit)
	director.recovery_started.connect(recovery_started.emit)
	director.milestone_reached.connect(milestone_reached.emit)
	director.milestone_reached.connect(_on_milestone_reached)
	director.district_completed.connect(_on_arc_completed)
	add_child(director)
	hazards = HAZARD_RUNTIME_SCRIPT.new() as HazardRuntime
	hazards.name = "HazardRuntime"
	hazards.setup(dependencies)
	add_child(hazards)
	hazard_pressure = HazardPressureController.new()
	hazard_pressure.setup(hazards)
	hazard_pressure.configure(0, 1)
	director.configure_hazards(hazards, hazard_pressure)
	catalysts = CATALYST_RUNTIME_SCRIPT.new() as CatalystRuntime
	catalysts.name = "CatalystRuntime"
	catalysts.setup(dependencies)
	add_child(catalysts)
	directives = DirectiveSession.new()
	directives.name = "DirectiveSession"
	directives.setup(
		dependencies,
		[BREACH_PROFILE, AFTERSHOCK_PROFILE, SKYBREAKER_PROFILE]
	)
	add_child(directives)
	dependencies.city.contextual_attacks.set_directive_session(directives)
	dependencies.encounter_runtime.configure_profiles(ROLE_PROFILES, TRAIT_PROFILES)
	trait_runtime = EnemyTraitRuntime.new()
	trait_runtime.name = "EnemyTraitRuntime"
	trait_runtime.setup(dependencies)
	add_child(trait_runtime)
	boss_session = CommandBossSession.new()
	boss_session.name = "CommandBossSession"
	boss_session.setup(dependencies)
	boss_session.completed.connect(_on_boss_completed)
	add_child(boss_session)
	pause_coordinator = RunPauseCoordinator.new()
	pause_coordinator.name = "RunPauseCoordinator"
	pause_coordinator.setup(dependencies, director, catalysts, hazards)
	add_child(pause_coordinator)
	directives.choices_offered.connect(_on_directive_choices_offered)
	directives.selected.connect(_on_directive_selected)
	_select_configuration(false)


func start_run(p_seed: int = 0) -> void:
	run_seed = p_seed
	cycle_count = 1
	_prepare_cycle()


func prepare_terminal_choice() -> void:
	if _terminal_pause_token == 0:
		_terminal_pause_token = pause_coordinator.acquire(&"extract_continue")


func continue_cycle() -> bool:
	if cycle_count >= 2:
		return false
	if _terminal_pause_token != 0:
		pause_coordinator.release(_terminal_pause_token)
		_terminal_pause_token = 0
	cycle_count += 1
	dependencies.telegraphs.cancel_all()
	dependencies.projectile_pool.release_all()
	dependencies.encounter_runtime.release_all()
	hazards.release_all()
	trait_runtime.reset_all()
	boss_session.reset_state()
	_prepare_cycle()
	return true


func release_terminal_choice() -> void:
	if _terminal_pause_token != 0:
		pause_coordinator.release(_terminal_pause_token)
		_terminal_pause_token = 0


func contract_succeeded() -> bool:
	if selected_contract == null:
		return false
	if selected_contract.metric == &"heavy_hits":
		return dependencies.rampage_session.heavy_hit_count <= selected_contract.maximum_value
	if selected_contract.metric == &"causal_depth":
		return (
			dependencies.rampage_session.causal_chain_tracker.best_depth
			>= absi(selected_contract.maximum_value)
		)
	return false


func _process(delta: float) -> void:
	if boss_session != null:
		boss_session.advance(delta)


func stop_run() -> void:
	if director != null:
		director.stop()
	if catalysts != null:
		catalysts.deactivate_all()
	if hazards != null:
		hazards.release_all()
	if directives != null:
		directives.stop()
	if pause_coordinator != null:
		pause_coordinator.release_all()
	if trait_runtime != null:
		trait_runtime.reset_all()
	if boss_session != null:
		boss_session.stop()
	release_terminal_choice()
	_directive_pause_token = 0


func reset_run() -> void:
	stop_run()
	if boss_session != null:
		boss_session.reset_state()
	if director != null:
		director.reset_to_contact()


func is_simulation_paused() -> bool:
	return pause_coordinator != null and pause_coordinator.is_paused()


func _on_phase_changed(index: int, display_name: String) -> void:
	var act_id: StringName = &""
	if district != null and index >= 0 and index < district.acts.size():
		act_id = district.acts[index].act_id
	act_changed.emit(index, act_id, display_name)


func _on_milestone_reached(milestone: StringName) -> void:
	if milestone == &"DIRECTIVE_CHOICE":
		directives.offer(run_seed)
	elif milestone == &"GAS_MAIN":
		var gas_main: Catalyst2D = catalysts.activate(
			1,
			GAS_MAIN_PROFILE,
			selected_recipe.gas_main_position
		)
		dependencies.encounter_runtime.set_catalyst_target(gas_main)


func _on_directive_choices_offered(_profiles: Array[DirectiveProfile]) -> void:
	if _directive_pause_token == 0:
		_directive_pause_token = pause_coordinator.acquire(&"directive_choice")


func _on_directive_selected(_profile: DirectiveProfile) -> void:
	if _directive_pause_token != 0:
		pause_coordinator.release(_directive_pause_token)
		_directive_pause_token = 0


func _on_arc_completed() -> void:
	boss_session.start()


func _on_boss_completed(_elapsed_seconds: float) -> void:
	district_completed.emit()


func _prepare_cycle() -> void:
	_select_configuration(true)
	director.configure_elite_affixes(run_seed, cycle_count)
	hazard_pressure.configure(run_seed, cycle_count)
	hazards.release_all()
	catalysts.deactivate_all()
	var transformer: Catalyst2D = catalysts.activate(
		0,
		preload("res://resources/catalysts/transformer.tres"),
		selected_recipe.transformer_position
	)
	dependencies.encounter_runtime.set_catalyst_target(transformer)
	director.start()


func _select_configuration(apply_to_director: bool) -> void:
	var selection: Dictionary = DistrictDeckSelector.select(
		base_district,
		DISTRICT_DECK,
		RUN_CONTRACTS,
		run_seed,
		cycle_count
	)
	selected_recipe = selection.recipe as DistrictRecipe
	selected_contract = selection.contract as RunContract
	if apply_to_director:
		district = selection.district as DistrictDefinition
		director.district = district
