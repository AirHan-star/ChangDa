class_name GearPanels
extends Control

signal panel_requested(panel: int)
signal craft_requested(tool: int)
signal equip_requested(tool: int)
signal ration_requested
signal travel_requested(map_id: int)
signal station_requested(station: int)

enum PanelKind { NONE, CRAFT, BAG, TRAVEL, JOURNAL }

const RESOURCE_NAMES := SupplyRules.ITEMS
const TOOL_NAMES := SupplyRules.TOOLS
const RESOURCE_ICONS: Array[Texture2D] = [
	preload("res://assets/icons/wood.png"),
	preload("res://assets/icons/ration.png"),
	preload("res://assets/icons/stone.png"),
	preload("res://assets/icons/iron-ore.png"), preload("res://assets/icons/sulfur.png"),
	preload("res://assets/icons/iron.png"), preload("res://assets/icons/powder.png"),
	preload("res://assets/icons/ammo.png"),
]
const TOOL_ICONS: Array[Texture2D] = [
	preload("res://assets/icons/wood-pick.png"),
	preload("res://assets/icons/stone-pick.png"),
	preload("res://assets/icons/stone-sword.png"),
	preload("res://assets/icons/iron-pick.png"), preload("res://assets/icons/iron-axe.png"),
	preload("res://assets/icons/carbine.png"),
]

var active_panel: int = PanelKind.NONE
var _overlay: ColorRect
var _title: Label
var _craft_list: VBoxContainer
var _bag: VBoxContainer
var _travel: VBoxContainer
var _journal: VBoxContainer
var _travel_options: Array[Button] = []
var _reading: Label
var _craft_context: Label
var _recipe_rows: Array[Control] = []
var _ammo: Label
var _quick_counts: Array[Label] = []
var _bag_counts: Array[Label] = []
var _tools: Array[Button] = []
var _craft_buttons: Array[Button] = []
var _ration_button: Button
var _normal := _box(Color("#172624"), Color("#354642"), 7)
var _hover := _box(Color("#263a35"), Color("#8bae93"), 7)
var _equipped := _box(Color("#253f35"), Color("#a8cba3"), 7)
var _disabled := _box(Color("#182320"), Color("#283631"), 7)


func _ready() -> void:
	_build_shortcuts()
	_build_overlay()


func show_panel(panel: int) -> void:
	active_panel = panel
	_overlay.visible = panel != PanelKind.NONE
	_craft_list.visible = panel == PanelKind.CRAFT
	_bag.visible = panel == PanelKind.BAG
	_travel.visible = panel == PanelKind.TRAVEL
	_journal.visible = panel == PanelKind.JOURNAL
	_title.text = ["", "合成", "背包", "中继传送", "余讯记录"][panel]


func refresh(rules: SupplyRules, equipped_tool: int) -> void:
	for i in range(RESOURCE_NAMES.size()):
		var number := str(rules.carried(i))
		if is_instance_valid(_quick_counts[i]):
			_quick_counts[i].text = number
		_bag_counts[i].text = number
	for i in range(TOOL_NAMES.size()):
		var owned := rules.has_tool(i)
		_bag_counts[RESOURCE_NAMES.size() + i].text = "1" if owned else "0"
		var tool := _tools[i]
		tool.disabled = not owned
		tool.add_theme_stylebox_override(&"normal", _equipped if equipped_tool == i else _normal)
		tool.tooltip_text = "已装备" if equipped_tool == i else ("点击装备" if owned else "未拥有")
	_ammo.text = "弹药  %d" % rules.carried(SupplyRules.Kind.AMMO)
	_ammo.visible = equipped_tool == SupplyRules.Tool.CARBINE


func craft_context(station: int, rules: SupplyRules, available: Callable, hint: String) -> void:
	_craft_context.text = hint
	for id in range(SupplyRules.RECIPES.size()):
		var data: Array = SupplyRules.RECIPES[id]
		var button := _craft_buttons[id]
		_recipe_rows[id].visible = data[1] == station
		button.disabled = not available.call(id)
		button.text = "已拥有" if rules.recipe_owned(id) else ("制作" if not button.disabled else "不可制作")


func travel_context(story: RelayStory, current: int) -> void:
	for i in range(_travel_options.size()):
		var button := _travel_options[i]
		button.disabled = i == current or not story.unlocked(i)
		var status := "当前位置" if i == current else ("前往" if story.unlocked(i) else "主线未开放")
		button.text = "%s     ·     %s" % [RelayStory.MAP_NAMES[i], status]


