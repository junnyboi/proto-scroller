class_name AudioVolumeSettings
extends RefCounted

enum Channel {
	MASTER,
	MUSIC,
	SFX,
	VOICE,
}

const PREFERENCE_PATH: String = "user://audio_settings.cfg"
const SECTION: String = "audio"
const SILENCE_FLOOR_DB: float = -80.0
const CHANNELS: Array[int] = [
	Channel.MASTER,
	Channel.MUSIC,
	Channel.SFX,
	Channel.VOICE,
]
const BUS_NAMES: Dictionary = {
	Channel.MASTER: &"Master",
	Channel.MUSIC: &"Music",
	Channel.SFX: &"SFX",
	Channel.VOICE: &"Voice",
}
const PREFERENCE_KEYS: Dictionary = {
	Channel.MASTER: "master_volume_percent",
	Channel.MUSIC: "music_volume_percent",
	Channel.SFX: "sfx_volume_percent",
	Channel.VOICE: "voice_volume_percent",
}
const DEFAULT_PERCENTS: Dictionary = {
	Channel.MASTER: 100.0,
	Channel.MUSIC: 70.0,
	Channel.SFX: 100.0,
	Channel.VOICE: 100.0,
}


static func load_percent(channel: int, path: String = PREFERENCE_PATH) -> float:
	if not _channel_valid(channel):
		return 0.0
	var fallback: float = default_percent(channel)
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return fallback
	var key: String = String(PREFERENCE_KEYS[channel])
	return clampf(float(config.get_value(SECTION, key, fallback)), 0.0, 100.0)


static func apply_saved(path: String = PREFERENCE_PATH) -> Dictionary:
	ensure_bus_hierarchy()
	var values: Dictionary = {}
	for channel: int in CHANNELS:
		values[channel] = apply_percent(channel, load_percent(channel, path))
	return values


static func set_and_save(
	channel: int,
	percent: float,
	path: String = PREFERENCE_PATH
) -> Error:
	if not _channel_valid(channel):
		return ERR_INVALID_PARAMETER
	var clamped_percent: float = apply_percent(channel, percent)
	var config: ConfigFile = ConfigFile.new()
	config.load(path)
	config.set_value(SECTION, String(PREFERENCE_KEYS[channel]), clamped_percent)
	return config.save(path)


static func apply_percent(channel: int, percent: float) -> float:
	if not _channel_valid(channel):
		return 0.0
	ensure_bus_hierarchy()
	var clamped_percent: float = clampf(percent, 0.0, 100.0)
	var bus_index: int = AudioServer.get_bus_index(bus_name(channel))
	AudioServer.set_bus_volume_db(bus_index, percent_to_db(clamped_percent))
	return clamped_percent


static func percent_to_db(percent: float) -> float:
	var linear_value: float = clampf(percent, 0.0, 100.0) / 100.0
	if linear_value <= 0.0001:
		return SILENCE_FLOOR_DB
	return maxf(linear_to_db(linear_value), SILENCE_FLOOR_DB)


static func bus_name(channel: int) -> StringName:
	return BUS_NAMES.get(channel, &"") as StringName


static func default_percent(channel: int) -> float:
	return float(DEFAULT_PERCENTS.get(channel, 0.0))


static func ensure_bus_hierarchy() -> void:
	_ensure_bus(&"Music", &"Master")
	_ensure_bus(&"SFX", &"Master")
	_ensure_bus(&"Mechanics", &"SFX")
	_ensure_bus(&"Threat", &"SFX")
	_ensure_bus(&"Voice", &"Master")
	_ensure_bus(&"UI", &"Master")
	_ensure_bus(&"Ambience", &"SFX")


static func clear_preference(path: String = PREFERENCE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _channel_valid(channel: int) -> bool:
	return channel in CHANNELS


static func _ensure_bus(bus: StringName, send: StringName) -> int:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, send)
	return index
