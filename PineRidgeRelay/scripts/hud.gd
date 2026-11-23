class_name RelayHUD
extends CanvasLayer

signal restart_requested

const ACCENT := Color("#efbf75")
const MINT := Color("#a6e0b8")
const NIGHT_BLUE := Color("#a6c9fa")
const WARNING := Color("#f39282")

@onready var mission: Label = $Screen/Brief/Mission
@onready var route: Label = $Screen/Brief/Route
@onready var prompt_panel: PanelContainer = $Screen/Prompt
@onready var prompt_label: Label = $Screen/Prompt/Text
@onready var phase_label: Label = $Screen/Survival/Content/Phase
@onready var health_label: Label = $Screen/Survival/Content/Gate
@onready var health_bar: ProgressBar = $Screen/Survival/Content/Health
@onready var raid_label: Label = $Screen/Survival/Content/Raid
@onready var gear: GearPanels = $Screen/Gear
@onready var toast: Label = $Screen/Toast
@onready var result: ColorRect = $Screen/Result
@onready var result_title: Label = $Screen/Result/Card/Content/Title
@onready var result_detail: Label = $Screen/Result/Card/Content/Detail

var _toast_time := 0.0


func _ready() -> void:
	$Screen/Result/Card/Content/Restart.pressed.connect(func(): restart_requested.emit())


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			toast.hide()


func show_supplies(rules: SupplyRules, equipped_tool: int) -> void:
	var wood := rules.carried(SupplyRules.Kind.WOOD)
	var cans := rules.carried(SupplyRules.Kind.CAN)
	var stored_wood := rules.stored(SupplyRules.Kind.WOOD)
	var stored_cans := rules.stored(SupplyRules.Kind.CAN)
	if rules.is_complete():
		mission.text = "补给任务完成"
		mission.add_theme_color_override(&"font_color", MINT)
	elif wood + stored_wood >= SupplyRules.WOOD_TARGET and cans + stored_cans >= SupplyRules.CAN_TARGET:
		mission.text = "返回气象站交付"
		mission.add_theme_color_override(&"font_color", ACCENT)
	else:
		mission.text = "收集补给"
		mission.add_theme_color_override(&"font_color", ACCENT)
	route.text = "已交付  木料 %d/%d  ·  罐头 %d/%d" % [
		stored_wood, SupplyRules.WOOD_TARGET, stored_cans, SupplyRules.CAN_TARGET
	]
	gear.refresh(rules, equipped_tool)


func show_survival(state: SurvivalRules, spawned: int, active: int) -> void:
	var phase := state.phase
	var second := ceili(state.remaining)
	var timer := "%02d:%02d" % [floori(second / 60.0), second % 60]
	var is_day := phase == SurvivalRules.Phase.DAY
	var phase_name := "白天 · 距天黑" if is_day else "夜晚 · 距天亮"
	if phase == SurvivalRules.Phase.WON:
		phase_name = "天亮"
	elif phase == SurvivalRules.Phase.LOST:
		phase_name = "气象站失守"
	phase_label.text = "%s   %s" % [phase_name, timer] if not state.is_over() else phase_name
	var phase_color := ACCENT if is_day else NIGHT_BLUE
	if phase_label.get_theme_color(&"font_color") != phase_color:
		phase_label.add_theme_color_override(&"font_color", phase_color)
	health_label.text = "大门 %d / %d     加固 %d / %d" % [
		state.health, state.max_health(), state.upgrades, SurvivalRules.MAX_UPGRADES
	]
	health_bar.max_value = state.max_health()
	health_bar.value = state.health
	if is_day:
		raid_label.text = "天黑后大门关闭 · 白天按 R 加固"
	else:
		raid_label.text = "感染者  %d 在场   /   %d 已来袭" % [active, spawned]


func set_prompt(message: String) -> void:
	prompt_panel.visible = not message.is_empty()
	prompt_label.text = message


func notify(message: String, seconds := 2.2) -> void:
	toast.text = message
	toast.show()
	_toast_time = seconds


func show_result(won: bool, health: int, delivered: bool) -> void:
	set_prompt("")
	toast.hide()
	result_title.text = "守到天亮 · 胜利" if won else "气象站失守 · 失败"
	result_title.add_theme_color_override(&"font_color", MINT if won else WARNING)
	var delivery := "补给任务完成" if delivered else "补给任务未完成"
	result_detail.text = "剩余门耐久 %d  ·  %s" % [health, delivery]
	result.show()
	$Screen/Result/Card/Content/Restart.grab_focus()
