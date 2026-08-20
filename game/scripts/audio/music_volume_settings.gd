class_name MusicVolumeSettings
extends RefCounted

const PREFERENCE_PATH: String = "user://audio_settings.cfg"
const SECTION: String = "audio"
const MUSIC_VOLUME_KEY: String = "music_volume_percent"
const MUSIC_BUS: StringName = &"Music"
const DEFAULT_PERCENT: float = 70.0
const SILENCE_FLOOR_DB: float = -80.0


static func load_percent(path: String = PREFERENCE_PATH) -> float:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return DEFAULT_PERCENT
	return clampf(float(config.get_value(SECTION, MUSIC_VOLUME_KEY, DEFAULT_PERCENT)), 0.0, 100.0)


static func apply_saved(path: String = PREFERENCE_PATH) -> float:
	var percent: float = load_percent(path)
	apply_percent(percent)
	return percent


static func set_and_save(percent: float, path: String = PREFERENCE_PATH) -> Error:
	var clamped_percent: float = apply_percent(percent)
	var config: ConfigFile = ConfigFile.new()
	config.load(path)
	config.set_value(SECTION, MUSIC_VOLUME_KEY, clamped_percent)
	return config.save(path)


static func apply_percent(percent: float) -> float:
	var clamped_percent: float = clampf(percent, 0.0, 100.0)
	var bus_index: int = _ensure_music_bus()
	AudioServer.set_bus_volume_db(bus_index, percent_to_db(clamped_percent))
	return clamped_percent


static func percent_to_db(percent: float) -> float:
	var linear_value: float = clampf(percent, 0.0, 100.0) / 100.0
	if linear_value <= 0.0001:
		return SILENCE_FLOOR_DB
	return maxf(linear_to_db(linear_value), SILENCE_FLOOR_DB)


static func clear_preference(path: String = PREFERENCE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _ensure_music_bus() -> int:
	var index: int = AudioServer.get_bus_index(MUSIC_BUS)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, MUSIC_BUS)
	AudioServer.set_bus_send(index, &"Master")
	return index
