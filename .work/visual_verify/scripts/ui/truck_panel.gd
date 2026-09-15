extends PanelContainer

const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")
const ui_style: GDScript = preload("res://scripts/ui/ui_style.gd")

var truck_mgr: Node = null
var ui_mgr: Node = null
var list_container: VBoxContainer
var truck_status_container: VBoxContainer
var info_label: Label
var update_timer: float = 0.0
var cargo_container: VBoxContainer
var cargo_draft: Dictionary = {}

func _ready() -> void:
    visible = false
    process_mode = PROCESS_MODE_ALWAYS
    _build_ui()

func _process(delta: float) -> void:
    if not visible or truck_mgr == null:
        return
    update_timer += delta
    if update_timer >= 0.5:
        update_timer = 0.0
        _refresh_truck_status()

func set_truck_manager(mgr: Node) -> void:
    truck_mgr = mgr

func set_ui_manager(mgr: Node) -> void:
    ui_mgr = mgr

func refresh() -> void:
    if truck_mgr == null:
        return
    info_label.text = "Select Cargo • Review Load and Expected Revenue • Confirm Shipment"
    _refresh_items()
    _refresh_truck_status()

func _build_ui() -> void:
    custom_minimum_size = Vector2.ZERO
    anchor_left = 0.5
    anchor_right = 0.5
    anchor_top = 0.5
    anchor_bottom = 0.5
    offset_left = -290
    offset_right = 290
    offset_top = -240
    offset_bottom = 240
    
    var main_style: StyleBoxFlat = StyleBoxFlat.new()
    main_style.bg_color = Color(0.96, 0.93, 0.87, 0.97)
    main_style.corner_radius_top_left = 12
    main_style.corner_radius_top_right = 12
    main_style.corner_radius_bottom_left = 12
    main_style.corner_radius_bottom_right = 12
    main_style.content_margin_left = 20.0
    main_style.content_margin_top = 20.0
    main_style.content_margin_right = 20.0
    main_style.content_margin_bottom = 20.0
    add_theme_stylebox_override("panel", main_style)
    
    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 4)
    margin.add_theme_constant_override("margin_top", 4)
    margin.add_theme_constant_override("margin_right", 4)
    margin.add_theme_constant_override("margin_bottom", 4)
    add_child(margin)
    
    var vbox: VBoxContainer = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 12)
    margin.add_child(vbox)
    
    # Header
    var header: HBoxContainer = HBoxContainer.new()
    vbox.add_child(header)
    header.add_child(ui_style.make_icon_slot("truck"))
    
    var title: Label = Label.new()
    title.text = "TRUCK DELIVERY"
    title.theme_type_variation = &"PanelTitle"
    title.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1))
    title.size_flags_horizontal = SIZE_EXPAND_FILL
    header.add_child(title)
    
    var close_btn: Button = Button.new()
    close_btn.text = "Close (ESC)"
    close_btn.pressed.connect(_on_close_pressed)
    header.add_child(close_btn)
    
    # Info line
    info_label = Label.new()
    info_label.add_theme_font_size_override("font_size", 14)
    info_label.add_theme_color_override("font_color", Color(0.35, 0.3, 0.25))
    vbox.add_child(info_label)
    
    # Split: left = items, right = truck status
    var hsplit: HSplitContainer = HSplitContainer.new()
    hsplit.size_flags_vertical = SIZE_EXPAND_FILL
    vbox.add_child(hsplit)
    
    # Left: sellable items and cargo draft
    var left_vbox: VBoxContainer = VBoxContainer.new()
    left_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
    left_vbox.custom_minimum_size = Vector2(330, 0)
    hsplit.add_child(left_vbox)

    var left_scroll: ScrollContainer = ScrollContainer.new()
    left_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
    left_scroll.size_flags_vertical = SIZE_EXPAND_FILL
    left_vbox.add_child(left_scroll)
    
    list_container = VBoxContainer.new()
    list_container.size_flags_horizontal = SIZE_EXPAND_FILL
    list_container.add_theme_constant_override("separation", 6)
    left_scroll.add_child(list_container)
    
    var hsep = HSeparator.new()
    left_vbox.add_child(hsep)
    
    cargo_container = VBoxContainer.new()
    cargo_container.size_flags_horizontal = SIZE_EXPAND_FILL
    left_vbox.add_child(cargo_container)
    
    # Right: truck status
    var right_panel: PanelContainer = PanelContainer.new()
    right_panel.custom_minimum_size = Vector2(260, 0)
    var right_style: StyleBoxFlat = StyleBoxFlat.new()
    right_style.bg_color = Color(0.92, 0.89, 0.83, 0.6)
    right_style.corner_radius_top_left = 8
    right_style.corner_radius_top_right = 8
    right_style.corner_radius_bottom_left = 8
    right_style.corner_radius_bottom_right = 8
    right_style.content_margin_left = 12.0
    right_style.content_margin_top = 12.0
    right_style.content_margin_right = 12.0
    right_style.content_margin_bottom = 12.0
    right_panel.add_theme_stylebox_override("panel", right_style)
    hsplit.add_child(right_panel)
    
    truck_status_container = VBoxContainer.new()
    truck_status_container.add_theme_constant_override("separation", 8)
    right_panel.add_child(truck_status_container)

