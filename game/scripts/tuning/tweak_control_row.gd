class_name TweakControlRow
extends PanelContainer

signal value_requested(identifier: StringName, value: Variant)
signal reset_requested(identifier: StringName)

var descriptor: RuntimeTweakDescriptor
var title_label: Label
var mode_label: Label
var value_label: Label
var slider: HSlider
var toggle: CheckButton
var reset_button: Button
var _binding: bool = false
var _compact: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 78.0)
	add_theme_stylebox_override(&"panel", RuntimeTweakTheme.panel_style(true))
	_build()


func bind(entry: RuntimeTweakDescriptor, requested: Variant, active: Variant) -> void:
	descriptor = entry
	visible = entry != null
	if entry == null:
		return
	_binding = true
	title_label.text = L10n.t(entry.label_key)
	if title_label.text == entry.label_key:
		title_label.text = entry.label_fallback()
	title_label.tooltip_text = L10n.t(entry.description_key)
	mode_label.text = L10n.t("tuning.mode.%s" % String(entry.apply_mode).to_lower())
	mode_label.visible = not _compact
	mode_label.modulate = (
		RuntimeTweakTheme.MUTED
		if entry.integrity == &"COSMETIC"
		else RuntimeTweakTheme.AMBER
	)
	slider.visible = entry.value_type != &"bool"
	toggle.visible = entry.value_type == &"bool"
	if entry.value_type == &"bool":
		toggle.button_pressed = bool(requested)
		toggle.text = L10n.t("tuning.value.on" if bool(requested) else "tuning.value.off")
	else:
		slider.min_value = entry.minimum
		slider.max_value = entry.maximum
		slider.step = entry.step
		slider.value = float(requested)
	value_label.visible = not _compact
	_update_value_label(requested, active)
	reset_button.disabled = entry.values_equal(requested, entry.default_value)
	_binding = false


func refresh(requested: Variant, active: Variant) -> void:
	if descriptor == null:
		return
	bind(descriptor, requested, active)


func set_compact(compact: bool) -> void:
	_compact = compact
	if descriptor != null:
		bind(descriptor, descriptor.default_value, descriptor.default_value)


func _build() -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 5)
	add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override(&"font_size", 17)
	title_label.add_theme_color_override(&"font_color", RuntimeTweakTheme.TEXT)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	header.add_child(title_label)
	mode_label = Label.new()
	mode_label.custom_minimum_size.x = 118.0
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_label.add_theme_font_size_override(&"font_size", 12)
	header.add_child(mode_label)
	reset_button = Button.new()
	reset_button.text = "R"
	reset_button.custom_minimum_size = Vector2(38.0, 32.0)
	reset_button.focus_mode = Control.FOCUS_ALL
	reset_button.tooltip_text = L10n.t("tuning.action.reset_parameter")
	var reset_style: StyleBoxFlat = RuntimeTweakTheme.button_style()
	reset_button.add_theme_stylebox_override(&"normal", reset_style)
	reset_button.add_theme_stylebox_override(&"hover", reset_style)
	reset_button.add_theme_stylebox_override(&"pressed", reset_style)
	reset_button.add_theme_stylebox_override(&"focus", reset_style)
	reset_button.pressed.connect(_on_reset_pressed)
	header.add_child(reset_button)
	var editor: HBoxContainer = HBoxContainer.new()
	editor.add_theme_constant_override(&"separation", 12)
	column.add_child(editor)
	slider = HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 32.0
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(_on_slider_changed)
	editor.add_child(slider)
	toggle = CheckButton.new()
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.custom_minimum_size.y = 34.0
	toggle.toggled.connect(_on_toggle_changed)
	editor.add_child(toggle)
	value_label = Label.new()
	value_label.custom_minimum_size.x = 150.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override(&"font_size", 15)
	value_label.add_theme_color_override(&"font_color", RuntimeTweakTheme.ACCENT)
	editor.add_child(value_label)


func _on_slider_changed(value: float) -> void:
	if _binding or descriptor == null:
		return
	var submitted: Variant = roundi(value) if descriptor.value_type == &"int" else value
	value_requested.emit(descriptor.id, submitted)


func _on_toggle_changed(enabled: bool) -> void:
	if _binding or descriptor == null:
		return
	toggle.text = L10n.t("tuning.value.on" if enabled else "tuning.value.off")
	value_requested.emit(descriptor.id, enabled)


func _on_reset_pressed() -> void:
	if descriptor != null:
		reset_requested.emit(descriptor.id)


func _update_value_label(requested: Variant, active: Variant) -> void:
	var requested_text: String = _format_value(requested)
	var active_text: String = _format_value(active)
	value_label.text = (
		requested_text
		if descriptor.values_equal(requested, active)
		else "%s  >  %s" % [active_text, requested_text]
	)
	value_label.modulate = (
		RuntimeTweakTheme.ACCENT
		if descriptor.values_equal(requested, active)
		else RuntimeTweakTheme.AMBER
	)


func _format_value(value: Variant) -> String:
	if descriptor.value_type == &"bool":
		return L10n.t("tuning.value.on" if bool(value) else "tuning.value.off")
	var number: String = (
		str(int(value))
		if descriptor.value_type == &"int" or is_equal_approx(float(value), roundf(float(value)))
		else "%.3f" % float(value)
	)
	number = number.trim_suffix("0").trim_suffix("0").trim_suffix(".") if "." in number else number
	return "%s %s" % [number, descriptor.unit] if not descriptor.unit.is_empty() else number
