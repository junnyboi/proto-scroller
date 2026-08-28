extends SceneTree

const CHUNK_FRAMES: int = 4096
const MIN_PEAK: float = 0.00001
const MIN_RMS: float = 0.000001
const MIN_NONZERO_SAMPLES: int = 32

var _stage: String = "baseline"
var _output_path: String = "/tmp/proto-scroller-phase4-audio-verification.json"


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="):
			_stage = argument.trim_prefix("--stage=")
		elif argument.begins_with("--output="):
			_output_path = argument.trim_prefix("--output=")
	if _stage not in ["baseline", "candidate_a", "candidate_b"]:
		push_error("Unsupported Phase 4 audio stage: %s" % _stage)
		quit(2)
		return
	call_deferred("_run_stage")


func _run_stage() -> void:
	var game_root: String = ProjectSettings.globalize_path("res://")
	var manifest_path: String = game_root.path_join(
		"../docs/manifests/asset_optimization_phase4_audio.json"
	).simplify_path()
	var manifest_text: String = FileAccess.get_file_as_string(manifest_path)
	var manifest: Variant = JSON.parse_string(manifest_text)
	if not manifest is Dictionary:
		push_error("Unable to parse Phase 4 audio manifest")
		quit(2)
		return
	var errors: PackedStringArray = []
	var results: Array[Dictionary] = []
	var expected_counts: Dictionary = {"voice": 0, "sfx": 0}
	for raw_asset: Variant in manifest.assets:
		var asset: Dictionary = raw_asset as Dictionary
		var group: String = String(asset.group)
		expected_counts[group] = int(expected_counts.get(group, 0)) + 1
		var result: Dictionary = await _verify_asset(asset, errors)
		results.append(result)
	var report: Dictionary = {
		"stage": _stage,
		"engine_version": Engine.get_version_info().get("string", "unknown"),
		"candidate_count": results.size(),
		"group_counts": expected_counts,
		"thresholds": {
			"minimum_peak": MIN_PEAK,
			"minimum_rms": MIN_RMS,
			"minimum_nonzero_samples": MIN_NONZERO_SAMPLES,
		},
		"bus_state": _bus_state(),
		"results": results,
		"errors": Array(errors),
		"status": "PASS" if errors.is_empty() else "FAIL",
	}
	var output: FileAccess = FileAccess.open(_output_path, FileAccess.WRITE)
	if output == null:
		push_error("Unable to open Phase 4 audio report: %s" % _output_path)
		quit(2)
		return
	output.store_string(JSON.stringify(report, "  ") + "\n")
	output.close()
	print(
		"[PHASE4-AUDIO-%s] stage=%s streams=%d voice=%d sfx=%d errors=%d report=%s"
		% [
			"PASS" if errors.is_empty() else "FAIL",
			_stage,
			results.size(),
			int(expected_counts.voice),
			int(expected_counts.sfx),
			errors.size(),
			_output_path,
		]
	)
	call_deferred("_finish", errors.is_empty())


func _finish(passed: bool) -> void:
	await process_frame
	await process_frame
	quit(0 if passed else 1)


