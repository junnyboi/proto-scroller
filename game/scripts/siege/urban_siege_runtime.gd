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
]

var dependencies: UrbanSiegeDependencies
var district: DistrictDefinition
var director: DistrictResponseDirector
var catalysts: CatalystRuntime
var directives: DirectiveSession
var pause_coordinator: RunPauseCoordinator
var trait_runtime: EnemyTraitRuntime
var run_seed: int = 0
var _directive_pause_token: int = 0


func setup(p_dependencies: UrbanSiegeDependencies, p_district: DistrictDefinition) -> void:
	dependencies = p_dependencies
	district = p_district
	director = DIRECTOR_SCRIPT.new() as DistrictResponseDirector
	director.name = "DistrictResponseDirector"
	director.setup_district(dependencies.encounter_runtime, district)
	director.phase_changed.connect(_on_phase_changed)
	director.beat_changed.connect(beat_changed.emit)
	director.recovery_started.connect(recovery_started.emit)
	director.milestone_reached.connect(milestone_reached.emit)
	director.milestone_reached.connect(_on_milestone_reached)
	director.district_completed.connect(district_completed.emit)
	add_child(director)
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
	pause_coordinator = RunPauseCoordinator.new()
	pause_coordinator.name = "RunPauseCoordinator"
	pause_coordinator.setup(dependencies, director, catalysts)
	add_child(pause_coordinator)
	directives.choices_offered.connect(_on_directive_choices_offered)
	directives.selected.connect(_on_directive_selected)


func start_run(p_seed: int = 0) -> void:
	run_seed = p_seed
	director.start()


func stop_run() -> void:
	if director != null:
		director.stop()
	if catalysts != null:
		catalysts.deactivate_all()
	if directives != null:
		directives.stop()
	if pause_coordinator != null:
		pause_coordinator.release_all()
	if trait_runtime != null:
		trait_runtime.reset_all()
	_directive_pause_token = 0


func reset_run() -> void:
	stop_run()
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
			Vector2(1340.0, 610.0)
		)
		dependencies.encounter_runtime.set_catalyst_target(gas_main)


func _on_directive_choices_offered(_profiles: Array[DirectiveProfile]) -> void:
	if _directive_pause_token == 0:
		_directive_pause_token = pause_coordinator.acquire(&"directive_choice")


func _on_directive_selected(_profile: DirectiveProfile) -> void:
	if _directive_pause_token != 0:
		pause_coordinator.release(_directive_pause_token)
		_directive_pause_token = 0