func _refresh_items() -> void:
    for child in list_container.get_children():
        child.queue_free()
    
    var items: Dictionary = inventory_manager.items.duplicate(true)
    if items.is_empty():
        var empty_lbl: Label = Label.new()
        empty_lbl.text = "No items to sell."
        empty_lbl.add_theme_font_size_override("font_size", 14)
        empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
        list_container.add_child(empty_lbl)
    else:
        var sorted_keys: Array = items.keys()
        sorted_keys.sort()
        for item_id_value in sorted_keys:
            var item_id: String = String(item_id_value)
            var amount: int = int(items[item_id_value])
            var drafted: int = int(cargo_draft.get(item_id, 0))
            amount -= drafted
            if amount <= 0: continue
            
            var sell_price: int = data_manager.get_item_sell_price(item_id)
            if sell_price <= 0: continue
            
            var row: HBoxContainer = HBoxContainer.new()
            row.add_theme_constant_override("separation", 6)
            list_container.add_child(row)
            
            var name_lbl: Label = Label.new()
            name_lbl.text = data_manager.get_item_display_name(item_id)
            name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
            name_lbl.add_theme_font_size_override("font_size", 13)
            name_lbl.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1))
            row.add_child(name_lbl)
            
            var count_lbl: Label = Label.new()
            count_lbl.text = "x%d" % amount
            count_lbl.add_theme_font_size_override("font_size", 13)
            count_lbl.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
            row.add_child(count_lbl)
            
            var price_lbl: Label = Label.new()
            price_lbl.text = vnd_format.format_vnd(sell_price)
            price_lbl.add_theme_font_size_override("font_size", 12)
            price_lbl.add_theme_color_override("font_color", Color(0.3, 0.5, 0.3))
            row.add_child(price_lbl)
            
            var sell1_btn: Button = Button.new()
            sell1_btn.text = "Sell 1"
            sell1_btn.add_theme_font_size_override("font_size", 11)
            sell1_btn.pressed.connect(_on_draft_add.bind(item_id, 1))
            row.add_child(sell1_btn)
            
            if amount > 1:
                var sell_all_btn: Button = Button.new()
                sell_all_btn.text = "Sell All"
                sell_all_btn.add_theme_font_size_override("font_size", 11)
                sell_all_btn.pressed.connect(_on_draft_add.bind(item_id, amount))
                row.add_child(sell_all_btn)

    _refresh_cargo_draft()

func get_cargo_total_amount() -> int:
    var total: int = 0
    for v in cargo_draft.values():
        total += int(v)
    return total

func get_cargo_expected_revenue() -> int:
    var total: int = 0
    for k in cargo_draft.keys():
        var sell_price: int = data_manager.get_item_sell_price(String(k))
        total += sell_price * int(cargo_draft[k])
    return total

func _on_draft_add(item_id: String, amount: int) -> void:
    var capacity: int = 20
    if truck_mgr.has_method("get_truck_capacity"):
        capacity = int(truck_mgr.call("get_truck_capacity"))
    var current_total: int = get_cargo_total_amount()
    var space_left: int = capacity - current_total
    
    if space_left <= 0:
        _show_notification("Truck capacity full")
        return
        
    var added = min(amount, space_left)
    cargo_draft[item_id] = int(cargo_draft.get(item_id, 0)) + added
    refresh()

