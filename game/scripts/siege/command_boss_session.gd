class_name CommandBossSession
extends Node

signal state_changed(state: StringName)
signal armor_changed(current: float, maximum: float)
signal completed(elapsed_seconds: float)

const STATE_IDLE: StringName = &"IDLE"
const STATE_SCREEN: StringName = &"SCREEN"
const STATE_BARRAGE: StringName = &"BARRAGE"
const STATE_EXPOSED: StringName = &"EXPOSED"
const STATE_WRECK: StringName = &"WRECK_FINISHER"
const STATE_COMPLETE: StringName = &"COMPLETE"
const ARMOR: float = 330.0
const HEALTH: float = 320.0
const SCREEN_DURATION: float = 4.0
const TARGET_DURATION: float = 60.0

var dependencies: UrbanSiegeDependencies
var state: StringName = STATE_IDLE
var boss: TankEnemy
var boss_wreck: EnemyWreck2D
var elapsed_seconds: float = 0.0
var _state_elapsed: float = 0.0


func setup(p_dependencies: UrbanSiegeDependencies) -> void:
	dependencies = p_dependencies
	dependencies.encounter_runtime.enemy_died.connect(_on_enemy_died)
	dependencies.remains_factory.wreck_spawned.connect(_on_wreck_spawned)
	dependencies.remains_factory.wreck_scrapped.connect(_on_wreck_scrapped)


func start() -> bool:
	if state != STATE_IDLE and state != STATE_COMPLETE:
		return false
	dependencies.encounter_runtime.release_all()
	boss = dependencies.encounter_runtime.acquire(
		&"tank",
		dependencies.encounter_runtime.resolve_spawn_position(
			Vector2(0.0, 551.0),
			&"AHEAD"
		),
		&"ANCHOR_TANK",
		&"COMMAND"
	) as TankEnemy
	if boss == null:
		return false
	boss.configure_boss(ARMOR, HEALTH)
	boss.boss_armor_changed.connect(_on_boss_armor_changed)
	boss.boss_armor_broken.connect(_on_boss_armor_broken)
	elapsed_seconds = 0.0
	_state_elapsed = 0.0
	_set_state(STATE_SCREEN)
	dependencies.encounter_runtime.set_attack_gate(false)
	armor_changed.emit(ARMOR, ARMOR)
	return true


func advance(delta: float) -> void:
	if state == STATE_IDLE or state == STATE_COMPLETE:
		return
	elapsed_seconds += delta
	_state_elapsed += delta
	if state == STATE_SCREEN and _state_elapsed >= SCREEN_DURATION:
		dependencies.encounter_runtime.set_attack_gate(true)
		_set_state(STATE_BARRAGE)


func stop() -> void:
	if boss != null and boss.active:
		dependencies.encounter_runtime.release(boss)
	if boss_wreck != null:
		boss_wreck.finisher_requires_ground_smash = false
	boss = null
	boss_wreck = null
	if state != STATE_COMPLETE:
		_set_state(STATE_IDLE)


func reset_state() -> void:
	stop()
	_set_state(STATE_IDLE)


func active() -> bool:
	return state != STATE_IDLE and state != STATE_COMPLETE


func _on_boss_armor_changed(current: float, maximum: float) -> void:
	armor_changed.emit(current, maximum)


func _on_boss_armor_broken() -> void:
	_set_state(STATE_EXPOSED)


func _on_enemy_died(enemy: EnemyActor2D, _event: DamageEvent, _points: int) -> void:
	if enemy == boss:
		dependencies.encounter_runtime.set_attack_gate(false)


func _on_wreck_spawned(enemy: EnemyActor2D, wreck: EnemyWreck2D) -> void:
	if enemy != boss:
		return
	boss_wreck = wreck
	boss_wreck.finisher_requires_ground_smash = true
	_set_state(STATE_WRECK)


func _on_wreck_scrapped(wreck: EnemyWreck2D, _event: DamageEvent, _points: int) -> void:
	if wreck != boss_wreck:
		return
	boss_wreck = null
	_set_state(STATE_COMPLETE)
	completed.emit(elapsed_seconds)


func _set_state(next_state: StringName) -> void:
	state = next_state
	_state_elapsed = 0.0
	state_changed.emit(state)
