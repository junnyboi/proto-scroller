extends GutTest

const CITY_SCENE: PackedScene = preload("res://scenes/gameplay/city_slice.tscn")
const BREACH: DirectiveProfile = preload(
	"res://resources/directives/demolition_breach.tres"
)
const AFTERSHOCK: DirectiveProfile = preload(
	"res://resources/directives/aftershock_breaks.tres"
)
const SKYBREAKER: DirectiveProfile = preload("res://resources/directives/skybreaker.tres")

var city: CitySlice
var session: DirectiveSession


func before_each() -> void:
	city = CITY_SCENE.instantiate() as CitySlice
	city.mobile_detection_override = 1
	add_child_autofree(city)
	await get_tree().process_frame
	session = city.urban_siege.directives


func test_breach_decorates_jab_cross_only_and_caps_multiplier() -> void:
	assert_true(session.select(BREACH))
	var jab_cross: AttackSpec = city.contextual_attacks.resolver.resolve(
		100,
		1,
		0.8,
		100.0,
		1000.0,
		96.0
	)
	var modified_jab_cross: AttackSpec = session.decorate_attack(jab_cross)
	assert_almost_eq(modified_jab_cross.structural_damage, 187.5, 0.01)
	assert_eq(modified_jab_cross.effect_flags, DamageEvent.FLAG_DIRECTIVE_BREACH)
	var smash: AttackSpec = city.contextual_attacks.resolver.resolve(
		101,
		1,
		0.2,
		100.0,
		1000.0,
		96.0
	)
	assert_almost_eq(session.decorate_attack(smash).structural_damage, 200.0, 0.01)


func test_aftershock_deduplicates_one_secondary_query_per_attack() -> void:
	assert_true(session.select(AFTERSHOCK))
	var smash: AttackSpec = session.decorate_attack(
		city.contextual_attacks.resolver.resolve(222, 1, 0.0, 100.0, 1000.0, 96.0)
	)
	session.attack_active(smash)
	session.attack_active(smash)
	assert_eq(session._seen_aftershocks.size(), 1)
	await get_tree().create_timer(0.18).timeout
	assert_eq(session._seen_aftershocks.size(), 1)


func test_skybreaker_redirects_at_most_three_pooled_bodies() -> void:
	assert_true(session.select(SKYBREAKER))
	for index: int in range(5):
		city.debris_pool.acquire(
			Transform2D(0.0, city.robot.global_position + Vector2(float(index) * 12.0, 0.0)),
			Vector2.ZERO
		)
	var smash: AttackSpec = session.decorate_attack(
		city.contextual_attacks.resolver.resolve(333, 1, 0.0, 100.0, 1000.0, 96.0)
	)
	session.attack_active(smash)
	var redirected: int = 0
	for body: DebrisBody2D in city.debris_pool.active_bodies():
		if body.linear_velocity.y <= -900.0:
			redirected += 1
	assert_eq(redirected, DirectiveSession.SKYBREAKER_BODY_CAP)


func test_failure_deducts_twenty_percent_of_secured_run_score() -> void:
	var penalties: Array[int] = []
	session.failed.connect(
		func(_profile: DirectiveProfile, penalty: int) -> void:
			penalties.append(penalty)
	)
	assert_true(session.select(BREACH))
	assert_true(city.rampage_session.publish(GameplayEvent.new(
		&"directive_score",
		401,
		GameplayEvent.Kind.PROP_DESTROYED,
		GameplayEvent.PROP_BREAK,
		100,
		6.0,
		true
	)))
	assert_eq(session.pending_score, 25)
	session._process(BREACH.duration_seconds)
	assert_eq(city.score, 80)
	assert_eq(penalties, [20])
	assert_eq(session.failure_count, 1)
	assert_false(session.is_active())
	assert_eq(city.gameplay_hud.directive_card.bank_label.text, "SCORE -20")


func test_failure_penalty_is_nonzero_when_directive_bank_is_empty() -> void:
	assert_true(city.rampage_session.publish(GameplayEvent.new(
		&"secured_score_before_directive",
		402,
		GameplayEvent.Kind.PROP_DESTROYED,
		GameplayEvent.PROP_BREAK,
		500,
		6.0,
		true
	)))
	assert_eq(city.score, 500)
	assert_true(session.select(BREACH))
	assert_eq(session.pending_score, 0)
	session._process(BREACH.duration_seconds)
	assert_eq(city.score, 400)
	assert_eq(city.gameplay_hud.directive_card.bank_label.text, "SCORE -100")


func test_breach_completes_after_three_accepted_cells() -> void:
	assert_true(session.select(BREACH))
	for index: int in range(3):
		session._on_event_published(GameplayEvent.new(
			StringName("directive_cell_%d" % index),
			500 + index,
			GameplayEvent.Kind.CELL_DESTROYED,
			GameplayEvent.CELL_BREACH,
			300,
			12.0,
			true
		))
	assert_eq(session.completion_count, 1)
	assert_false(session.is_active())


func test_directive_card_is_noninteractive_and_above_mobile_smash() -> void:
	city.gameplay_hud.show_directive(BREACH, 0, BREACH.target_count, 0)
	var card: DirectiveCard = city.gameplay_hud.directive_card
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_false(card.get_global_rect().intersects(city.mobile_controls.smash_bounds()))
	assert_not_null(card.icon.texture)
	assert_eq(card.size, Vector2(392.0, 104.0))
	assert_lte(card.title_label.position.x + card.title_label.size.x, card.size.x)
	assert_lte(card.detail_label.position.x + card.detail_label.size.x, card.size.x)
	assert_lte(card.bank_label.position.x + card.bank_label.size.x, card.size.x)


func test_directive_result_card_dismisses_after_bounded_hold() -> void:
	city.gameplay_hud.show_directive_result("DEMOLITION BREACH FAILED", false, 100)
	var card: DirectiveCard = city.gameplay_hud.directive_card
	assert_true(card.visible)
	assert_eq(card.bank_label.text, "SCORE -100")
	card._process(DirectiveCard.RESULT_DISPLAY_SECONDS + 0.01)
	assert_false(card.visible)


func test_choice_overlay_pauses_runtime_and_selects_exactly_once() -> void:
	var momentum_before: float = city.rampage_session.momentum_value()
	var projectile_process_before: int = city.projectile_root.process_mode
	session.offer(8)
	assert_true(city.urban_siege.is_simulation_paused())
	assert_true(city.gameplay_hud.directive_choice_overlay.visible)
	assert_eq(city.urban_siege.pause_coordinator.lease_count(), 1)
	assert_eq(city.projectile_root.process_mode, Node.PROCESS_MODE_DISABLED)
	city._process(1.0)
	assert_almost_eq(city.rampage_session.momentum_value(), momentum_before, 0.001)
	city.gameplay_hud.directive_choice_overlay.buttons[0].pressed.emit()
	assert_false(city.urban_siege.is_simulation_paused())
	assert_false(city.gameplay_hud.directive_choice_overlay.visible)
	assert_not_null(session.active_profile)
	assert_eq(city.projectile_root.process_mode, projectile_process_before)
	assert_false(session.select(AFTERSHOCK))
