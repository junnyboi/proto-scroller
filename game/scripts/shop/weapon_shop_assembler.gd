class_name WeaponShopAssembler
extends Node

var session: WeaponShopSession
var effects: WeaponShopUpgradeRuntime
var overlay: WeaponShopOverlay
var banner: DistrictTransitionBanner
var music_duck: MusicDuckController
var upgrade_session: UpgradeSession


func setup(city: Node) -> PackedStringArray:
	name = "WeaponShopAssembler"
	var robot: GiantRobotController = city.get("robot") as GiantRobotController
	var siege: UrbanSiegeRuntime = city.get("urban_siege") as UrbanSiegeRuntime
	var rampage: RampageSession = city.get("rampage_session") as RampageSession
	var upgrades: PlayerUpgradeAssembler = (
		city.get("upgrade_assembler") as PlayerUpgradeAssembler
	)
	banner = city.get("district_transition_banner") as DistrictTransitionBanner
	music_duck = city.get("music_duck_controller") as MusicDuckController
	upgrade_session = upgrades.session
	effects = WeaponShopUpgradeRuntime.new()
	effects.name = "WeaponShopUpgradeRuntime"
	effects.setup(robot)
	add_child(effects)
	upgrades.shop_effects = effects
	upgrades.arsenal.shop_effects = effects
	city.get("contextual_attacks").call(&"set_shop_upgrade_runtime", effects)
	overlay = WeaponShopOverlay.new()
	var hud: GameplayHud = city.get("gameplay_hud") as GameplayHud
	hud.add_child(overlay)
	session = WeaponShopSession.new()
	session.name = "WeaponShopSession"
	add_child(session)
	var errors: PackedStringArray = session.setup(
		siege.pause_coordinator,
		rampage.run_score,
		effects,
		robot,
		city.get("telegraph_presenter") as TelegraphPresenter2D
	)
	session.shop_opened.connect(_on_shop_opened)
	session.purchase_completed.connect(_on_purchase_completed)
	session.purchase_rejected.connect(_on_purchase_rejected)
	session.shop_closed.connect(_on_shop_closed)
	overlay.purchase_requested.connect(session.purchase)
	overlay.continue_requested.connect(session.close_shop)
	siege.pause_coordinator.pause_changed.connect(_on_pause_changed)
	return errors


func queue_transition(
	previous_district_id: StringName,
	district: CityDistrictProfile,
	logical_chunk: int
) -> bool:
	return (
		session != null
		and session.queue_transition(previous_district_id, district, logical_chunk)
	)


func _on_shop_opened(
	district: CityDistrictProfile,
	products: Array[WeaponShopProduct],
	score: int
) -> void:
	upgrade_session.set_presentation_blocked(true)
	music_duck.set_ducked(true)
	var statuses: Dictionary[StringName, StringName] = {}
	for product: WeaponShopProduct in products:
		statuses[product.product_id] = session.product_status(product)
	overlay.show_shop(district, products, score, statuses)


func _on_purchase_completed(product: WeaponShopProduct, remaining_score: int) -> void:
	overlay.set_score(remaining_score)
	overlay.update_status(product.product_id, &"sold")
	overlay.show_feedback("shop.purchase_complete")
	_refresh_statuses()


func _on_purchase_rejected(product: WeaponShopProduct, reason: StringName) -> void:
	overlay.update_status(product.product_id, reason)
	overlay.show_feedback("shop.rejected.%s" % String(reason))


func _on_shop_closed(district: CityDistrictProfile, logical_chunk: int) -> void:
	overlay.hide_shop()
	music_duck.set_ducked(false)
	upgrade_session.set_presentation_blocked(false)
	banner.present(district, logical_chunk)


func _on_pause_changed(paused: bool) -> void:
	effects.set_process(not paused)


func _refresh_statuses() -> void:
	for card: WeaponShopCard in overlay.cards:
		if card.product != null:
			overlay.update_status(
				card.product.product_id,
				session.product_status(card.product)
			)
