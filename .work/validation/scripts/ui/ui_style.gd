extends RefCounted

const asset_catalog: GDScript = preload("res://scripts/visual/lahoue_asset_catalog.gd")

const color_success: Color = Color("#4f8a4c")
const color_info: Color = Color("#426f9b")
const color_warning: Color = Color("#a2672f")
const color_locked: Color = Color("#9a4d43")
const color_premium: Color = Color("#8a6828")
const color_muted: Color = Color("#746b60")
const modal_margin: Vector2 = Vector2(32.0, 180.0)


static func fit_centered_modal(panel: Control, viewport_size: Vector2, preferred_size: Vector2) -> void:
	if panel == null:
		return
	var available: Vector2 = Vector2(
		maxf(viewport_size.x - modal_margin.x, 320.0),
		maxf(viewport_size.y - modal_margin.y, 300.0)
	)
	var fitted: Vector2 = Vector2(minf(preferred_size.x, available.x), minf(preferred_size.y, available.y))
	panel.custom_minimum_size = Vector2.ZERO
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -fitted.x * 0.5
	panel.offset_right = fitted.x * 0.5
	panel.offset_top = -fitted.y * 0.5
	panel.offset_bottom = fitted.y * 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.clip_contents = true
	panel.set_meta("responsive_size", fitted)
	panel.set_meta("responsive_viewport", viewport_size)


static func make_card(variation: StringName = &"Card") -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = variation
	return card


static func make_icon_slot(kind: String, compact: bool = false) -> PanelContainer:
	var semantic_id: String = asset_catalog.get_bound_id("gameplay_icons", kind.to_lower())
	var texture: Texture2D = asset_catalog.get_ui_texture("gameplay_icons", semantic_id)
	return _make_texture_slot(texture, "icon_%s" % kind.to_lower(), compact, _icon_glyph(kind))


static func make_item_icon_slot(item_id: String, context: String = "inventory", compact: bool = false) -> PanelContainer:
	var texture: Texture2D = asset_catalog.get_item_texture(item_id, context)
	return _make_texture_slot(texture, "item_icon_%s" % item_id, compact, item_id.left(4).to_upper())


static func make_dish_icon_slot(recipe_id: String, compact: bool = false) -> PanelContainer:
	var texture: Texture2D = asset_catalog.get_dish_texture(recipe_id)
	return _make_texture_slot(texture, "dish_icon_%s" % recipe_id, compact, "DISH")


static func make_ui_icon_slot(category_id: String, semantic_id: String, compact: bool = false) -> PanelContainer:
	var texture: Texture2D = asset_catalog.get_ui_texture(category_id, semantic_id)
	return _make_texture_slot(texture, "%s_%s" % [category_id, semantic_id], compact, semantic_id.left(4).to_upper())


static func make_atlas_icon_slot(atlas_id: String, semantic_id: String, compact: bool = false) -> PanelContainer:
	var texture: Texture2D = asset_catalog.get_atlas_texture(atlas_id, semantic_id)
	return _make_texture_slot(texture, "%s_%s" % [atlas_id, semantic_id], compact, semantic_id.left(4).to_upper())


static func make_achievement_icon_slot(achievement_id: String, compact: bool = false) -> PanelContainer:
	var semantic_id: String = asset_catalog.get_bound_id("achievement_badges", achievement_id)
	return make_atlas_icon_slot("achievement_badges_and_emblems_sheet", semantic_id, compact)


static func make_money_icon_slot(amount: int, compact: bool = false) -> PanelContainer:
	var denomination: int = 10000
	for candidate: int in [10000, 20000, 50000, 100000, 200000, 500000]:
		if amount >= candidate:
			denomination = candidate
	var semantic_id: String = "vnd_%d" % denomination
	return make_ui_icon_slot("money_icons", semantic_id, compact)


static func _make_texture_slot(
	texture: Texture2D,
	node_name: String,
	compact: bool,
	fallback_text: String
) -> PanelContainer:
	var slot: PanelContainer = PanelContainer.new()
	slot.name = node_name.validate_node_name()
	slot.theme_type_variation = &"IconSlot"
	slot.custom_minimum_size = Vector2(28.0 if compact else 36.0, 28.0 if compact else 36.0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		return slot
	var glyph: Label = Label.new()
	glyph.text = fallback_text
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 10 if compact else 11)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(glyph)
	return slot


static func make_status_label(text: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func status_variation(reason: String) -> StringName:
	if reason == "MAX LEVEL" or reason == "Ready" or reason == "Available to Purchase":
		return &"StatusSuccess"
	if reason.begins_with("Requires Level") or reason.begins_with("Locked"):
		return &"StatusLocked"
	if reason == "Not Enough Money" or reason.contains("full") or reason.contains("Unpaid"):
		return &"StatusWarning"
	return &"StatusInfo"


static func _icon_glyph(kind: String) -> String:
	match kind.to_lower():
		"money": return "VNĐ"
		"exp": return "EXP"
		"warehouse": return "WH"
		"crop": return "CR"
		"animal": return "AN"
		"layer_chicken": return "EGG"
		"meat_chicken": return "MEAT"
		"seafood": return "SEA"
		"restaurant": return "RST"
		"staff": return "STF"
		"truck": return "TRK"
		"helicopter": return "HEL"
		"vip": return "VIP"
		"resort": return "RES"
		"premium": return "PREM"
		"achievement": return "★"
	return kind.left(4).to_upper()
