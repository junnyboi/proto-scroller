class_name BossSiegeInterlock
extends RefCounted

const RECOVERY_SECONDS: float = 1.0
const CANCELLED_EFFECT_FLAGS: int = (
	DamageEvent.FLAG_CATALYST
	| DamageEvent.FLAG_DIRECTIVE_AFTERSHOCK
	| DamageEvent.FLAG_DIRECTIVE_SKYBREAKER
	| DamageEvent.FLAG_VOLATILE
	| DamageEvent.FLAG_HAZARD
)

var siege: UrbanSiegeRuntime
var owned: bool = false
var captured_state: Dictionary = {}


func setup(p_siege: UrbanSiegeRuntime) -> void:
	siege = p_siege


func acquire() -> bool:
	if owned or siege == null or siege.director == null:
		return false
	captured_state = {
		"run_seed": siege.run_seed,
		"cycle_count": siege.cycle_count,
		"director": siege.director.suspend_for_boss(),
	}
	owned = true
	siege.set_boss_gate_owned(true)
	clear_competing_combat()
	return true


func clear_competing_combat() -> void:
	if not owned or siege == null:
		return
	var dependencies: UrbanSiegeDependencies = siege.dependencies
	for enemy: EnemyActor2D in dependencies.encounter_runtime.all_actors():
		if enemy != siege.boss_session.boss:
			dependencies.encounter_runtime.release(enemy)
	dependencies.telegraphs.cancel_all()
	dependencies.projectile_pool.release_hostile(dependencies.robot)
	if dependencies.destruction_director != null:
		dependencies.destruction_director.cancel_effect_flags(CANCELLED_EFFECT_FLAGS)
	siege.hazards.release_all()
	siege.catalysts.deactivate_all()
	siege.trait_runtime.reset_all()
	siege.withdraw_directive_for_boss()


func resume_after_success() -> bool:
	if not owned or siege == null:
		return false
	siege.run_seed = int(captured_state.get("run_seed", siege.run_seed))
	siege.cycle_count = int(captured_state.get("cycle_count", siege.cycle_count))
	owned = false
	var resumed: bool = siege.director.resume_after_boss(RECOVERY_SECONDS)
	siege.set_boss_gate_owned(false)
	captured_state.clear()
	return resumed


func discard() -> void:
	if siege != null:
		siege.director.discard_boss_suspension()
		siege.set_boss_gate_owned(false)
	owned = false
	captured_state.clear()


func capture_state() -> Dictionary:
	return captured_state.duplicate(true)


func is_owned() -> bool:
	return owned
