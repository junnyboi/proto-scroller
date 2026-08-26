class_name AudioCueRegistry
extends RefCounted

enum Cue {
	INVALID,
	OVERDRIVE_ACTIVATION,
	COMBO_BREAK,
	UPGRADE_CONFIRM,
	SHOP_PURCHASE,
	SHOP_REPAIR,
}

const OVERDRIVE_ACTIVATION_SFX: AudioStream = preload(
	"res://audio/sfx/rampage/overdrive_activation.wav"
)
const COMBO_BREAK_SFX: AudioStream = preload(
	"res://audio/sfx/rampage/combo_break.wav"
)
const UPGRADE_CONFIRM_SFX: AudioStream = preload(
	"res://audio/sfx/upgrades/upgrade_confirm.wav"
)
const SHOP_PURCHASE_SFX: AudioStream = preload(
	"res://audio/sfx/shop/shop_purchase.wav"
)
const SHOP_REPAIR_SFX: AudioStream = preload(
	"res://audio/sfx/shop/shop_repair.wav"
)
const PROFILES: Dictionary = {
	Cue.OVERDRIVE_ACTIVATION: {
		&"id": &"overdrive",
		&"stream": OVERDRIVE_ACTIVATION_SFX,
		&"bus": &"SFX",
		&"volume_db": -3.0,
		&"priority": AudioVoicePriority.SIGNATURE,
	},
	Cue.COMBO_BREAK: {
		&"id": &"combo_break",
		&"stream": COMBO_BREAK_SFX,
		&"bus": &"SFX",
		&"volume_db": -5.0,
		&"priority": AudioVoicePriority.MAJOR,
	},
	Cue.UPGRADE_CONFIRM: {
		&"id": &"upgrade",
		&"stream": UPGRADE_CONFIRM_SFX,
		&"bus": &"UI",
		&"volume_db": -5.0,
		&"priority": AudioVoicePriority.MAJOR,
	},
	Cue.SHOP_PURCHASE: {
		&"id": &"shop_purchase",
		&"stream": SHOP_PURCHASE_SFX,
		&"bus": &"UI",
		&"volume_db": 2.0,
		&"priority": AudioVoicePriority.MAJOR,
	},
	Cue.SHOP_REPAIR: {
		&"id": &"shop_repair",
		&"stream": SHOP_REPAIR_SFX,
		&"bus": &"UI",
		&"volume_db": 0.0,
		&"priority": AudioVoicePriority.MAJOR,
	},
}


static func profile(cue: Cue) -> Dictionary:
	return PROFILES.get(cue, {}) as Dictionary


static func is_valid(cue: Cue) -> bool:
	return PROFILES.has(cue)
