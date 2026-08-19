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
	var errors: PackedStringArray = session.setup(
		siege.run_seed,
		CATALOG,
		siege.pause_coordinator,
		runtimes,
		city.get_instance_id()
	)
	session.set_presentation_blocked(true)
	rampage.run_experience.level_gained.connect(session.queue_level)
	return errors