func _refresh_cargo_draft() -> void:
    for child in cargo_container.get_children():
        child.queue_free()
        
    var title: Label = Label.new()
    title.text = "Selected Cargo"
    title.add_theme_font_size_override("font_size", 14)
    title.add_theme_color_override("font_color", Color(0.2, 0.25, 0.4))
    cargo_container.add_child(title)
    
    if cargo_draft.is_empty():
        var empty_lbl: Label = Label.new()
        empty_lbl.text = "Draft is empty"
        empty_lbl.add_theme_font_size_override("font_size", 12)
        cargo_container.add_child(empty_lbl)
        return
        
    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0, 80)
    cargo_container.add_child(scroll)
    
    var draft_list = VBoxContainer.new()
    scroll.add_child(draft_list)
    
    for item_id_val in cargo_draft:
        var item_id: String = String(item_id_val)
        var qty: int = int(cargo_draft[item_id])
        var sp: int = data_manager.get_item_sell_price(item_id)
        
        var row = HBoxContainer.new()
        draft_list.add_child(row)
        
        var n_lbl = Label.new()
        n_lbl.text = data_manager.get_item_display_name(item_id) + " x" + str(qty)
        n_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
        n_lbl.add_theme_font_size_override("font_size", 12)
        row.add_child(n_lbl)
        
        var p_lbl = Label.new()
        p_lbl.text = vnd_format.format_vnd(sp * qty)
        p_lbl.add_theme_font_size_override("font_size", 12)
        row.add_child(p_lbl)
        
    var cap: int = 20
    if truck_mgr.has_method("get_truck_capacity"):
        cap = int(truck_mgr.call("get_truck_capacity"))
        
    var sum_lbl = Label.new()
    sum_lbl.text = "Load: %d / %d\nExpected Revenue: %s" % [get_cargo_total_amount(), cap, vnd_format.format_vnd(get_cargo_expected_revenue())]
    sum_lbl.add_theme_font_size_override("font_size", 13)
    cargo_container.add_child(sum_lbl)
    
    var btn_row = HBoxContainer.new()
    cargo_container.add_child(btn_row)
    
    var confirm_btn = Button.new()
    confirm_btn.text = "Confirm Shipment"
    confirm_btn.size_flags_horizontal = SIZE_EXPAND_FILL
    confirm_btn.pressed.connect(_on_confirm_shipment)
    btn_row.add_child(confirm_btn)
    
    var clear_btn = Button.new()
    clear_btn.text = "Clear"
    clear_btn.pressed.connect(_on_clear_cargo)
    btn_row.add_child(clear_btn)

func _on_clear_cargo() -> void:
    cargo_draft.clear()
    refresh()

func _on_confirm_shipment() -> void:
    if cargo_draft.is_empty():
        return
    if not bool(truck_mgr.call("has_available_truck")):
        _show_notification("Shipment active")
        return
        
    var cap: int = 20
    if truck_mgr.has_method("get_truck_capacity"):
        cap = int(truck_mgr.call("get_truck_capacity"))
        
    if get_cargo_total_amount() > cap:
        _show_notification("Truck capacity full")
        return
        
    if bool(truck_mgr.call("dispatch_multiple", cargo_draft)):
        _show_notification("Shipment confirmed")
        cargo_draft.clear()
        refresh()
    else:
        _show_notification("Cannot dispatch")

