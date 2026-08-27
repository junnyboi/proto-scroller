class_name PlayerCombatProfileStore
extends Node

const SCHEMA_VERSION: int = 1
const SAVE_PATH: String = "user://player_combat_profile.json"
const MAX_STAT_KEYS: int = 128
const MAX_COUNTER: int = 2_147_483_647

var save_path: String = SAVE_PATH
var _profile: Dictionary = {}


func setup(path: String = SAVE_PATH) -> void:
	save_path = path
	_profile = _load_profile()


func snapshot() -> Dictionary:
	return _profile.duplicate(true)


func enrich_and_submit(summary: RunSummarySnapshot) -> RunSummarySnapshot:
	if summary == null:
		return summary
	var previous_best_score: int = int(_profile.get("best_score", 0))
	var previous_combo_tier: int = int(_profile.get("highest_combo_tier", 0))
	_profile["total_runs"] = _bounded_sum(int(_profile.get("total_runs", 0)), 1)
	if summary.completed:
		_profile["victories"] = _bounded_sum(int(_profile.get("victories", 0)), 1)
	_profile["best_score"] = maxi(previous_best_score, summary.score)
	_profile["highest_combo_tier"] = maxi(previous_combo_tier, summary.highest_combo_tier)
	_profile["total_enemy_kills"] = _bounded_sum(
		int(_profile.get("total_enemy_kills", 0)),
		summary.total_enemies_defeated
	)
	_profile["lifetime_enemy_kills"] = _merge_counts(
		_profile.get("lifetime_enemy_kills", {}) as Dictionary,
		summary.enemy_kills
	)
	_profile["lifetime_weapon_kills"] = _merge_counts(
		_profile.get("lifetime_weapon_kills", {}) as Dictionary,
		summary.weapon_kills
	)
	_profile["updated_unix_time"] = int(Time.get_unix_time_from_system())
	_save_profile()
	return summary.with_career_result({
		"new_combo_record": (
			summary.highest_combo_tier > 0
			and summary.highest_combo_tier > previous_combo_tier
		),
		"new_score_record": summary.score > previous_best_score,
		"career_snapshot": snapshot(),
	})


func leaderboard_candidate(
	summary: RunSummarySnapshot,
	build_revision: String = "development"
) -> Dictionary:
	if summary == null:
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"build_revision": build_revision,
		"anonymous_profile_id": String(_profile.get("anonymous_profile_id", "")),
		"run": {
			"score": summary.score,
			"grade": String(summary.grade),
			"completed": summary.completed,
			"acts_completed": summary.waves_cleared,
			"cycle_count": summary.cycle_count,
			"ending_id": String(summary.ending_id),
			"peak_multiplier": summary.peak_combo,
			"highest_combo_tier": summary.highest_combo_tier,
			"best_physical_chain": summary.best_chain,
			"total_enemy_kills": summary.total_enemies_defeated,
			"unique_enemy_types": summary.unique_enemy_types,
			"preferred_weapon": String(summary.preferred_weapon),
			"enemy_kills": _string_keyed_counts(summary.enemy_kills),
			"weapon_kills": _string_keyed_counts(summary.weapon_kills),
		},
		"career": {
			"total_runs": int(_profile.get("total_runs", 0)),
			"victories": int(_profile.get("victories", 0)),
			"best_score": int(_profile.get("best_score", 0)),
			"highest_combo_tier": int(_profile.get("highest_combo_tier", 0)),
			"total_enemy_kills": int(_profile.get("total_enemy_kills", 0)),
		},
	}


func _load_profile() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return _default_profile()
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return _default_profile()
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _default_profile()
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return _default_profile()
	return _sanitize_profile(parsed as Dictionary)


func _save_profile() -> bool:
	var temporary_path: String = save_path + ".tmp"
	var backup_path: String = save_path + ".bak"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_profile, "", true, true))
	file.close()
	var save_global: String = ProjectSettings.globalize_path(save_path)
	var temporary_global: String = ProjectSettings.globalize_path(temporary_path)
	var backup_global: String = ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_global)
	if FileAccess.file_exists(save_path):
		if DirAccess.rename_absolute(save_global, backup_global) != OK:
			DirAccess.remove_absolute(temporary_global)
			return false
	if DirAccess.rename_absolute(temporary_global, save_global) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_global, save_global)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_global)
	return true


func _sanitize_profile(raw: Dictionary) -> Dictionary:
	if int(raw.get("schema_version", 0)) != SCHEMA_VERSION:
		return _default_profile()
	var sanitized: Dictionary = _default_profile()
	var anonymous_id: String = String(raw.get("anonymous_profile_id", "")).strip_edges()
	if not anonymous_id.is_empty() and anonymous_id.length() <= 64:
		sanitized["anonymous_profile_id"] = anonymous_id
	for key: String in [
		"total_runs", "victories", "best_score", "highest_combo_tier",
		"total_enemy_kills", "updated_unix_time",
	]:
		sanitized[key] = clampi(int(raw.get(key, 0)), 0, MAX_COUNTER)
	sanitized["lifetime_enemy_kills"] = _sanitize_counts(
		raw.get("lifetime_enemy_kills", {}) as Dictionary
	)
	sanitized["lifetime_weapon_kills"] = _sanitize_counts(
		raw.get("lifetime_weapon_kills", {}) as Dictionary
	)
	return sanitized


func _default_profile() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"anonymous_profile_id": _new_anonymous_profile_id(),
		"total_runs": 0,
		"victories": 0,
		"best_score": 0,
		"highest_combo_tier": 0,
		"total_enemy_kills": 0,
		"lifetime_enemy_kills": {},
		"lifetime_weapon_kills": {},
		"updated_unix_time": 0,
	}


func _new_anonymous_profile_id() -> String:
	var random_bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	return random_bytes.hex_encode()


func _merge_counts(existing: Dictionary, additions: Dictionary) -> Dictionary:
	var merged: Dictionary = _sanitize_counts(existing)
	for value: Variant in additions:
		var identifier: String = String(value).strip_edges()
		if identifier.is_empty() or (not merged.has(identifier) and merged.size() >= MAX_STAT_KEYS):
			continue
		merged[identifier] = _bounded_sum(
			int(merged.get(identifier, 0)),
			maxi(int(additions[value]), 0)
		)
	return merged


func _sanitize_counts(raw: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	var keys: Array = raw.keys()
	keys.sort_custom(func(first: Variant, second: Variant) -> bool:
		return String(first) < String(second)
	)
	for value: Variant in keys:
		if sanitized.size() >= MAX_STAT_KEYS:
			break
		var identifier: String = String(value).strip_edges()
		var count: int = clampi(int(raw[value]), 0, MAX_COUNTER)
		if identifier.is_empty() or identifier.length() > 64 or count <= 0:
			continue
		sanitized[identifier] = count
	return sanitized


func _string_keyed_counts(counts: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in counts:
		result[String(value)] = maxi(int(counts[value]), 0)
	return result


func _bounded_sum(first: int, second: int) -> int:
	return clampi(first + second, 0, MAX_COUNTER)
