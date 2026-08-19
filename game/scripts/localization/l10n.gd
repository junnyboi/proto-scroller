class_name L10n
extends RefCounted

const DEFAULT_LOCALE: String = "en"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "zh-CN"]
const CATALOG_PATHS: Dictionary = {
	"en": "res://localization/en.json",
	"zh-CN": "res://localization/zh-CN.json",
}
const LOCALE_OVERRIDE_ENV: String = "PROTO_SCROLLER_LOCALE"
const CJK_FONT_PATH: String = "res://art/fonts/DroidSansFallbackFull-ProtoScroller.ttf"

static var _catalogs: Dictionary = {}
static var _locale: String = ""
static var _loaded: bool = false
static var _cjk_font: Font


static func t(key: String, placeholders: Dictionary = {}) -> String:
	_ensure_loaded()
	var catalog: Dictionary = _catalogs.get(_locale, {}) as Dictionary
	var fallback: Dictionary = _catalogs.get(DEFAULT_LOCALE, {}) as Dictionary
	var value: String = String(catalog.get(key, fallback.get(key, key)))
	if not fallback.has(key):
		push_warning("Missing English localization key: %s" % key)
	if placeholders.is_empty():
		return value
	return value.format(placeholders)


static func set_locale(locale: String) -> bool:
	_ensure_loaded()
	var normalized: String = _normalize_locale(locale)
	if not SUPPORTED_LOCALES.has(normalized):
		return false
	_locale = normalized
	return true


static func current_locale() -> String:
	_ensure_loaded()
	return _locale


static func available_locales() -> PackedStringArray:
	return SUPPORTED_LOCALES.duplicate()


static func apply_locale_font(root: Node) -> void:
	_ensure_loaded()
	if _locale != "zh-CN":
		return
	if _cjk_font == null:
		_cjk_font = load(CJK_FONT_PATH) as Font
	if _cjk_font == null:
		push_error("Unable to load Simplified Chinese font: %s" % CJK_FONT_PATH)
		return
	if root is Control:
		(root as Control).add_theme_font_override(&"font", _cjk_font)
	for node: Node in root.find_children("*", "Control", true, false):
		(node as Control).add_theme_font_override(&"font", _cjk_font)


static func keys_for_locale(locale: String) -> PackedStringArray:
	_ensure_loaded()
	var normalized: String = _normalize_locale(locale)
	var catalog: Dictionary = _catalogs.get(normalized, {}) as Dictionary
	var keys: PackedStringArray = []
	for key: Variant in catalog.keys():
		keys.append(String(key))
	keys.sort()
	return keys


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_load_catalogs()
	_locale = _detect_locale()
	_loaded = true


static func _load_catalogs() -> void:
	for locale: String in SUPPORTED_LOCALES:
		var path: String = String(CATALOG_PATHS[locale])
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("Unable to open localization catalog: %s" % path)
			_catalogs[locale] = {}
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			push_error("Localization catalog must be a JSON object: %s" % path)
			_catalogs[locale] = {}
			continue
		_catalogs[locale] = parsed


static func _detect_locale() -> String:
	var override: String = OS.get_environment(LOCALE_OVERRIDE_ENV)
	if not override.is_empty():
		var normalized_override: String = _normalize_locale(override)
		if SUPPORTED_LOCALES.has(normalized_override):
			return normalized_override
	var detected: String = _normalize_locale(OS.get_locale())
	return detected if SUPPORTED_LOCALES.has(detected) else DEFAULT_LOCALE


static func _normalize_locale(locale: String) -> String:
	var normalized: String = locale.strip_edges().replace("_", "-").to_lower()
	if (
		normalized == "zh"
		or normalized.begins_with("zh-cn")
		or normalized.begins_with("zh-sg")
		or normalized.begins_with("zh-hans")
	):
		return "zh-CN"
	if normalized.begins_with("en"):
		return "en"
	return locale
