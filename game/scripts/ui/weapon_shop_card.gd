class_name WeaponShopCard
extends Button

signal purchase_requested(product_id: StringName)

const AVAILABLE_COLOR: Color = Color("7ae4ff")
const PRICE_COLOR: Color = Color("f1b36f")
const MUTED_COLOR: Color = Color("75838b")

var product: WeaponShopProduct
var accent_color: Color = AVAILABLE_COLOR
var title_label: Label
var description_label: Label
var price_label: Label
var state_label: Label


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build_contents()
	pressed.connect(_on_pressed)
	resized.connect(_apply_layout)
	_apply_style(false)


func configure(
	p_product: WeaponShopProduct,
	p_status: StringName,
	p_accent_color: Color
) -> void:
	product = p_product
	accent_color = p_accent_color
	title_label.text = L10n.t(product.name_key)
	description_label.text = L10n.t(product.description_key)
	price_label.text = L10n.t("shop.price", {"price": "%05d" % product.price})
	set_status(p_status)


func set_status(status: StringName) -> void:
	disabled = status != &"available"
	match status:
		&"sold":
			state_label.text = L10n.t("shop.sold")
			state_label.modulate = MUTED_COLOR
		&"healthy":
			state_label.text = L10n.t("shop.full_integrity")
			state_label.modulate = MUTED_COLOR
		&"funds":
			state_label.text = L10n.t("shop.insufficient")
			state_label.modulate = Color("d98262")
		_:
			state_label.text = L10n.t("shop.buy")
			state_label.modulate = accent_color
	_apply_style(has_focus())


func _build_contents() -> void:
	text = ""
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override(&"font_size", 22)
	add_child(title_label)
	description_label = Label.new()
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override(&"font_size", 17)
	description_label.modulate = Color("b7c4cb")
	add_child(description_label)
	price_label = Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override(&"font_size", 24)
	price_label.modulate = PRICE_COLOR
	add_child(price_label)
	state_label = Label.new()
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override(&"font_size", 18)
	add_child(state_label)
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))


func _apply_layout() -> void:
	var padding: float = 18.0
	title_label.position = Vector2(padding, 14.0)
	title_label.size = Vector2(size.x - padding * 2.0, 54.0)
	description_label.position = Vector2(padding, 70.0)
	description_label.size = Vector2(size.x - padding * 2.0, maxf(size.y - 142.0, 54.0))
	price_label.position = Vector2(padding, size.y - 68.0)
	price_label.size = Vector2(size.x - padding * 2.0, 30.0)
	state_label.position = Vector2(padding, size.y - 36.0)
	state_label.size = Vector2(size.x - padding * 2.0, 24.0)


func _apply_style(focused: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.055, 0.96 if not disabled else 0.78)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = accent_color if focused and not disabled else Color("50636c")
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	add_theme_stylebox_override(&"normal", style)
	add_theme_stylebox_override(&"hover", style)
	add_theme_stylebox_override(&"focus", style)
	add_theme_stylebox_override(&"disabled", style)


func _on_focus_changed(focused: bool) -> void:
	_apply_style(focused)


func _on_pressed() -> void:
	if product != null and not disabled:
		purchase_requested.emit(product.product_id)
