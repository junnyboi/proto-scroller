class_name PlayerUpgradeAssembler
extends Node

const CATALOG: UpgradeCatalog = preload(
	"res://resources/upgrades/upgrade_catalog.tres"
)

var session: UpgradeSession
var runtimes: Dictionary[StringName, UpgradeRuntime] = {}


func setup(city: Node) -> PackedStringArray:
	name = "PlayerUpgradeAssembler"
	for profile: UpgradeProfile in CATALOG.profiles:
		var runtime: UpgradeRuntime = UpgradeRuntime.new()
		runtime.name = "%sRuntime" % String(profile.runtime_key).to_pascal_case()
		runtime.setup(profile.runtime_key, profile.max_rank)
		add_child(runtime)
		runtimes[profile.runtime_key] = runtime
	session = UpgradeSession.new()
	session.name = "UpgradeSession"
	add_child(session)
	var siege: UrbanSiegeRuntime = city.get("urban_siege") as UrbanSiegeRuntime
	var rampage: RampageSession = city.get("rampage_session") as RampageSession
	var hud: GameplayHud = city.get("gameplay_hud") as GameplayHud
	var errors: PackedStringArray = session.setup(
		siege.run_seed,
		CATALOG,
		siege.pause_coordinator,
		runtimes,
		city.get_instance_id()
	)
	session.offer_opened.connect(_on_offer_opened.bind(hud))
	session.offer_resolved.connect(_on_offer_resolved.bind(hud))
	session.queue_drained.connect(hud.upgrade_choice_overlay.hide_offer)
	session.rank_changed.connect(hud.weapon_status_strip.set_rank)
	hud.upgrade_choice_overlay.choice_selected.connect(session.select_choice)
	session.set_presentation_blocked(false)
	rampage.run_experience.level_gained.connect(session.queue_level)
	return errors


func _on_offer_opened(offer: UpgradeOffer, hud: GameplayHud) -> void:
	hud.upgrade_choice_overlay.show_offer(
		offer,
		CATALOG,
		session.ranks,
		offer.sequence + session.pending.size()
	)


func _on_offer_resolved(
	_offer: UpgradeOffer,
	_selected_id: StringName,
	_new_rank: int,
	hud: GameplayHud
) -> void:
	hud.upgrade_choice_overlay.hide_offer()