func _verify_asset(asset: Dictionary, errors: PackedStringArray) -> Dictionary:
	var source_path: String = String(asset.source_path)
	var group: String = String(asset.group)
	var expected_rate: int = _expected_mix_rate(asset)
	var expected_bus: StringName = &"Voice" if group == "voice" else &"SFX"
	var stream: AudioStream = load(source_path) as AudioStream
	if stream == null:
		errors.append("%s failed to load" % source_path)
		return {"source_path": source_path, "group": group, "status": "FAIL"}
	if not stream is AudioStreamWAV:
		errors.append("%s imported as %s, expected AudioStreamWAV" % [source_path, stream.get_class()])
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	if wav.format != AudioStreamWAV.FORMAT_QOA:
		errors.append("%s is not imported as QOA" % source_path)
	if wav.mix_rate != expected_rate:
		errors.append("%s mix rate %d, expected %d" % [source_path, wav.mix_rate, expected_rate])
	if wav.get_length() <= 0.0:
		errors.append("%s has zero imported duration" % source_path)
	var playback: AudioStreamPlayback = wav.instantiate_playback()
	if playback == null:
		errors.append("%s failed to instantiate playback" % source_path)
		return {"source_path": source_path, "group": group, "status": "FAIL"}
	playback.start(0.0)
	var peak: float = 0.0
	var sum_squares: float = 0.0
	var sample_count: int = 0
	var nonzero_samples: int = 0
	var frame_count: int = 0
	var maximum_frames: int = ceili(wav.get_length() * float(AudioServer.get_mix_rate())) + CHUNK_FRAMES * 2
	while playback.is_playing() and frame_count < maximum_frames:
		var frames: PackedVector2Array = playback.mix_audio(1.0, CHUNK_FRAMES)
		if frames.is_empty():
			break
		for frame: Vector2 in frames:
			var left: float = absf(frame.x)
			var right: float = absf(frame.y)
			peak = maxf(peak, maxf(left, right))
			sum_squares += frame.x * frame.x + frame.y * frame.y
			sample_count += 2
			if left > 0.0000001:
				nonzero_samples += 1
			if right > 0.0000001:
				nonzero_samples += 1
		frame_count += frames.size()
	var rms: float = sqrt(sum_squares / float(maxi(sample_count, 1)))
	if peak < MIN_PEAK:
		errors.append("%s decoded peak %.9f is effectively silent" % [source_path, peak])
	if rms < MIN_RMS:
		errors.append("%s decoded RMS %.9f is effectively silent" % [source_path, rms])
	if nonzero_samples < MIN_NONZERO_SAMPLES:
		errors.append("%s decoded only %d nonzero samples" % [source_path, nonzero_samples])
	var bus_index: int = AudioServer.get_bus_index(expected_bus)
	if bus_index < 0:
		errors.append("%s expected bus %s is missing" % [source_path, expected_bus])
	elif AudioServer.is_bus_mute(bus_index):
		errors.append("%s expected bus %s is muted" % [source_path, expected_bus])
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = wav
	player.bus = expected_bus
	get_root().add_child(player)
	player.play()
	await process_frame
	var player_started: bool = player.playing
	if not player_started:
		errors.append("%s did not enter active playback on %s" % [source_path, expected_bus])
	player.stop()
	player.free()
	return {
		"source_path": source_path,
		"group": group,
		"expected_bus": String(expected_bus),
		"bus_index": bus_index,
		"bus_muted": false if bus_index < 0 else AudioServer.is_bus_mute(bus_index),
		"bus_volume_db": -999.0 if bus_index < 0 else AudioServer.get_bus_volume_db(bus_index),
		"format": wav.format,
		"mix_rate_hz": wav.mix_rate,
		"length_seconds": snappedf(wav.get_length(), 0.000001),
		"decoded_frames": frame_count,
		"decoded_peak": snappedf(peak, 0.00000001),
		"decoded_rms": snappedf(rms, 0.00000001),
		"nonzero_samples": nonzero_samples,
		"player_started": player_started,
		"status": "PASS" if (
			wav.format == AudioStreamWAV.FORMAT_QOA
			and wav.mix_rate == expected_rate
			and peak >= MIN_PEAK
			and rms >= MIN_RMS
			and nonzero_samples >= MIN_NONZERO_SAMPLES
			and bus_index >= 0
			and not AudioServer.is_bus_mute(bus_index)
			and player_started
		) else "FAIL",
	}


func _expected_mix_rate(asset: Dictionary) -> int:
	var group: String = String(asset.group)
	var before: Dictionary = asset.before as Dictionary
	var baseline_rate: int = (
		int(before.force_max_rate_hz)
		if bool(before.force_max_rate)
		else int(before.sample_rate_hz)
	)
	if _stage == "baseline":
		return baseline_rate
	if _stage == "candidate_a":
		return 24000 if group == "voice" else baseline_rate
	return 24000


func _bus_state() -> Dictionary:
	var state: Dictionary = {}
	for bus_name: StringName in [&"Master", &"SFX", &"Voice", &"UI", &"Mechanics", &"Threat", &"Ambience"]:
		var index: int = AudioServer.get_bus_index(bus_name)
		state[String(bus_name)] = {
			"index": index,
			"mute": true if index < 0 else AudioServer.is_bus_mute(index),
			"volume_db": -999.0 if index < 0 else AudioServer.get_bus_volume_db(index),
		}
	return state
