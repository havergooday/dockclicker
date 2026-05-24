extends Control

@onready var back_button: Button = $Header/BackButton
@onready var shop_tab_btn: Button = $TabBar/ShopTabBtn
@onready var inventory_tab_btn: Button = $TabBar/InventoryTabBtn
@onready var shop_scroll: ScrollContainer = $ShopScroll
@onready var inventory_scroll: ScrollContainer = $InventoryScroll
@onready var content_vbox: VBoxContainer = $ShopScroll/ContentVBox
@onready var inventory_vbox: VBoxContainer = $InventoryScroll/InventoryVBox

var _damage_info: Label
var _upgrade_btn: Button
var _part_buttons: Dictionary = {}   # "type_tier" -> Button
var _stock_labels: Dictionary = {}   # "type_tier" -> Label
var _inventory_content: VBoxContainer

func _ready() -> void:
	PanelManager.register_panel("shop", self)
	back_button.pressed.connect(func(): PanelManager.show_bridge())
	shop_tab_btn.pressed.connect(_show_shop_tab)
	inventory_tab_btn.pressed.connect(_show_inventory_tab)
	GameState.credits_changed.connect(func(_v): _refresh())
	GameState.planet_unlocked.connect(func(_id): _refresh())
	GameState.part_purchased.connect(func(_pt, _t): _refresh_inventory())
	_build_shop_ui()
	_build_inventory_ui()
	_refresh()

func _show_shop_tab() -> void:
	shop_scroll.visible = true
	inventory_scroll.visible = false

func _show_inventory_tab() -> void:
	shop_scroll.visible = false
	inventory_scroll.visible = true

# ── 상점 탭 ──────────────────────────────

func _build_shop_ui() -> void:
	_build_damage_section()
	content_vbox.add_child(HSeparator.new())
	for part_type in ["pilot", "body", "weapon", "legs"]:
		_build_part_section(part_type)

func _build_damage_section() -> void:
	var header := Label.new()
	header.text = "── 클릭 강화 ──"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(header)

	_damage_info = Label.new()
	_damage_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(_damage_info)

	_upgrade_btn = Button.new()
	_upgrade_btn.custom_minimum_size = Vector2(0, 36)
	_upgrade_btn.pressed.connect(func(): GameState.upgrade_click_damage())
	content_vbox.add_child(_upgrade_btn)

func _build_part_section(part_type: String) -> void:
	var data: Dictionary = GameState.PARTS[part_type]

	var header := Label.new()
	header.text = "── %s ──" % data["name"]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(header)

	var tiers: Array = data["tiers"]
	for i in tiers.size():
		var tier: int = i + 1
		var tier_data: Dictionary = tiers[i]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		content_vbox.add_child(row)

		var lv_lbl := Label.new()
		lv_lbl.text = "Lv.%d" % tier
		lv_lbl.custom_minimum_size = Vector2(32, 0)
		row.add_child(lv_lbl)

		var name_lbl := Label.new()
		name_lbl.text = tier_data["name"]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var effect_lbl := Label.new()
		effect_lbl.text = data["effect"] % tier_data["value"]
		effect_lbl.custom_minimum_size = Vector2(80, 0)
		effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(effect_lbl)

		var stock_lbl := Label.new()
		stock_lbl.custom_minimum_size = Vector2(32, 0)
		stock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(stock_lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 30)
		row.add_child(btn)

		_part_buttons["%s_%d" % [part_type, tier]] = btn
		_stock_labels["%s_%d" % [part_type, tier]] = stock_lbl

		var pt := part_type
		var t: int = tier
		btn.pressed.connect(func(): GameState.buy_part(pt, t))

	content_vbox.add_child(HSeparator.new())

# ── 보유 파츠 탭 ─────────────────────────

func _build_inventory_ui() -> void:
	var title := Label.new()
	title.text = "── 보유 파츠 ──"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_vbox.add_child(title)

	inventory_vbox.add_child(HSeparator.new())

	_inventory_content = VBoxContainer.new()
	_inventory_content.add_theme_constant_override("separation", 4)
	inventory_vbox.add_child(_inventory_content)

# ── refresh ──────────────────────────────

func _refresh() -> void:
	_refresh_damage()
	_refresh_parts()
	_refresh_inventory()

func _refresh_damage() -> void:
	var level := GameState.damage_upgrade_level
	var damage := GameState.click_damage
	_damage_info.text = "클릭 데미지: %d  (강화 %d/%d)" % [damage, level, GameState.DAMAGE_UPGRADE_COSTS.size()]
	var cost := GameState.get_damage_upgrade_cost()
	if cost < 0:
		_upgrade_btn.text = "최대 강화 달성"
		_upgrade_btn.disabled = true
	else:
		_upgrade_btn.text = "데미지 강화  +1  (%d CR)" % cost
		_upgrade_btn.disabled = GameState.total_credits < cost

func _refresh_parts() -> void:
	for part_type in ["pilot", "body", "weapon", "legs"]:
		var tiers: Array = GameState.PARTS[part_type]["tiers"]
		for i in tiers.size():
			var tier := i + 1
			var key := "%s_%d" % [part_type, tier]
			var btn: Button = _part_buttons.get(key)
			var stock_lbl: Label = _stock_labels.get(key)
			if btn == null:
				continue

			var qty: int = GameState.get_owned_qty(part_type, tier)
			if stock_lbl:
				stock_lbl.text = "×%d" % qty

			var tier_data: Dictionary = tiers[i]
			var req: String = tier_data.get("required_planet", "")
			if req != "" and not GameState.is_planet_unlocked(req):
				btn.text = "행성 미해금"
				btn.disabled = true
			else:
				btn.text = "%d CR" % tier_data["cost"]
				btn.disabled = GameState.total_credits < tier_data["cost"]

func _refresh_inventory() -> void:
	for child in _inventory_content.get_children():
		child.queue_free()

	var has_any := false
	for part_type in ["pilot", "body", "weapon", "legs"]:
		var data: Dictionary = GameState.PARTS[part_type]
		var qtys: Array = GameState.owned_parts[part_type]

		for i in qtys.size():
			for _j in qtys[i]:
				has_any = true
				var td: Dictionary = data["tiers"][i]
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)

				var tag := Label.new()
				tag.text = data["name"]
				tag.custom_minimum_size = Vector2(44, 0)
				tag.modulate = Color(1, 1, 1, 0.6)
				row.add_child(tag)

				var name_lbl := Label.new()
				name_lbl.text = "Lv.%d  %s" % [i + 1, td["name"]]
				name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(name_lbl)

				var effect_lbl := Label.new()
				effect_lbl.text = data["effect"] % td["value"]
				effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				row.add_child(effect_lbl)

				_inventory_content.add_child(row)

	if not has_any:
		var none_lbl := Label.new()
		none_lbl.text = "보유한 파츠 없음"
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_lbl.modulate = Color(1, 1, 1, 0.5)
		_inventory_content.add_child(none_lbl)