func journal(text: String) -> void:
	_reading.text = text


func set_ration_available(available: bool) -> void:
	_ration_button.disabled = not available


func _build_shortcuts() -> void:
	var dock := VBoxContainer.new()
	add_child(dock)
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	dock.offset_left = -186
	dock.offset_top = -114
	dock.offset_right = -24
	dock.offset_bottom = -22
	dock.alignment = BoxContainer.ALIGNMENT_END
	dock.add_theme_constant_override(&"separation", 6)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ammo = _label("弹药", 18)
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo.hide()
	dock.add_child(_ammo)
	var quantities := HBoxContainer.new()
	quantities.alignment = BoxContainer.ALIGNMENT_END
	quantities.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantities.add_theme_constant_override(&"separation", 5)
	dock.add_child(quantities)
	_quick_counts.resize(RESOURCE_NAMES.size())
	for kind in [SupplyRules.Kind.WOOD, SupplyRules.Kind.STONE, SupplyRules.Kind.CAN]:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(46, 37)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override(&"panel", _normal)
		var face := Control.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(face)
		var graphic := _icon(RESOURCE_ICONS[kind], 29)
		graphic.position = Vector2(3, 1)
		face.add_child(graphic)
		var count := _corner_count()
		face.add_child(count)
		_quick_counts[kind] = count
		quantities.add_child(slot)
	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_END
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.add_theme_constant_override(&"separation", 5)
	dock.add_child(keys)
	_shortcut(keys, "Tab", preload("res://assets/icons/craft.png"), "合成", PanelKind.CRAFT)
	_shortcut(keys, "B", preload("res://assets/icons/bag.png"), "背包", PanelKind.BAG)


func _shortcut(parent: HBoxContainer, text: String, art: Texture2D, tip: String, panel: int) -> void:
	var button := _button(text)
	button.custom_minimum_size = Vector2(71, 38)
	button.icon = art
	button.expand_icon = true
	button.add_theme_constant_override(&"icon_max_width", 23)
	button.tooltip_text = tip
	button.pressed.connect(func(): panel_requested.emit(panel))
	parent.add_child(button)


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.037, 0.059, 0.057, 0.67)
	_overlay.hide()
	var stage := CenterContainer.new()
	_overlay.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 558
	card.add_theme_stylebox_override(&"panel", _box(Color("#182523"), Color("#537069"), 11, 20))
	stage.add_child(card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 17)
	card.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	_title = _label("合成", 25)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := _button("Esc  关闭")
	close.custom_minimum_size = Vector2(98, 36)
	close.pressed.connect(func(): panel_requested.emit(PanelKind.NONE))
	header.add_child(close)
	_craft_list = VBoxContainer.new()
	_craft_list.add_theme_constant_override(&"separation", 8)
	body.add_child(_craft_list)
	_bag = VBoxContainer.new()
	_bag.add_theme_constant_override(&"separation", 10)
	body.add_child(_bag)
	_travel = VBoxContainer.new()
	_travel.add_theme_constant_override(&"separation", 10)
	body.add_child(_travel)
	_journal = VBoxContainer.new()
	body.add_child(_journal)
	_reading = _label("", 19)
	_reading.custom_minimum_size = Vector2(510, 180)
	_reading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_journal.add_child(_reading)
	for map_id in range(RelayStory.MAP_NAMES.size()):
		var destination := _button("")
		destination.custom_minimum_size.y = 47
		destination.pressed.connect(func(): travel_requested.emit(map_id))
		_travel.add_child(destination)
		_travel_options.append(destination)
	_build_recipes()
	_build_bag()
	show_panel(PanelKind.NONE)


