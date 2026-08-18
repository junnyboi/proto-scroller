class_name DistrictRecipeValidator
extends RefCounted


static func validate(district: DistrictDefinition) -> PackedStringArray:
	var errors: PackedStringArray = []
	for act: DistrictAct in district.acts:
		for beat: DistrictBeat in act.beats:
			var counts: Dictionary[StringName, int] = {
				&"soldier": 0, &"tank": 0, &"helicopter": 0,
			}
			var elites: int = 0
			for entry: EnemySpawnEntry in beat.spawns:
				var kind: StringName = StringName(entry.kind)
				counts[kind] += 1
				elites += 1 if not entry.trait_id.is_empty() else 0
			if counts[&"soldier"] > RuntimeBudget.SOLDIERS:
				errors.append("%s soldiers exceed cap" % beat.beat_id)
			if counts[&"tank"] > RuntimeBudget.TANKS:
				errors.append("%s tanks exceed cap" % beat.beat_id)
			if counts[&"helicopter"] > RuntimeBudget.HELICOPTERS:
				errors.append("%s helicopters exceed cap" % beat.beat_id)
			if counts.values().reduce(func(a: int, b: int) -> int: return a + b, 0) > 9:
				errors.append("%s actors exceed cap" % beat.beat_id)
			if elites > 1:
				errors.append("%s has multiple elites" % beat.beat_id)
	return errors
