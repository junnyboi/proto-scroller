class_name WeaponShopStatPreviewPanel
extends Control

var frame_texture: TextureRect
var heading_label: Label
var product_label: Label
var rows_label: Label
var status_label: Label
var active_product_id: StringName = &""


func _ready() -> void:
	name = "WeaponShopStatPreviewPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_controls()
	resized.connect(_apply_layout)
	_apply_layout()


func show_preview(
	product: WeaponShopProduct,
	rows: Array[Dictionary],
	status: StringName
) -> void:
	if product == null:
		return
	active_product_id = product.product_id
	heading_label.text = L10n.t("shop.preview.title")
	product_label.text = L10n.t(product.name_key)
	rows_label.text = WeaponShopStatFormatter.format_rows(rows)
	status_label.text = _status_text(status)
	visible = true


func update_status(product_id: StringName, status: StringName) -> void:
	if product_id == active_product_id:
		status_label.text = _status_text(status)


func _build_controls() -> void:
	frame_texture = TextureRect.new()
	frame_texture.texture = WeaponShopVisualCatalog.STAT_PREVIEW_FRAME
	frame_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_texture.stretch_mode = TextureRect.STRETCH_SCALE
	frame_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame_texture)
	heading_label = _label(14, Color("f1b36f"))
	add_child(heading_label)
	product_label = _label(20, Color("e8f3ef"))
	add_child(product_label)
	rows_label = _label(17, Color("7ae4ff"))
	rows_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(rows_label)
	status_label = _label(14, Color("9fb0b8"))
	add_child(status_label)


func _apply_layout() -> void:
	var padding: float = 22.0
	heading_label.position = Vector2(padding, 14.0)
	heading_label.size = Vector2(size.x - padding * 2.0, 24.0)
	product_label.position = Vector2(padding, 40.0)
	product_label.size = Vector2(size.x - padding * 2.0, 34.0)
	rows_label.position = Vector2(padding, 76.0)
	rows_label.size = Vector2(size.x - padding * 2.0, maxf(size.y - 118.0, 38.0))
	status_label.position = Vector2(padding, size.y - 35.0)
	status_label.size = Vector2(size.x - padding * 2.0, 24.0)


func _status_text(status: StringName) -> String:
	match status:
		&"sold":
			return L10n.t("shop.sold")
		&"healthy":
			return L10n.t("shop.full_integrity")
		&"funds":
			return L10n.t("shop.insufficient")
		_:
			return L10n.t("shop.preview.available")


func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override(&"font_size", font_size)
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