func _refresh_truck_status() -> void:
    for child in truck_status_container.get_children():
        child.queue_free()
    
    if truck_mgr == null:
        return
    
    # Header
    var header_lbl: Label = Label.new()
    header_lbl.text = "Truck Lv%d" % int(truck_mgr.get("truck_level"))
    header_lbl.add_theme_font_size_override("font_size", 16)
    header_lbl.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1))
    truck_status_container.add_child(header_lbl)
    
    var delivery_time_lbl: Label = Label.new()
    delivery_time_lbl.text = "Delivery: %ds" % int(truck_mgr.call("get_delivery_time"))
    delivery_time_lbl.add_theme_font_size_override("font_size", 12)
    delivery_time_lbl.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
    truck_status_container.add_child(delivery_time_lbl)
    
    var capacity: int = 20
    if truck_mgr.has_method("get_truck_capacity"):
        capacity = int(truck_mgr.call("get_truck_capacity"))
        
    var cap_lbl: Label = Label.new()
    cap_lbl.text = "Capacity: %d" % capacity
    cap_lbl.add_theme_font_size_override("font_size", 12)
    cap_lbl.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
    truck_status_container.add_child(cap_lbl)
    
    # Each truck
    var truck_count: int = int(truck_mgr.get("truck_count"))
    var max_trucks: int = int(truck_mgr.get("max_trucks"))
    
    for i in range(max_trucks):
        var truck_lbl: Label = Label.new()
        truck_lbl.add_theme_font_size_override("font_size", 13)
        
        if i >= truck_count:
            truck_lbl.text = "Truck %d — Locked" % (i + 1)
            truck_lbl.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
        elif truck_mgr.call("is_truck_delivering", i):
            var remaining: float = float(truck_mgr.call("get_truck_remaining", i))
            var amount: int = 0
            var phase: String = "Delivering"
            if truck_mgr.has_method("get_truck_amount"):
                amount = int(truck_mgr.call("get_truck_amount", i))
            if truck_mgr.has_method("get_truck_phase"):
                phase = String(truck_mgr.call("get_truck_phase", i))
            
            var display_rem: int = ceili(remaining)
            if remaining <= 0.0:
                var travel_time: float = 0.0
                if truck_mgr.has_method("get_visual_travel_time"):
                    travel_time = float(truck_mgr.call("get_visual_travel_time"))
                display_rem = ceili(travel_time + remaining)
                if display_rem < 0:
                    display_rem = 0
            truck_lbl.text = "Truck %d — %s — %d/%d — %ds" % [i + 1, phase, amount, capacity, display_rem]
            truck_lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 0.2))
        else:
            truck_lbl.text = "Truck %d — Ready — 0/%d" % [i + 1, capacity]
            truck_lbl.add_theme_color_override("font_color", Color(0.2, 0.6, 0.3))
        
        truck_status_container.add_child(truck_lbl)

    var hsep2 = HSeparator.new()
    truck_status_container.add_child(hsep2)
    
    var truck_level: int = int(truck_mgr.get("truck_level"))
    var max_level: int = int(truck_mgr.call("get_max_truck_level"))
    if truck_level < max_level:
        var upg_cost: int = 0
        if truck_mgr.has_method("get_upgrade_cost"):
            upg_cost = int(truck_mgr.call("get_upgrade_cost"))
        
        var progression: Dictionary = data_manager.get_dataset("progression")
        var levels: Dictionary = ((progression.get("truck", {}) as Dictionary).get("levels", {}) as Dictionary)
        var current_data: Dictionary = levels.get(str(truck_level), {}) as Dictionary
        var next_data: Dictionary = levels.get(str(truck_level + 1), {}) as Dictionary
        var required_level: int = int(next_data.get("required_player_level", 0))
        var benefits: Label = Label.new()
        benefits.text = "Next Lv%d: Capacity %d → %d | Delivery %ds → %ds" % [
            truck_level + 1,
            int(current_data.get("capacity", 0)), int(next_data.get("capacity", 0)),
            int(current_data.get("delivery_time", 0)), int(next_data.get("delivery_time", 0)),
        ]
        benefits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        benefits.theme_type_variation = &"StatusInfo"
        truck_status_container.add_child(benefits)
        var reason: String = "Ready"
        if game_manager.level < required_level:
            reason = "Requires Level %d" % required_level
        elif not game_manager.can_afford(upg_cost):
            reason = "Not Enough Money"
        var reason_label: Label = ui_style.make_status_label(reason, ui_style.status_variation(reason))
        truck_status_container.add_child(reason_label)
        var upg_btn: Button = Button.new()
        upg_btn.name = "upgrade_truck_button"
        upg_btn.text = "Upgrade Lv%d — %s" % [truck_level + 1, vnd_format.format_vnd(upg_cost)]
        upg_btn.disabled = not bool(truck_mgr.call("can_upgrade_truck"))
        upg_btn.pressed.connect(_on_upgrade_truck)
        truck_status_container.add_child(upg_btn)
    else:
        truck_status_container.add_child(ui_style.make_status_label("MAX LEVEL", &"StatusSuccess"))
        
    if truck_count < max_trucks:
        var buy_cost: int = 0
        if truck_mgr.has_method("get_buy_truck_cost"):
            buy_cost = int(truck_mgr.call("get_buy_truck_cost"))
            
        var buy_btn: Button = Button.new()
        buy_btn.text = "Buy Truck #%d — %s" % [truck_count + 1, vnd_format.format_vnd(buy_cost)]
        buy_btn.disabled = not bool(truck_mgr.call("can_buy_truck"))
        buy_btn.pressed.connect(_on_buy_truck)
        truck_status_container.add_child(buy_btn)
        if buy_btn.disabled:
            var buy_reason: String = "Not Enough Money" if not game_manager.can_afford(buy_cost) else "Unavailable"
            truck_status_container.add_child(ui_style.make_status_label(buy_reason, ui_style.status_variation(buy_reason)))


func _on_upgrade_truck() -> void:
    if truck_mgr == null:
        return
    if bool(truck_mgr.call("upgrade_truck")):
        _show_notification("Truck upgraded!")
        refresh()
    else:
        _show_notification("Truck upgrade unavailable — check required level and money")

func _on_buy_truck() -> void:
    if truck_mgr == null:
        return
    if bool(truck_mgr.call("buy_truck")):
        _show_notification("New truck purchased!")
        refresh()
    else:
        _show_notification("Cannot buy Truck — Not Enough Money")

func _on_close_pressed() -> void:
    cargo_draft.clear()
    if ui_mgr != null and ui_mgr.has_method("_close_active_panel"):
        ui_mgr.call("_close_active_panel")
    else:
        visible = false

func _show_notification(msg: String) -> void:
    if ui_mgr != null:
        var notif: Node = ui_mgr.get("notification_node")
        if notif != null and notif.has_method("show_notification"):
            notif.call("show_notification", msg, "info")
