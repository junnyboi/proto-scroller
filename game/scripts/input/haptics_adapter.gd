class_name HapticsAdapter
extends Node

@export var enabled: bool = true
@export_range(-1, 1, 1) var detection_override: int = -1

var request_count: int = 0
var last_duration_ms: int = 0
var mobile_device_detected: bool = false


func _ready() -> void:
	mobile_device_detected = _detect_mobile_device()


func setup(p_detection_override: int = -1) -> void:
	detection_override = p_detection_override


func pulse(duration_ms: int) -> bool:
	if not enabled or not mobile_device_detected:
		return false
	last_duration_ms = clampi(duration_ms, 1, 100)
	request_count += 1
	if detection_override >= 0:
		return true
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"navigator.vibrate && navigator.vibrate(%d)" % last_duration_ms,
			true
		)
		return true
	Input.vibrate_handheld(last_duration_ms)
	return true


func cancel() -> void:
	if detection_override >= 0:
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.vibrate && navigator.vibrate(0)", true)
	else:
		Input.vibrate_handheld(0)


func reset_runtime_state() -> void:
	cancel()
	request_count = 0
	last_duration_ms = 0


func _detect_mobile_device() -> bool:
	if detection_override >= 0:
		return detection_override == 1
	if OS.has_feature("web"):
		var browser_touch: Variant = JavaScriptBridge.eval(
			"(navigator.maxTouchPoints || 0) > 0",
			true
		)
		if bool(browser_touch):
			return true
	return (
		OS.has_feature("mobile")
		or OS.has_feature("android")
		or OS.has_feature("ios")
		or DisplayServer.is_touchscreen_available()
	)