func _build_recipes() -> void:
	var stations := HBoxContainer.new()
	stations.add_theme_constant_override(&"separation", 7)
	_craft_list.add_child(stations)
	for station in range(SupplyRules.STATIONS.size()):
		var tab := _button(SupplyRules.STATIONS[station])
		tab.custom_minimum_size.y = 36
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(func(): station_requested.emit(station))
		stations.add_child(tab)
	_craft_context = _label("", 14)
	_craft_context.modulate = Color("#bdc7a3")
	_craft_list.add_child(_craft_context)
	for id in range(SupplyRules.RECIPES.size()):
		var data: Array = SupplyRules.RECIPES[id]
		var shell := PanelContainer.new()
		shell.add_theme_stylebox_override(&"panel", _box(Color("#202f2b"), Color("#30443b"), 7, 7))
		_craft_list.add_child(shell)
		_recipe_rows.append(shell)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 13)
		shell.add_child(row)
		var texture := TOOL_ICONS[data[4]] if data[4] >= 0 else preload("res://assets/icons/craft.png")
		if not data[3].is_empty():
			texture = RESOURCE_ICONS[data[3].keys()[0]]
		row.add_child(_icon(texture, 36))
		var labels := VBoxContainer.new()
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(labels)
		labels.add_child(_label(data[0], 17))
		var ingredients := PackedStringArray()
		for kind in data[2]:
			ingredients.append("%s ×%d" % [RESOURCE_NAMES[kind], data[2][kind]])
		var cost := _label("  ·  ".join(ingredients), 14)
		cost.modulate = Color("#bdc7a3")
		labels.add_child(cost)
		var action := _button("制作")
		action.custom_minimum_size = Vector2(100, 36)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		action.pressed.connect(func(): craft_requested.emit(id))
		row.add_child(action)
		_craft_buttons.append(action)


func _build_bag() -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 9)
	grid.add_theme_constant_override(&"v_separation", 9)
	_bag.add_child(grid)
	for i in range(RESOURCE_NAMES.size() + TOOL_NAMES.size()):
		var is_tool := i >= RESOURCE_NAMES.size()
		var tool := i - RESOURCE_NAMES.size()
		var name: String = TOOL_NAMES[tool] if is_tool else RESOURCE_NAMES[i]
		var graphic := TOOL_ICONS[tool] if is_tool else RESOURCE_ICONS[i]
		var frame: Control
		if is_tool:
			var selector := _button("")
			selector.pressed.connect(func(): equip_requested.emit(tool))
			_tools.append(selector)
			frame = selector
		else:
			var slot := PanelContainer.new()
			slot.add_theme_stylebox_override(&"panel", _normal)
			frame = slot
		frame.custom_minimum_size = Vector2(121, 86)
		grid.add_child(frame)
		var face := Control.new()
		frame.add_child(face)
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var picture := _icon(graphic, 43)
		picture.position = Vector2(39, 7)
		face.add_child(picture)
		var description := _label(name, 14)
		description.position = Vector2(7, 61)
		face.add_child(description)
		var count := _corner_count()
		face.add_child(count)
		_bag_counts.append(count)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 12)
	_bag.add_child(footer)
	var hint := _label("点击工具装备", 14)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.modulate = Color("#bdc7a3")
	footer.add_child(hint)
	_ration_button = _button("食用罐头  [H]")
	_ration_button.icon = RESOURCE_ICONS[SupplyRules.Kind.CAN]
	_ration_button.expand_icon = true
	_ration_button.add_theme_constant_override(&"icon_max_width", 25)
	_ration_button.custom_minimum_size = Vector2(148, 36)
	_ration_button.pressed.connect(func(): ration_requested.emit())
	footer.add_child(_ration_button)


func _corner_count() -> Label:
	var count := _label("0", 15)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -31
	count.offset_top = -23
	count.offset_right = -5
	count.offset_bottom = -2
	count.add_theme_color_override(&"font_outline_color", Color("#10201d"))
	count.add_theme_constant_override(&"outline_size", 5)
	return count


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override(&"normal", _normal)
	button.add_theme_stylebox_override(&"hover", _hover)
	button.add_theme_stylebox_override(&"pressed", _equipped)
	button.add_theme_stylebox_override(&"disabled", _disabled)
	button.add_theme_color_override(&"font_disabled_color", Color("#88958b"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _icon(texture: Texture2D, size: int) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.custom_minimum_size = Vector2(size, size)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


func _box(fill: Color, border: Color, radius: int, inset := 0) -> StyleBoxFlat:
	var shell := StyleBoxFlat.new()
	shell.bg_color = fill
	shell.border_color = border
	shell.set_border_width_all(1)
	shell.set_corner_radius_all(radius)
	shell.content_margin_left = inset
	shell.content_margin_right = inset
	shell.content_margin_top = inset
	shell.content_margin_bottom = inset
	return shell
