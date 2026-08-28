extends Node

const MANIFEST_PATH: String = "res://phase4_audio_manifest.json"
const PLAYER_SETTLE_SECONDS: float = 0.08


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_publish({"status": "FAIL", "errors": ["manifest_parse_failed"]})
		return
	var manifest: Dictionary = parsed as Dictionary
	var errors: PackedStringArray = []
	var results: Array[Dictionary] = []
	while not bool(JavaScriptBridge.eval("navigator.userActivation.hasBeenActive === true")):
		await get_tree().process_frame
	await get_tree().create_timer(0.20).timeout
	for raw_asset: Variant in manifest.assets:
		var asset: Dictionary = raw_asset as Dictionary
		var source_path: String = String(asset.source_path)
		var group: String = String(asset.group)
		var bus: StringName = &"Voice" if group == "voice" else &"SFX"
		var stream: AudioStream = load(source_path) as AudioStream
		if stream == null or not stream is AudioStreamWAV:
			errors.append("%s failed to load as AudioStreamWAV" % source_path)
			continue
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		var bus_index: int = AudioServer.get_bus_index(bus)
		if wav.format != AudioStreamWAV.FORMAT_QOA:
			errors.append("%s is not QOA" % source_path)
		if wav.mix_rate != 24000:
			errors.append("%s mix rate is %d" % [source_path, wav.mix_rate])
		if wav.get_length() <= 0.0:
			errors.append("%s has zero duration" % source_path)
		if bus_index < 0 or AudioServer.is_bus_mute(bus_index):
			errors.append("%s bus %s is missing or muted" % [source_path, bus])
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = wav
		player.bus = bus
		add_child(player)
		player.play()
		await get_tree().process_frame
		await get_tree().process_frame
		var started: bool = player.playing
		if not started:
			errors.append("%s did not enter active Web playback" % source_path)
		results.append({
			"source_path": source_path,
			"group": group,
			"bus": String(bus),
			"bus_muted": false if bus_index < 0 else AudioServer.is_bus_mute(bus_index),
			"mix_rate_hz": wav.mix_rate,
			"format": wav.format,
			"length_seconds": snappedf(wav.get_length(), 0.000001),
			"player_started": started,
		})
		await get_tree().create_timer(PLAYER_SETTLE_SECONDS).timeout
		player.stop()
		player.free()
	var report: Dictionary = {
		"status": "PASS" if errors.is_empty() else "FAIL",
		"stream_count": results.size(),
		"voice_count": results.filter(func(item: Dictionary) -> bool: return item.group == "voice").size(),
		"sfx_count": results.filter(func(item: Dictionary) -> bool: return item.group == "sfx").size(),
		"audio_mix_rate_hz": AudioServer.get_mix_rate(),
		"results": results,
		"errors": Array(errors),
	}
	_publish(report)


func _publish(report: Dictionary) -> void:
	print("[PHASE4-WEB-AUDIO-%s] streams=%d errors=%d" % [
		report.get("status", "FAIL"),
		int(report.get("stream_count", 0)),
		(report.get("errors", []) as Array).size(),
	])
	JavaScriptBridge.eval(
		"window.__PROTO_SCROLLER_PHASE4_AUDIO__ = %s;" % JSON.stringify(report)
	)
