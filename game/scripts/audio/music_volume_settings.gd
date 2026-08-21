class_name MusicVolumeSettings
extends RefCounted

const PREFERENCE_PATH: String = "user://audio_settings.cfg"
const SECTION: String = "audio"
const MUSIC_VOLUME_KEY: String = "music_volume_percent"
const SFX_VOLUME_KEY: String = "sfx_volume_percent"
const VOICE_VOLUME_KEY: String = "voice_volume_percent"
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const VOICE_BUS: StringName = &"Voice"
const DEFAULT_PERCENT: float = 70.0
const DEFAULT_MUSIC_PERCENT: float = DEFAULT_PERCENT
const DEFAULT_SFX_PERCENT: float = 100.0
const DEFAULT_VOICE_PERCENT: float = 100.0
const SILENCE_FLOOR_DB: float = -80.0


static func load_percent(path: String = PREFERENCE_PATH) -> float:
	return _load_bus_percent(MUSIC_VOLUME_KEY, DEFAULT_MUSIC_PERCENT, path)


static func load_sfx_percent(path: String = PREFERENCE_PATH) -> float:
	return _load_bus_percent(SFX_VOLUME_KEY, DEFAULT_SFX_PERCENT, path)


static func load_voice_percent(path: String = PREFERENCE_PATH) -> float:
	return _load_bus_percent(VOICE_VOLUME_KEY, DEFAULT_VOICE_PERCENT, path)


static func apply_saved(path: String = PREFERENCE_PATH) -> float:
	return apply_percent(load_percent(path))


static func apply_all_saved(path: String = PREFERENCE_PATH) -> Dictionary[StringName, float]:
	return {
		MUSIC_BUS: apply_saved(path),
		SFX_BUS: apply_sfx_percent(load_sfx_percent(path)),
		VOICE_BUS: apply_voice_percent(load_voice_percent(path)),
	}


static func set_and_save(percent: float, path: String = PREFERENCE_PATH) -> Error:
	return _set_bus_and_save(MUSIC_VOLUME_KEY, MUSIC_BUS, percent, path)


static func set_sfx_and_save(percent: float, path: String = PREFERENCE_PATH) -> Error:
	return _set_bus_and_save(SFX_VOLUME_KEY, SFX_BUS, percent, path)


static func set_voice_and_save(percent: float, path: String = PREFERENCE_PATH) -> Error:
	return _set_bus_and_save(VOICE_VOLUME_KEY, VOICE_BUS, percent, path)


static func apply_percent(percent: float) -> float:
	return _apply_bus_percent(MUSIC_BUS, percent)


static func apply_sfx_percent(percent: float) -> float:
	return _apply_bus_percent(SFX_BUS, percent)


static func apply_voice_percent(percent: float) -> float:
	return _apply_bus_percent(VOICE_BUS, percent)


static func percent_to_db(percent: float) -> float:
	var linear_value: float = clampf(percent, 0.0, 100.0) / 100.0
	if linear_value <= 0.0001:
		return SILENCE_FLOOR_DB
	return maxf(linear_to_db(linear_value), SILENCE_FLOOR_DB)


static func clear_preference(path: String = PREFERENCE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _load_bus_percent(key: String, default_percent: float, path: String) -> float:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return default_percent
	return clampf(float(config.get_value(SECTION, key, default_percent)), 0.0, 100.0)


static func _set_bus_and_save(
	key: String,
	bus_name: StringName,
	percent: float,
	path: String
) -> Error:
	var clamped_percent: float = _apply_bus_percent(bus_name, percent)
	var config: ConfigFile = ConfigFile.new()
	config.load(path)
	config.set_value(SECTION, key, clamped_percent)
	return config.save(path)


static func _apply_bus_percent(bus_name: StringName, percent: float) -> float:
	var clamped_percent: float = clampf(percent, 0.0, 100.0)
	var bus_index: int = _ensure_bus(bus_name)
	AudioServer.set_bus_volume_db(bus_index, percent_to_db(clamped_percent))
	return clamped_percent


static func _ensure_bus(bus_name: StringName) -> int:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")
	return index
