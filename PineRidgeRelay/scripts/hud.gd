extends CanvasLayer

const ACCENT := Color("#efbf75")
const MINT := Color("#a6e0b8")

@onready var mission: Label = $Screen/Brief/Content/Mission
@onready var route: Label = $Screen/Brief/Content/Route
@onready var inventory: Label = $Screen/Inventory/Content/Carried
@onready var deposited: Label = $Screen/Inventory/Content/Stored
@onready var prompt_panel: PanelContainer = $Screen/Prompt
@onready var prompt_label: Label = $Screen/Prompt/Text


func show_supplies(rules: SupplyRules) -> void:
	var wood := rules.carried(SupplyRules.Kind.WOOD)
	var cans := rules.carried(SupplyRules.Kind.CAN)
	var stored_wood := rules.stored(SupplyRules.Kind.WOOD)
	var stored_cans := rules.stored(SupplyRules.Kind.CAN)
	inventory.text = "木料 %d     罐头 %d" % [wood, cans]
	deposited.text = "已存入   木料 %d / %d     罐头 %d / %d" % [
		stored_wood, SupplyRules.WOOD_TARGET, stored_cans, SupplyRules.CAN_TARGET
	]

	if rules.is_complete():
		mission.text = "补给任务完成"
		mission.add_theme_color_override(&"font_color", MINT)
		route.text = "物资已存入气象站的补给箱。"
	elif wood + stored_wood >= SupplyRules.WOOD_TARGET and cans + stored_cans >= SupplyRules.CAN_TARGET:
		mission.text = "返回气象站"
		mission.add_theme_color_override(&"font_color", ACCENT)
		route.text = "沿原路回到橙色屋檐下，补给箱在站内。"
	else:
		mission.text = "收集并交回补给"
		route.text = "沿林间小路找金色木料和青色罐头。"


func set_prompt(message: String) -> void:
	prompt_panel.visible = not message.is_empty()
	prompt_label.text = message
