class_name HybridEncounterResolver
extends RefCounted

const BUSINESS: StringName = &"BUSINESS"
const RESIDENTIAL: StringName = &"RESIDENTIAL"
const ENTERTAINMENT: StringName = &"ENTERTAINMENT"
const MILITARY: StringName = &"MILITARY"
const ROYAL: StringName = &"ROYAL"


static func resolve_beat(
	base_beat: DistrictBeat,
	district_id: StringName,
	act_index: int,
	beat_index: int,
	run_seed: int
) -> DistrictBeat:
	if base_beat == null or district_id == BUSINESS:
		return base_beat
	var resolved: DistrictBeat = base_beat.duplicate(true) as DistrictBeat
	var rotation: int = posmod(run_seed + act_index * 7 + beat_index * 3, 6)
	var preferred: Array[StringName] = _preferred_hybrids(district_id, rotation)
	var used_families: Dictionary[StringName, bool] = {}
	var resolved_threat: int = _resolved_threat(resolved)
	for hybrid_id: StringName in preferred:
		var required_family: StringName = EnemyArchetypeCatalog.family_for(hybrid_id)
		if used_families.has(required_family):
			continue
		for entry: EnemySpawnEntry in resolved.spawns:
			if EnemyArchetypeCatalog.family_for(StringName(entry.kind)) != required_family:
				continue
			var original_kind: StringName = StringName(entry.kind)
			var projected_threat: int = (
				resolved_threat
				- _entry_threat(original_kind)
				+ _entry_threat(hybrid_id)
			)
			if projected_threat > base_beat.maximum_threat:
				continue
			entry.kind = String(hybrid_id)
			resolved_threat = projected_threat
			used_families[required_family] = true
			break
	return resolved


static func substitutions(
	base_beat: DistrictBeat,
	resolved_beat: DistrictBeat
) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	if base_beat == null or resolved_beat == null:
		return changes
	for index: int in range(mini(base_beat.spawns.size(), resolved_beat.spawns.size())):
		var before: StringName = StringName(base_beat.spawns[index].kind)
		var after: StringName = StringName(resolved_beat.spawns[index].kind)
		if before != after:
			changes.append({"entry_index": index, "before": before, "after": after})
	return changes


static func eligible_hybrids(district_id: StringName) -> Array[StringName]:
	match district_id:
		RESIDENTIAL:
			return [&"reclaimed_breacher", &"graft_runner"]
		ENTERTAINMENT:
			return [&"choir_siren", &"ossuary_crawler", &"graft_runner"]
		MILITARY:
			return [&"seraph_carrier", &"pale_engine", &"graft_runner"]
		ROYAL:
			return [
				&"reclaimed_breacher", &"graft_runner", &"choir_siren",
				&"ossuary_crawler", &"seraph_carrier", &"pale_engine",
			]
	return []


static func _preferred_hybrids(district_id: StringName, rotation: int) -> Array[StringName]:
	var eligible: Array[StringName] = eligible_hybrids(district_id)
	if eligible.is_empty():
		return eligible
	var rotated: Array[StringName] = []
	for offset: int in range(eligible.size()):
		rotated.append(eligible[wrapi(rotation + offset, 0, eligible.size())])
	return rotated


static func _resolved_threat(beat: DistrictBeat) -> int:
	var threat: int = 0
	for entry: EnemySpawnEntry in beat.spawns:
		threat += _entry_threat(StringName(entry.kind))
	return threat


static func _entry_threat(kind: StringName) -> int:
	return (
		EnemyArchetypeCatalog.threat_cost(kind)
		* EnemyArchetypeCatalog.spawn_multiplier(kind)
	)
