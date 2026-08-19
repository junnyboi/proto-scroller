extends GutTest

const TITLE_SCREEN_SCENE: PackedScene = preload("res://scenes/title_screen.tscn")
const TEST_PREFERENCE_PATH: String = "user://test-l10n-preference.cfg"


func before_each() -> void:
	L10n.clear_locale_preference(TEST_PREFERENCE_PATH)
	L10n.set_locale("en")


func after_each() -> void:
	L10n.set_locale("en")
	L10n.clear_locale_preference(TEST_PREFERENCE_PATH)


func test_catalogs_have_identical_keys() -> void:
	var english_keys: PackedStringArray = L10n.keys_for_locale("en")
	var chinese_keys: PackedStringArray = L10n.keys_for_locale("zh-CN")
	assert_gt(english_keys.size(), 100)
	assert_eq(chinese_keys, english_keys)
	var english_placeholders: Dictionary[String, PackedStringArray] = {}
	L10n.set_locale("en")
	for key: String in english_keys:
		english_placeholders[key] = _placeholders(L10n.t(key))
	L10n.set_locale("zh-CN")
	for key: String in chinese_keys:
		assert_eq(_placeholders(L10n.t(key)), english_placeholders[key], key)


func test_named_placeholders_are_substituted() -> void:
	assert_eq(
		L10n.t("hud.health", {"current": "080", "maximum": "100"}),
		"CHASSIS 080 / 100"
	)
	assert_true(L10n.set_locale("zh-CN"))
	assert_eq(
		L10n.t("hud.health", {"current": "080", "maximum": "100"}),
		"机体 080 / 100"
	)
	var dash_profile: UpgradeProfile = load(
		"res://resources/upgrades/dash_amplifier.tres"
	) as UpgradeProfile
	assert_eq(dash_profile.display_name, "upgrade.dash_amplifier.name")
	assert_eq(dash_profile.description, "upgrade.dash_amplifier.description")
	assert_eq(L10n.t(dash_profile.display_name), "冲刺增幅器")
	assert_true(L10n.t(dash_profile.description).contains("300 毫秒"))


func test_unsupported_locale_is_rejected_without_mutation() -> void:
	assert_false(L10n.set_locale("fr-FR"))
	assert_eq(L10n.current_locale(), "en")
	assert_false(L10n.set_locale("zh-TW"))
	assert_eq(L10n.current_locale(), "en")
	assert_true(L10n.set_locale("zh_Hans_CN"))
	assert_eq(L10n.current_locale(), "zh-CN")
	assert_true(L10n.set_locale("zh-CN", true, TEST_PREFERENCE_PATH))
	assert_eq(L10n.preferred_locale(TEST_PREFERENCE_PATH), "zh-CN")
	assert_false(L10n.uses_automatic_locale(TEST_PREFERENCE_PATH))
	assert_true(FileAccess.file_exists(TEST_PREFERENCE_PATH))
	var detected_locale: String = L10n.automatic_locale()
	assert_true(L10n.use_automatic_locale(TEST_PREFERENCE_PATH))
	assert_eq(L10n.current_locale(), detected_locale)
	assert_true(L10n.uses_automatic_locale(TEST_PREFERENCE_PATH))
	assert_eq(L10n.preferred_locale(TEST_PREFERENCE_PATH), "")
	assert_false(FileAccess.file_exists(TEST_PREFERENCE_PATH))


func test_simplified_chinese_title_screen_uses_catalog_copy() -> void:
	L10n.set_locale("zh-CN")
	var screen: TitleScreen = TITLE_SCREEN_SCENE.instantiate() as TitleScreen
	screen.locale_preference_path = TEST_PREFERENCE_PATH
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_eq((screen.get_node("%TitleLabel") as Label).text, L10n.t("title.command_heading"))
	assert_true(
		(screen.get_node("%InitializeButton") as Button).text.contains(L10n.t("title.begin"))
	)
	assert_eq(
		(screen.get_node("%InstructionLabel") as Label).text,
		L10n.t("title.command_hook")
	)
	assert_true(
		(screen.get_node("%BriefingArt") as TextureRect)
		.texture.resource_path.contains("briefing_landscape_zh_cn")
	)
	var title_font: Font = (screen.get_node("%TitleLabel") as Label).get_theme_font(&"font")
	assert_true(title_font.has_char("中".unicode_at(0)))


func _placeholders(value: String) -> PackedStringArray:
	var matcher: RegEx = RegEx.new()
	matcher.compile("\\{([a-zA-Z0-9_]+)\\}")
	var names: PackedStringArray = []
	for result: RegExMatch in matcher.search_all(value):
		names.append(result.get_string(1))
	names.sort()
	return names
